#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

PROJECT_NAME="lifecycle-gate-app"
PROJECT_DIR="$TEST_DIR/$PROJECT_NAME"

"$ROOT_DIR/bin/new-full-project" --no-git "$PROJECT_NAME" "$TEST_DIR" >/dev/null

fail() {
  echo "$*" >&2
  exit 1
}

expect_fail() {
  local expected="$1"
  local output
  shift

  if output="$("$@" 2>&1)"; then
    fail "Expected command to fail: $*"
  fi

  case "$output" in
    *"$expected"*) ;;
    *) fail "Expected failure containing '$expected', got: $output" ;;
  esac
}

write_file() {
  local path="$1"
  shift
  printf '%s\n' "$@" > "$path"
}

set_state() {
  local key="$1"
  local value="$2"
  local state_file="$PROJECT_DIR/.ai/LIFECYCLE_STATE"
  local tmp_file="${state_file}.tmp.$$"

  awk -F= -v key="$key" -v value="$value" '
    BEGIN { found = 0 }
    $1 == key { print key "=" value; found++; next }
    { print }
    END { if (found != 1) exit 42 }
  ' "$state_file" > "$tmp_file" || fail "Unable to set state key: $key"
  mv "$tmp_file" "$state_file"
}

assert_state() {
  local key="$1"
  local expected="$2"
  grep -Fxq "$key=$expected" "$PROJECT_DIR/.ai/LIFECYCLE_STATE" || \
    fail "Expected lifecycle state $key=$expected"
}

assert_baseline() {
  local key="$1"
  local expected="$2"
  grep -Fxq "$key=$expected" "$PROJECT_DIR/.ai/LIFECYCLE_BASELINE" || \
    fail "Expected lifecycle baseline $key=$expected"
}

set_problem_risk() {
  local value="$1"
  local path="$PROJECT_DIR/docs/lifecycle/PROBLEM_FRAMING.md"
  local tmp_file="${path}.tmp.$$"

  awk -v value="$value" '
    /^Risk Level: / { print "Risk Level: " value; next }
    { print }
  ' "$path" > "$tmp_file"
  mv "$tmp_file" "$path"
  set_state RISK_LEVEL "$value"
}

complete_plan() {
  write_file "$PROJECT_DIR/docs/lifecycle/PROBLEM_FRAMING.md" \
    "# Problem Framing" \
    "Risk Level: M" \
    "## Observed Facts" \
    "Users cannot complete the critical workflow; incident report IR-1 is the evidence." \
    "## Surface Request" \
    "Add a shortcut." \
    "## U-Shaped Descent to the Root Need" \
    "The root need is reliable completion of the workflow." \
    "## Core Goal and Success Measures" \
    "At least 99% of valid attempts complete in the smoke environment." \
    "## First-Principles Constraints" \
    "No data loss; authorization remains enforced." \
    "## Non-Goals and Rejected Pseudo-Requirements" \
    "A visual redesign is excluded because it does not prove reliability." \
    "## Risk Classification" \
    "All high-risk triggers are no; uncertainty keeps the project at M." \
    "## Risk-Level Rationale" \
    "M is retained because the workflow changes application behavior." \
    "## Plan Gate Decision" \
    "Accepted by reviewer R on 2026-08-31; evidence IR-1."
  set_state PLAN_STATUS PASS
}

