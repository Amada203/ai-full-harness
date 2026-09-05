#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

PROJECT_NAME="autopilot-contract-app"
PROJECT_DIR="$TEST_DIR/$PROJECT_NAME"

fail() {
  echo "$*" >&2
  exit 1
}

expect_command_failure_without_stdout() {
  local label="$1"
  shift

  if "$@" >"$TEST_DIR/fingerprint.out" 2>"$TEST_DIR/fingerprint.err"; then
    fail "$label"
  fi
  [[ ! -s "$TEST_DIR/fingerprint.out" ]] || \
    fail "$label (unexpected stdout: $(cat "$TEST_DIR/fingerprint.out"))"
}

expect_fingerprint_failure() {
  local label="$1"
  local target="$2"

  expect_command_failure_without_stdout \
    "$label" "$AUTOPILOT_FINGERPRINT" "$target"
}

expect_contract_success() {
  local label="$1"
  shift

  if ! "$@" >"$TEST_DIR/contract.out" 2>"$TEST_DIR/contract.err"; then
    fail "$label (stderr: $(cat "$TEST_DIR/contract.err"))"
  fi
}

expect_contract_failure() {
  local label="$1"
  shift

  if "$@" >"$TEST_DIR/contract.out" 2>"$TEST_DIR/contract.err"; then
    fail "$label"
  fi
  [[ ! -s "$TEST_DIR/contract.out" ]] || \
    fail "$label (unexpected stdout: $(cat "$TEST_DIR/contract.out"))"
  [[ -s "$TEST_DIR/contract.err" ]] || \
    fail "$label (missing failure reason)"
}

set_kv_value() {
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
    fail "Unable to set $key in $file"
  }
  mv "$tmp_file" "$file"
}

write_stage0_plan_pass() {
  cat > "$PROJECT_DIR/docs/lifecycle/PROBLEM_FRAMING.md" <<'EOF'
# Problem Framing

Risk Level: M

## Observed Facts

The project is a local validator fixture.

## Surface Request

Enable Autopilot only after lifecycle gates are satisfied.

## U-Shaped Descent to the Root Need

The root need is controlled automation, not unsupervised authority expansion.

## Core Goal and Success Measures

Autopilot may run only when the owner contract and Stage 0 evidence are fresh.

## First-Principles Constraints

The controller cannot write protected control paths or use unpinned code.

## Non-Goals and Rejected Pseudo-Requirements

No direct default-branch writes, no secret reads, and no self approval.

## Risk Classification

| Trigger | Answer | Evidence |
|---|---|---|
| Sensitive data, identity, secrets, or authorization | no | Local fixture only. |
| Destructive, irreversible, or migration behavior | no | Validator fixture only. |
| Financial, legal, medical, safety, or regulated outcome | no | No regulated output. |
| Autonomous AI decision or consequential external publication | yes | Autopilot is an autonomous controller. |
| Production security or broad blast radius | no | No production access. |

## Risk-Level Rationale

Risk Level M because autonomous controller enrollment is being validated.

## Plan Gate Decision

Decision: PASS. Decision maker: test fixture. Date: 2026-09-04. Evidence:
this file.
EOF

  set_kv_value "$PROJECT_DIR/.ai/LIFECYCLE_STATE" PLAN_STATUS PASS
  set_kv_value "$PROJECT_DIR/.ai/LIFECYCLE_BASELINE" PLAN_FINGERPRINT \
    "$("$PROJECT_DIR/scripts/lifecycle-fingerprint.sh" plan)"
}

write_enrollment() {
  local enabled="$1"
  local controller_ref="$2"
  local auto_activate="$3"

  cat > "$ENROLLMENT_PATH" <<EOF
schema_version: 1
autopilot_enabled: $enabled
controller_repository: Amada203/project-autopilot
controller_ref: $controller_ref
auto_activate_after_stage0: $auto_activate
requested_by: owner
EOF
}

write_policy() {
  local risk="$1"
  local lane="$2"
  local auto_merge_l="$3"
  local auto_promote_m="$4"
  local production_deploy="$5"
  local daily_budget="$6"
  local approved_commands="$7"
  local allowed_paths="$8"

  cat > "$POLICY_PATH" <<EOF
schema_version: 1
risk_level: $risk
promotion_lane: $lane
auto_merge_l: $auto_merge_l
auto_promote_m: $auto_promote_m
production_deploy: $production_deploy
daily_budget: $daily_budget
approved_test_commands: $approved_commands
allowed_paths: $allowed_paths
EOF
}

write_state() {
  local state="$1"
  local enabled="$2"
  local contract_fingerprint="$3"
  local constitution_fingerprint="$4"
  local policy_fingerprint="$5"
  local static_contract_fingerprint="${6:-UNRECORDED}"

  cat > "$STATE_PATH" <<EOF
SCHEMA_VERSION=1
STATE=$state
AUTOPILOT_ENABLED=$enabled
CONTRACT_FINGERPRINT=$contract_fingerprint
STATIC_CONTRACT_FINGERPRINT=$static_contract_fingerprint
CONSTITUTION_FINGERPRINT=$constitution_fingerprint
POLICY_FINGERPRINT=$policy_fingerprint
CONSECUTIVE_FAILURES=0
LAST_REASON=Test fixture state.
LAST_TRANSITION_AT=UNRECORDED
EOF
}

record_current_autopilot_fingerprints() {
  set_kv_value "$STATE_PATH" CONTRACT_FINGERPRINT \
    "$("$AUTOPILOT_FINGERPRINT" contract)"
  set_kv_value "$STATE_PATH" STATIC_CONTRACT_FINGERPRINT \
    "$("$AUTOPILOT_FINGERPRINT" static-contract)"
  set_kv_value "$STATE_PATH" CONSTITUTION_FINGERPRINT \
    "$("$AUTOPILOT_FINGERPRINT" constitution)"
  set_kv_value "$STATE_PATH" POLICY_FINGERPRINT \
    "$("$AUTOPILOT_FINGERPRINT" policy)"
}

expect_transition_success() {
  local label="$1"
  shift

  if ! "$@" >"$TEST_DIR/transition.out" 2>"$TEST_DIR/transition.err"; then
    fail "$label (stderr: $(cat "$TEST_DIR/transition.err"))"
  fi
}

expect_transition_failure() {
  local label="$1"
  shift

  if "$@" >"$TEST_DIR/transition.out" 2>"$TEST_DIR/transition.err"; then
    fail "$label"
  fi
  [[ ! -s "$TEST_DIR/transition.out" ]] || \
    fail "$label (unexpected stdout: $(cat "$TEST_DIR/transition.out"))"
  [[ -s "$TEST_DIR/transition.err" ]] || \
    fail "$label (missing failure reason)"
}

state_file_value() {
  local key="$1"

  awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' \
    "$STATE_PATH"
}

assert_state_value() {
  local key="$1"
  local expected="$2"
  local actual

  actual="$(state_file_value "$key")"
  [[ "$actual" == "$expected" ]] || \
    fail "Expected $key=$expected; found $actual"
}

prepare_enabled_autopilot_state() {
  local state="$1"

  write_stage0_plan_pass
  write_enrollment true 0123456789abcdef0123456789abcdef01234567 true
  write_policy M candidate_pr false false false 1 "[npm test -- --run]" "[src/, tests/]"
  write_state "$state" true UNRECORDED UNRECORDED UNRECORDED
  record_current_autopilot_fingerprints
}

