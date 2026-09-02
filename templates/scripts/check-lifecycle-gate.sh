#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_FILE="$ROOT_DIR/.ai/LIFECYCLE_STATE"
BASELINE_FILE="$ROOT_DIR/.ai/LIFECYCLE_BASELINE"
FINGERPRINTER="$ROOT_DIR/scripts/lifecycle-fingerprint.sh"

fail() {
  echo "lifecycle-gate: $*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage: scripts/check-lifecycle-gate.sh <gate>

Gates:
  plan design prototype implementation release github retrospective
USAGE
}

[[ $# -eq 1 ]] || {
  usage >&2
  exit 2
}

REQUESTED_GATE="$1"

case "$REQUESTED_GATE" in
  plan|design|prototype|implementation|release|github|retrospective) ;;
  *) fail "Unknown lifecycle gate: $REQUESTED_GATE" ;;
esac

[[ -f "$STATE_FILE" && ! -L "$STATE_FILE" ]] || \
  fail "Lifecycle state must be a regular project file: .ai/LIFECYCLE_STATE"
[[ -f "$BASELINE_FILE" && ! -L "$BASELINE_FILE" ]] || \
  fail "Lifecycle baseline must be a regular project file: .ai/LIFECYCLE_BASELINE"
[[ -x "$FINGERPRINTER" ]] || fail "Lifecycle fingerprinter is unavailable"

state_value() {
  local key="$1"
  local count

  count="$(awk -F= -v key="$key" '$1 == key { count++ } END { print count + 0 }' "$STATE_FILE")"
  [[ "$count" == 1 ]] || fail "State key must occur exactly once: $key"

  awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print }' "$STATE_FILE"
}

require_state_value() {
  local key="$1"
  local expected="$2"
  local actual

  actual="$(state_value "$key")"
  [[ "$actual" == "$expected" ]] || fail "$key must be $expected; found $actual"
}

baseline_value() {
  local key="$1"
  local count

  count="$(awk -F= -v key="$key" '$1 == key { count++ } END { print count + 0 }' "$BASELINE_FILE")"
  [[ "$count" == 1 ]] || fail "Baseline key must occur exactly once: $key"
  awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print }' "$BASELINE_FILE"
}

require_fingerprint() {
  local gate="$1"
  local label="$2"
  local key
  local recorded
  local current

  key="$(printf '%s_FINGERPRINT' "$gate" | tr '[:lower:]' '[:upper:]')"
  recorded="$(baseline_value "$key")"
  [[ "$recorded" != UNRECORDED ]] || fail "$label fingerprint is not recorded"
  current="$($FINGERPRINTER "$gate")"
  [[ "$recorded" == "$current" ]] || fail "$label fingerprint is stale"
}

require_regular_project_file() {
  local relative="$1"
  local path="$ROOT_DIR/$relative"

  [[ -f "$path" ]] || fail "Missing lifecycle evidence: $relative"
  [[ ! -L "$path" ]] || fail "Lifecycle evidence must be a regular project file: $relative"
}

require_complete_file() {
  local relative="$1"
  local path="$ROOT_DIR/$relative"

  require_regular_project_file "$relative"

  if grep -Fq '<!-- REQUIRED:' "$path"; then
    fail "Required evidence is incomplete: $relative"
  fi

  if LC_ALL=C grep -Eq '(^|[^A-Za-z])TBD([^A-Za-z]|$)' "$path"; then
    fail "Placeholder remains: $relative"
  fi
}

require_exact_line() {
  local relative="$1"
  local expected="$2"
  local failure_message="$3"

  grep -Fxq "$expected" "$ROOT_DIR/$relative" || fail "$failure_message"
}

require_sections() {
  local relative="$1"
  local path="$ROOT_DIR/$relative"
  local section
  shift

  for section in "$@"; do
    grep -Fxq "$section" "$path" || fail "Missing required section: $section in $relative"
  done
}

