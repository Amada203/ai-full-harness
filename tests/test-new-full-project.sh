#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PROJECT_NAME="demo-full-app"
PROJECT_DIR="$TMP_DIR/$PROJECT_NAME"

AI_PROJECT_STACK='React / Node.js & shell \ tools' \
AI_PROJECT_DESCRIPTION='A demo / app & harness \ path' \
  "$ROOT_DIR/bin/new-full-project" "$PROJECT_NAME" "$TMP_DIR"

assert_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "Expected file missing: $path" >&2
    exit 1
  fi
}

assert_dir() {
  local path="$1"
  if [[ ! -d "$path" ]]; then
    echo "Expected directory missing: $path" >&2
    exit 1
  fi
}

assert_missing() {
  local path="$1"
  if [[ -e "$path" ]]; then
    echo "Expected path to be absent: $path" >&2
    exit 1
  fi
}

assert_contains() {
  local path="$1"
  local expected="$2"
  if ! grep -Fq "$expected" "$path"; then
    echo "Expected '$expected' in $path" >&2
    exit 1
  fi
}

assert_file "$PROJECT_DIR/AGENTS.md"
assert_file "$PROJECT_DIR/CLAUDE.md"
assert_file "$PROJECT_DIR/GEMINI.md"
assert_file "$PROJECT_DIR/.cursor/rules/project-lifecycle.mdc"
assert_file "$PROJECT_DIR/.ai/PROJECT_CONTEXT.md"
assert_file "$PROJECT_DIR/.ai/PROJECT_RULES.md"
assert_file "$PROJECT_DIR/.ai/PROJECT_HISTORY.md"
assert_file "$PROJECT_DIR/.ai/WORKFLOW.md"
assert_file "$PROJECT_DIR/.ai/HARNESS_VERSION"
assert_file "$PROJECT_DIR/.ai/LIFECYCLE_STATE"
assert_file "$PROJECT_DIR/.ai/LIFECYCLE_BASELINE"
assert_file "$PROJECT_DIR/docs/product/PRD.md"
assert_file "$PROJECT_DIR/docs/technical/TECHNICAL_PRD.md"
assert_file "$PROJECT_DIR/docs/design/README.md"
assert_file "$PROJECT_DIR/docs/design-review/README.md"
assert_file "$PROJECT_DIR/docs/data/DATA_DICT.md"
assert_file "$PROJECT_DIR/docs/data/DELIVERY_RULES.md"
assert_file "$PROJECT_DIR/docs/lifecycle/README.md"
assert_file "$PROJECT_DIR/docs/lifecycle/PROBLEM_FRAMING.md"
assert_file "$PROJECT_DIR/docs/lifecycle/DESIGN_CHALLENGE.md"
assert_file "$PROJECT_DIR/docs/lifecycle/PROTOTYPE_SMOKE_TEST.md"
assert_file "$PROJECT_DIR/docs/lifecycle/SMOKE_TEST_REPORT.md"
assert_file "$PROJECT_DIR/docs/lifecycle/ADVERSARIAL_REVIEW.md"
assert_file "$PROJECT_DIR/docs/lifecycle/RETROSPECTIVE.md"
assert_file "$PROJECT_DIR/docs/lifecycle/IMPROVEMENT_PROPOSAL.md"
assert_file "$PROJECT_DIR/dist/README.md"
assert_file "$PROJECT_DIR/scripts/check-harness.sh"
assert_file "$PROJECT_DIR/scripts/check-lifecycle-gate.sh"
assert_file "$PROJECT_DIR/scripts/lifecycle-fingerprint.sh"
assert_file "$PROJECT_DIR/scripts/record-lifecycle-gate.sh"
assert_file "$PROJECT_DIR/.github/workflows/harness-gates.yml"
assert_dir "$PROJECT_DIR/.git"

assert_missing "$PROJECT_DIR/PROJECT_CONTEXT.md"
assert_missing "$PROJECT_DIR/PROJECT_RULES.md"
assert_missing "$PROJECT_DIR/PROJECT_HISTORY.md"
assert_missing "$PROJECT_DIR/.DS_Store"