transition_pair_is_legal() {
  local from_state="$1"
  local to_state="$2"

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

"$ROOT_DIR/bin/new-full-project" --no-git "$PROJECT_NAME" "$TEST_DIR" >/dev/null

CONSTITUTION_PATH="$PROJECT_DIR/.autopilot/CONSTITUTION.yml"
ENROLLMENT_PATH="$PROJECT_DIR/.autopilot/ENROLLMENT.yml"
POLICY_PATH="$PROJECT_DIR/.autopilot/POLICY.yml"
OBJECTIVES_PATH="$PROJECT_DIR/.autopilot/OBJECTIVES.md"
PROTECTED_PATHS_PATH="$PROJECT_DIR/.autopilot/PROTECTED_PATHS.yml"
AUTOPILOT_DIR="$PROJECT_DIR/.autopilot"
STATE_PATH="$PROJECT_DIR/.autopilot/AUTOPILOT_STATE"
AUTOPILOT_FINGERPRINT="$PROJECT_DIR/scripts/autopilot-fingerprint.sh"
CHECK_AUTOPILOT="$PROJECT_DIR/scripts/check-autopilot-contract.sh"
TRANSITION_AUTOPILOT="$PROJECT_DIR/scripts/transition-autopilot.sh"
CHECK_HARNESS="$PROJECT_DIR/scripts/check-harness.sh"

[[ -f "$CONSTITUTION_PATH" ]] || fail "Missing required autopilot constitution: $CONSTITUTION_PATH"
[[ -f "$ENROLLMENT_PATH" ]] || fail "Missing required autopilot enrollment: $ENROLLMENT_PATH"
[[ -f "$POLICY_PATH" ]] || fail "Missing required autopilot policy: $POLICY_PATH"
[[ -f "$OBJECTIVES_PATH" ]] || fail "Missing required autopilot objectives: $OBJECTIVES_PATH"
[[ -f "$PROTECTED_PATHS_PATH" ]] || fail "Missing required autopilot protected paths: $PROTECTED_PATHS_PATH"
[[ -f "$STATE_PATH" ]] || fail "Missing required autopilot state: $STATE_PATH"

grep -Fxq "schema_version: 1" "$CONSTITUTION_PATH" || \
  fail "Expected schema_version: 1 in autopilot constitution"
grep -Fxq "direct_default_branch_write: false" "$CONSTITUTION_PATH" || \
  fail "Expected direct_default_branch_write: false in autopilot constitution"
grep -Fxq "self_approve_pull_request: false" "$CONSTITUTION_PATH" || \
  fail "Expected self_approve_pull_request: false in autopilot constitution"
grep -Fxq "modify_autopilot_contract: false" "$CONSTITUTION_PATH" || \
  fail "Expected modify_autopilot_contract: false in autopilot constitution"
grep -Fxq "modify_harness_controls: false" "$CONSTITUTION_PATH" || \
  fail "Expected modify_harness_controls: false in autopilot constitution"
grep -Fxq "read_or_export_secrets: false" "$CONSTITUTION_PATH" || \
  fail "Expected read_or_export_secrets: false in autopilot constitution"
grep -Fxq "run_candidate_code_with_secrets: false" "$CONSTITUTION_PATH" || \
  fail "Expected run_candidate_code_with_secrets: false in autopilot constitution"
grep -Fxq "auto_promote_high_risk: false" "$CONSTITUTION_PATH" || \
  fail "Expected auto_promote_high_risk: false in autopilot constitution"
grep -Fxq "autopilot_enabled: false" "$ENROLLMENT_PATH" || \
  fail "Expected autopilot_enabled: false in autopilot enrollment"
grep -Fxq "controller_ref: UNCONFIGURED" "$ENROLLMENT_PATH" || \
  fail "Expected controller_ref: UNCONFIGURED in autopilot enrollment"
grep -Fxq "risk_level: M" "$POLICY_PATH" || \
  fail "Expected risk_level: M in autopilot policy"
grep -Fxq "promotion_lane: observe_only" "$POLICY_PATH" || \
  fail "Expected promotion_lane: observe_only in autopilot policy"
grep -Fxq "daily_budget: 0" "$POLICY_PATH" || \
  fail "Expected daily_budget: 0 in autopilot policy"
grep -Fxq "approved_test_commands: []" "$POLICY_PATH" || \
  fail "Expected approved_test_commands: [] in autopilot policy"
grep -Fq 'scripts/check-autopilot-contract.sh' "$PROTECTED_PATHS_PATH" || \
  fail "Expected validator script to be protected"
grep -Fq 'terraform/' "$PROTECTED_PATHS_PATH" || \
  fail "Expected infrastructure configuration to be protected"
grep -Fq 'credentials.*' "$PROTECTED_PATHS_PATH" || \
  fail "Expected private credential files to be protected"
grep -Fq 'docker-compose.*.yml' "$PROTECTED_PATHS_PATH" || \
  fail "Expected canonical autopilot protected paths"
grep -Fqx '<!-- REQUIRED: Stage 0 objective and measurable success criteria -->' "$OBJECTIVES_PATH" || \
  fail "Expected canonical required objective marker"
grep -Fxq "STATE=NEW" "$STATE_PATH" || \
  fail "Expected STATE=NEW in default autopilot state"
grep -Fxq "AUTOPILOT_ENABLED=false" "$STATE_PATH" || \
  fail "Expected AUTOPILOT_ENABLED=false in default autopilot state"
grep -Fxq "LAST_REASON=Initial generated state." "$STATE_PATH" || \
  fail "Expected LAST_REASON=Initial generated state. in default autopilot state"
grep -Fxq "CONSTITUTION_FINGERPRINT=UNRECORDED" "$STATE_PATH" || \
  fail "Expected CONSTITUTION_FINGERPRINT=UNRECORDED in default autopilot state"
grep -Fxq "CONTRACT_FINGERPRINT=UNRECORDED" "$STATE_PATH" || \
  fail "Expected CONTRACT_FINGERPRINT=UNRECORDED in default autopilot state"
grep -Fxq "STATIC_CONTRACT_FINGERPRINT=UNRECORDED" "$STATE_PATH" || \
  fail "Expected STATIC_CONTRACT_FINGERPRINT=UNRECORDED in default autopilot state"
grep -Fxq "LAST_TRANSITION_AT=UNRECORDED" "$STATE_PATH" || \
  fail "Expected LAST_TRANSITION_AT=UNRECORDED in default autopilot state"

[[ -f "$AUTOPILOT_FINGERPRINT" ]] || \
  fail "Missing autopilot fingerprinter: $AUTOPILOT_FINGERPRINT"
[[ -x "$AUTOPILOT_FINGERPRINT" ]] || \
  fail "Expected autopilot-fingerprint.sh to be executable"
[[ -f "$CHECK_AUTOPILOT" ]] || \
  fail "Missing autopilot contract validator: $CHECK_AUTOPILOT"
[[ -x "$CHECK_AUTOPILOT" ]] || \
  fail "Expected check-autopilot-contract.sh to be executable"
[[ -f "$TRANSITION_AUTOPILOT" ]] || \
  fail "Missing autopilot transition command: $TRANSITION_AUTOPILOT"
[[ -x "$TRANSITION_AUTOPILOT" ]] || \
  fail "Expected transition-autopilot.sh to be executable"

CONSTITUTION_DIGEST="$($AUTOPILOT_FINGERPRINT constitution)" || \
  fail "Expected constitution fingerprinting to succeed"
case "$CONSTITUTION_DIGEST" in
  sha256:*|cksum:*) ;;
  *) fail "Expected an algorithm-prefixed constitution digest; found: $CONSTITUTION_DIGEST" ;;
esac

BASE_CONTRACT_DIGEST="$($AUTOPILOT_FINGERPRINT contract)" || \
  fail "Expected contract fingerprinting to succeed"
for static_path in \
  "$CONSTITUTION_PATH" \
  "$ENROLLMENT_PATH" \
  "$OBJECTIVES_PATH" \
  "$POLICY_PATH" \
  "$PROTECTED_PATHS_PATH"; do
  cp "$static_path" "$TEST_DIR/static-control.original"
  printf '\n# fingerprint mutation\n' >> "$static_path"
  MUTATED_CONTRACT_DIGEST="$($AUTOPILOT_FINGERPRINT contract)" || \
    fail "Expected mutated static control file to remain fingerprintable: $static_path"
  [[ "$MUTATED_CONTRACT_DIGEST" != "$BASE_CONTRACT_DIGEST" ]] || \
    fail "Expected every static control file to affect the contract digest: $static_path"
  cp "$TEST_DIR/static-control.original" "$static_path"
done

cp "$STATE_PATH" "$TEST_DIR/AUTOPILOT_STATE.original"
printf '\n# mutable state mutation\n' >> "$STATE_PATH"
STATE_MUTATED_CONTRACT_DIGEST="$($AUTOPILOT_FINGERPRINT contract)" || \
  fail "Expected mutable Autopilot state to remain outside the contract scope"
[[ "$STATE_MUTATED_CONTRACT_DIGEST" == "$BASE_CONTRACT_DIGEST" ]] || \
  fail "Expected AUTOPILOT_STATE changes not to affect the contract digest"
