#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUTOPILOT_DIR="$ROOT_DIR/.autopilot"
STATE_FILE="$AUTOPILOT_DIR/AUTOPILOT_STATE"
LOCK_DIR="$AUTOPILOT_DIR/.transition.lock"
CHECKER="$ROOT_DIR/scripts/check-autopilot-contract.sh"
LIFECYCLE_CHECKER="$ROOT_DIR/scripts/check-lifecycle-gate.sh"
FINGERPRINTER="$ROOT_DIR/scripts/autopilot-fingerprint.sh"

lock_acquired=0
committed=0
state_backup=""
state_tmp=""

fail() {
  echo "autopilot-transition: $*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage:
  scripts/transition-autopilot.sh <target-state> [reason]
  scripts/transition-autopilot.sh --record-failure <reason>
  scripts/transition-autopilot.sh --accept-policy <reason>

Target states:
  STAGE0_PASSED GITHUB_CONNECTED REGISTERED OBSERVE_ONLY ACTIVE PAUSED REVOKED SAFE_STOP
USAGE
}

cleanup() {
  if [[ "$committed" -eq 0 && -n "$state_backup" && -f "$state_backup" ]]; then
    cp "$state_backup" "$STATE_FILE" 2>/dev/null || true
  fi
  [[ -n "$state_tmp" ]] && rm -f "$state_tmp"
  [[ -n "$state_backup" ]] && rm -f "$state_backup"
  if [[ "$lock_acquired" -eq 1 ]]; then
    rmdir "$LOCK_DIR" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

trim() {
  local value="$1"

  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

reject_unsafe_value() {
  local label="$1"
  local value="$2"

  case "$value" in
    *$'\n'*|*$'\r'*|*";"*|*"|"*|*"&"*|*"<"*|*">"*|*"\`"*|*'$'*|*"("*|*")"*|*"{"*|*"}"*|*"#"*)
      fail "Unsafe metacharacter in $label"
      ;;
  esac
}

require_regular_state_file() {
  [[ -d "$AUTOPILOT_DIR" ]] || fail "Missing Autopilot directory: .autopilot"
  [[ ! -L "$AUTOPILOT_DIR" ]] || fail "Autopilot directory must not be a symlink"
  [[ -e "$STATE_FILE" || -L "$STATE_FILE" ]] || \
    fail "Missing Autopilot state: .autopilot/AUTOPILOT_STATE"
  [[ ! -L "$STATE_FILE" ]] || \
    fail "Autopilot state must not be a symlink"
  [[ -f "$STATE_FILE" ]] || fail "Autopilot state must be a regular file"
  [[ -x "$CHECKER" ]] || fail "Autopilot contract checker is unavailable"
  [[ -x "$LIFECYCLE_CHECKER" ]] || fail "Lifecycle checker is unavailable"
  [[ -x "$FINGERPRINTER" ]] || fail "Autopilot fingerprinter is unavailable"
}

key_allowed() {
  local key="$1"
  shift
  local allowed

  for allowed in "$@"; do
    [[ "$key" == "$allowed" ]] && return 0
  done
  return 1
}

state_value() {
  local key="$1"
  local count

  count="$(awk -F= -v key="$key" '$1 == key { count++ } END { print count + 0 }' \
    "$STATE_FILE")"
  [[ "$count" == 1 ]] || fail "State key must occur exactly once: $key"
  awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' \
    "$STATE_FILE"
}

require_state_syntax() {
  local allowed_keys=(
    SCHEMA_VERSION
    STATE
    AUTOPILOT_ENABLED
    CONTRACT_FINGERPRINT
    STATIC_CONTRACT_FINGERPRINT
    CONSTITUTION_FINGERPRINT
    POLICY_FINGERPRINT
    CONSECUTIVE_FAILURES
    LAST_REASON
    LAST_TRANSITION_AT
  )
  local seen_keys=()
  local line
  local line_number=0
  local key
  local value
  local required

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_number=$((line_number + 1))
    [[ "$line" =~ ^([A-Z][A-Z0-9_]*)=(.*)$ ]] || \
      fail "Malformed Autopilot state line $line_number"
    key="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"
    key_allowed "$key" "${allowed_keys[@]}" || \
      fail "Unknown Autopilot state key: $key"
    if [[ ${#seen_keys[@]} -gt 0 ]] && key_allowed "$key" "${seen_keys[@]}"; then
      fail "Duplicate Autopilot state key: $key"
    fi
    seen_keys+=("$key")
    reject_unsafe_value "AUTOPILOT_STATE.$key" "$value"
  done < "$STATE_FILE"

  for required in "${allowed_keys[@]}"; do
    [[ ${#seen_keys[@]} -gt 0 ]] && key_allowed "$required" "${seen_keys[@]}" || \
      fail "Missing required Autopilot state key: $required"
  done
}

legal_state() {
  case "$1" in
    NEW|STAGE0_PASSED|GITHUB_CONNECTED|REGISTERED|OBSERVE_ONLY|ACTIVE|PAUSED|REVOKED|SAFE_STOP) ;;
    *) return 1 ;;
  esac
}

legal_transition() {
  local from_state="$1"
  local to_state="$2"

  [[ "$from_state" != "$to_state" ]] || return 1

  case "$from_state:$to_state" in
    NEW:STAGE0_PASSED|\
    STAGE0_PASSED:GITHUB_CONNECTED|\
    GITHUB_CONNECTED:REGISTERED|\
    REGISTERED:OBSERVE_ONLY|\
    OBSERVE_ONLY:ACTIVE|\
    ACTIVE:PAUSED|\
    ACTIVE:REVOKED|\
    ACTIVE:SAFE_STOP|\
    PAUSED:ACTIVE|\
    PAUSED:REVOKED|\
    SAFE_STOP:PAUSED|\
    SAFE_STOP:REVOKED)
      return 0
      ;;
  esac

  return 1
}

reason_required() {
  local from_state="$1"
  local to_state="$2"

  case "$to_state" in
    GITHUB_CONNECTED|REGISTERED|ACTIVE|REVOKED) return 0 ;;
  esac

  [[ "$from_state" == SAFE_STOP ]] && return 0
  return 1
}

require_reason() {
  local reason="$1"

  reason="$(trim "$reason")"
  [[ -n "$reason" ]] || fail "This transition requires a non-empty reason"
  reject_unsafe_value "reason" "$reason"
  printf '%s' "$reason"
}

optional_reason() {
  local fallback="$1"
  local reason="$2"

  if [[ -z "$(trim "$reason")" ]]; then
    reason="$fallback"
  fi
  reason="$(trim "$reason")"
  reject_unsafe_value "reason" "$reason"
  printf '%s' "$reason"
}

fingerprint_is_legal() {
  local value="$1"

  [[ "$value" =~ ^(UNRECORDED|sha256:[0-9a-f]{64}|cksum:[0-9]+:[0-9]+)$ ]]
}

require_current_recorded_fingerprint() {
  local label="$1"
  local recorded="$2"
  local current="$3"

  fingerprint_is_legal "$recorded" || fail "$label fingerprint is invalid"
  if [[ "$recorded" != UNRECORDED && "$recorded" != "$current" ]]; then
    fail "$label fingerprint is stale"
  fi
}

write_state_file() {
  local next_state="$1"
  local failures="$2"
  local reason="$3"
  local timestamp="$4"
  local enabled="$5"
  local contract_fingerprint="$6"
  local constitution_fingerprint="$7"
  local policy_fingerprint="$8"
  local static_contract_fingerprint="$9"

  state_tmp="$(mktemp "$AUTOPILOT_DIR/AUTOPILOT_STATE.tmp.XXXXXX")"
  {
    printf 'SCHEMA_VERSION=1\n'
    printf 'STATE=%s\n' "$next_state"
    printf 'AUTOPILOT_ENABLED=%s\n' "$enabled"
    printf 'CONTRACT_FINGERPRINT=%s\n' "$contract_fingerprint"
    printf 'STATIC_CONTRACT_FINGERPRINT=%s\n' "$static_contract_fingerprint"
    printf 'CONSTITUTION_FINGERPRINT=%s\n' "$constitution_fingerprint"
    printf 'POLICY_FINGERPRINT=%s\n' "$policy_fingerprint"
    printf 'CONSECUTIVE_FAILURES=%s\n' "$failures"
    printf 'LAST_REASON=%s\n' "$reason"
    printf 'LAST_TRANSITION_AT=%s\n' "$timestamp"
  } > "$state_tmp"
  mv "$state_tmp" "$STATE_FILE" || fail "Unable to atomically update Autopilot state"
  state_tmp=""
}

join_reason_args() {
  local reason=""
  local part

  for part in "$@"; do
    if [[ -z "$reason" ]]; then
      reason="$part"
    else
      reason="$reason $part"
    fi
  done
  printf '%s' "$reason"
}

[[ $# -ge 1 ]] || {
  usage >&2
  exit 2
}

ACTION=transition
TARGET_STATE="$1"
shift

if [[ "$TARGET_STATE" == -h || "$TARGET_STATE" == --help ]]; then
  usage
  exit 0
fi

if [[ "$TARGET_STATE" == --record-failure ]]; then
  ACTION=record_failure
elif [[ "$TARGET_STATE" == --accept-policy ]]; then
  ACTION=accept_policy
else
  legal_state "$TARGET_STATE" || fail "Unknown target state: $TARGET_STATE"
fi

reason_input="$(join_reason_args "$@")"

require_regular_state_file
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  fail "Another Autopilot transition is in progress"
fi
lock_acquired=1

state_backup="$(mktemp "${TMPDIR:-/tmp}/autopilot-state.XXXXXX")"
cp "$STATE_FILE" "$state_backup"

require_state_syntax

current_state="$(state_value STATE)"
enabled="$(state_value AUTOPILOT_ENABLED)"
failures="$(state_value CONSECUTIVE_FAILURES)"
contract_recorded="$(state_value CONTRACT_FINGERPRINT)"
static_contract_recorded="$(state_value STATIC_CONTRACT_FINGERPRINT)"
constitution_recorded="$(state_value CONSTITUTION_FINGERPRINT)"
policy_recorded="$(state_value POLICY_FINGERPRINT)"

legal_state "$current_state" || fail "Current STATE is invalid: $current_state"
case "$enabled" in
  true|false) ;;
  *) fail "AUTOPILOT_ENABLED must be true or false" ;;
esac
[[ "$failures" =~ ^[0-9]+$ ]] || \
  fail "CONSECUTIVE_FAILURES must be a non-negative integer"

contract_current="$("$FINGERPRINTER" contract)"
static_contract_current="$("$FINGERPRINTER" static-contract)"
constitution_current="$("$FINGERPRINTER" constitution)"
policy_current="$("$FINGERPRINTER" policy)"
require_current_recorded_fingerprint \
  "Constitution" "$constitution_recorded" "$constitution_current"
require_current_recorded_fingerprint \
  "Static contract" "$static_contract_recorded" "$static_contract_current"
if [[ "$ACTION" != accept_policy ]]; then
  require_current_recorded_fingerprint "Contract" "$contract_recorded" "$contract_current"
  require_current_recorded_fingerprint "Policy" "$policy_recorded" "$policy_current"
else
  fingerprint_is_legal "$contract_recorded" || fail "Contract fingerprint is invalid"
  fingerprint_is_legal "$policy_recorded" || fail "Policy fingerprint is invalid"
fi

timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

if [[ "$ACTION" == accept_policy ]]; then
  case "$current_state" in
    OBSERVE_ONLY|PAUSED) ;;
    *) fail "Policy changes may be accepted only while OBSERVE_ONLY or PAUSED" ;;
  esac
  reason="$(require_reason "$reason_input")"
  write_state_file "$current_state" "$failures" "$reason" "$timestamp" "$enabled" \
    "$contract_current" "$constitution_current" "$policy_current" "$static_contract_current"
  "$CHECKER" >/dev/null
  committed=1
  echo "autopilot-transition: accepted reviewed policy ($current_state)"
  exit 0
