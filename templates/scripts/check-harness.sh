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
  ".ai/ARCHIFY_LOCK.json"
  ".ai/PROJECT_ID"
  ".ai/CONTINUITY_CHECKPOINT.json"
  ".ai/KNOWLEDGE_SYNC.yml"
  "docs/architecture/README.md"
  "scripts/architecture.mjs"
  "scripts/project-continuity.mjs"
  "scripts/knowledge-sync.mjs"
  ".ai/LIFECYCLE_STATE"
  ".ai/LIFECYCLE_BASELINE"
  ".autopilot/CONSTITUTION.yml"
  ".autopilot/ENROLLMENT.yml"
  ".autopilot/POLICY.yml"
  ".autopilot/OBJECTIVES.md"
  ".autopilot/PROTECTED_PATHS.yml"
  ".autopilot/AUTOPILOT_STATE"
  ".autopilot/GITHUB_GRANT.yml"
  "docs/product/PRD.md"
  "docs/technical/TECHNICAL_PRD.md"
  "docs/design/README.md"
  "docs/design-review/README.md"
  "docs/data/DATA_DICT.md"
  "docs/data/DELIVERY_RULES.md"
  "docs/autopilot/README.md"
  "docs/autopilot/FEEDBACK.md"
  "docs/lifecycle/README.md"
  "docs/lifecycle/PROBLEM_FRAMING.md"
  "docs/lifecycle/DESIGN_CHALLENGE.md"
  "docs/lifecycle/PROTOTYPE_SMOKE_TEST.md"
  "docs/lifecycle/SMOKE_TEST_REPORT.md"
  "docs/lifecycle/ADVERSARIAL_REVIEW.md"
  "docs/lifecycle/RETROSPECTIVE.md"
  "docs/lifecycle/IMPROVEMENT_PROPOSAL.md"
  "docs/lifecycle/REFACTOR_PLAN.md"
  "docs/lifecycle/REFACTOR_RECOVERY.md"
  "dist/README.md"
  "scripts/check-lifecycle-gate.sh"
  "scripts/autopilot-fingerprint.sh"
  "scripts/check-autopilot-contract.sh"
  "scripts/check-autopilot-grant.sh"
  "scripts/lifecycle-fingerprint.sh"
  "scripts/record-lifecycle-gate.sh"
  "scripts/transition-autopilot.sh"
  "scripts/check-refactor.sh"
  "scripts/start-refactor.sh"
  "scripts/transition-refactor.sh"
  ".github/workflows/harness-gates.yml"
  ".github/workflows/autopilot-enrollment.yml"
  ".github/workflows/autopilot-upgrade-receiver.yml"
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
  scripts/autopilot-fingerprint.sh \
  scripts/check-autopilot-contract.sh \
  scripts/check-autopilot-grant.sh \
  scripts/check-lifecycle-gate.sh \
  scripts/lifecycle-fingerprint.sh \
  scripts/record-lifecycle-gate.sh \
  scripts/transition-autopilot.sh; do
  if [[ ! -x "$ROOT_DIR/$script" ]]; then
    echo "Harness script is not executable: $script" >&2
    exit 1
  fi
done

for script in scripts/check-refactor.sh scripts/start-refactor.sh scripts/transition-refactor.sh; do
  if [[ ! -x "$ROOT_DIR/$script" ]]; then
    echo "Harness script is not executable: $script" >&2
    exit 1
  fi
  bash -n "$ROOT_DIR/$script"
done

if [[ ! -x "$ROOT_DIR/scripts/project-continuity.mjs" ]]; then
  echo "Harness script is not executable: scripts/project-continuity.mjs" >&2
  exit 1
fi

if [[ ! -x "$ROOT_DIR/scripts/knowledge-sync.mjs" ]]; then
  echo "Harness script is not executable: scripts/knowledge-sync.mjs" >&2
  exit 1
fi

bash -n "$ROOT_DIR/scripts/autopilot-fingerprint.sh"
bash -n "$ROOT_DIR/scripts/check-autopilot-contract.sh"
bash -n "$ROOT_DIR/scripts/check-autopilot-grant.sh"
bash -n "$ROOT_DIR/scripts/check-harness.sh"
bash -n "$ROOT_DIR/scripts/check-lifecycle-gate.sh"
bash -n "$ROOT_DIR/scripts/lifecycle-fingerprint.sh"
bash -n "$ROOT_DIR/scripts/record-lifecycle-gate.sh"
bash -n "$ROOT_DIR/scripts/transition-autopilot.sh"
node --check "$ROOT_DIR/scripts/project-continuity.mjs"
node --check "$ROOT_DIR/scripts/knowledge-sync.mjs"

if ! grep -Eq '^PROJECT_ID=([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}|\{\{PROJECT_ID\}\})$' \
  "$ROOT_DIR/.ai/PROJECT_ID"; then
  echo "Invalid project identity" >&2
  exit 1
fi

node -e '
const fs = require("node:fs");
const value = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
if (value.schemaVersion !== 1 || !["UNINITIALIZED", "CAPTURED"].includes(value.status)) process.exit(1);
' "$ROOT_DIR/.ai/CONTINUITY_CHECKPOINT.json" || {
  echo "Invalid continuity checkpoint schema" >&2
  exit 1
}

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
  if ! grep -Fq "node scripts/project-continuity.mjs audit" "$ROOT_DIR/$file"; then
    echo "Entry file does not invoke continuity audit: $file" >&2
    exit 1
  fi
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
  if ! grep -Fq "scripts/check-autopilot-contract.sh" "$ROOT_DIR/$file"; then
    echo "Entry file does not point to the Autopilot validator: $file" >&2
    exit 1
  fi
  if ! grep -Fq "never source" "$ROOT_DIR/$file"; then
    echo "Entry file does not prohibit sourcing Autopilot data: $file" >&2
    exit 1
  fi
done

echo "check-harness: ok"