cp "$TEST_DIR/AUTOPILOT_STATE.original" "$STATE_PATH"

mv "$PROTECTED_PATHS_PATH" "$TEST_DIR/PROTECTED_PATHS.yml.missing"
expect_fingerprint_failure \
  "Expected a late producer failure to return no partial fingerprint" contract
mv "$TEST_DIR/PROTECTED_PATHS.yml.missing" "$PROTECTED_PATHS_PATH"

FALLBACK_BIN="$TEST_DIR/fallback-bin"
mkdir -p "$FALLBACK_BIN"
for tool in bash dirname find cksum; do
  ln -s "$(command -v "$tool")" "$FALLBACK_BIN/$tool"
done
CKSUM_FALLBACK_DIGEST="$(PATH="$FALLBACK_BIN" \
  "$AUTOPILOT_FINGERPRINT" constitution)" || \
  fail "Expected fingerprinting to fall back to cksum"
case "$CKSUM_FALLBACK_DIGEST" in
  cksum:*:*) ;;
  *) fail "Expected a cksum-prefixed fallback digest; found: $CKSUM_FALLBACK_DIGEST" ;;
esac

MANIFEST_HASH_BIN="$TEST_DIR/manifest-hash-bin"
MANIFEST_CAPTURE="$TEST_DIR/contract-manifest"
mkdir -p "$MANIFEST_HASH_BIN"
cat > "$MANIFEST_HASH_BIN/shasum" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

payload="$(cat)"
case "$payload" in
  *'PATH_LENGTH='*) printf '%s\n' "$payload" > "$MANIFEST_CAPTURE" ;;
esac
printf '%064d  -\n' 7
EOF
chmod +x "$MANIFEST_HASH_BIN/shasum"
PATH="$MANIFEST_HASH_BIN:$PATH" MANIFEST_CAPTURE="$MANIFEST_CAPTURE" \
  "$AUTOPILOT_FINGERPRINT" contract >/dev/null || \
  fail "Expected contract manifest capture to succeed"
[[ -f "$MANIFEST_CAPTURE" ]] || fail "Expected final contract manifest input to be captured"
CAPTURED_MANIFEST="$(cat "$MANIFEST_CAPTURE")"
for relative in \
  .autopilot/CONSTITUTION.yml \
  .autopilot/ENROLLMENT.yml \
  .autopilot/OBJECTIVES.md \
  .autopilot/POLICY.yml \
  .autopilot/PROTECTED_PATHS.yml; do
  manifest_record="PATH_LENGTH=${#relative}"$'\n'"PATH=$relative"
  case "$CAPTURED_MANIFEST" in
    *"$manifest_record"*) ;;
    *) fail "Expected final contract manifest to contain framed path: $relative" ;;
  esac
done

FAIL_FIND_BIN="$TEST_DIR/fail-find-bin"
REAL_FIND="$(command -v find)"
mkdir -p "$FAIL_FIND_BIN"
cat > "$FAIL_FIND_BIN/find" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

"$REAL_FIND" "$@"
exit 9
EOF
chmod +x "$FAIL_FIND_BIN/find"
expect_command_failure_without_stdout \
  "Expected a failing path producer to fail closed" \
  env PATH="$FAIL_FIND_BIN:$PATH" REAL_FIND="$REAL_FIND" \
  "$AUTOPILOT_FINGERPRINT" contract

FAIL_ONCE_HASH_BIN="$TEST_DIR/fail-once-hash-bin"
FAIL_ONCE_COUNTER="$TEST_DIR/fail-once-hash-counter"
mkdir -p "$FAIL_ONCE_HASH_BIN"
cat > "$FAIL_ONCE_HASH_BIN/shasum" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

cat >/dev/null
count=0
if [[ -f "$FAIL_ONCE_COUNTER" ]]; then
  read -r count < "$FAIL_ONCE_COUNTER"
fi
count=$((count + 1))
printf '%s\n' "$count" > "$FAIL_ONCE_COUNTER"
printf '%064d  -\n' 8
[[ "$count" -ne 1 ]]
EOF
chmod +x "$FAIL_ONCE_HASH_BIN/shasum"
expect_command_failure_without_stdout \
  "Expected a single control-file digest producer failure to fail closed" \
  env PATH="$FAIL_ONCE_HASH_BIN:$PATH" FAIL_ONCE_COUNTER="$FAIL_ONCE_COUNTER" \
  "$AUTOPILOT_FINGERPRINT" contract

FAIL_CKSUM_BIN="$TEST_DIR/fail-cksum-bin"
mkdir -p "$FAIL_CKSUM_BIN"
for tool in bash cat dirname find; do
  ln -s "$(command -v "$tool")" "$FAIL_CKSUM_BIN/$tool"
done
cat > "$FAIL_CKSUM_BIN/cksum" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
printf '123 4\n'
exit 9
EOF
chmod +x "$FAIL_CKSUM_BIN/cksum"
expect_command_failure_without_stdout \
  "Expected a failing cksum producer to fail closed" \
  env PATH="$FAIL_CKSUM_BIN" "$AUTOPILOT_FINGERPRINT" constitution

MULTILINE_CKSUM_BIN="$TEST_DIR/multiline-cksum-bin"
mkdir -p "$MULTILINE_CKSUM_BIN"
for tool in bash cat dirname find; do
  ln -s "$(command -v "$tool")" "$MULTILINE_CKSUM_BIN/$tool"
done
cat > "$MULTILINE_CKSUM_BIN/cksum" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
printf '123\n4\n'
EOF
chmod +x "$MULTILINE_CKSUM_BIN/cksum"
expect_command_failure_without_stdout \
  "Expected multiline cksum output to be rejected" \
  env PATH="$MULTILINE_CKSUM_BIN" "$AUTOPILOT_FINGERPRINT" constitution

BAD_SHASUM_BIN="$TEST_DIR/bad-shasum-bin"
mkdir -p "$BAD_SHASUM_BIN"
cat > "$BAD_SHASUM_BIN/shasum" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
printf 'not-a-digest\n'
EOF
chmod +x "$BAD_SHASUM_BIN/shasum"
expect_command_failure_without_stdout \
  "Expected malformed shasum output to be rejected" \
  env PATH="$BAD_SHASUM_BIN:$PATH" "$AUTOPILOT_FINGERPRINT" constitution

BAD_SHA256SUM_BIN="$TEST_DIR/bad-sha256sum-bin"
mkdir -p "$BAD_SHA256SUM_BIN"
for tool in bash cat dirname find; do
  ln -s "$(command -v "$tool")" "$BAD_SHA256SUM_BIN/$tool"
done
cat > "$BAD_SHA256SUM_BIN/sha256sum" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
printf 'not-a-digest  -\n'
EOF
chmod +x "$BAD_SHA256SUM_BIN/sha256sum"
expect_command_failure_without_stdout \
  "Expected malformed sha256sum output to be rejected" \
  env PATH="$BAD_SHA256SUM_BIN" "$AUTOPILOT_FINGERPRINT" constitution

BAD_OPENSSL_BIN="$TEST_DIR/bad-openssl-bin"
mkdir -p "$BAD_OPENSSL_BIN"
for tool in bash cat dirname find; do
  ln -s "$(command -v "$tool")" "$BAD_OPENSSL_BIN/$tool"
done
cat > "$BAD_OPENSSL_BIN/openssl" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
printf '(stdin)= not-a-digest\n'
EOF
chmod +x "$BAD_OPENSSL_BIN/openssl"
expect_command_failure_without_stdout \
  "Expected malformed openssl output to be rejected" \
  env PATH="$BAD_OPENSSL_BIN" "$AUTOPILOT_FINGERPRINT" constitution

FAKE_HASH_BIN="$TEST_DIR/fake-hash-bin"
mkdir -p "$FAKE_HASH_BIN"
cat > "$FAKE_HASH_BIN/shasum" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

payload="$(cat)"
constitution_digest_one=$'PATH=.autopilot/CONSTITUTION.yml\nDIGEST=sha256:0000000000000000000000000000000000000000000000000000000000000001'
constitution_digest_two=$'PATH=.autopilot/CONSTITUTION.yml\nDIGEST=sha256:0000000000000000000000000000000000000000000000000000000000000002'
case "$payload" in
  *'schema_version: 101'*) printf '%064d  -\n' 1 ;;
  *'schema_version: 202'*) printf '%064d  -\n' 2 ;;
  *"$constitution_digest_one"*) printf '%064d  -\n' 3 ;;
  *"$constitution_digest_two"*) printf '%064d  -\n' 4 ;;
  *)
    read -r crc _ <<CKSUM