complete_design() {
  write_file "$PROJECT_DIR/docs/product/PRD.md" \
    "# Product Requirements Document" \
    "## Problem and Evidence Reference" \
    "Problem framing identifies unreliable workflow completion." \
    "## Core Outcome and Success Metrics" \
    "Success metric: 99% in the smoke environment." \
    "## Goals" \
    "Reliable workflow completion." \
    "## Non-Goals and Rejected Pseudo-Requirements" \
    "Unrelated redesign." \
    "## Users and Affected Parties" \
    "Authorized users and operators." \
    "## User Stories" \
    "An authorized user completes the workflow." \
    "## Business Rules and First-Principles Constraints" \
    "Authorization and data integrity remain enforced." \
    "## Pages, Flows, and States" \
    "Critical flow covers success and visible failure." \
    "## Failure and Business-Backfire Scenarios" \
    "Silent failure harms completion and trust." \
    "## Acceptance Criteria" \
    "The critical path completes and failures are visible." \
    "## Evidence and Verification Mapping" \
    "Smoke evidence maps to the release gate." \
    "## Open Questions" \
    "None."
  write_file "$PROJECT_DIR/docs/technical/TECHNICAL_PRD.md" \
    "# Technical Requirements Document" \
    "## Problem, Risk, and Design Evidence" \
    "The passed problem and design evidence define risk H for this fixture." \
    "## Architecture and Trust Boundaries" \
    "Preserve the existing boundary and add validated handling." \
    "## Assumptions and Falsification Plan" \
    "Trace evidence can disprove the handler assumption." \
    "## Alternatives and Decision" \
    "Validated handling is selected over full replacement." \
    "## Data Model and Invariants" \
    "Authorization and durable completion remain invariant." \
    "## API Contract" \
    "The existing contract is preserved." \
    "## Frontend Structure" \
    "Not applicable because the fixture has no UI change." \
    "## Backend Structure" \
    "The handler owns input validation and completion." \
    "## Failure, Containment, and Rollback Design" \
    "Restore the previous handler and disable the feature." \
    "## Non-Functional Requirements" \
    "Security, reliability, and observability retain existing budgets." \
    "## Smoke and Adversarial Verification Plan" \
    "Prototype and pre-release smoke plus malicious input attacks." \
    "## Data, Model, and Agent Controls" \
    "The fixture has no model or Agent; input provenance and tool authority remain bounded." \
    "## Residual Risk and Approval" \
    "Only reversible operational noise remains."
  write_file "$PROJECT_DIR/docs/lifecycle/DESIGN_CHALLENGE.md" \
    "# Design Challenge" \
    "## Root Problem Restatement" \
    "The workflow must complete reliably without weakening authorization." \
    "## Assumptions to Falsify" \
    "The handler is the bottleneck; a trace can disprove it." \
    "## First-Principles Constraints" \
    "Preserve data and authorization invariants." \
    "## Option A" \
    "Add validated handling; small change with a local rollback." \
    "## Option B" \
    "Replace the workflow; broader cost and blast radius." \
    "## Selected Path and Rejected Alternatives" \
    "Choose A because it meets the goal with lower blast radius." \
    "## Adversarial Design Attacks" \
    "Malformed and unauthorized inputs are rejected and logged." \
    "## Fallback and Rollback Path" \
    "Restore the previous handler and disable the feature flag." \
    "## Design Gate Decision" \
    "Accepted by reviewer R on 2026-08-31."
  set_state DESIGN_STATUS PASS
}

write_prototype() {
  local result="$1"
  write_file "$PROJECT_DIR/docs/lifecycle/PROTOTYPE_SMOKE_TEST.md" \
    "# Prototype Smoke Test" \
    "Applicability: REQUIRED" \
    "## Minimum Mainline" \
    "Submit one valid request and observe durable completion." \
    "## Environment and Preconditions" \
    "Isolated fixture with known authorization and input." \
    "## Smoke Cases" \
    "| ID | Step or command | Expected | Actual evidence | Status |" \
    "|---|---|---|---|---|" \
    "| P-01 | run fixture | completion | log-1 | $result |" \
    "## Failure and Stop Condition" \
    "Any incomplete request sends the design back." \
    "Result: $result" \
    "## Decision Record" \
    "Reviewed by R on 2026-08-31; evidence log-1."
}

write_smoke() {
  local result="$1"
  write_file "$PROJECT_DIR/docs/lifecycle/SMOKE_TEST_REPORT.md" \
    "# Pre-Release Smoke Test Report" \
    "## Release Candidate" \
    "Version 1, revision fixture, isolated environment." \
    "## Critical Mainlines" \
    "| ID | Command or action | Expected | Actual evidence | Status |" \
    "|---|---|---|---|---|" \
    "| S-01 | run fixture | completion | log-2 | $result |" \
    "## Negative Control" \
    "Invalid authorization is rejected, proving the check is active." \
    "## Rollback Signal" \
    "Any mainline failure or authorization regression triggers rollback." \
    "## Skipped Checks" \
    "None." \
    "Result: $result" \
    "## Decision Record" \
    "Reviewed by R on 2026-08-31; evidence log-2."
}

