#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_FILE="$ROOT_DIR/.ai/LIFECYCLE_STATE"
BASELINE_FILE="$ROOT_DIR/.ai/LIFECYCLE_BASELINE"
LOCK_DIR="$ROOT_DIR/.ai/.lifecycle-record.lock"
CHECKER="$ROOT_DIR/scripts/check-lifecycle-gate.sh"
FINGERPRINTER="$ROOT_DIR/scripts/lifecycle-fingerprint.sh"

fail() {
  echo "lifecycle-record: $*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage: scripts/record-lifecycle-gate.sh <gate>

Gates:
  plan design prototype implementation release github retrospective
USAGE
}

[[ $# -eq 1 ]] || {
  usage >&2
  exit 2
}

GATE="$1"
case "$GATE" in
  plan|design|prototype|implementation|release|github|retrospective) ;;
  *) fail "Unknown lifecycle gate: $GATE" ;;
esac

[[ -f "$STATE_FILE" ]] || fail "Missing lifecycle state: .ai/LIFECYCLE_STATE"
[[ -f "$BASELINE_FILE" ]] || fail "Missing lifecycle baseline: .ai/LIFECYCLE_BASELINE"
[[ -x "$CHECKER" ]] || fail "Lifecycle checker is unavailable"
[[ -x "$FINGERPRINTER" ]] || fail "Lifecycle fingerprinter is unavailable"

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  fail "Another lifecycle record operation is in progress"
fi

baseline_backup="$(mktemp "${TMPDIR:-/tmp}/lifecycle-baseline.XXXXXX")"
state_backup="$(mktemp "${TMPDIR:-/tmp}/lifecycle-state.XXXXXX")"
cp "$BASELINE_FILE" "$baseline_backup"
cp "$STATE_FILE" "$state_backup"
committed=0

cleanup() {
  if [[ "$committed" -eq 0 ]]; then
    [[ -f "$baseline_backup" ]] && cp "$baseline_backup" "$BASELINE_FILE"
    [[ -f "$state_backup" ]] && cp "$state_backup" "$STATE_FILE"
  fi
  rm -f "$baseline_backup" "$state_backup"
  rmdir "$LOCK_DIR" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

set_key() {
  local file="$1"
  local key="$2"
  local value="$3"
  local tmp_file="${file}.tmp.$$"

  awk -F= -v key="$key" -v value="$value" '
    BEGIN { found = 0 }
    $1 == key { print key "=" value; found++; next }
    { print }
    END { if (found != 1) exit 42 }
  ' "$file" > "$tmp_file" || {
    rm -f "$tmp_file"
    fail "Unable to update key: $key"
  }
  mv "$tmp_file" "$file"
}

fingerprint_key="$(printf '%s_FINGERPRINT' "$GATE" | tr '[:lower:]' '[:upper:]')"
fingerprint="$($FINGERPRINTER "$GATE")"
set_key "$BASELINE_FILE" "$fingerprint_key" "$fingerprint"

if ! "$CHECKER" "$GATE"; then
  fail "Gate validation failed; lifecycle state and baseline were not advanced"
fi

reset_gate() {
  local gate="$1"
  local status_key
  local baseline_key

  status_key="$(printf '%s_STATUS' "$gate" | tr '[:lower:]' '[:upper:]')"
  baseline_key="$(printf '%s_FINGERPRINT' "$gate" | tr '[:lower:]' '[:upper:]')"
  set_key "$STATE_FILE" "$status_key" BLOCKED
  set_key "$BASELINE_FILE" "$baseline_key" UNRECORDED
}

case "$GATE" in
  plan)
    for downstream in design prototype implementation release github retrospective; do reset_gate "$downstream"; done
    set_key "$STATE_FILE" HUMAN_APPROVAL_REF NONE
    set_key "$STATE_FILE" GITHUB_APPROVAL_REF NONE
    ;;
  design)
    for downstream in prototype implementation release github retrospective; do reset_gate "$downstream"; done
    set_key "$STATE_FILE" HUMAN_APPROVAL_REF NONE
    set_key "$STATE_FILE" GITHUB_APPROVAL_REF NONE
    ;;
  prototype)
    for downstream in implementation release github retrospective; do reset_gate "$downstream"; done
    set_key "$STATE_FILE" HUMAN_APPROVAL_REF NONE
    set_key "$STATE_FILE" GITHUB_APPROVAL_REF NONE
    ;;
  implementation)
    for downstream in release github retrospective; do reset_gate "$downstream"; done
    set_key "$STATE_FILE" HUMAN_APPROVAL_REF NONE
    set_key "$STATE_FILE" GITHUB_APPROVAL_REF NONE
    ;;
  release)
    for downstream in github retrospective; do reset_gate "$downstream"; done
    set_key "$STATE_FILE" GITHUB_APPROVAL_REF NONE
    ;;
  github)
    reset_gate retrospective
    ;;
  retrospective) ;;
esac

set_key "$STATE_FILE" CURRENT_GATE "$GATE"
committed=1
echo "lifecycle-record: $GATE recorded ($fingerprint)"
