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
  "docs/product/PRD.md"
  "docs/technical/TECHNICAL_PRD.md"
  "docs/design/README.md"
  "docs/design-review/README.md"
  "docs/data/DATA_DICT.md"
  "docs/data/DELIVERY_RULES.md"
  "dist/README.md"
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$ROOT_DIR/$file" ]]; then
    echo "Missing required harness file: $file" >&2
    exit 1
  fi
done

if ! grep -Fq ".ai/PROJECT_RULES.md is the single source of truth" "$ROOT_DIR/.ai/PROJECT_RULES.md"; then
  echo "Missing single-source-of-truth declaration in .ai/PROJECT_RULES.md" >&2
  exit 1
fi

for file in AGENTS.md CLAUDE.md GEMINI.md .cursor/rules/project-lifecycle.mdc; do
  if ! grep -Fq ".ai/PROJECT_RULES.md is the single source of truth" "$ROOT_DIR/$file"; then
    echo "Entry file does not point to .ai/PROJECT_RULES.md as rule source: $file" >&2
    exit 1
  fi
done

echo "check-harness: ok"