$(printf '%s' "$payload" | cksum)
CKSUM
    printf '%064d  -\n' "$crc"
    ;;
esac
EOF
chmod +x "$FAKE_HASH_BIN/shasum"

cp "$CONSTITUTION_PATH" "$CONSTITUTION_PATH.swap-original"
cp "$ENROLLMENT_PATH" "$ENROLLMENT_PATH.swap-original"
sed 's/schema_version: 1/schema_version: 101/' \
  "$CONSTITUTION_PATH.swap-original" > "$CONSTITUTION_PATH"
sed 's/schema_version: 1/schema_version: 202/' \
  "$ENROLLMENT_PATH.swap-original" > "$ENROLLMENT_PATH"
CONTRACT_DIGEST_BEFORE_SWAP="$(PATH="$FAKE_HASH_BIN:$PATH" \
  "$AUTOPILOT_FINGERPRINT" contract)" || \
  fail "Expected valid control files to produce a contract fingerprint"

sed 's/schema_version: 1/schema_version: 202/' \
  "$CONSTITUTION_PATH.swap-original" > "$CONSTITUTION_PATH"
sed 's/schema_version: 1/schema_version: 101/' \
  "$ENROLLMENT_PATH.swap-original" > "$ENROLLMENT_PATH"
CONTRACT_DIGEST_AFTER_SWAP="$(PATH="$FAKE_HASH_BIN:$PATH" \
  "$AUTOPILOT_FINGERPRINT" contract)" || \
  fail "Expected swapped valid control files to produce a contract fingerprint"
[[ "$CONTRACT_DIGEST_AFTER_SWAP" != "$CONTRACT_DIGEST_BEFORE_SWAP" ]] || \
  fail "Expected contract fingerprint to bind each control-file digest to its path"

mv "$CONSTITUTION_PATH.swap-original" "$CONSTITUTION_PATH"
mv "$ENROLLMENT_PATH.swap-original" "$ENROLLMENT_PATH"

CONTRACT_DIGEST="$($AUTOPILOT_FINGERPRINT contract)" || \
  fail "Expected contract fingerprinting to succeed"
REPEATED_CONTRACT_DIGEST="$($AUTOPILOT_FINGERPRINT contract)" || \
  fail "Expected repeated contract fingerprinting to succeed"
[[ "$REPEATED_CONTRACT_DIGEST" == "$CONTRACT_DIGEST" ]] || \
  fail "Expected unchanged control files to have a deterministic contract fingerprint"

cp "$CONSTITUTION_PATH" "$TEST_DIR/CONSTITUTION.yml.original"
cp "$POLICY_PATH" "$TEST_DIR/POLICY.yml.original"
cp "$OBJECTIVES_PATH" "$TEST_DIR/OBJECTIVES.md.original"

sed 's/direct_default_branch_write: false/direct_default_branch_write: true/' \
  "$TEST_DIR/CONSTITUTION.yml.original" > "$CONSTITUTION_PATH"
CHANGED_CONSTITUTION_DIGEST="$($AUTOPILOT_FINGERPRINT constitution)" || \
  fail "Expected constitution fingerprinting after a value change to succeed"
[[ "$CHANGED_CONSTITUTION_DIGEST" != "$CONSTITUTION_DIGEST" ]] || \
  fail "Expected a changed constitution value to change its fingerprint"
cp "$TEST_DIR/CONSTITUTION.yml.original" "$CONSTITUTION_PATH"

mv "$POLICY_PATH" "$TEST_DIR/POLICY.yml.missing"
expect_fingerprint_failure \
  "Expected a missing contract control file to be rejected" contract
mv "$TEST_DIR/POLICY.yml.missing" "$POLICY_PATH"

cp "$CONSTITUTION_PATH" "$TEST_DIR/external-constitution.yml"
rm -f "$CONSTITUTION_PATH"
ln -s "$TEST_DIR/external-constitution.yml" "$CONSTITUTION_PATH"
expect_fingerprint_failure \
  "Expected a symlinked constitution to be rejected" constitution
rm -f "$CONSTITUTION_PATH"
cp "$TEST_DIR/CONSTITUTION.yml.original" "$CONSTITUTION_PATH"

printf 'external version one\n' > "$TEST_DIR/external-control-target"
ln -s "$TEST_DIR/external-control-target" "$AUTOPILOT_DIR/external-control-link"
CONTRACT_WITH_EXTERNAL_LINK="$($AUTOPILOT_FINGERPRINT contract)" || \
  fail "Expected an unrelated control-directory symlink to remain out of contract scope"
printf 'external version two\n' > "$TEST_DIR/external-control-target"
CONTRACT_AFTER_EXTERNAL_CHANGE="$($AUTOPILOT_FINGERPRINT contract)" || \
  fail "Expected external symlink target changes to remain out of contract scope"
[[ "$CONTRACT_WITH_EXTERNAL_LINK" == "$CONTRACT_AFTER_EXTERNAL_CHANGE" ]] || \
  fail "Expected contract fingerprinting not to follow unrelated external symlink targets"
rm -f "$AUTOPILOT_DIR/external-control-link"

NEWLINE_PATH="$AUTOPILOT_DIR/unsupported"$'\n'"name"
printf 'ambiguous path\n' > "$NEWLINE_PATH"
expect_fingerprint_failure \
  "Expected a newline-containing Autopilot filename to be rejected" contract
rm -f "$NEWLINE_PATH"

printf 'malformed data line\n' >> "$CONSTITUTION_PATH"
expect_fingerprint_failure \
  "Expected a malformed YAML data line to be rejected" constitution
cp "$TEST_DIR/CONSTITUTION.yml.original" "$CONSTITUTION_PATH"

printf 'Bad_key: false\n' >> "$CONSTITUTION_PATH"
expect_fingerprint_failure \
  "Expected a malformed YAML key name to be rejected" constitution
cp "$TEST_DIR/CONSTITUTION.yml.original" "$CONSTITUTION_PATH"

INJECTION_TARGET="$TEST_DIR/control-data-was-executed"
printf '\n# $(touch %s)\n' "$INJECTION_TARGET" >> "$OBJECTIVES_PATH"
"$AUTOPILOT_FINGERPRINT" contract >/dev/null || \
  fail "Expected inert control-file content to remain fingerprintable"
[[ ! -e "$INJECTION_TARGET" ]] || \
  fail "Expected control-file content not to be sourced or executed"
cp "$TEST_DIR/OBJECTIVES.md.original" "$OBJECTIVES_PATH"

expect_fingerprint_failure \
  "Expected an unknown autopilot fingerprint target to fail" unknown

VALIDATOR_BASELINE_DIR="$TEST_DIR/validator-baseline"
mkdir -p "$VALIDATOR_BASELINE_DIR/autopilot" "$VALIDATOR_BASELINE_DIR/ai"
cp "$CONSTITUTION_PATH" "$VALIDATOR_BASELINE_DIR/autopilot/CONSTITUTION.yml"
cp "$ENROLLMENT_PATH" "$VALIDATOR_BASELINE_DIR/autopilot/ENROLLMENT.yml"
cp "$POLICY_PATH" "$VALIDATOR_BASELINE_DIR/autopilot/POLICY.yml"
cp "$PROTECTED_PATHS_PATH" "$VALIDATOR_BASELINE_DIR/autopilot/PROTECTED_PATHS.yml"
cp "$STATE_PATH" "$VALIDATOR_BASELINE_DIR/autopilot/AUTOPILOT_STATE"
cp "$PROJECT_DIR/.ai/LIFECYCLE_STATE" "$VALIDATOR_BASELINE_DIR/ai/LIFECYCLE_STATE"
cp "$PROJECT_DIR/.ai/LIFECYCLE_BASELINE" "$VALIDATOR_BASELINE_DIR/ai/LIFECYCLE_BASELINE"
cp "$PROJECT_DIR/docs/lifecycle/PROBLEM_FRAMING.md" \
  "$VALIDATOR_BASELINE_DIR/PROBLEM_FRAMING.md"

