#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
PROJECT_DIR="$TEST_DIR/refactor-fixture"
"$ROOT_DIR/bin/new-full-project" refactor-fixture "$TEST_DIR" >/dev/null

fail() { echo "$*" >&2; exit 1; }
expect_fail() {
  local expected="$1"; shift; local output
  if output="$("$@" 2>&1)"; then fail "Expected failure: $*"; fi
  [[ "$output" == *"$expected"* ]] || fail "Expected '$expected', got: $output"
}
set_state() {
  local key="$1" value="$2" file="$PROJECT_DIR/.ai/LIFECYCLE_STATE"
  sed "s/^${key}=.*/${key}=${value}/" "$file" > "$file.tmp"
  mv "$file.tmp" "$file"
}
write_plan() {
  cat > "$PROJECT_DIR/docs/lifecycle/REFACTOR_PLAN.md" <<'EOF'
# Refactor Plan
Refactor ID: core-boundary-v2
## Root Need and Behavioral Baseline
Preserve the verified public behavior baseline B-17 while separating responsibilities.
## Preserved Contracts and Callers
API v1 and callers C1/C2 remain compatible throughout the transition.
## Architecture Delta
Move validation behind the existing boundary; architecture evidence A-2 maps old to new nodes.
## Incremental Stages
Stage one adds compatibility, stage two migrates callers, stage three removes the old path.
## Data Compatibility and Migration
Dual-read fixture covers old/new records; repeated migration is idempotent.
## Rollback Boundary
Before stage three, restore the old reader; after data conversion use backup R-9.
## Verification Plan
Run contract, smoke, migration interruption, rollback and adversarial cases per stage.
## Approval
Owner decision O-12 confirms the direction, not GitHub publication.
Decision: APPROVED
EOF
}
write_recovery() {
  local result="$1"
  cat > "$PROJECT_DIR/docs/lifecycle/REFACTOR_RECOVERY.md" <<EOF
# Refactor Recovery Record
Refactor ID: core-boundary-v2
## Actual Change and Stage Completion
All three reviewed stages completed; implementation revision local-fixture.
## Compatibility Results
API v1 and callers C1/C2 pass the before/after contract fixture.
## Migration and Partial-Failure Drill
Interrupted migration resumed idempotently from record 42; backup R-9 restored cleanly.
## Smoke and Regression Evidence
| ID | Command | Expected | Evidence | Status |
|---|---|---|---|---|
| R-01 | fixture smoke | behavior B-17 | log-r1 | $result |
## Rollback and Restore Drill
Old reader plus backup R-9 restored the baseline in drill RR-2.
## Adversarial Findings
| Severity | Status | Scenario | Evidence | Disposition | Owner |
|---|---|---|---|---|---|
| P1 | CLOSED | partial migration replay | RR-2 | idempotency guard verified | maintainer |
## Architecture Reconciliation
Architecture A-2 matches the implemented boundary and remaining compatibility adapter.
Result: $result
EOF
}

set_state PLAN_STATUS PASS
expect_fail "continuity checkpoint" "$PROJECT_DIR/scripts/start-refactor.sh" core-boundary-v2
node "$PROJECT_DIR/scripts/project-continuity.mjs" snapshot >/dev/null
expect_fail "refactor id" "$PROJECT_DIR/scripts/start-refactor.sh" '../unsafe'
"$PROJECT_DIR/scripts/start-refactor.sh" core-boundary-v2 >/dev/null
grep -Fxq 'REFACTOR_ID=core-boundary-v2' "$PROJECT_DIR/.ai/LIFECYCLE_STATE"
grep -Fxq 'REFACTOR_STATUS=PLANNED' "$PROJECT_DIR/.ai/LIFECYCLE_STATE"
grep -Fxq 'DESIGN_STATUS=BLOCKED' "$PROJECT_DIR/.ai/LIFECYCLE_STATE"
grep -Fxq 'DESIGN_FINGERPRINT=UNRECORDED' "$PROJECT_DIR/.ai/LIFECYCLE_BASELINE"
expect_fail "already active" "$PROJECT_DIR/scripts/start-refactor.sh" second
expect_fail "incomplete" "$PROJECT_DIR/scripts/check-refactor.sh" design
expect_fail "Illegal refactor transition" "$PROJECT_DIR/scripts/transition-refactor.sh" PASS
write_plan
"$PROJECT_DIR/scripts/check-refactor.sh" design >/dev/null
before="$($PROJECT_DIR/scripts/lifecycle-fingerprint.sh design)"
mkdir "$PROJECT_DIR/.ai/.refactor-transition.lock"
expect_fail "another refactor transition" "$PROJECT_DIR/scripts/transition-refactor.sh" IN_PROGRESS
rmdir "$PROJECT_DIR/.ai/.refactor-transition.lock"
"$PROJECT_DIR/scripts/transition-refactor.sh" IN_PROGRESS >/dev/null
expect_fail "incomplete" "$PROJECT_DIR/scripts/transition-refactor.sh" PASS
write_recovery FAIL
expect_fail "Result: PASS" "$PROJECT_DIR/scripts/transition-refactor.sh" PASS
write_recovery PASS
"$PROJECT_DIR/scripts/transition-refactor.sh" PASS >/dev/null
"$PROJECT_DIR/scripts/check-refactor.sh" implementation >/dev/null
grep -Fxq 'REFACTOR_STATUS=PASS' "$PROJECT_DIR/.ai/LIFECYCLE_STATE"
printf '\nNew architecture delta evidence.\n' >> "$PROJECT_DIR/docs/lifecycle/REFACTOR_PLAN.md"
after="$($PROJECT_DIR/scripts/lifecycle-fingerprint.sh design)"
[[ "$before" != "$after" ]] || fail "Refactor plan must affect design fingerprint"
echo 'test-refactor-recovery: ok'