write_adversarial() {
  local severity="$1"
  local status="$2"
  local decision="$3"
  write_file "$PROJECT_DIR/docs/lifecycle/ADVERSARIAL_REVIEW.md" \
    "# Adversarial Review" \
    "## Review Scope and Independent Perspective" \
    "Reviewer R attacked revision fixture from an independent failure perspective." \
    "## Attack Matrix" \
    "| Severity | Status | Attack or failure scenario | Evidence | Disposition | Owner |" \
    "|---|---|---|---|---|---|" \
    "| $severity | $status | Unauthorized malformed input | log-3 | rejected safely | R |" \
    "## Data, Model, and Agent Logic Attacks" \
    "Data provenance, model evaluation, prompt injection, and tool authority were reviewed." \
    "## Residual Risk" \
    "Only reversible P3 operational noise remains." \
    "## Rollback and Containment Verification" \
    "Feature disable and previous-handler restoration were exercised." \
    "Decision: $decision" \
    "## Decision Record" \
    "Reviewed by R on 2026-08-31; evidence log-3."
}

write_retrospective() {
  write_file "$PROJECT_DIR/docs/lifecycle/RETROSPECTIVE.md" \
    "# Retrospective" \
    "## Observable Facts" \
    "The initial mainline failed and log-1 recorded the handler error." \
    "## U-Shaped Root-Cause Descent" \
    "The symptom traced to an unchecked invariant at the handler boundary." \
    "## Violated First-Principles Constraint" \
    "Valid authorized input must either complete or fail visibly." \
    "## Counterfactual" \
    "A boundary smoke check would have prevented progression." \
    "## Systemic Corrective Actions" \
    "Keep the boundary smoke check; owner R; review 2026-09-30; evidence test-1; DONE." \
    "## Learning Returned to the Harness" \
    "Retain the negative-control requirement." \
    "## Retrospective Gate Decision" \
    "Accepted by reviewer R on 2026-08-31."
  write_file "$PROJECT_DIR/docs/lifecycle/IMPROVEMENT_PROPOSAL.md" \
    "# Harness Improvement Proposal" \
    "Applicability: NONE - no reusable harness defect was found in this project."
}

write_improvement_proposal() {
  local decision="$1"
  write_file "$PROJECT_DIR/docs/lifecycle/IMPROVEMENT_PROPOSAL.md" \
    "# Harness Improvement Proposal" \
    "Applicability: PROPOSED" \
    "## Triggering Evidence" \
    "Test log-1 shows a reusable boundary-check omission." \
    "## Reusable Failure Pattern" \
    "Projects can advance without recording the negative control." \
    "## Proposed Harness Change" \
    "Require a named negative-control result in smoke evidence." \
    "## Expected Benefit" \
    "The gate proves that its check is active rather than merely passing." \
    "## Risks and Counterexamples" \
    "Non-executable projects need an explicit applicability path." \
    "## Validation Plan" \
    "Add one failing fixture and one valid non-executable fixture." \
    "## Rollback Plan" \
    "Revert the template and validator together if false blocks rise." \
    "## Scope and Migration" \
    "Apply only to newly generated projects until a reviewed migrator exists." \
    "## Human Review" \
    "Owner R must approve the source-harness change separately." \
    "Proposal Decision: $decision"
}

GATE="$PROJECT_DIR/scripts/check-lifecycle-gate.sh"
RECORD="$PROJECT_DIR/scripts/record-lifecycle-gate.sh"
FINGERPRINT="$PROJECT_DIR/scripts/lifecycle-fingerprint.sh"

expect_fail "PLAN_STATUS must be PASS" "$GATE" plan
set_state DESIGN_STATUS PASS
expect_fail "PLAN_STATUS must be PASS" "$GATE" design
set_state DESIGN_STATUS BLOCKED

complete_plan
expect_fail "Plan fingerprint is not recorded" "$GATE" plan
"$RECORD" plan >/dev/null
"$GATE" plan >/dev/null

cp "$PROJECT_DIR/docs/lifecycle/PROBLEM_FRAMING.md" \
  "$PROJECT_DIR/docs/lifecycle/PROBLEM_FRAMING.md.fresh"
printf '%s\n' "A changed plan input invalidates its recorded evidence." >> \
  "$PROJECT_DIR/docs/lifecycle/PROBLEM_FRAMING.md"
expect_fail "Plan fingerprint is stale" "$GATE" plan
mv "$PROJECT_DIR/docs/lifecycle/PROBLEM_FRAMING.md.fresh" \
  "$PROJECT_DIR/docs/lifecycle/PROBLEM_FRAMING.md"
"$GATE" plan >/dev/null

cp "$PROJECT_DIR/docs/lifecycle/PROBLEM_FRAMING.md" \
  "$TEST_DIR/external-problem-framing.md"
mv "$PROJECT_DIR/docs/lifecycle/PROBLEM_FRAMING.md" \
  "$PROJECT_DIR/docs/lifecycle/PROBLEM_FRAMING.md.local"