restore_validator_baseline() {
  cp "$VALIDATOR_BASELINE_DIR/autopilot/CONSTITUTION.yml" "$CONSTITUTION_PATH"
  cp "$VALIDATOR_BASELINE_DIR/autopilot/ENROLLMENT.yml" "$ENROLLMENT_PATH"
  cp "$VALIDATOR_BASELINE_DIR/autopilot/POLICY.yml" "$POLICY_PATH"
  cp "$VALIDATOR_BASELINE_DIR/autopilot/PROTECTED_PATHS.yml" "$PROTECTED_PATHS_PATH"
  cp "$VALIDATOR_BASELINE_DIR/autopilot/AUTOPILOT_STATE" "$STATE_PATH"
  cp "$VALIDATOR_BASELINE_DIR/ai/LIFECYCLE_STATE" \
    "$PROJECT_DIR/.ai/LIFECYCLE_STATE"
  cp "$VALIDATOR_BASELINE_DIR/ai/LIFECYCLE_BASELINE" \
    "$PROJECT_DIR/.ai/LIFECYCLE_BASELINE"
  cp "$VALIDATOR_BASELINE_DIR/PROBLEM_FRAMING.md" \
    "$PROJECT_DIR/docs/lifecycle/PROBLEM_FRAMING.md"
}

expect_yaml_control_key_failures() {
  local path="$1"
  local required_key="$2"
  local label="$3"

  printf '\n%s: 1\n' "$required_key" >> "$path"
  expect_contract_failure \
    "Expected duplicate $label keys to be rejected" "$CHECK_AUTOPILOT"
  restore_validator_baseline

  printf '\nunknown_key: false\n' >> "$path"
  expect_contract_failure \
    "Expected unknown $label keys to be rejected" "$CHECK_AUTOPILOT"
  restore_validator_baseline

  awk -v key="$required_key:" '$1 != key { print }' "$path" > "$path.tmp.$$"
  mv "$path.tmp.$$" "$path"
  expect_contract_failure \
    "Expected missing required $label keys to be rejected" "$CHECK_AUTOPILOT"
  restore_validator_baseline
}

expect_yaml_control_key_failures "$CONSTITUTION_PATH" schema_version constitution
expect_yaml_control_key_failures "$ENROLLMENT_PATH" schema_version enrollment
expect_yaml_control_key_failures "$POLICY_PATH" schema_version policy
expect_yaml_control_key_failures "$PROTECTED_PATHS_PATH" schema_version protected-path

expect_contract_success \
  "Expected a fresh disabled contract to validate" "$CHECK_AUTOPILOT"
expect_contract_success \
  "Expected the enrollment mode alias to validate" "$CHECK_AUTOPILOT" enrollment
"$CHECK_HARNESS" >/dev/null || fail "Expected check-harness to accept Autopilot structure"

cp "$POLICY_PATH" "$TEST_DIR/POLICY.yml.validator-original"
printf '\nrisk_level: L\n' >> "$POLICY_PATH"
expect_contract_failure \
  "Expected duplicate policy keys to be rejected" "$CHECK_AUTOPILOT"
restore_validator_baseline

printf '\nunknown_key: false\n' >> "$ENROLLMENT_PATH"
expect_contract_failure \
  "Expected unknown enrollment keys to be rejected" "$CHECK_AUTOPILOT"
restore_validator_baseline

awk '$1 != "risk_level:" { print }' "$POLICY_PATH" > "$POLICY_PATH.tmp.$$"
mv "$POLICY_PATH.tmp.$$" "$POLICY_PATH"
expect_contract_failure \
  "Expected missing required policy keys to be rejected" "$CHECK_AUTOPILOT"
restore_validator_baseline

printf '\nSTATE=NEW\n' >> "$STATE_PATH"
expect_contract_failure \
  "Expected duplicate Autopilot state keys to be rejected" "$CHECK_AUTOPILOT"
restore_validator_baseline

printf '\nUNKNOWN_STATE_KEY=false\n' >> "$STATE_PATH"
expect_contract_failure \
  "Expected unknown Autopilot state keys to be rejected" "$CHECK_AUTOPILOT"
restore_validator_baseline

awk -F= '$1 != "CONSECUTIVE_FAILURES" { print }' "$STATE_PATH" > "$STATE_PATH.tmp.$$"
mv "$STATE_PATH.tmp.$$" "$STATE_PATH"
expect_contract_failure \
  "Expected missing required Autopilot state keys to be rejected" "$CHECK_AUTOPILOT"
restore_validator_baseline

set_kv_value "$STATE_PATH" LAST_TRANSITION_AT "not-a-utc-timestamp"
expect_contract_failure \
  "Expected invalid transition timestamps to be rejected" "$CHECK_AUTOPILOT"
restore_validator_baseline

INJECTION_TARGET="$TEST_DIR/validator-control-data-executed"
awk -v target="$INJECTION_TARGET" '
  $0 == "requested_by: owner" {
    print "requested_by: owner$(touch " target ")"
    next
  }
  { print }
' "$ENROLLMENT_PATH" > "$ENROLLMENT_PATH.tmp.$$"
mv "$ENROLLMENT_PATH.tmp.$$" "$ENROLLMENT_PATH"
expect_contract_failure \
  "Expected shell metacharacters in control values to be rejected" \
  "$CHECK_AUTOPILOT"
[[ ! -e "$INJECTION_TARGET" ]] || \
  fail "Expected validator not to execute control data"
restore_validator_baseline

sed 's/autopilot_enabled: false/autopilot_enabled: maybe/' \
  "$ENROLLMENT_PATH" > "$ENROLLMENT_PATH.tmp.$$"
mv "$ENROLLMENT_PATH.tmp.$$" "$ENROLLMENT_PATH"
expect_contract_failure \
  "Expected invalid enrollment booleans to be rejected" "$CHECK_AUTOPILOT"
restore_validator_baseline

sed 's/risk_level: M/risk_level: X/' "$POLICY_PATH" > "$POLICY_PATH.tmp.$$"
mv "$POLICY_PATH.tmp.$$" "$POLICY_PATH"
expect_contract_failure \
  "Expected invalid policy risk levels to be rejected" "$CHECK_AUTOPILOT"
restore_validator_baseline

set_kv_value "$STATE_PATH" STATE LAUNCHED
expect_contract_failure \
  "Expected invalid Autopilot states to be rejected" "$CHECK_AUTOPILOT"
restore_validator_baseline

sed 's/direct_default_branch_write: false/direct_default_branch_write: true/' \
  "$CONSTITUTION_PATH" > "$CONSTITUTION_PATH.tmp.$$"
mv "$CONSTITUTION_PATH.tmp.$$" "$CONSTITUTION_PATH"
expect_contract_failure \
  "Expected changed constitution capabilities to be rejected" "$CHECK_AUTOPILOT"
restore_validator_baseline

write_policy M observe_only false false false 0 "[]" "[././.autopilot/file]"
expect_contract_failure \
  "Expected normalized protected-path overlap to be rejected" "$CHECK_AUTOPILOT"
restore_validator_baseline

write_policy M observe_only false false false 0 "[]" "[.github]"
expect_contract_failure \
  "Expected protected parent-directory overlap to be rejected" "$CHECK_AUTOPILOT"
restore_validator_baseline

printf 'schema_version: 1\nprotected_paths: []\n' > "$PROTECTED_PATHS_PATH"
expect_contract_failure \
  "Expected empty protected_paths to be rejected" "$CHECK_AUTOPILOT"
restore_validator_baseline

printf 'schema_version: 1\nprotected_paths: [.autopilot/, .ai/, .github/workflows/, CODEOWNERS, .env.*]\n' \
  > "$PROTECTED_PATHS_PATH"
expect_contract_failure \
  "Expected required protected path membership to be exact" "$CHECK_AUTOPILOT"
restore_validator_baseline

printf 'schema_version: 1\nprotected_paths: [.autopilot/, .ai/, .github/workflows/, CODEOWNERS, .env, .env.prod]\n' \
  > "$PROTECTED_PATHS_PATH"
expect_contract_failure \
  "Expected glob protected path membership to be exact" "$CHECK_AUTOPILOT"
restore_validator_baseline

write_policy M candidate_pr false false false 0 "[]" "[]"
expect_contract_failure \
  "Expected disabled enrollment to require observe_only policy" "$CHECK_AUTOPILOT"
