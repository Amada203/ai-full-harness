#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

# Fail-closed verifier for the externally issued GitHub candidate grant.
#
# This command proves local eligibility only. It is not an authorization, it
# cannot verify the external approver's identity, and it never performs a
# remote write. The trusted central control plane remains the authority that
# actually verifies issuer provenance before any candidate branch or draft PR.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GRANT_FILE="$ROOT_DIR/.autopilot/GITHUB_GRANT.yml"
CONTRACT_CHECKER="$ROOT_DIR/scripts/check-autopilot-contract.sh"
LOCK_DIR="$ROOT_DIR/.autopilot/.grant-consume.lock"

EXIT_DENY=1
EXIT_EXTERNAL_REQUIRED=3

fail() {
  echo "autopilot-grant: DENY: $*" >&2
  exit "$EXIT_DENY"
}

external_required() {
  echo "autopilot-grant: EXTERNAL_VERIFICATION_REQUIRED: $*" >&2
  exit "$EXIT_EXTERNAL_REQUIRED"
}

usage() {
  cat <<'USAGE'
Usage:
  scripts/check-autopilot-grant.sh status
  scripts/check-autopilot-grant.sh evaluate --repository-id ID --task-digest DIGEST
      --action ACTION --branch BRANCH --path P [--path P ...]
      --approval-artifact FILE [--revocation-epoch N]
  scripts/check-autopilot-grant.sh consume-run

Actions inside a grant are permanently limited to: candidate_branch, draft_pr.
Exit codes: 0 allow/eligible, 1 deny, 2 usage, 3 structurally valid grant
awaiting external verification.
USAGE
}

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
}

