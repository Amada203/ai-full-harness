#!/usr/bin/env bash
set -euo pipefail

# Adversarial fixtures for the externally issued GitHub candidate grant.
#
# Counterexamples prove: forged self-approval, wrong repository or task,
# path-scope and protected-path violations, expiry, revocation, replay and
# budget exhaustion, malformed grants, symlinked control files, and default
# branch or out-of-scope actions all deny before any write could occur.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PROJECT_NAME="demo-grant-app"
PROJECT_DIR="$TMP_DIR/$PROJECT_NAME"

"$ROOT_DIR/bin/new-full-project" --no-git "$PROJECT_NAME" "$TMP_DIR" >/dev/null

GRANT="$PROJECT_DIR/.autopilot/GITHUB_GRANT.yml"
GRANT_TOOL="$PROJECT_DIR/scripts/check-autopilot-grant.sh"
ARTIFACT="$TMP_DIR/approval-artifact.txt"

printf 'external approval record for task T-1001\n' > "$ARTIFACT"
ARTIFACT_DIGEST="$(shasum -a 256 "$ARTIFACT" | awk '{print $1}')"
TASK_DIGEST="0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

assert_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "Expected file missing: $path" >&2
    exit 1
  fi
}

assert_exit() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  if [[ "$expected" != "$actual" ]]; then
    echo "Expected exit $expected but got $actual: $label" >&2
    exit 1
  fi
}

deny() {
  local label="$1"
  shift
  local output
  set +e
  output="$("$GRANT_TOOL" evaluate "$@" 2>&1)"
  local status=$?
  set -e
  assert_exit 1 "$status" "$label must deny"
  case "$output" in
    *DENY*) ;;
    *) echo "Denial without reason for: $label" >&2; exit 1 ;;
  esac
  echo "deny ok: $label"
}

write_grant() {
  cat > "$GRANT" <<'GRANT'
schema_version: 1
grant_present: true
grant_id: GRANT-2026-0001
issuer: central-control-plane
external_authority_ref: ledger/run-2026-09-06-0001
approval_digest: DIGEST_PLACEHOLDER
repository_id: Amada203/demo-grant-app
task_digest: TASK_PLACEHOLDER
allowed_paths: [src/, docs/]
branch_prefix: autopilot
allowed_actions: [candidate_branch, draft_pr]
expires_at: 2099-01-01T00:00:00Z
max_runs: 5
runs_consumed: 0
revocation_epoch: 1
GRANT
  awk -v digest="$ARTIFACT_DIGEST" '{ gsub(/DIGEST_PLACEHOLDER/, digest); print }' \
    "$GRANT" > "$GRANT.tmp" && mv "$GRANT.tmp" "$GRANT"
  awk -v digest="$TASK_DIGEST" '{ gsub(/TASK_PLACEHOLDER/, digest); print }' \
    "$GRANT" > "$GRANT.tmp" && mv "$GRANT.tmp" "$GRANT"
}

valid_args=(
  --repository-id Amada203/demo-grant-app
  --task-digest "$TASK_DIGEST"
  --action candidate_branch
  --branch autopilot/task-1001
  --path src/app.ts
  --approval-artifact "$ARTIFACT"
  --revocation-epoch 1
)

# 1. Fresh generated project: grant disabled, verifier structurally required.

assert_file "$GRANT"
[[ -x "$GRANT_TOOL" ]] || {
  echo "Expected check-autopilot-grant.sh to be executable" >&2
  exit 1
}

grep -Fqx 'grant_present: false' "$GRANT" || {
  echo "Generated grant must default to disabled" >&2
  exit 1
}

set +e
status_output="$("$GRANT_TOOL" status 2>&1)"
status_exit=$?
set -e
assert_exit 0 "$status_exit" "disabled status must pass"
case "$status_output" in
  *disabled*) ;;
  *) echo "Disabled status must state the disabled boundary" >&2; exit 1 ;;
esac

deny "evaluate without a grant" "${valid_args[@]}"

# 2. A structurally valid grant requires external verification from status.

write_grant