restore_validator_baseline

write_enrollment true UNCONFIGURED true
set_kv_value "$STATE_PATH" AUTOPILOT_ENABLED true
expect_contract_failure \
  "Expected enabled enrollment with unpinned controller ref to be rejected" \
  "$CHECK_AUTOPILOT"
restore_validator_baseline

write_enrollment false UNCONFIGURED true
expect_contract_failure \
  "Expected disabled enrollment to require auto activation false" "$CHECK_AUTOPILOT"
restore_validator_baseline

write_enrollment true 0123456789abcdef0123456789abcdef01234567 false
set_kv_value "$STATE_PATH" AUTOPILOT_ENABLED true
expect_contract_failure \
  "Expected enabled enrollment to require auto activation true" "$CHECK_AUTOPILOT"
restore_validator_baseline

sed 's#Amada203/project-autopilot#attacker/project-autopilot#' \
  "$ENROLLMENT_PATH" > "$ENROLLMENT_PATH.tmp.$$"
mv "$ENROLLMENT_PATH.tmp.$$" "$ENROLLMENT_PATH"
expect_contract_failure \
  "Expected an unexpected controller repository to be rejected" "$CHECK_AUTOPILOT"
restore_validator_baseline

write_enrollment true 0123456789abcdef0123456789abcdef01234567 true
set_kv_value "$STATE_PATH" AUTOPILOT_ENABLED true
record_current_autopilot_fingerprints
expect_contract_failure \
  "Expected enabled enrollment with a blocked Stage 0 gate to be rejected" \
  "$CHECK_AUTOPILOT"
restore_validator_baseline

write_stage0_plan_pass
write_enrollment true 0123456789abcdef0123456789abcdef01234567 true
write_policy M candidate_pr false false false 1 "[npm test -- --run]" "[src/, tests/]"
write_state STAGE0_PASSED true sha256:2222222222222222222222222222222222222222222222222222222222222222 \
  sha256:0000000000000000000000000000000000000000000000000000000000000000 \
  sha256:1111111111111111111111111111111111111111111111111111111111111111
expect_contract_failure \
  "Expected stale Autopilot fingerprints to be rejected" "$CHECK_AUTOPILOT"
restore_validator_baseline

write_stage0_plan_pass
write_enrollment true 0123456789abcdef0123456789abcdef01234567 true
write_policy M candidate_pr false false false 1 "[npm test -- --run]" "[src/, tests/]"
write_state ACTIVE true UNRECORDED UNRECORDED UNRECORDED
record_current_autopilot_fingerprints
expect_contract_success \
  "Expected ACTIVE enrollment to validate when every prerequisite is fresh" \
  "$CHECK_AUTOPILOT"
restore_validator_baseline

write_stage0_plan_pass
write_enrollment true 0123456789abcdef0123456789abcdef01234567 true
write_policy M candidate_pr false false false 1 "[npm test -- --run]" "[src/, tests/]"
write_state ACTIVE true UNRECORDED UNRECORDED UNRECORDED
record_current_autopilot_fingerprints
write_enrollment true abcdefabcdefabcdefabcdefabcdefabcdefabcd true
expect_contract_failure \
  "Expected ACTIVE enrollment to fail closed when controller_ref changes" \
  "$CHECK_AUTOPILOT"
restore_validator_baseline

write_stage0_plan_pass
write_enrollment true 0123456789abcdef0123456789abcdef01234567 true
write_policy M candidate_pr false false false 1 "[npm test -- --run]" "[src/]"
CKSUM_BIN="$TEST_DIR/validator-cksum-bin"
mkdir -p "$CKSUM_BIN"
for tool in bash cat dirname find cksum awk grep sed tr; do
  ln -s "$(command -v "$tool")" "$CKSUM_BIN/$tool"
done
set_kv_value "$PROJECT_DIR/.ai/LIFECYCLE_BASELINE" PLAN_FINGERPRINT \
  "$(PATH="$CKSUM_BIN" "$PROJECT_DIR/scripts/lifecycle-fingerprint.sh" plan)"
CONSTITUTION_CKSUM="$(PATH="$CKSUM_BIN" "$AUTOPILOT_FINGERPRINT" constitution)" || \
  fail "Expected cksum constitution fingerprint to be available"
POLICY_CKSUM="$(PATH="$CKSUM_BIN" "$AUTOPILOT_FINGERPRINT" policy)" || \
  fail "Expected cksum policy fingerprint to be available"
CONTRACT_CKSUM="$(PATH="$CKSUM_BIN" "$AUTOPILOT_FINGERPRINT" contract)" || \
  fail "Expected cksum contract fingerprint to be available"
write_state ACTIVE true "$CONTRACT_CKSUM" "$CONSTITUTION_CKSUM" "$POLICY_CKSUM"
expect_contract_failure \
  "Expected ACTIVE enrollment to reject cksum fingerprints as authorization evidence" \
  env PATH="$CKSUM_BIN" "$CHECK_AUTOPILOT"
restore_validator_baseline

write_stage0_plan_pass
write_enrollment true 0123456789abcdef0123456789abcdef01234567 true
write_policy M candidate_pr false false false 1 "[]" "[src/]"
write_state ACTIVE true UNRECORDED UNRECORDED UNRECORDED
record_current_autopilot_fingerprints
expect_contract_failure \
  "Expected ACTIVE enrollment to require approved test commands" \
  "$CHECK_AUTOPILOT"
restore_validator_baseline

mv "$AUTOPILOT_DIR" "$TEST_DIR/autopilot-dir.missing"
if "$CHECK_HARNESS" >/dev/null 2>&1; then
  fail "Expected check-harness to reject a missing Autopilot directory"
fi
mv "$TEST_DIR/autopilot-dir.missing" "$AUTOPILOT_DIR"

mv "$CHECK_AUTOPILOT" "$TEST_DIR/check-autopilot-contract.sh.missing"
if "$CHECK_HARNESS" >/dev/null 2>&1; then
  fail "Expected check-harness to reject a missing Autopilot validator"
fi
mv "$TEST_DIR/check-autopilot-contract.sh.missing" "$CHECK_AUTOPILOT"

write_stage0_plan_pass
write_enrollment true 0123456789abcdef0123456789abcdef01234567 true
write_policy M candidate_pr false false false 1 "[npm test -- --run]" "[src/, tests/]"
write_state NEW true UNRECORDED UNRECORDED UNRECORDED
expect_transition_success \
  "Expected NEW enabled bootstrap to record fingerprints and enter STAGE0_PASSED" \
  "$TRANSITION_AUTOPILOT" STAGE0_PASSED
assert_state_value STATE STAGE0_PASSED
[[ "$(state_file_value CONTRACT_FINGERPRINT)" != UNRECORDED ]] || \
  fail "Expected bootstrap transition to record contract fingerprint"
[[ "$(state_file_value CONSTITUTION_FINGERPRINT)" != UNRECORDED ]] || \
  fail "Expected bootstrap transition to record constitution fingerprint"
[[ "$(state_file_value POLICY_FINGERPRINT)" != UNRECORDED ]] || \
  fail "Expected bootstrap transition to record policy fingerprint"
restore_validator_baseline

prepare_enabled_autopilot_state NEW
expect_transition_success \
  "Expected NEW -> STAGE0_PASSED transition to succeed" \
  "$TRANSITION_AUTOPILOT" STAGE0_PASSED
assert_state_value STATE STAGE0_PASSED
assert_state_value CONSECUTIVE_FAILURES 0
[[ "$(state_file_value LAST_TRANSITION_AT)" != UNRECORDED ]] || \
  fail "Expected successful transitions to record LAST_TRANSITION_AT"

expect_transition_success \
  "Expected STAGE0_PASSED -> GITHUB_CONNECTED transition to succeed" \
  "$TRANSITION_AUTOPILOT" GITHUB_CONNECTED "GitHub App installed for fixture"
assert_state_value STATE GITHUB_CONNECTED
case "$(state_file_value LAST_REASON)" in
  "GitHub App installed for fixture") ;;
  *) fail "Expected privileged transition reason to be recorded" ;;
esac

expect_transition_success \
  "Expected GITHUB_CONNECTED -> REGISTERED transition to succeed" \
  "$TRANSITION_AUTOPILOT" REGISTERED "Central registry accepted fixture"