require_regular_grant_file() {
  [[ -d "$ROOT_DIR/.autopilot" ]] || fail "Missing Autopilot directory: .autopilot"
  [[ ! -L "$ROOT_DIR/.autopilot" ]] || fail "Autopilot directory must not be a symlink"
  [[ -e "$GRANT_FILE" || -L "$GRANT_FILE" ]] || \
    fail "Missing grant reference: .autopilot/GITHUB_GRANT.yml"
  [[ ! -L "$GRANT_FILE" ]] || fail "Grant reference must not be a symlink"
  [[ -f "$GRANT_FILE" ]] || fail "Grant reference must be a regular file"
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

parse_grant_file() {
  local allowed_keys=(
    schema_version
    grant_present
    grant_id
    issuer
    external_authority_ref
    approval_digest
    repository_id
    task_digest
    allowed_paths
    branch_prefix
    allowed_actions
    expires_at
    max_runs
    runs_consumed
    revocation_epoch
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

    [[ "$line" =~ ^([a-z][a-z0-9_]*):[[:space:]]*(.*)$ ]] || \
      fail "Malformed grant line $line_number"

    key="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"
    key_allowed "$key" "${allowed_keys[@]}" || fail "Unknown grant key: $key"
    if [[ ${#seen_keys[@]} -gt 0 ]] && key_allowed "$key" "${seen_keys[@]}"; then
      fail "Duplicate grant key: $key"
    fi
    seen_keys+=("$key")
    reject_shell_metacharacters "grant.$key" "$value"
  done < "$GRANT_FILE"

  for required in "${allowed_keys[@]}"; do
    [[ ${#seen_keys[@]} -gt 0 ]] && key_allowed "$required" "${seen_keys[@]}" || \
      fail "Missing required grant key: $required"
  done
}

grant_value() {
  local key="$1"

  awk -v key="$key" '
    index($0, key ":") == 1 {
      sub(/^[^:]*:[[:space:]]*/, "")
      print
      exit
    }
  ' "$GRANT_FILE"
}

require_bool() {
  local label="$1"
  local value="$2"

  case "$value" in
    true|false) ;;
    *) fail "$label must be true or false" ;;
  esac
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

  value="$(awk -v key="$key" '
    index($0, key ":") == 1 {
      sub(/^[^:]*:[[:space:]]*/, "")
      print
      exit
    }
  ' "$path")"
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
  local candidate="$1"
  local scope="$2"

  [[ "$candidate" == "$scope" ]] && return 0
  [[ "$scope" == "$candidate/"* ]] && return 0

  if [[ "$scope" == */ ]]; then
    [[ "$candidate" == "${scope%/}" ]] && return 0
    [[ "$candidate" == "$scope"* ]] && return 0
  fi

  if [[ "$candidate" == */ ]]; then
    [[ "$scope" == "$candidate"* ]] && return 0
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

digest_file() {
  local output

  if command -v shasum >/dev/null 2>&1; then
    output="$(shasum -a 256 < "$1")" || fail "Unable to digest approval artifact"
    printf '%s\n' "${output%% *}"
  elif command -v sha256sum >/dev/null 2>&1; then
    output="$(sha256sum < "$1")" || fail "Unable to digest approval artifact"
    printf '%s\n' "${output%% *}"
  else
    fail "No SHA-256 tool available for approval artifact verification"
  fi
}

[[ $# -ge 1 ]] || {
  usage >&2
  exit 2
}

MODE="$1"
shift

case "$MODE" in
  status|evaluate|consume-run) ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

require_regular_grant_file
parse_grant_file

[[ "$(grant_value schema_version)" == 1 ]] || fail "Unsupported grant schema"

grant_present="$(grant_value grant_present)"
require_bool "grant_present" "$grant_present"

if [[ "$grant_present" == false ]]; then
  if [[ "$MODE" == status ]]; then
    echo "autopilot-grant: disabled (no remote candidate authority)"
    exit 0
  fi
  fail "No grant is present; remote candidate operations are disabled"
fi

grant_id="$(grant_value grant_id)"
issuer="$(grant_value issuer)"
external_authority_ref="$(grant_value external_authority_ref)"
approval_digest="$(grant_value approval_digest)"
grant_repository="$(grant_value repository_id)"
grant_task_digest="$(grant_value task_digest)"
branch_prefix="$(grant_value branch_prefix)"
expires_at="$(grant_value expires_at)"
max_runs="$(grant_value max_runs)"
runs_consumed="$(grant_value runs_consumed)"
revocation_epoch="$(grant_value revocation_epoch)"

if [[ "$MODE" == status ]]; then
  external_required \
    "grant $grant_id is structurally present; issuer provenance requires the trusted central control plane"
fi

# --- Universal structural denies (apply to every granted capability). ------

[[ "$grant_id" != NONE && -n "$grant_id" ]] || fail "grant_id is not issued"
case "$issuer" in
  NONE|""|owner|self|project|human|autopilot|controller|Amada203/project-autopilot)
    fail "issuer cannot be the project, the owner request, or the controller itself"
    ;;
esac
[[ "$external_authority_ref" != NONE && ${#external_authority_ref} -ge 8 ]] || \
  fail "external_authority_ref must reference an external approval source"
[[ "$approval_digest" =~ ^[0-9a-f]{64}$ ]] || \
  fail "approval_digest must be a SHA-256 digest of the external approval artifact"
[[ "$grant_repository" != NONE && -n "$grant_repository" ]] || \
  fail "grant repository identity is missing"
[[ "$grant_task_digest" =~ ^[0-9a-f]{64}$ ]] || \
  fail "task_digest must be a SHA-256 digest of the approved task objective"
[[ "$branch_prefix" != NONE && "$branch_prefix" != */* && "$branch_prefix" != main && "$branch_prefix" != master ]] || \
  fail "branch_prefix must name a non-default branch namespace"
[[ "$expires_at" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] || \
  fail "expires_at must be a UTC timestamp"
[[ "$max_runs" =~ ^[0-9]+$ ]] || fail "max_runs must be a non-negative integer"
[[ "$runs_consumed" =~ ^[0-9]+$ ]] || fail "runs_consumed must be a non-negative integer"
[[ "$revocation_epoch" =~ ^[0-9]+$ ]] || fail "revocation_epoch must be a non-negative integer"

allowed_actions="$(list_items "$GRANT_FILE" allowed_actions allowed_actions)"
allowed_paths="$(list_items "$GRANT_FILE" allowed_paths allowed_paths)"

while IFS= read -r action_item; do
  [[ -n "$action_item" ]] || continue
  case "$action_item" in
    candidate_branch|draft_pr) ;;
    *) fail "grant action is outside the permanently narrow candidate scope: $action_item" ;;
  esac
done <<< "$allowed_actions"

[[ -n "$allowed_actions" ]] || fail "grant lists no allowed actions"

# --- consume-run: atomically consume one budgeted run. ----------------------

if [[ "$MODE" == consume-run ]]; then
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    fail "Another grant consumption is in progress"
  fi
  grant_backup="$(mktemp "${TMPDIR:-/tmp}/autopilot-grant.XXXXXX")"
  cp "$GRANT_FILE" "$grant_backup"
  committed=0
  cleanup() {
    if [[ "$committed" -eq 0 ]]; then
      cp "$grant_backup" "$GRANT_FILE" 2>/dev/null || true
    fi
    rm -f "$grant_backup"
    rmdir "$LOCK_DIR" 2>/dev/null || true
  }
  trap cleanup EXIT INT TERM

  parse_grant_file
  runs_consumed="$(grant_value runs_consumed)"
  max_runs="$(grant_value max_runs)"
  [[ "$runs_consumed" -lt "$max_runs" ]] || \
    fail "grant budget is exhausted ($runs_consumed/$max_runs runs)"

  grant_tmp="$(mktemp "$ROOT_DIR/.autopilot/GITHUB_GRANT.yml.tmp.XXXXXX")"
  awk -v value="$((runs_consumed + 1))" '
    $1 == "runs_consumed:" { print "runs_consumed: " value; next }
    { print }
  ' "$GRANT_FILE" > "$grant_tmp"
  mv "$grant_tmp" "$GRANT_FILE"
  committed=1
  echo "autopilot-grant: consumed run $((runs_consumed + 1))/$max_runs"
  exit 0
fi

# --- evaluate: full fail-closed eligibility decision. -----------------------

requested_repository=""
requested_task_digest=""
requested_action=""
requested_branch=""
requested_revocation_epoch=""
approval_artifact=""
requested_paths=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repository-id|--task-digest|--action|--branch|--approval-artifact)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      case "$1" in
        --repository-id) requested_repository="$2" ;;
        --task-digest) requested_task_digest="$2" ;;
        --action) requested_action="$2" ;;
        --branch) requested_branch="$2" ;;
        --approval-artifact) approval_artifact="$2" ;;
      esac
      shift 2
      ;;
    --path)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      requested_paths+=("$2")
      shift 2
      ;;
    --revocation-epoch)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      requested_revocation_epoch="$2"
      shift 2
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

[[ -n "$requested_repository" ]] || fail "repository identity is required for evaluation"
[[ "$requested_repository" == "$grant_repository" ]] || \
  fail "grant was issued for repository $grant_repository, not $requested_repository"
[[ "$requested_task_digest" == "$grant_task_digest" ]] || \
  fail "task digest does not match the approved task objective"
[[ -n "$requested_revocation_epoch" ]] || \
  fail "current revocation epoch is required for evaluation"
[[ "$requested_revocation_epoch" =~ ^[0-9]+$ ]] || \
  fail "revocation epoch must be a non-negative integer"
[[ "$requested_revocation_epoch" -eq "$revocation_epoch" ]] || \
  fail "grant was revoked (epoch $revocation_epoch, current $requested_revocation_epoch)"

[[ -n "$approval_artifact" ]] || fail "external approval artifact is required for evaluation"
[[ -e "$approval_artifact" || -L "$approval_artifact" ]] || \
  fail "external approval artifact does not exist: $approval_artifact"
[[ ! -L "$approval_artifact" ]] || fail "external approval artifact must not be a symlink"
[[ -f "$approval_artifact" ]] || fail "external approval artifact must be a regular file"
artifact_actual="$(digest_file "$approval_artifact")"
[[ "$artifact_actual" == "$approval_digest" ]] || \
  fail "approval artifact digest does not match the issued grant"

now_utc="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
if [[ ! "$now_utc" < "$expires_at" ]]; then
  fail "grant expired at $expires_at"
fi

[[ "$runs_consumed" -lt "$max_runs" ]] || \
  fail "grant budget is exhausted ($runs_consumed/$max_runs runs)"

case "$requested_action" in
  candidate_branch|draft_pr) ;;
  *) fail "action is outside the permanently narrow candidate scope: $requested_action" ;;
esac

action_allowed=0
while IFS= read -r action_item; do
  [[ "$action_item" == "$requested_action" ]] && action_allowed=1
done <<< "$allowed_actions"
[[ "$action_allowed" -eq 1 ]] || \
  fail "action $requested_action is not listed in the grant"

[[ -n "$requested_branch" ]] || fail "candidate branch is required for evaluation"
case "$requested_branch" in
  main|master)
    fail "default branch writes are never grantable: $requested_branch"
    ;;
  "$branch_prefix"/*) ;;
  *)
    fail "branch $requested_branch is outside the granted $branch_prefix/ namespace"
    ;;
esac

[[ ${#requested_paths[@]} -gt 0 ]] || \
  fail "at least one candidate path is required for evaluation"

protected_list="$(list_items \
  "$ROOT_DIR/.autopilot/PROTECTED_PATHS.yml" protected_paths protected_paths)"

for requested_path in "${requested_paths[@]}"; do
  candidate_path="$(normalize_contract_path "candidate path" "$requested_path")"

  if is_inherently_protected_path "$candidate_path"; then
    fail "candidate path is inherently protected: $candidate_path"
  fi

  in_scope=0
  while IFS= read -r allowed_item; do
    scope_path="$(normalize_contract_path "allowed_paths" "$allowed_item")"
    if paths_overlap "$candidate_path" "$scope_path"; then
      in_scope=1
      break
    fi
  done <<< "$allowed_paths"
  [[ "$in_scope" -eq 1 ]] || \
    fail "candidate path is outside the granted path scope: $candidate_path"

  while IFS= read -r protected_item; do
    [[ -n "$protected_item" ]] || continue
    if paths_overlap "$candidate_path" "$protected_item"; then
      fail "candidate path overlaps protected paths: $candidate_path"
    fi
  done <<< "$protected_list"
done

if ! "$CONTRACT_CHECKER" >/dev/null 2>&1; then
  fail "the Autopilot contract does not currently pass; candidate eligibility is suspended"
fi

echo "autopilot-grant: ALLOW_CANDIDATE (local eligibility only; not an authorization)"