set +e
status_output="$("$GRANT_TOOL" status 2>&1)"
status_exit=$?
set -e
assert_exit 3 "$status_exit" "present grant must demand external verification"
case "$status_output" in
  *EXTERNAL_VERIFICATION_REQUIRED*) ;;
  *) echo "Present grant must require external verification" >&2; exit 1 ;;
esac

# 3. In-scope evaluation is locally eligible.

set +e
allow_output="$("$GRANT_TOOL" evaluate "${valid_args[@]}" 2>&1)"
allow_exit=$?
set -e
assert_exit 0 "$allow_exit" "in-scope candidate must be locally eligible"
case "$allow_output" in
  *ALLOW_CANDIDATE*) ;;
  *) echo "In-scope candidate must be marked ALLOW_CANDIDATE" >&2; exit 1 ;;
esac

# 4. Forged and self-issued approvals.

sed -i '' 's/^issuer: central-control-plane$/issuer: owner/' "$GRANT" 2>/dev/null ||
  sed -i 's/^issuer: central-control-plane$/issuer: owner/' "$GRANT"
deny "self-issued owner approval" "${valid_args[@]}"

write_grant
sed -i '' 's/^issuer: central-control-plane$/issuer: Amada203\/project-autopilot/' "$GRANT" 2>/dev/null ||
  sed -i 's/^issuer: central-control-plane$/issuer: Amada203\/project-autopilot/' "$GRANT"
deny "controller self-approval" "${valid_args[@]}"

write_grant
sed -i '' 's/^external_authority_ref: .*/external_authority_ref: NONE/' "$GRANT" 2>/dev/null ||
  sed -i 's/^external_authority_ref: .*/external_authority_ref: NONE/' "$GRANT"
deny "missing external authority reference" "${valid_args[@]}"

# 5. Identity and objective binding.

write_grant
deny "wrong repository" \
  --repository-id Amada203/other-project \
  --task-digest "$TASK_DIGEST" \
  --action candidate_branch \
  --branch autopilot/task-1001 \
  --path src/app.ts \
  --approval-artifact "$ARTIFACT" \
  --revocation-epoch 1

write_grant
deny "wrong task digest" \
  --repository-id Amada203/demo-grant-app \
  --task-digest ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff \
  --action candidate_branch \
  --branch autopilot/task-1001 \
  --path src/app.ts \
  --approval-artifact "$ARTIFACT" \
  --revocation-epoch 1

# 6. Expiry, revocation, replay, and budget exhaustion.

write_grant
sed -i '' 's/^expires_at: .*/expires_at: 2020-01-01T00:00:00Z/' "$GRANT" 2>/dev/null ||
  sed -i 's/^expires_at: .*/expires_at: 2020-01-01T00:00:00Z/' "$GRANT"
deny "expired grant" "${valid_args[@]}"

write_grant
deny "revoked grant epoch" "${valid_args[@]}" --revocation-epoch 2

write_grant
sed -i '' 's/^runs_consumed: 0$/runs_consumed: 5/' "$GRANT" 2>/dev/null ||
  sed -i 's/^runs_consumed: 0$/runs_consumed: 5/' "$GRANT"
deny "exhausted grant budget" "${valid_args[@]}"

# 7. Path scope, protected paths, parent traversal, and inherent protection.

write_grant
deny "path outside grant scope" "${valid_args[@]}" --path lib/helper.ts

write_grant
cp "$PROJECT_DIR/.autopilot/PROTECTED_PATHS.yml" "$TMP_DIR/PROTECTED_PATHS.yml.backup"
sed -i '' 's/^\(protected_paths: \[.*\)\]$/\1, docs\/]/' "$PROJECT_DIR/.autopilot/PROTECTED_PATHS.yml" 2>/dev/null ||
  sed -i 's/^\(protected_paths: \[.*\)\]$/\1, docs\/]/' "$PROJECT_DIR/.autopilot/PROTECTED_PATHS.yml"
grep -Fq 'docs/]' "$PROJECT_DIR/.autopilot/PROTECTED_PATHS.yml" || {
  echo "Failed to add docs/ to protected paths fixture" >&2
  exit 1
}
deny "protected path overlap" "${valid_args[@]}" --path docs/design.md
mv "$TMP_DIR/PROTECTED_PATHS.yml.backup" "$PROJECT_DIR/.autopilot/PROTECTED_PATHS.yml"