assert_state_value STATE REGISTERED

expect_transition_success \
  "Expected REGISTERED -> OBSERVE_ONLY transition to succeed" \
  "$TRANSITION_AUTOPILOT" OBSERVE_ONLY
assert_state_value STATE OBSERVE_ONLY

expect_transition_success \
  "Expected OBSERVE_ONLY -> ACTIVE transition to succeed" \
  "$TRANSITION_AUTOPILOT" ACTIVE "Owner approved active fixture"
assert_state_value STATE ACTIVE

expect_transition_success \
  "Expected ACTIVE -> PAUSED transition to succeed" \
  "$TRANSITION_AUTOPILOT" PAUSED
assert_state_value STATE PAUSED

expect_transition_success \
  "Expected PAUSED -> ACTIVE transition to succeed" \
  "$TRANSITION_AUTOPILOT" ACTIVE "Owner resumed active fixture"
assert_state_value STATE ACTIVE

expect_transition_success \
  "Expected ACTIVE -> SAFE_STOP transition to succeed" \
  "$TRANSITION_AUTOPILOT" SAFE_STOP
assert_state_value STATE SAFE_STOP

expect_transition_success \
  "Expected SAFE_STOP -> PAUSED recovery to succeed with reason" \
  "$TRANSITION_AUTOPILOT" PAUSED "Owner reviewed safe stop"
assert_state_value STATE PAUSED

expect_transition_success \
  "Expected PAUSED -> REVOKED transition to succeed with reason" \
  "$TRANSITION_AUTOPILOT" REVOKED "Owner revoked fixture"
assert_state_value STATE REVOKED
restore_validator_baseline

prepare_enabled_autopilot_state OBSERVE_ONLY
write_policy M observe_only false false false 0 "[]" "[]"
write_state OBSERVE_ONLY true UNRECORDED UNRECORDED UNRECORDED
record_current_autopilot_fingerprints
write_policy M candidate_pr false false false 1 "[npm test -- --run]" "[src/, tests/]"
expect_transition_success \
  "Expected an explicit owner policy acceptance to record a reviewed policy change" \
  "$TRANSITION_AUTOPILOT" --accept-policy "Owner reviewed candidate policy"
assert_state_value STATE OBSERVE_ONLY
case "$(state_file_value LAST_REASON)" in
  "Owner reviewed candidate policy") ;;
  *) fail "Expected contract acceptance reason to be recorded" ;;
esac
[[ "$(state_file_value POLICY_FINGERPRINT)" == "$($AUTOPILOT_FINGERPRINT policy)" ]] || \
  fail "Expected accepted policy fingerprint to match the reviewed policy"
expect_transition_success \
  "Expected activation after explicit owner contract acceptance" \
  "$TRANSITION_AUTOPILOT" ACTIVE "Owner activated reviewed candidate policy"
assert_state_value STATE ACTIVE
restore_validator_baseline

prepare_enabled_autopilot_state OBSERVE_ONLY
write_policy M observe_only false false false 0 "[]" "[]"
write_state OBSERVE_ONLY true UNRECORDED UNRECORDED UNRECORDED
record_current_autopilot_fingerprints
write_policy M candidate_pr false false false 1 "[npm test -- --run]" "[src/]"
before_policy_acceptance="$(cat "$STATE_PATH")"
expect_transition_failure \
  "Expected policy acceptance without an owner reason to fail" \
  "$TRANSITION_AUTOPILOT" --accept-policy
[[ "$(cat "$STATE_PATH")" == "$before_policy_acceptance" ]] || \
  fail "Expected failed policy acceptance to preserve state"
printf '\n  - owner-private/\n' >> "$PROTECTED_PATHS_PATH"
expect_transition_failure \
  "Expected policy acceptance to reject simultaneous non-policy contract changes" \
  "$TRANSITION_AUTOPILOT" --accept-policy "Policy-only review"
[[ "$(cat "$STATE_PATH")" == "$before_policy_acceptance" ]] || \
  fail "Expected rejected mixed contract acceptance to preserve state"
restore_validator_baseline

prepare_enabled_autopilot_state NEW
before_invalid_transition="$(cat "$STATE_PATH")"
expect_transition_failure \
  "Expected skipped NEW -> ACTIVE transition to fail" \
  "$TRANSITION_AUTOPILOT" ACTIVE "Owner tried to skip gates"
[[ "$(cat "$STATE_PATH")" == "$before_invalid_transition" ]] || \
  fail "Expected skipped transition not to mutate state"

expect_transition_failure \
  "Expected duplicate NEW -> NEW transition to fail" \
  "$TRANSITION_AUTOPILOT" NEW

set_kv_value "$STATE_PATH" STATE STAGE0_PASSED
expect_transition_failure \
  "Expected reversed STAGE0_PASSED -> NEW transition to fail" \
  "$TRANSITION_AUTOPILOT" NEW

expect_transition_failure \
  "Expected unknown transition target to fail" \
  "$TRANSITION_AUTOPILOT" LAUNCHED
restore_validator_baseline

for from_state in NEW STAGE0_PASSED GITHUB_CONNECTED REGISTERED OBSERVE_ONLY ACTIVE PAUSED REVOKED SAFE_STOP; do
  for to_state in NEW STAGE0_PASSED GITHUB_CONNECTED REGISTERED OBSERVE_ONLY ACTIVE PAUSED REVOKED SAFE_STOP; do
    if transition_pair_is_legal "$from_state" "$to_state"; then
      continue
    fi
    prepare_enabled_autopilot_state "$from_state"
    state_before_invalid_pair="$(cat "$STATE_PATH")"
    expect_transition_failure \
      "Expected invalid transition $from_state -> $to_state to fail" \
      "$TRANSITION_AUTOPILOT" "$to_state" "Invalid transition fixture"
    [[ "$(cat "$STATE_PATH")" == "$state_before_invalid_pair" ]] || \
      fail "Expected invalid transition $from_state -> $to_state not to mutate state"
  done
done
restore_validator_baseline

write_stage0_plan_pass
write_enrollment false UNCONFIGURED false
write_policy M observe_only false false false 0 "[]" "[]"
write_state PAUSED false UNRECORDED UNRECORDED UNRECORDED
record_current_autopilot_fingerprints
expect_transition_failure \
  "Expected disabled-to-ACTIVE transition to fail" \
  "$TRANSITION_AUTOPILOT" ACTIVE "Owner cannot activate disabled enrollment"
restore_validator_baseline

prepare_enabled_autopilot_state STAGE0_PASSED
expect_transition_failure \
  "Expected GITHUB_CONNECTED transition without reason to fail" \
  "$TRANSITION_AUTOPILOT" GITHUB_CONNECTED

expect_transition_failure \
  "Expected multiline transition reason to fail" \
  "$TRANSITION_AUTOPILOT" GITHUB_CONNECTED $'bad\nreason'
restore_validator_baseline

prepare_enabled_autopilot_state GITHUB_CONNECTED
expect_transition_failure \
  "Expected REGISTERED transition without reason to fail" \
  "$TRANSITION_AUTOPILOT" REGISTERED
restore_validator_baseline

prepare_enabled_autopilot_state OBSERVE_ONLY
expect_transition_failure \
  "Expected ACTIVE transition without reason to fail" \
  "$TRANSITION_AUTOPILOT" ACTIVE
restore_validator_baseline

prepare_enabled_autopilot_state ACTIVE
expect_transition_failure \
  "Expected REVOKED transition without reason to fail" \
  "$TRANSITION_AUTOPILOT" REVOKED
restore_validator_baseline

prepare_enabled_autopilot_state SAFE_STOP
expect_transition_failure \
  "Expected SAFE_STOP recovery without reason to fail" \
  "$TRANSITION_AUTOPILOT" PAUSED
restore_validator_baseline

prepare_enabled_autopilot_state NEW
printf '\nUNKNOWN_STATE_KEY=false\n' >> "$STATE_PATH"
state_before_unknown_key_transition="$(cat "$STATE_PATH")"
expect_transition_failure \
  "Expected transition to reject unknown current state keys" \
  "$TRANSITION_AUTOPILOT" STAGE0_PASSED
[[ "$(cat "$STATE_PATH")" == "$state_before_unknown_key_transition" ]] || \
  fail "Expected unknown state key transition failure not to mutate state"