require_pass_case() {
  local relative="$1"
  local label="$2"

  if ! LC_ALL=C awk -F'|' '
    function trim(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      return value
    }
    NF >= 5 && toupper(trim($(NF - 1))) == "PASS" { found = 1 }
    END { exit found ? 0 : 1 }
  ' "$ROOT_DIR/$relative"; then
    fail "$label requires at least one PASS case"
  fi
}

require_no_failed_cases() {
  local relative="$1"
  local label="$2"

  if LC_ALL=C awk -F'|' '
    function trim(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      return value
    }
    NF >= 5 && toupper(trim($(NF - 1))) == "FAIL" { found = 1 }
    END { exit found ? 0 : 1 }
  ' "$ROOT_DIR/$relative"; then
    fail "$label contains a FAIL case"
  fi

  if LC_ALL=C awk -F'|' '
    function trim(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      return value
    }
    NF >= 5 {
      status = toupper(trim($(NF - 1)))
      if (status != "PASS" && status != "FAIL" && status != "STATUS" && status !~ /^-+$/) {
        found = 1
      }
    }
    END { exit found ? 0 : 1 }
  ' "$ROOT_DIR/$relative"; then
    fail "$label contains a non-PASS case"
  fi
}

require_attack_row() {
  local relative="docs/lifecycle/ADVERSARIAL_REVIEW.md"

  if ! LC_ALL=C awk -F'|' '
    function trim(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      return value
    }
    NF >= 7 && toupper(trim($2)) ~ /^P[0-3]$/ { found = 1 }
    END { exit found ? 0 : 1 }
  ' "$ROOT_DIR/$relative"; then
    fail "Adversarial review requires at least one attack row"
  fi
}

require_improvement_disposition() {
  local relative="docs/lifecycle/IMPROVEMENT_PROPOSAL.md"
  local path="$ROOT_DIR/$relative"
  local applicability_count

  require_regular_project_file "$relative"

  applicability_count="$(LC_ALL=C grep -Ec '^Applicability:' "$path" || true)"
  [[ "$applicability_count" == 1 ]] || \
    fail "Improvement proposal must declare exactly one Applicability"

  if LC_ALL=C grep -Eq '^Proposal Decision: (APPROVED|APPLIED)$' "$path"; then
    fail "Improvement proposal cannot claim APPROVED or APPLIED"
  fi

  if LC_ALL=C grep -Eq '^Applicability: NONE - .{10,}$' "$path"; then
    return 0
  fi

  require_exact_line \
    "$relative" \
    "Applicability: PROPOSED" \
    "Improvement proposal requires either a concrete NONE rationale or Applicability: PROPOSED"
  require_complete_file "$relative"
  require_sections "$relative" \
    "# Harness Improvement Proposal" \
    "## Triggering Evidence" \
    "## Reusable Failure Pattern" \
    "## Proposed Harness Change" \
    "## Expected Benefit" \
    "## Risks and Counterexamples" \
    "## Validation Plan" \
    "## Rollback Plan" \
    "## Scope and Migration" \
    "## Human Review"
  require_exact_line \
    "$relative" \
    "Proposal Decision: REVIEW" \
    "Improvement proposal must remain in REVIEW until separately approved"
}

required_keys=(
  SCHEMA_VERSION
  RISK_LEVEL
  CURRENT_GATE
  PLAN_STATUS
  DESIGN_STATUS
  PROTOTYPE_STATUS
  IMPLEMENTATION_STATUS
  RELEASE_STATUS
  GITHUB_STATUS
  RETROSPECTIVE_STATUS
  HUMAN_APPROVAL_REF
  GITHUB_APPROVAL_REF
)