write_grant
deny "parent directory traversal" "${valid_args[@]}" --path "src/../../.env"

write_grant
deny "inherently protected deployment path" "${valid_args[@]}" --path deploy/prod.yaml

# 8. Action and branch boundaries.

write_grant
deny "merge action outside candidate scope" "${valid_args[@]}" \
  --action merge

write_grant
deny "default branch write" "${valid_args[@]}" \
  --branch main

write_grant
deny "branch outside granted namespace" "${valid_args[@]}" \
  --branch feature/experimental

# 9. Approval artifact integrity.

write_grant
deny "missing approval artifact" "${valid_args[@]}" \
  --approval-artifact "$TMP_DIR/absent-artifact.txt"

printf 'tampered approval record\n' > "$TMP_DIR/tampered-artifact.txt"
write_grant
deny "approval artifact digest mismatch" "${valid_args[@]}" \
  --approval-artifact "$TMP_DIR/tampered-artifact.txt"

# 10. Malformed and symlinked control files.

write_grant
awk '{ if ($0 ~ /^task_digest:/) { print; print "issuer_duplicate: x" } else { print } }' \
  "$GRANT" > "$GRANT.tmp" && mv "$GRANT.tmp" "$GRANT"
set +e
"$GRANT_TOOL" status >/dev/null 2>&1
malformed_exit=$?
set -e
assert_exit 1 "$malformed_exit" "unknown grant key must fail structurally"

write_grant
printf 'schema_version: 1\n' > "$TMP_DIR/external-grant.yml"
mv "$GRANT" "$TMP_DIR/GRANT.regular"
ln -s "$TMP_DIR/external-grant.yml" "$GRANT"
set +e
"$GRANT_TOOL" status >/dev/null 2>&1
symlink_exit=$?
set -e
rm -f "$GRANT"
mv "$TMP_DIR/GRANT.regular" "$GRANT"
assert_exit 1 "$symlink_exit" "symlinked grant file must deny"

# 11. Eligibility is suspended when the contract itself fails.

write_grant
cp "$PROJECT_DIR/.autopilot/POLICY.yml" "$TMP_DIR/POLICY.yml.backup"
sed -i '' 's/^risk_level: M$/risk_level: X/' "$PROJECT_DIR/.autopilot/POLICY.yml" 2>/dev/null ||
  sed -i 's/^risk_level: M$/risk_level: X/' "$PROJECT_DIR/.autopilot/POLICY.yml"
deny "suspended contract" "${valid_args[@]}"
mv "$TMP_DIR/POLICY.yml.backup" "$PROJECT_DIR/.autopilot/POLICY.yml"

# 12. Budget consumption is locked, atomic, and bounded.

write_grant
sed -i '' 's/^max_runs: 5$/max_runs: 3/' "$GRANT" 2>/dev/null ||
  sed -i 's/^max_runs: 5$/max_runs: 3/' "$GRANT"

consumed=0
for _ in 1 2 3 4; do
  set +e
  "$GRANT_TOOL" consume-run >/dev/null 2>&1
  consume_exit=$?
  set -e
  [[ "$consume_exit" == 0 ]] && consumed=$((consumed + 1)) || \
    assert_exit 1 "$consume_exit" "over-budget consumption must deny"
done
[[ "$consumed" == 3 ]] || {
  echo "Expected exactly 3 budgeted consumptions, got $consumed" >&2
  exit 1
}
grep -Fqx 'runs_consumed: 3' "$GRANT" || {
  echo "Grant must record the consumed budget" >&2
  exit 1
}

deny "post-exhaustion evaluation" "${valid_args[@]}"

# 13. A disabled grant cannot be re-enabled into eligibility without issuer.

sed -i '' 's/^grant_present: true$/grant_present: false/' "$GRANT" 2>/dev/null ||
  sed -i 's/^grant_present: true$/grant_present: false/' "$GRANT"
deny "re-disabled grant" "${valid_args[@]}"

echo "autopilot grant test passed."