ln -s "$TEST_DIR/external-problem-framing.md" \
  "$PROJECT_DIR/docs/lifecycle/PROBLEM_FRAMING.md"
expect_fail "Lifecycle evidence must be a regular project file" "$GATE" plan
unlink "$PROJECT_DIR/docs/lifecycle/PROBLEM_FRAMING.md"
mv "$PROJECT_DIR/docs/lifecycle/PROBLEM_FRAMING.md.local" \
  "$PROJECT_DIR/docs/lifecycle/PROBLEM_FRAMING.md"
"$GATE" plan >/dev/null

cp "$PROJECT_DIR/docs/lifecycle/PROBLEM_FRAMING.md" \
  "$PROJECT_DIR/docs/lifecycle/PROBLEM_FRAMING.md.valid"
write_file "$PROJECT_DIR/docs/lifecycle/PROBLEM_FRAMING.md" \
  "# Problem Framing" \
  "Risk Level: M"
expect_fail "Missing required section: ## Observed Facts" "$GATE" plan
mv "$PROJECT_DIR/docs/lifecycle/PROBLEM_FRAMING.md.valid" \
  "$PROJECT_DIR/docs/lifecycle/PROBLEM_FRAMING.md"

set_state DESIGN_STATUS PASS
expect_fail "Required evidence is incomplete" "$GATE" design
complete_design
expect_fail "Design fingerprint is not recorded" "$GATE" design
"$RECORD" design >/dev/null
"$GATE" design >/dev/null

set_state PROTOTYPE_STATUS NA
write_file "$PROJECT_DIR/docs/lifecycle/PROTOTYPE_SMOKE_TEST.md" \
  "# Prototype Smoke Test" \
  "Applicability: N/A - the change has no executable prototype surface." \
  "Result: N/A"
expect_fail "Prototype fingerprint is not recorded" "$GATE" prototype
"$RECORD" prototype >/dev/null
"$GATE" prototype >/dev/null

set_problem_risk H
expect_fail "Plan fingerprint is stale" "$GATE" prototype
"$RECORD" plan >/dev/null
assert_state DESIGN_STATUS BLOCKED
assert_baseline DESIGN_FINGERPRINT UNRECORDED
complete_design
"$RECORD" design >/dev/null
set_state PROTOTYPE_STATUS NA
expect_fail "High-risk prototype cannot be NA" "$GATE" prototype

set_state PROTOTYPE_STATUS PASS
write_prototype FAIL
expect_fail "Prototype smoke test must contain Result: PASS" "$GATE" prototype
write_prototype PASS
expect_fail "Prototype fingerprint is not recorded" "$GATE" prototype
"$RECORD" prototype >/dev/null
"$GATE" prototype >/dev/null

awk '!/^\| P-01 /' "$PROJECT_DIR/docs/lifecycle/PROTOTYPE_SMOKE_TEST.md" > \
  "$PROJECT_DIR/docs/lifecycle/PROTOTYPE_SMOKE_TEST.md.tmp"
mv "$PROJECT_DIR/docs/lifecycle/PROTOTYPE_SMOKE_TEST.md.tmp" \
  "$PROJECT_DIR/docs/lifecycle/PROTOTYPE_SMOKE_TEST.md"
expect_fail "Prototype smoke test requires at least one PASS case" "$GATE" prototype
write_prototype PASS

set_state IMPLEMENTATION_STATUS PASS
write_smoke FAIL
write_adversarial P1 CLOSED PASS
expect_fail "Pre-release smoke test must contain Result: PASS" "$GATE" implementation

write_smoke PASS
printf '%s\n' '| S-02 | secondary mainline | completion | failed-log | FAIL |' >> \
  "$PROJECT_DIR/docs/lifecycle/SMOKE_TEST_REPORT.md"
write_adversarial P2 CLOSED PASS
expect_fail "Pre-release smoke test contains a FAIL case" "$GATE" implementation
write_smoke PASS

printf '%s\n' '| S-02 | secondary mainline | completion | pending-log | BLOCKED |' >> \
  "$PROJECT_DIR/docs/lifecycle/SMOKE_TEST_REPORT.md"
expect_fail "Pre-release smoke test contains a non-PASS case" "$GATE" implementation
write_smoke PASS