assert_contains "$PROJECT_DIR/.ai/PROJECT_CONTEXT.md" "Project: demo-full-app"
assert_contains "$PROJECT_DIR/.ai/PROJECT_CONTEXT.md" "Stage 0 Plan"
assert_contains "$PROJECT_DIR/.ai/PROJECT_CONTEXT.md" 'React / Node.js & shell \ tools'
assert_contains "$PROJECT_DIR/.ai/PROJECT_CONTEXT.md" 'A demo / app & harness \ path'
assert_contains "$PROJECT_DIR/.ai/PROJECT_CONTEXT.md" "Risk Level: M"
assert_contains "$PROJECT_DIR/.ai/HARNESS_VERSION" "2.2.0"
assert_contains "$PROJECT_DIR/.ai/LIFECYCLE_STATE" "RISK_LEVEL=M"
assert_contains "$PROJECT_DIR/.ai/LIFECYCLE_STATE" "PLAN_STATUS=BLOCKED"
assert_contains "$PROJECT_DIR/.ai/LIFECYCLE_BASELINE" "PLAN_FINGERPRINT=UNRECORDED"
assert_contains "$PROJECT_DIR/docs/lifecycle/ADVERSARIAL_REVIEW.md" "Data, Model, and Agent Logic Attacks"
assert_contains "$PROJECT_DIR/docs/data/DATA_DICT.md" "<!-- REQUIRED:"
assert_contains "$PROJECT_DIR/docs/data/DELIVERY_RULES.md" "<!-- REQUIRED:"
assert_contains "$PROJECT_DIR/.ai/PROJECT_RULES.md" ".ai/PROJECT_RULES.md is the single source of truth"
assert_contains "$PROJECT_DIR/.ai/PROJECT_RULES.md" "Document and Directory Map"
assert_contains "$PROJECT_DIR/.ai/PROJECT_RULES.md" "Agent Startup Protocol"
assert_contains "$PROJECT_DIR/.ai/PROJECT_RULES.md" "First-Principles Reasoning"
assert_contains "$PROJECT_DIR/.ai/PROJECT_RULES.md" "U-Shaped Thinking"
assert_contains "$PROJECT_DIR/.ai/PROJECT_RULES.md" "Smoke Testing"
assert_contains "$PROJECT_DIR/.ai/PROJECT_RULES.md" "Adversarial Review"
assert_contains "$PROJECT_DIR/.ai/PROJECT_RULES.md" "Enforcement Boundary"
assert_contains "$PROJECT_DIR/.ai/PROJECT_RULES.md" "docs/product/"
assert_contains "$PROJECT_DIR/.ai/PROJECT_RULES.md" "docs/technical/"
assert_contains "$PROJECT_DIR/.ai/WORKFLOW.md" "Standard Task Flow"
assert_contains "$PROJECT_DIR/.ai/WORKFLOW.md" 'Read `.ai/PROJECT_CONTEXT.md`'
assert_contains "$PROJECT_DIR/.ai/WORKFLOW.md" 'Read `.ai/LIFECYCLE_STATE`'
assert_contains "$PROJECT_DIR/.ai/WORKFLOW.md" 'Read `.ai/LIFECYCLE_BASELINE`'
assert_contains "$PROJECT_DIR/.ai/WORKFLOW.md" "record-lifecycle-gate.sh plan"
assert_contains "$PROJECT_DIR/.ai/WORKFLOW.md" "check-lifecycle-gate.sh plan"
assert_contains "$PROJECT_DIR/.ai/WORKFLOW.md" "Stage 3.5 Test and Debug"
assert_contains "$PROJECT_DIR/.ai/WORKFLOW.md" "Stage 7 Retrospective"
assert_contains "$PROJECT_DIR/.ai/WORKFLOW.md" "standalone HTML mockup"
assert_contains "$PROJECT_DIR/.ai/WORKFLOW.md" "Ask whether to submit to GitHub"
assert_contains "$PROJECT_DIR/.ai/PROJECT_RULES.md" "Test and Debug"
assert_contains "$PROJECT_DIR/.ai/PROJECT_RULES.md" "standalone HTML mockup"
assert_contains "$PROJECT_DIR/.ai/PROJECT_RULES.md" "Ask whether to submit to GitHub"
assert_contains "$PROJECT_DIR/AGENTS.md" ".ai/PROJECT_RULES.md is the single source of truth"
assert_contains "$PROJECT_DIR/AGENTS.md" ".ai/LIFECYCLE_STATE"
assert_contains "$PROJECT_DIR/AGENTS.md" ".ai/LIFECYCLE_BASELINE"
assert_contains "$PROJECT_DIR/CLAUDE.md" ".ai/PROJECT_RULES.md is the single source of truth"
assert_contains "$PROJECT_DIR/CLAUDE.md" ".ai/LIFECYCLE_STATE"
assert_contains "$PROJECT_DIR/CLAUDE.md" ".ai/LIFECYCLE_BASELINE"
assert_contains "$PROJECT_DIR/GEMINI.md" ".ai/PROJECT_RULES.md is the single source of truth"
assert_contains "$PROJECT_DIR/GEMINI.md" ".ai/LIFECYCLE_STATE"
assert_contains "$PROJECT_DIR/GEMINI.md" ".ai/LIFECYCLE_BASELINE"
assert_contains "$PROJECT_DIR/.cursor/rules/project-lifecycle.mdc" "alwaysApply: true"
assert_contains "$PROJECT_DIR/.cursor/rules/project-lifecycle.mdc" ".ai/PROJECT_RULES.md is the single source of truth"
assert_contains "$PROJECT_DIR/.cursor/rules/project-lifecycle.mdc" ".ai/LIFECYCLE_STATE"
assert_contains "$PROJECT_DIR/.cursor/rules/project-lifecycle.mdc" ".ai/LIFECYCLE_BASELINE"
assert_contains "$PROJECT_DIR/.github/workflows/harness-gates.yml" \
  "scripts/check-lifecycle-gate.sh github"