line_number=0
while IFS= read -r state_line || [[ -n "$state_line" ]]; do
  line_number=$((line_number + 1))
  if [[ ! "$state_line" =~ ^[A-Z][A-Z0-9_]*=[A-Za-z0-9._:/@%+?\&=#-]+$ ]]; then
    fail "Invalid lifecycle state line $line_number"
  fi

  state_key="${state_line%%=*}"
  case "$state_key" in
    SCHEMA_VERSION|RISK_LEVEL|CURRENT_GATE|PLAN_STATUS|DESIGN_STATUS|PROTOTYPE_STATUS|IMPLEMENTATION_STATUS|RELEASE_STATUS|GITHUB_STATUS|RETROSPECTIVE_STATUS|HUMAN_APPROVAL_REF|GITHUB_APPROVAL_REF) ;;
    *) fail "Unknown lifecycle state key: $state_key" ;;
  esac
done < "$STATE_FILE"

for key in "${required_keys[@]}"; do
  state_value "$key" >/dev/null
done

baseline_required_keys=(
  SCHEMA_VERSION
  PLAN_FINGERPRINT
  DESIGN_FINGERPRINT
  PROTOTYPE_FINGERPRINT
  IMPLEMENTATION_FINGERPRINT
  RELEASE_FINGERPRINT
  GITHUB_FINGERPRINT
  RETROSPECTIVE_FINGERPRINT
)

line_number=0
while IFS= read -r baseline_line || [[ -n "$baseline_line" ]]; do
  line_number=$((line_number + 1))
  if [[ ! "$baseline_line" =~ ^[A-Z][A-Z0-9_]*=(UNRECORDED|sha256:[0-9a-f]{64}|cksum:[0-9]+:[0-9]+|1)$ ]]; then
    fail "Invalid lifecycle baseline line $line_number"
  fi
  baseline_key="${baseline_line%%=*}"
  case "$baseline_key" in
    SCHEMA_VERSION|PLAN_FINGERPRINT|DESIGN_FINGERPRINT|PROTOTYPE_FINGERPRINT|IMPLEMENTATION_FINGERPRINT|RELEASE_FINGERPRINT|GITHUB_FINGERPRINT|RETROSPECTIVE_FINGERPRINT) ;;
    *) fail "Unknown lifecycle baseline key: $baseline_key" ;;
  esac
done < "$BASELINE_FILE"

for key in "${baseline_required_keys[@]}"; do
  baseline_value "$key" >/dev/null
done

[[ "$(baseline_value SCHEMA_VERSION)" == 1 ]] || fail "Unsupported lifecycle baseline schema"

require_state_value SCHEMA_VERSION 1

RISK_LEVEL="$(state_value RISK_LEVEL)"
case "$RISK_LEVEL" in
  L|M|H) ;;
  *) fail "RISK_LEVEL must be L, M, or H; found $RISK_LEVEL" ;;
esac

CURRENT_GATE="$(state_value CURRENT_GATE)"
case "$CURRENT_GATE" in
  plan|design|prototype|implementation|release|github|retrospective) ;;
  *) fail "CURRENT_GATE is invalid: $CURRENT_GATE" ;;
esac

for status_key in PLAN_STATUS DESIGN_STATUS IMPLEMENTATION_STATUS RELEASE_STATUS RETROSPECTIVE_STATUS; do
  status_value="$(state_value "$status_key")"
  case "$status_value" in
    BLOCKED|PASS) ;;
    *) fail "$status_key must be BLOCKED or PASS; found $status_value" ;;
  esac
done

PROTOTYPE_STATUS="$(state_value PROTOTYPE_STATUS)"
case "$PROTOTYPE_STATUS" in
  BLOCKED|PASS|NA) ;;
  *) fail "PROTOTYPE_STATUS must be BLOCKED, PASS, or NA; found $PROTOTYPE_STATUS" ;;
esac

GITHUB_STATUS="$(state_value GITHUB_STATUS)"
case "$GITHUB_STATUS" in
  BLOCKED|APPROVED) ;;
  *) fail "GITHUB_STATUS must be BLOCKED or APPROVED; found $GITHUB_STATUS" ;;
esac

