#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUTOPILOT_DIR="$ROOT_DIR/.autopilot"
CONSTITUTION_FILE="$AUTOPILOT_DIR/CONSTITUTION.yml"
ENROLLMENT_FILE="$AUTOPILOT_DIR/ENROLLMENT.yml"
POLICY_FILE="$AUTOPILOT_DIR/POLICY.yml"
PROTECTED_PATHS_FILE="$AUTOPILOT_DIR/PROTECTED_PATHS.yml"
STATE_FILE="$AUTOPILOT_DIR/AUTOPILOT_STATE"
FINGERPRINTER="$ROOT_DIR/scripts/autopilot-fingerprint.sh"
LIFECYCLE_CHECKER="$ROOT_DIR/scripts/check-lifecycle-gate.sh"

fail() {
  echo "autopilot-contract: $*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage: scripts/check-autopilot-contract.sh [contract|enrollment]
       scripts/check-autopilot-contract.sh protected-diff <base-sha> <head-sha>
USAGE
}

MODE="${1:-contract}"
BASE_REF=""
HEAD_REF=""
case "$MODE" in
  contract|enrollment) ;;
  protected-diff)
    [[ $# -eq 3 ]] || fail "protected-diff requires base and head commit SHAs"
    BASE_REF="$2"
    HEAD_REF="$3"
    [[ "$BASE_REF" =~ ^[0-9a-fA-F]{40}$ ]] || fail "protected-diff base must be a full commit SHA"
    [[ "$HEAD_REF" =~ ^[0-9a-fA-F]{40}$ ]] || fail "protected-diff head must be a full commit SHA"
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *) fail "Unknown validation mode: $MODE" ;;
esac

trim() {
  local value="$1"

  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

strip_matching_quotes() {
  local value="$1"

  case "$value" in
    \"*\")
      value="${value#\"}"
      value="${value%\"}"
      ;;
    \'*\')
      value="${value#\'}"
      value="${value%\'}"
      ;;
  esac
  printf '%s' "$value"
}

reject_shell_metacharacters() {
  local label="$1"
  local value="$2"

  case "$value" in
    *$'\n'*|*$'\r'*|*";"*|*"|"*|*"&"*|*"<"*|*">"*|*"\`"*|*'$'*|*"("*|*")"*|*"{"*|*"}"*|*"#"*)
      fail "Unsafe metacharacter in $label"
      ;;
  esac

  if [[ "$value" =~ (^|[[:space:]])\*[^[:space:]]+ ]]; then
    fail "YAML aliases are not supported in $label"
  fi
}

require_regular_file() {
  local label="$1"
  local path="$2"

  [[ -e "$path" || -L "$path" ]] || fail "Missing required file: $label"
  [[ ! -L "$path" ]] || fail "Required file must not be a symlink: $label"
  [[ -f "$path" ]] || fail "Required path must be a regular file: $label"
}

require_autopilot_structure() {
  [[ -d "$AUTOPILOT_DIR" ]] || fail "Missing Autopilot directory: .autopilot"
  [[ ! -L "$AUTOPILOT_DIR" ]] || fail "Autopilot directory must not be a symlink"

  require_regular_file ".autopilot/CONSTITUTION.yml" "$CONSTITUTION_FILE"
  require_regular_file ".autopilot/ENROLLMENT.yml" "$ENROLLMENT_FILE"
  require_regular_file ".autopilot/POLICY.yml" "$POLICY_FILE"
  require_regular_file ".autopilot/PROTECTED_PATHS.yml" "$PROTECTED_PATHS_FILE"
  require_regular_file ".autopilot/AUTOPILOT_STATE" "$STATE_FILE"

  [[ -x "$FINGERPRINTER" ]] || fail "Autopilot fingerprinter is unavailable"
  [[ -x "$LIFECYCLE_CHECKER" ]] || fail "Lifecycle checker is unavailable"
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

parse_flat_yaml_file() {
  local path="$1"
  local label="$2"
  shift 2
  local allowed_keys=("$@")
  local seen_keys=()
  local line
  local line_number=0
  local key
  local value
  local required

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_number=$((line_number + 1))
    [[ -z "$line" || "$line" == \#* ]] && continue

    [[ "$line" =~ ^([a-z][a-z0-9_]*):[[:space:]]*(.*)$ ]] || \
      fail "Malformed $label line $line_number"

    key="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"
    key_allowed "$key" "${allowed_keys[@]}" || fail "Unknown $label key: $key"
    if [[ ${#seen_keys[@]} -gt 0 ]] && key_allowed "$key" "${seen_keys[@]}"; then
      fail "Duplicate $label key: $key"
    fi
    seen_keys+=("$key")
    reject_shell_metacharacters "$label.$key" "$value"
  done < "$path"

  for required in "${allowed_keys[@]}"; do
    [[ ${#seen_keys[@]} -gt 0 ]] && key_allowed "$required" "${seen_keys[@]}" || \
      fail "Missing required $label key: $required"
  done
}

yaml_value() {
  local path="$1"
  local key="$2"

  awk -v key="$key" '
    index($0, key ":") == 1 {
      sub(/^[^:]*:[[:space:]]*/, "")
      print
      exit
    }
  ' "$path"
}

state_value() {
  local key="$1"

  awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' \
    "$STATE_FILE"
}

require_bool() {
  local label="$1"
  local value="$2"

  case "$value" in
    true|false) ;;
    *) fail "$label must be true or false" ;;
  esac
}

require_yaml_bool() {
  local path="$1"
  local key="$2"

  require_bool "$key" "$(yaml_value "$path" "$key")"
}

list_items() {
  local path="$1"
  local key="$2"
  local label="$3"
  local value
  local inner
  local old_ifs
  local items=()
  local item

  value="$(yaml_value "$path" "$key")"
  [[ "$value" == \[*\] ]] || fail "$label must be a bracketed list"
  [[ "$value" != "[]" ]] || return 0

  inner="${value#[}"
  inner="${inner%]}"
  old_ifs="$IFS"
  IFS=','
  read -r -a items <<< "$inner"
  IFS="$old_ifs"

  for item in "${items[@]}"; do
    item="$(trim "$item")"
    item="$(strip_matching_quotes "$item")"
    [[ -n "$item" ]] || fail "$label contains an empty item"
    reject_shell_metacharacters "$label item" "$item"
    printf '%s\n' "$item"
  done
}

normalize_contract_path() {
  local label="$1"
  local path="$2"

  path="$(trim "$path")"
  path="$(strip_matching_quotes "$path")"

  [[ -n "$path" ]] || fail "$label contains an empty path"
  case "$path" in
    /*) fail "$label must be project-relative: $path" ;;
    *$'\n'*|*$'\r'*) fail "$label contains an ambiguous path" ;;
    *".."*) fail "$label cannot contain parent-directory segments: $path" ;;
    *"*"*) ;;
  esac

  while [[ "$path" == ./* ]]; do
    path="${path#./}"
  done
  while [[ "$path" == *//* ]]; do
    path="${path//\/\//\/}"
  done

  [[ -n "$path" && "$path" != "." && "$path" != "./" ]] || \
    fail "$label cannot allow the project root"
  printf '%s\n' "$path"
}

paths_overlap() {
  local allowed="$1"
  local protected="$2"
  local allowed_dir
  local protected_dir

  case "$protected" in
    *"*"*)
      case "$allowed" in
        $protected) return 0 ;;
      esac
      return 1
      ;;
  esac

  [[ "$allowed" == "$protected" ]] && return 0
  [[ "$protected" == "$allowed/"* ]] && return 0

  if [[ "$protected" == */ ]]; then
    protected_dir="$protected"
    [[ "$allowed" == "${protected_dir%/}" ]] && return 0
    [[ "$allowed" == "$protected_dir"* ]] && return 0
  fi

  if [[ "$allowed" == */ ]]; then
    allowed_dir="$allowed"
    [[ "$protected" == "$allowed_dir"* ]] && return 0
  fi

  return 1
}

is_inherently_protected_path() {
  local path="$1"
  local basename="${path##*/}"

  case "/$path/" in
    */config/*|*/secrets/*|*/deploy/*|*/deployment/*|*/infra/*|*/k8s/*|*/helm/*|*/terraform/*|*/.terraform/*)
      return 0
      ;;
  esac
  case "$basename" in
    .env|.env.*|Dockerfile|docker-compose.yml|docker-compose.*.yml|vercel.json|fly.toml|netlify.toml|render.yaml|*.pem|*.key|*.p12|*.pfx|*.tf|*.tfvars|credentials.*|secrets.*)
      return 0
      ;;
  esac
  return 1
}

parse_state_file() {
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
    [[ -z "$line" || "$line" == \#* ]] && continue

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
    reject_shell_metacharacters "AUTOPILOT_STATE.$key" "$value"
  done < "$STATE_FILE"

  for required in "${allowed_keys[@]}"; do
    [[ ${#seen_keys[@]} -gt 0 ]] && key_allowed "$required" "${seen_keys[@]}" || \
      fail "Missing required Autopilot state key: $required"
  done
}

fingerprint_is_legal() {
  local value="$1"

  [[ "$value" =~ ^(UNRECORDED|sha256:[0-9a-f]{64}|cksum:[0-9]+:[0-9]+)$ ]]
}

require_current_fingerprint() {
  local label="$1"
  local recorded="$2"
  local current="$3"
  local required="$4"

  if [[ "$recorded" == UNRECORDED ]]; then
    [[ "$required" == 0 ]] || fail "$label fingerprint is not recorded"
    return 0
  fi

  [[ "$recorded" == "$current" ]] || fail "$label fingerprint is stale"
}

require_autopilot_structure

parse_flat_yaml_file "$CONSTITUTION_FILE" constitution \
  schema_version \
  direct_default_branch_write \
  self_approve_pull_request \
  modify_autopilot_contract \
  modify_harness_controls \
  read_or_export_secrets \
  run_candidate_code_with_secrets \
  auto_promote_high_risk

parse_flat_yaml_file "$ENROLLMENT_FILE" enrollment \
  schema_version \
  autopilot_enabled \
  controller_repository \
  controller_ref \
  auto_activate_after_stage0 \
  requested_by

parse_flat_yaml_file "$POLICY_FILE" policy \
  schema_version \
  risk_level \
  promotion_lane \
  auto_merge_l \
  auto_promote_m \
  production_deploy \
  daily_budget \
  approved_test_commands \
  allowed_paths

parse_flat_yaml_file "$PROTECTED_PATHS_FILE" protected_paths \
  schema_version \
  protected_paths

parse_state_file

[[ "$(yaml_value "$CONSTITUTION_FILE" schema_version)" == 1 ]] || \
  fail "Unsupported constitution schema"
[[ "$(yaml_value "$ENROLLMENT_FILE" schema_version)" == 1 ]] || \
  fail "Unsupported enrollment schema"
[[ "$(yaml_value "$POLICY_FILE" schema_version)" == 1 ]] || \
  fail "Unsupported policy schema"
[[ "$(yaml_value "$PROTECTED_PATHS_FILE" schema_version)" == 1 ]] || \
  fail "Unsupported protected paths schema"
[[ "$(state_value SCHEMA_VERSION)" == 1 ]] || \
  fail "Unsupported Autopilot state schema"

for constitution_key in \
  direct_default_branch_write \
  self_approve_pull_request \
  modify_autopilot_contract \
  modify_harness_controls \
  read_or_export_secrets \
  run_candidate_code_with_secrets \
  auto_promote_high_risk; do
  [[ "$(yaml_value "$CONSTITUTION_FILE" "$constitution_key")" == false ]] || \
    fail "Immutable constitution capability must remain false: $constitution_key"
done

enrollment_enabled="$(yaml_value "$ENROLLMENT_FILE" autopilot_enabled)"
auto_activate="$(yaml_value "$ENROLLMENT_FILE" auto_activate_after_stage0)"
controller_ref="$(yaml_value "$ENROLLMENT_FILE" controller_ref)"
requested_by="$(yaml_value "$ENROLLMENT_FILE" requested_by)"
controller_repository="$(yaml_value "$ENROLLMENT_FILE" controller_repository)"

require_bool "autopilot_enabled" "$enrollment_enabled"
require_bool "auto_activate_after_stage0" "$auto_activate"
[[ "$requested_by" == owner ]] || fail "requested_by must be owner"
[[ "$controller_repository" == Amada203/project-autopilot ]] || \
  fail "controller_repository must be Amada203/project-autopilot"

if [[ "$enrollment_enabled" == true ]]; then
  [[ "$auto_activate" == true ]] || \
    fail "Enabled enrollment requires auto_activate_after_stage0: true"
  [[ "$controller_ref" =~ ^[0-9a-fA-F]{40}$ ]] || \
    fail "Enabled enrollment requires a full 40-character controller SHA"
else
  [[ "$auto_activate" == false ]] || \
    fail "Disabled enrollment requires auto_activate_after_stage0: false"
  [[ "$controller_ref" == UNCONFIGURED || "$controller_ref" =~ ^[0-9a-fA-F]{40}$ ]] || \
    fail "Disabled enrollment allows only UNCONFIGURED or a pinned controller SHA"
fi

risk_level="$(yaml_value "$POLICY_FILE" risk_level)"
promotion_lane="$(yaml_value "$POLICY_FILE" promotion_lane)"
auto_merge_l="$(yaml_value "$POLICY_FILE" auto_merge_l)"
auto_promote_m="$(yaml_value "$POLICY_FILE" auto_promote_m)"
production_deploy="$(yaml_value "$POLICY_FILE" production_deploy)"
daily_budget="$(yaml_value "$POLICY_FILE" daily_budget)"

case "$risk_level" in
  L|M|H) ;;
  *) fail "risk_level must be L, M, or H" ;;
esac

case "$promotion_lane" in
  observe_only|candidate_pr|canary|auto_merge) ;;
  *) fail "promotion_lane is invalid" ;;
esac

require_bool "auto_merge_l" "$auto_merge_l"
require_bool "auto_promote_m" "$auto_promote_m"
require_bool "production_deploy" "$production_deploy"
[[ "$daily_budget" =~ ^[0-9]+$ ]] || fail "daily_budget must be a non-negative integer"

if [[ "$enrollment_enabled" == false && "$promotion_lane" != observe_only ]]; then
  fail "Disabled enrollment requires promotion_lane: observe_only"
fi

if [[ "$risk_level" == H ]]; then
  [[ "$promotion_lane" != canary && "$promotion_lane" != auto_merge ]] || \
    fail "High-risk policy cannot use automatic promotion lanes"
  [[ "$auto_merge_l" == false && "$auto_promote_m" == false ]] || \
    fail "High-risk policy cannot enable automatic promotion"
fi

protected_items="$(list_items "$PROTECTED_PATHS_FILE" protected_paths "protected_paths")"
allowed_items="$(list_items "$POLICY_FILE" allowed_paths "allowed_paths")"
approved_commands="$(list_items "$POLICY_FILE" approved_test_commands "approved_test_commands")"

[[ -n "$protected_items" ]] || fail "protected_paths must not be empty"
protected_item_block=$'\n'"$protected_items"$'\n'
for required_protected_path in \
  .autopilot/ \
  .ai/ \
  .github/workflows/ \
  .cursor/rules/ \
  AGENTS.md \
  CLAUDE.md \
  GEMINI.md \
  CODEOWNERS \
  scripts/autopilot-fingerprint.sh \
  scripts/architecture.mjs \
  scripts/check-autopilot-contract.sh \
  scripts/check-harness.sh \
  scripts/check-lifecycle-gate.sh \
  scripts/lifecycle-fingerprint.sh \
  scripts/record-lifecycle-gate.sh \
  scripts/transition-autopilot.sh \
  .env \
  '.env.*' \
  config/ \
  secrets/ \
  deploy/ \
  deployment/ \
  infra/ \
  k8s/ \
  helm/ \
  terraform/ \
  .terraform/ \
  Dockerfile \
  docker-compose.yml \
  'docker-compose.*.yml' \
  vercel.json \
  fly.toml \
  netlify.toml \
  render.yaml \
  'credentials.*' \
  'secrets.*'; do
  case "$protected_item_block" in
    *$'\n'"$required_protected_path"$'\n'*) ;;
    *) fail "Missing required protected path: $required_protected_path" ;;
  esac
done

if [[ -n "$allowed_items" && -n "$protected_items" ]]; then
  while IFS= read -r allowed_item; do
    allowed_path="$(normalize_contract_path "allowed_paths" "$allowed_item")"
    case "$allowed_path" in
      *"*"*) fail "allowed_paths cannot contain globs: $allowed_path" ;;
    esac
    while IFS= read -r protected_item; do
      protected_path="$(normalize_contract_path "protected_paths" "$protected_item")"
      if paths_overlap "$allowed_path" "$protected_path"; then
        fail "allowed_paths overlaps protected_paths: $allowed_path"
      fi
    done <<< "$protected_items"
  done <<< "$allowed_items"
fi

autopilot_state="$(state_value STATE)"
state_enabled="$(state_value AUTOPILOT_ENABLED)"
contract_recorded="$(state_value CONTRACT_FINGERPRINT)"
static_contract_recorded="$(state_value STATIC_CONTRACT_FINGERPRINT)"
constitution_recorded="$(state_value CONSTITUTION_FINGERPRINT)"
policy_recorded="$(state_value POLICY_FINGERPRINT)"
consecutive_failures="$(state_value CONSECUTIVE_FAILURES)"
last_transition_at="$(state_value LAST_TRANSITION_AT)"

case "$autopilot_state" in
  NEW|STAGE0_PASSED|GITHUB_CONNECTED|REGISTERED|OBSERVE_ONLY|ACTIVE|PAUSED|REVOKED|SAFE_STOP) ;;
  *) fail "STATE is invalid: $autopilot_state" ;;
esac

require_bool "AUTOPILOT_ENABLED" "$state_enabled"
[[ "$state_enabled" == "$enrollment_enabled" ]] || \
  fail "AUTOPILOT_STATE enabled flag must match enrollment"
fingerprint_is_legal "$contract_recorded" || fail "CONTRACT_FINGERPRINT is invalid"
fingerprint_is_legal "$static_contract_recorded" || \
  fail "STATIC_CONTRACT_FINGERPRINT is invalid"
fingerprint_is_legal "$constitution_recorded" || \
  fail "CONSTITUTION_FINGERPRINT is invalid"
fingerprint_is_legal "$policy_recorded" || fail "POLICY_FINGERPRINT is invalid"
[[ "$consecutive_failures" =~ ^[0-9]+$ ]] || \
  fail "CONSECUTIVE_FAILURES must be a non-negative integer"
case "$last_transition_at" in
  UNRECORDED) ;;
  *)
    [[ "$last_transition_at" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] || \
      fail "LAST_TRANSITION_AT must be UNRECORDED or a UTC timestamp"
    ;;
esac

plan_complete=0
if "$LIFECYCLE_CHECKER" plan >/dev/null 2>&1; then
  plan_complete=1
fi

if [[ "$plan_complete" == 0 ]]; then
  case "$autopilot_state" in
    NEW|STAGE0_PASSED) ;;
    *) fail "Autopilot cannot advance beyond Stage 0 before the plan gate passes" ;;
  esac
fi

if [[ "$enrollment_enabled" == true && "$plan_complete" == 0 ]]; then
  fail "Enabled enrollment requires a passed Stage 0 plan gate"
fi

fingerprints_required=0
if [[ "$enrollment_enabled" == true || "$autopilot_state" != NEW ]]; then
  fingerprints_required=1
fi

contract_current="$("$FINGERPRINTER" contract)"
static_contract_current="$("$FINGERPRINTER" static-contract)"
constitution_current="$("$FINGERPRINTER" constitution)"
policy_current="$("$FINGERPRINTER" policy)"
require_current_fingerprint \
  "Contract" "$contract_recorded" "$contract_current" "$fingerprints_required"
require_current_fingerprint \
  "Static contract" "$static_contract_recorded" "$static_contract_current" "$fingerprints_required"
require_current_fingerprint \
  "Constitution" "$constitution_recorded" "$constitution_current" "$fingerprints_required"
require_current_fingerprint \
  "Policy" "$policy_recorded" "$policy_current" "$fingerprints_required"

if [[ "$autopilot_state" == ACTIVE ]]; then
  [[ "$contract_recorded" == sha256:* ]] || \
    fail "ACTIVE requires a sha256 contract fingerprint"
  [[ "$static_contract_recorded" == sha256:* ]] || \
    fail "ACTIVE requires a sha256 static contract fingerprint"
  [[ "$constitution_recorded" == sha256:* ]] || \
    fail "ACTIVE requires a sha256 constitution fingerprint"
  [[ "$policy_recorded" == sha256:* ]] || \
    fail "ACTIVE requires a sha256 policy fingerprint"
  [[ -n "$approved_commands" ]] || \
    fail "ACTIVE requires at least one approved test command"
fi

if [[ "$MODE" == protected-diff ]]; then
  command -v git >/dev/null 2>&1 || fail "git is required for protected-diff validation"
  git -C "$ROOT_DIR" cat-file -e "${BASE_REF}^{commit}" 2>/dev/null || \
    fail "protected-diff base commit is unavailable"
  git -C "$ROOT_DIR" cat-file -e "${HEAD_REF}^{commit}" 2>/dev/null || \
    fail "protected-diff head commit is unavailable"
  diff_tmp="$(mktemp "${TMPDIR:-/tmp}/autopilot-protected-diff.XXXXXX")"
  if ! git -C "$ROOT_DIR" diff --name-only -z "$BASE_REF" "$HEAD_REF" -- > "$diff_tmp"; then
    rm -f "$diff_tmp"
    fail "Unable to calculate protected-path diff"
  fi
  while IFS= read -r -d '' changed_path; do
    if is_inherently_protected_path "$changed_path"; then
      rm -f "$diff_tmp"
      fail "Protected control path changed in pull request: $changed_path"
    fi
    while IFS= read -r protected_item; do
      protected_path="$(normalize_contract_path "protected_paths" "$protected_item")"
      if paths_overlap "$changed_path" "$protected_path"; then
        rm -f "$diff_tmp"
        fail "Protected control path changed in pull request: $changed_path"
      fi
    done <<< "$protected_items"
  done < "$diff_tmp"
  rm -f "$diff_tmp"
fi

echo "check-autopilot-contract: ok ($autopilot_state)"
