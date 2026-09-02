#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

required_files=(
  "AGENTS.md"
  "CLAUDE.md"
  "GEMINI.md"
  ".cursor/rules/project-lifecycle.mdc"
  ".ai/PROJECT_CONTEXT.md"
  ".ai/PROJECT_RULES.md"
  ".ai/PROJECT_HISTORY.md"
  ".ai/WORKFLOW.md"
  ".ai/HARNESS_VERSION"
  ".ai/LIFECYCLE_STATE"
  ".ai/LIFECYCLE_BASELINE"
  "docs/product/PRD.md"
  "docs/technical/TECHNICAL_PRD.md"
  "docs/design/README.md"
  "docs/design-review/README.md"
  "docs/data/DATA_DICT.md"
  "docs/data/DELIVERY_RULES.md"
  "docs/lifecycle/README.md"
  "docs/lifecycle/PROBLEM_FRAMING.md"
  "docs/lifecycle/DESIGN_CHALLENGE.md"
  "docs/lifecycle/PROTOTYPE_SMOKE_TEST.md"
  "docs/lifecycle/SMOKE_TEST_REPORT.md"
  "docs/lifecycle/ADVERSARIAL_REVIEW.md"
  "docs/lifecycle/RETROSPECTIVE.md"
  "docs/lifecycle/IMPROVEMENT_PROPOSAL.md"
  "dist/README.md"
  "scripts/check-lifecycle-gate.sh"
  "scripts/lifecycle-fingerprint.sh"
  "scripts/record-lifecycle-gate.sh"
  ".github/workflows/harness-gates.yml"
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$ROOT_DIR/$file" ]]; then
    echo "Missing required harness file: $file" >&2
    exit 1
  fi
  if [[ -L "$ROOT_DIR/$file" ]]; then
    echo "Required harness file must not be a symbolic link: $file" >&2
    exit 1
  fi
done

for script in \
  scripts/check-lifecycle-gate.sh \
  scripts/lifecycle-fingerprint.sh \
  scripts/record-lifecycle-gate.sh; do
  if [[ ! -x "$ROOT_DIR/$script" ]]; then
    echo "Lifecycle script is not executable: $script" >&2
    exit 1
  fi
done

bash -n "$ROOT_DIR/scripts/check-harness.sh"
bash -n "$ROOT_DIR/scripts/check-lifecycle-gate.sh"
bash -n "$ROOT_DIR/scripts/lifecycle-fingerprint.sh"
bash -n "$ROOT_DIR/scripts/record-lifecycle-gate.sh"

if ! grep -Fxq "SCHEMA_VERSION=1" "$ROOT_DIR/.ai/LIFECYCLE_STATE"; then
  echo "Unsupported or missing lifecycle state schema" >&2
  exit 1
fi

if ! grep -Fxq "SCHEMA_VERSION=1" "$ROOT_DIR/.ai/LIFECYCLE_BASELINE"; then
  echo "Unsupported or missing lifecycle baseline schema" >&2
  exit 1
fi

if ! grep -Fq "scripts/check-lifecycle-gate.sh github" \
  "$ROOT_DIR/.github/workflows/harness-gates.yml"; then
  echo "GitHub Actions must enforce the fixed github lifecycle gate" >&2
  exit 1
fi

if ! grep -Fq ".ai/PROJECT_RULES.md is the single source of truth" "$ROOT_DIR/.ai/PROJECT_RULES.md"; then
  echo "Missing single-source-of-truth declaration in .ai/PROJECT_RULES.md" >&2
  exit 1
fi

for file in AGENTS.md CLAUDE.md GEMINI.md .cursor/rules/project-lifecycle.mdc; do
  if ! grep -Fq ".ai/PROJECT_RULES.md is the single source of truth" "$ROOT_DIR/$file"; then
    echo "Entry file does not point to .ai/PROJECT_RULES.md as rule source: $file" >&2
    exit 1
  fi
  if ! grep -Fq ".ai/LIFECYCLE_STATE" "$ROOT_DIR/$file"; then
    echo "Entry file does not point to .ai/LIFECYCLE_STATE: $file" >&2
    exit 1
  fi
  if ! grep -Fq ".ai/LIFECYCLE_BASELINE" "$ROOT_DIR/$file"; then
    echo "Entry file does not point to .ai/LIFECYCLE_BASELINE: $file" >&2
    exit 1
  fi
done

echo "check-harness: ok"