check_plan() {
  require_state_value PLAN_STATUS PASS
  require_complete_file "docs/lifecycle/PROBLEM_FRAMING.md"
  require_sections "docs/lifecycle/PROBLEM_FRAMING.md" \
    "# Problem Framing" \
    "## Observed Facts" \
    "## Surface Request" \
    "## U-Shaped Descent to the Root Need" \
    "## Core Goal and Success Measures" \
    "## First-Principles Constraints" \
    "## Non-Goals and Rejected Pseudo-Requirements" \
    "## Risk Classification" \
    "## Risk-Level Rationale" \
    "## Plan Gate Decision"
  require_exact_line \
    "docs/lifecycle/PROBLEM_FRAMING.md" \
    "Risk Level: $RISK_LEVEL" \
    "Problem-framing risk level must match .ai/LIFECYCLE_STATE"
  require_fingerprint plan Plan
}

check_design() {
  check_plan
  require_state_value DESIGN_STATUS PASS
  require_complete_file "docs/product/PRD.md"
  require_complete_file "docs/technical/TECHNICAL_PRD.md"
  require_complete_file "docs/lifecycle/DESIGN_CHALLENGE.md"
  require_sections "docs/product/PRD.md" \
    "# Product Requirements Document" \
    "## Problem and Evidence Reference" \
    "## Core Outcome and Success Metrics" \
    "## Non-Goals and Rejected Pseudo-Requirements" \
    "## Failure and Business-Backfire Scenarios" \
    "## Acceptance Criteria" \
    "## Evidence and Verification Mapping"
  require_sections "docs/technical/TECHNICAL_PRD.md" \
    "# Technical Requirements Document" \
    "## Architecture and Trust Boundaries" \
    "## Assumptions and Falsification Plan" \
    "## Alternatives and Decision" \
    "## Failure, Containment, and Rollback Design" \
    "## Smoke and Adversarial Verification Plan" \
    "## Data, Model, and Agent Controls" \
    "## Residual Risk and Approval"
  require_sections "docs/lifecycle/DESIGN_CHALLENGE.md" \
    "# Design Challenge" \
    "## Root Problem Restatement" \
    "## Assumptions to Falsify" \
    "## First-Principles Constraints" \
    "## Option A" \
    "## Option B" \
    "## Selected Path and Rejected Alternatives" \
    "## Adversarial Design Attacks" \
    "## Fallback and Rollback Path" \
    "## Design Gate Decision"
  require_fingerprint design Design
}

check_prototype() {
  check_design
  require_regular_project_file "docs/lifecycle/PROTOTYPE_SMOKE_TEST.md"

  case "$PROTOTYPE_STATUS" in
    PASS)
      require_complete_file "docs/lifecycle/PROTOTYPE_SMOKE_TEST.md"
      require_sections "docs/lifecycle/PROTOTYPE_SMOKE_TEST.md" \
        "# Prototype Smoke Test" \
        "## Minimum Mainline" \
        "## Environment and Preconditions" \
        "## Smoke Cases" \
        "## Failure and Stop Condition" \
        "## Decision Record"
      require_exact_line \
        "docs/lifecycle/PROTOTYPE_SMOKE_TEST.md" \
        "Applicability: REQUIRED" \
        "Applicable prototype smoke test must contain Applicability: REQUIRED"
      require_exact_line \
        "docs/lifecycle/PROTOTYPE_SMOKE_TEST.md" \
        "Result: PASS" \
        "Prototype smoke test must contain Result: PASS"
      require_pass_case \
        "docs/lifecycle/PROTOTYPE_SMOKE_TEST.md" \
        "Prototype smoke test"
      require_no_failed_cases \
        "docs/lifecycle/PROTOTYPE_SMOKE_TEST.md" \
        "Prototype smoke test"
      ;;
    NA)
      [[ "$RISK_LEVEL" != H ]] || fail "High-risk prototype cannot be NA"
      if ! LC_ALL=C grep -Eq '^Applicability: N/A - .{10,}$' \
        "$ROOT_DIR/docs/lifecycle/PROTOTYPE_SMOKE_TEST.md"; then
        fail "Prototype NA requires a concrete Applicability rationale"
      fi
      ;;
    *)
      fail "PROTOTYPE_STATUS must be PASS or an allowed NA; found $PROTOTYPE_STATUS"
      ;;
  esac
  require_fingerprint prototype Prototype
}