write_file "$PROJECT_DIR/docs/lifecycle/ADVERSARIAL_REVIEW.md" \
  "# Adversarial Review" \
  "## Review Scope and Independent Perspective" \
  "Independent review of the fixture." \
  "## Attack Matrix" \
  "No attack row was recorded." \
  "## Data, Model, and Agent Logic Attacks" \
  "No model or Agent surface exists." \
  "## Residual Risk" \
  "Reversible P3 risk only." \
  "## Rollback and Containment Verification" \
  "Rollback was exercised." \
  "Decision: PASS" \
  "## Decision Record" \
  "Reviewer R on 2026-08-31."
expect_fail "Adversarial review requires at least one attack row" "$GATE" implementation

write_adversarial P1 open PASS
expect_fail "Open P0/P1 adversarial findings block the gate" "$GATE" implementation

write_adversarial P1 CLOSED PASS
expect_fail "Implementation fingerprint is not recorded" "$GATE" implementation

cp "$PROJECT_DIR/.ai/LIFECYCLE_BASELINE" \
  "$PROJECT_DIR/.ai/LIFECYCLE_BASELINE.before-failed-record"
cp "$PROJECT_DIR/.ai/LIFECYCLE_STATE" \
  "$PROJECT_DIR/.ai/LIFECYCLE_STATE.before-failed-record"
write_smoke FAIL
expect_fail "Pre-release smoke test must contain Result: PASS" \
  "$RECORD" implementation
cmp "$PROJECT_DIR/.ai/LIFECYCLE_BASELINE.before-failed-record" \
  "$PROJECT_DIR/.ai/LIFECYCLE_BASELINE" >/dev/null || \
  fail "Failed recording changed the lifecycle baseline"
cmp "$PROJECT_DIR/.ai/LIFECYCLE_STATE.before-failed-record" \
  "$PROJECT_DIR/.ai/LIFECYCLE_STATE" >/dev/null || \
  fail "Failed recording changed the lifecycle state"
write_smoke PASS

mkdir "$PROJECT_DIR/.ai/.lifecycle-record.lock"
expect_fail "Another lifecycle record operation is in progress" \
  "$RECORD" implementation
rmdir "$PROJECT_DIR/.ai/.lifecycle-record.lock"

"$RECORD" implementation >/dev/null
"$GATE" implementation >/dev/null

cp "$PROJECT_DIR/scripts/check-harness.sh" \
  "$PROJECT_DIR/scripts/check-harness.sh.fresh"
printf '%s\n' "# implementation fingerprint mutation" >> \
  "$PROJECT_DIR/scripts/check-harness.sh"
expect_fail "Implementation fingerprint is stale" "$GATE" implementation
mv "$PROJECT_DIR/scripts/check-harness.sh.fresh" \
  "$PROJECT_DIR/scripts/check-harness.sh"
"$GATE" implementation >/dev/null

mkdir -p "$PROJECT_DIR/node_modules/local-cache"
write_file "$PROJECT_DIR/node_modules/local-cache/generated.js" \
  "generated dependency cache"
"$GATE" implementation >/dev/null || \
  fail "Ignored dependency caches must not stale implementation evidence"

external_target="$TEST_DIR/external-target.txt"
write_file "$external_target" "external version one"
ln -s "$external_target" "$PROJECT_DIR/external-link.txt"
expect_fail "Implementation fingerprint is stale" "$GATE" implementation
"$RECORD" implementation >/dev/null
write_file "$external_target" "external version two"
"$GATE" implementation >/dev/null || \
  fail "External symlink target content must not enter the project fingerprint"

set_state RELEASE_STATUS PASS
set_state HUMAN_APPROVAL_REF obsolete-human-approval
set_state GITHUB_STATUS APPROVED
set_state GITHUB_APPROVAL_REF obsolete-github-approval
set_state RETROSPECTIVE_STATUS PASS
"$RECORD" implementation >/dev/null
assert_state RELEASE_STATUS BLOCKED
assert_state GITHUB_STATUS BLOCKED
assert_state RETROSPECTIVE_STATUS BLOCKED
assert_state HUMAN_APPROVAL_REF NONE
assert_state GITHUB_APPROVAL_REF NONE
assert_baseline RELEASE_FINGERPRINT UNRECORDED
assert_baseline GITHUB_FINGERPRINT UNRECORDED
assert_baseline RETROSPECTIVE_FINGERPRINT UNRECORDED

set_state RELEASE_STATUS PASS
expect_fail "High-risk release requires HUMAN_APPROVAL_REF" "$GATE" release
set_state HUMAN_APPROVAL_REF approval-review-2026-08-31
expect_fail "Release fingerprint is not recorded" "$GATE" release
"$RECORD" release >/dev/null
"$GATE" release >/dev/null