if [[ ! -x "$PROJECT_DIR/scripts/lifecycle-fingerprint.sh" ]]; then
  echo "Expected lifecycle-fingerprint.sh to be executable" >&2
  exit 1
fi
[[ -x "$PROJECT_DIR/scripts/record-lifecycle-gate.sh" ]] || {
  echo "Expected record-lifecycle-gate.sh to be executable" >&2
  exit 1
}

"$PROJECT_DIR/scripts/check-harness.sh"

cp "$PROJECT_DIR/AGENTS.md" "$PROJECT_DIR/AGENTS.md.valid"
awk '!/\.ai\/LIFECYCLE_STATE/' "$PROJECT_DIR/AGENTS.md" > \
  "$PROJECT_DIR/AGENTS.md.tmp"
mv "$PROJECT_DIR/AGENTS.md.tmp" "$PROJECT_DIR/AGENTS.md"
if "$PROJECT_DIR/scripts/check-harness.sh" >/dev/null 2>&1; then
  echo "Expected check-harness to reject an entry file without lifecycle state" >&2
  exit 1
fi
mv "$PROJECT_DIR/AGENTS.md.valid" "$PROJECT_DIR/AGENTS.md"

if "$PROJECT_DIR/scripts/check-lifecycle-gate.sh" plan >/dev/null 2>&1; then
  echo "Expected a fresh project to fail the plan gate" >&2
  exit 1
fi

if multiline_output="$(AI_PROJECT_DESCRIPTION=$'line one\nline two' \
  "$ROOT_DIR/bin/new-full-project" --no-git invalid-multiline "$TMP_DIR" \
  2>&1)"; then
  echo "Expected the generator to reject a multiline description" >&2
  exit 1
fi
case "$multiline_output" in
  *"AI_PROJECT_DESCRIPTION must be a single line"*) ;;
  *) echo "Unexpected multiline validation error: $multiline_output" >&2; exit 1 ;;
esac

DEFAULT_PROJECT_DIR="$TMP_DIR/default-values-app"
"$ROOT_DIR/bin/new-full-project" --no-git default-values-app "$TMP_DIR" >/dev/null
assert_contains "$DEFAULT_PROJECT_DIR/.ai/PROJECT_CONTEXT.md" \
  "Not provided during initialization; resolve in Stage 0."

if rg -n '(^|[^A-Za-z])TBD([^A-Za-z]|$)' "$PROJECT_DIR/docs" >/dev/null; then
  echo "Expected generated documentation to use explicit required markers instead of TBD" >&2
  exit 1
fi

echo "test-new-full-project: ok"