check_implementation() {
  check_prototype
  require_state_value IMPLEMENTATION_STATUS PASS
  require_complete_file "docs/lifecycle/SMOKE_TEST_REPORT.md"
  require_sections "docs/lifecycle/SMOKE_TEST_REPORT.md" \
    "# Pre-Release Smoke Test Report" \
    "## Release Candidate" \
    "## Critical Mainlines" \
    "## Negative Control" \
    "## Rollback Signal" \
    "## Skipped Checks" \
    "## Decision Record"
  require_exact_line \
    "docs/lifecycle/SMOKE_TEST_REPORT.md" \
    "Result: PASS" \
    "Pre-release smoke test must contain Result: PASS"
  require_pass_case \
    "docs/lifecycle/SMOKE_TEST_REPORT.md" \
    "Pre-release smoke test"
  require_no_failed_cases \
    "docs/lifecycle/SMOKE_TEST_REPORT.md" \
    "Pre-release smoke test"
  require_complete_file "docs/lifecycle/ADVERSARIAL_REVIEW.md"
  require_sections "docs/lifecycle/ADVERSARIAL_REVIEW.md" \
    "# Adversarial Review" \
    "## Review Scope and Independent Perspective" \
    "## Attack Matrix" \
    "## Data, Model, and Agent Logic Attacks" \
    "## Residual Risk" \
    "## Rollback and Containment Verification" \
    "## Decision Record"
  require_attack_row

  if LC_ALL=C awk -F'|' '
    function trim(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      return value
    }
    {
      severity = toupper(trim($2))
      status = toupper(trim($3))
      if ((severity == "P0" || severity == "P1") && status != "CLOSED") {
        blocked = 1
      }
    }
    END { exit blocked ? 0 : 1 }
  ' "$ROOT_DIR/docs/lifecycle/ADVERSARIAL_REVIEW.md"; then
    fail "Open P0/P1 adversarial findings block the gate"
  fi

  require_exact_line \
    "docs/lifecycle/ADVERSARIAL_REVIEW.md" \
    "Decision: PASS" \
    "Adversarial review must contain Decision: PASS"
  require_fingerprint implementation Implementation
}

check_release() {
  check_implementation
  require_state_value RELEASE_STATUS PASS

  if [[ "$RISK_LEVEL" == H ]]; then
    human_approval_ref="$(state_value HUMAN_APPROVAL_REF)"
    if [[ -z "$human_approval_ref" || "$human_approval_ref" == NONE ]]; then
      fail "High-risk release requires HUMAN_APPROVAL_REF"
    fi
  fi
  require_fingerprint release Release
}

check_github() {
  check_release
  require_state_value GITHUB_STATUS APPROVED

  github_approval_ref="$(state_value GITHUB_APPROVAL_REF)"
  if [[ -z "$github_approval_ref" || "$github_approval_ref" == NONE ]]; then
    fail "GitHub approval requires GITHUB_APPROVAL_REF"
  fi
  require_fingerprint github GitHub
}

check_retrospective() {
  check_release
  require_state_value RETROSPECTIVE_STATUS PASS
  require_complete_file "docs/lifecycle/RETROSPECTIVE.md"
  require_sections "docs/lifecycle/RETROSPECTIVE.md" \
    "# Retrospective" \
    "## Observable Facts" \
    "## U-Shaped Root-Cause Descent" \
    "## Violated First-Principles Constraint" \
    "## Counterfactual" \
    "## Systemic Corrective Actions" \
    "## Learning Returned to the Harness" \
    "## Retrospective Gate Decision"
  require_improvement_disposition
  require_fingerprint retrospective Retrospective
}

case "$REQUESTED_GATE" in
  plan) check_plan ;;
  design) check_design ;;
  prototype) check_prototype ;;
  implementation) check_implementation ;;
  release) check_release ;;
  github) check_github ;;
  retrospective) check_retrospective ;;
esac

echo "lifecycle-gate: $REQUESTED_GATE ok (risk $RISK_LEVEL)"