cp "$PROJECT_DIR/dist/README.md" "$PROJECT_DIR/dist/README.md.fresh"
printf '%s\n' "release mutation" >> "$PROJECT_DIR/dist/README.md"
expect_fail "Release fingerprint is stale" "$GATE" release
mv "$PROJECT_DIR/dist/README.md.fresh" "$PROJECT_DIR/dist/README.md"
"$GATE" release >/dev/null

set_state GITHUB_STATUS APPROVED
expect_fail "GitHub approval requires GITHUB_APPROVAL_REF" "$GATE" github
set_state GITHUB_APPROVAL_REF user-message-2026-08-31
expect_fail "GitHub fingerprint is not recorded" "$GATE" github
"$RECORD" github >/dev/null
"$GATE" github >/dev/null

set_state GITHUB_APPROVAL_REF changed-user-message
expect_fail "GitHub fingerprint is stale" "$GATE" github
set_state GITHUB_APPROVAL_REF user-message-2026-08-31
"$GATE" github >/dev/null

set_state RETROSPECTIVE_STATUS PASS
expect_fail "Required evidence is incomplete" "$GATE" retrospective
write_retrospective
expect_fail "Retrospective fingerprint is not recorded" "$GATE" retrospective
"$RECORD" retrospective >/dev/null
"$GATE" retrospective >/dev/null

write_file "$PROJECT_DIR/docs/lifecycle/IMPROVEMENT_PROPOSAL.md" \
  "# Harness Improvement Proposal" \
  "Applicability: PROPOSED" \
  "Proposal Decision: REVIEW"
expect_fail "Missing required section: ## Triggering Evidence" \
  "$GATE" retrospective

write_improvement_proposal APPLIED
expect_fail "Improvement proposal cannot claim APPROVED or APPLIED" \
  "$GATE" retrospective

write_improvement_proposal REVIEW
"$RECORD" retrospective >/dev/null
"$GATE" retrospective >/dev/null

printf '%s\n' \
  "Applicability: NONE - contradictory applicability must be rejected." >> \
  "$PROJECT_DIR/docs/lifecycle/IMPROVEMENT_PROPOSAL.md"
expect_fail "Improvement proposal must declare exactly one Applicability" \
  "$GATE" retrospective
write_improvement_proposal REVIEW

printf '%s\n' "Proposal Decision: APPLIED" >> \
  "$PROJECT_DIR/docs/lifecycle/IMPROVEMENT_PROPOSAL.md"
expect_fail "Improvement proposal cannot claim APPROVED or APPLIED" \
  "$GATE" retrospective
write_improvement_proposal REVIEW
"$GATE" retrospective >/dev/null

newline_path="$PROJECT_DIR/docs/design/line"$'\n'"break.md"
printf '%s\n' "ambiguous path" > "$newline_path"
expect_fail "Filenames containing newlines are unsupported" "$FINGERPRINT" plan
unlink "$newline_path"

cp "$PROJECT_DIR/.ai/LIFECYCLE_STATE" "$PROJECT_DIR/.ai/LIFECYCLE_STATE.valid"
printf '%s\n' 'RISK_LEVEL=H' >> "$PROJECT_DIR/.ai/LIFECYCLE_STATE"
expect_fail "State key must occur exactly once: RISK_LEVEL" "$GATE" plan
mv "$PROJECT_DIR/.ai/LIFECYCLE_STATE.valid" "$PROJECT_DIR/.ai/LIFECYCLE_STATE"

cp "$PROJECT_DIR/.ai/LIFECYCLE_STATE" "$PROJECT_DIR/.ai/LIFECYCLE_STATE.valid"
printf '%s\n' 'EXTRA_STATUS=PASS' >> "$PROJECT_DIR/.ai/LIFECYCLE_STATE"
expect_fail "Unknown lifecycle state key: EXTRA_STATUS" "$GATE" plan
mv "$PROJECT_DIR/.ai/LIFECYCLE_STATE.valid" "$PROJECT_DIR/.ai/LIFECYCLE_STATE"

injection_target="$TEST_DIR/state-was-executed"
printf 'MALFORMED=$(touch %s)\n' "$injection_target" >> \
  "$PROJECT_DIR/.ai/LIFECYCLE_STATE"
expect_fail "Invalid lifecycle state line" "$GATE" plan
[[ ! -e "$injection_target" ]] || fail "Lifecycle state content was executed"

expect_fail "Unknown lifecycle gate" "$GATE" unknown

echo "test-lifecycle-gates: ok"