restore_validator_baseline

prepare_enabled_autopilot_state STAGE0_PASSED
mkdir "$AUTOPILOT_DIR/.transition.lock"
state_before_lock_failure="$(cat "$STATE_PATH")"
expect_transition_failure \
  "Expected concurrent lock contention to fail" \
  "$TRANSITION_AUTOPILOT" GITHUB_CONNECTED "Lock contention fixture"
[[ "$(cat "$STATE_PATH")" == "$state_before_lock_failure" ]] || \
  fail "Expected lock contention not to mutate state"
rmdir "$AUTOPILOT_DIR/.transition.lock"
restore_validator_baseline

prepare_enabled_autopilot_state STAGE0_PASSED
state_before_write_failure="$(cat "$STATE_PATH")"
FAILING_MV_BIN="$TEST_DIR/failing-mv-bin"
mkdir -p "$FAILING_MV_BIN"
cat > "$FAILING_MV_BIN/mv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${2:-}" == "$AUTOPILOT_STATE_PATH" ]]; then
  exit 9
fi
exec "$REAL_MV" "$@"
EOF
chmod +x "$FAILING_MV_BIN/mv"
expect_transition_failure \
  "Expected failed atomic state write to roll back" \
  env PATH="$FAILING_MV_BIN:$PATH" REAL_MV="$(command -v mv)" \
  AUTOPILOT_STATE_PATH="$STATE_PATH" \
  "$TRANSITION_AUTOPILOT" GITHUB_CONNECTED "Write failure fixture"
[[ "$(cat "$STATE_PATH")" == "$state_before_write_failure" ]] || \
  fail "Expected failed atomic write to restore original state"
restore_validator_baseline

prepare_enabled_autopilot_state OBSERVE_ONLY
write_policy M candidate_pr false false false 1 "[]" "[src/]"
record_current_autopilot_fingerprints
state_before_post_check_failure="$(cat "$STATE_PATH")"
expect_transition_failure \
  "Expected failed post-transition validation to roll back" \
  "$TRANSITION_AUTOPILOT" ACTIVE "Post validator failure fixture"
[[ "$(cat "$STATE_PATH")" == "$state_before_post_check_failure" ]] || \
  fail "Expected post-validation failure to restore original state"
restore_validator_baseline

prepare_enabled_autopilot_state ACTIVE
expect_transition_success \
  "Expected first recorded failure to keep ACTIVE state" \
  "$TRANSITION_AUTOPILOT" --record-failure "first fixture failure"
assert_state_value STATE ACTIVE
assert_state_value CONSECUTIVE_FAILURES 1
expect_transition_success \
  "Expected second recorded failure to keep ACTIVE state" \
  "$TRANSITION_AUTOPILOT" --record-failure "second fixture failure"
assert_state_value STATE ACTIVE
assert_state_value CONSECUTIVE_FAILURES 2
expect_transition_success \
  "Expected third recorded failure to enter SAFE_STOP" \
  "$TRANSITION_AUTOPILOT" --record-failure "third fixture failure"
assert_state_value STATE SAFE_STOP
assert_state_value CONSECUTIVE_FAILURES 3
restore_validator_baseline

for failure_state in NEW STAGE0_PASSED GITHUB_CONNECTED REGISTERED OBSERVE_ONLY PAUSED REVOKED SAFE_STOP; do
  prepare_enabled_autopilot_state "$failure_state"
  state_before_invalid_failure="$(cat "$STATE_PATH")"
  expect_transition_failure \
    "Expected failure recording from $failure_state to fail closed" \
    "$TRANSITION_AUTOPILOT" --record-failure "invalid state failure fixture"
  [[ "$(cat "$STATE_PATH")" == "$state_before_invalid_failure" ]] || \
    fail "Expected rejected failure recording from $failure_state not to mutate state"
done
restore_validator_baseline

PROTECTED_DIFF_PROJECT="$TEST_DIR/protected-diff-app"
"$ROOT_DIR/bin/new-full-project" --no-git protected-diff-app "$TEST_DIR" >/dev/null
sed 's#]$#, payments/]#' "$PROTECTED_DIFF_PROJECT/.autopilot/PROTECTED_PATHS.yml" \
  > "$PROTECTED_DIFF_PROJECT/.autopilot/PROTECTED_PATHS.yml.tmp"
mv "$PROTECTED_DIFF_PROJECT/.autopilot/PROTECTED_PATHS.yml.tmp" \
  "$PROTECTED_DIFF_PROJECT/.autopilot/PROTECTED_PATHS.yml"
git -C "$PROTECTED_DIFF_PROJECT" init -q
git -C "$PROTECTED_DIFF_PROJECT" config user.name "Autopilot Contract Test"
git -C "$PROTECTED_DIFF_PROJECT" config user.email "autopilot-contract@example.invalid"
git -C "$PROTECTED_DIFF_PROJECT" add .
git -C "$PROTECTED_DIFF_PROJECT" commit -qm baseline
PROTECTED_DIFF_BASE="$(git -C "$PROTECTED_DIFF_PROJECT" rev-parse HEAD)"
mkdir -p "$PROTECTED_DIFF_PROJECT/src"
printf 'safe business change\n' > "$PROTECTED_DIFF_PROJECT/src/app.txt"
git -C "$PROTECTED_DIFF_PROJECT" add src/app.txt
git -C "$PROTECTED_DIFF_PROJECT" commit -qm safe-business-change
PROTECTED_DIFF_SAFE_HEAD="$(git -C "$PROTECTED_DIFF_PROJECT" rev-parse HEAD)"
expect_contract_success \
  "Expected protected-diff validation to allow business paths" \
  "$PROTECTED_DIFF_PROJECT/scripts/check-autopilot-contract.sh" protected-diff \
  "$PROTECTED_DIFF_BASE" "$PROTECTED_DIFF_SAFE_HEAD"
mkdir -p "$PROTECTED_DIFF_PROJECT/payments"
printf 'protected owner path\n' > "$PROTECTED_DIFF_PROJECT/payments/rules.txt"
git -C "$PROTECTED_DIFF_PROJECT" add payments/rules.txt
git -C "$PROTECTED_DIFF_PROJECT" commit -qm custom-protected-path
PROTECTED_DIFF_CUSTOM_HEAD="$(git -C "$PROTECTED_DIFF_PROJECT" rev-parse HEAD)"
expect_contract_failure \
  "Expected protected-diff to honor owner-added base protected paths" \
  "$PROTECTED_DIFF_PROJECT/scripts/check-autopilot-contract.sh" protected-diff \
  "$PROTECTED_DIFF_SAFE_HEAD" "$PROTECTED_DIFF_CUSTOM_HEAD"
mkdir -p "$PROTECTED_DIFF_PROJECT/services/api/config"
printf 'nested protected config\n' > "$PROTECTED_DIFF_PROJECT/services/api/config/runtime.yml"
git -C "$PROTECTED_DIFF_PROJECT" add services/api/config/runtime.yml
git -C "$PROTECTED_DIFF_PROJECT" commit -qm nested-protected-config
PROTECTED_DIFF_NESTED_HEAD="$(git -C "$PROTECTED_DIFF_PROJECT" rev-parse HEAD)"
expect_contract_failure \
  "Expected protected-diff to reject nested configuration controls" \
  "$PROTECTED_DIFF_PROJECT/scripts/check-autopilot-contract.sh" protected-diff \
  "$PROTECTED_DIFF_CUSTOM_HEAD" "$PROTECTED_DIFF_NESTED_HEAD"
set_kv_value "$PROTECTED_DIFF_PROJECT/.autopilot/AUTOPILOT_STATE" LAST_REASON forged-direct-edit
git -C "$PROTECTED_DIFF_PROJECT" add .autopilot/AUTOPILOT_STATE
git -C "$PROTECTED_DIFF_PROJECT" commit -qm forged-state
PROTECTED_DIFF_HEAD="$(git -C "$PROTECTED_DIFF_PROJECT" rev-parse HEAD)"
expect_contract_failure \
  "Expected protected-diff validation to reject direct state edits" \
  "$PROTECTED_DIFF_PROJECT/scripts/check-autopilot-contract.sh" protected-diff \
  "$PROTECTED_DIFF_NESTED_HEAD" "$PROTECTED_DIFF_HEAD"

echo "Autopilot contract test passed."