fi

if [[ "$ACTION" == record_failure ]]; then
  [[ "$current_state" == ACTIVE ]] || \
    fail "Failures may be recorded only while Autopilot is ACTIVE"
  reason="$(require_reason "$reason_input")"
  failures=$((failures + 1))
  next_state="$current_state"
  if [[ "$failures" -ge 3 ]]; then
    next_state=SAFE_STOP
  fi

  write_state_file "$next_state" "$failures" "$reason" "$timestamp" "$enabled" \
    "$contract_current" "$constitution_current" "$policy_current" "$static_contract_current"
  "$CHECKER" >/dev/null
  committed=1
  echo "autopilot-transition: recorded failure $failures ($next_state)"
  exit 0
fi

if ! legal_transition "$current_state" "$TARGET_STATE"; then
  fail "Illegal Autopilot transition: $current_state -> $TARGET_STATE"
fi

if reason_required "$current_state" "$TARGET_STATE"; then
  reason="$(require_reason "$reason_input")"
else
  reason="$(optional_reason "Transition to $TARGET_STATE" "$reason_input")"
fi

if [[ "$TARGET_STATE" == ACTIVE && "$enabled" != true ]]; then
  fail "Cannot enter ACTIVE while Autopilot enrollment is disabled"
fi

if [[ "$TARGET_STATE" == STAGE0_PASSED ]]; then
  "$LIFECYCLE_CHECKER" plan >/dev/null || \
    fail "STAGE0_PASSED requires a passed Stage 0 plan gate"
elif [[ "$current_state" != NEW ]]; then
  "$CHECKER" >/dev/null
fi

write_state_file "$TARGET_STATE" 0 "$reason" "$timestamp" "$enabled" \
  "$contract_current" "$constitution_current" "$policy_current" "$static_contract_current"
"$CHECKER" >/dev/null
committed=1
echo "autopilot-transition: $current_state -> $TARGET_STATE"
