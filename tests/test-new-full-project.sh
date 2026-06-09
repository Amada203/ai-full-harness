#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PROJECT_NAME="demo-full-app"
PROJECT_DIR="$TMP_DIR/$PROJECT_NAME"

AI_PROJECT_STACK="React + Node.js" \
AI_PROJECT_DESCRIPTION="A demo app for full harness initialization" \
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
assert_file "$PROJECT_DIR/docs/product/PRD.md"
assert_file "$PROJECT_DIR/docs/technical/TECHNICAL_PRD.md"
assert_file "$PROJECT_DIR/docs/design/README.md"
assert_file "$PROJECT_DIR/docs/design-review/README.md"
assert_file "$PROJECT_DIR/docs/data/DATA_DICT.md"
assert_file "$PROJECT_DIR/docs/data/DELIVERY_RULES.md"
assert_file "$PROJECT_DIR/dist/README.md"
assert_file "$PROJECT_DIR/scripts/check-harness.sh"
assert_dir "$PROJECT_DIR/.git"

assert_missing "$PROJECT_DIR/PROJECT_CONTEXT.md"
assert_missing "$PROJECT_DIR/PROJECT_RULES.md"
assert_missing "$PROJECT_DIR/PROJECT_HISTORY.md"

assert_contains "$PROJECT_DIR/.ai/PROJECT_CONTEXT.md" "Project: demo-full-app"
assert_contains "$PROJECT_DIR/.ai/PROJECT_CONTEXT.md" "Stage 0 Plan"
assert_contains "$PROJECT_DIR/.ai/PROJECT_CONTEXT.md" "React + Node.js"
assert_contains "$PROJECT_DIR/.ai/PROJECT_RULES.md" ".ai/PROJECT_RULES.md is the single source of truth"
assert_contains "$PROJECT_DIR/.ai/PROJECT_RULES.md" "Document and Directory Map"
assert_contains "$PROJECT_DIR/.ai/PROJECT_RULES.md" "Agent Startup Protocol"
assert_contains "$PROJECT_DIR/.ai/PROJECT_RULES.md" "docs/product/"
assert_contains "$PROJECT_DIR/.ai/PROJECT_RULES.md" "docs/technical/"
assert_contains "$PROJECT_DIR/.ai/WORKFLOW.md" "Standard Task Flow"
assert_contains "$PROJECT_DIR/.ai/WORKFLOW.md" 'Read `.ai/PROJECT_CONTEXT.md`'
assert_contains "$PROJECT_DIR/.ai/WORKFLOW.md" "Stage 3.5 Test and Debug"
assert_contains "$PROJECT_DIR/.ai/WORKFLOW.md" "standalone HTML mockup"
assert_contains "$PROJECT_DIR/.ai/PROJECT_RULES.md" "Test and Debug"
assert_contains "$PROJECT_DIR/.ai/PROJECT_RULES.md" "standalone HTML mockup"
assert_contains "$PROJECT_DIR/AGENTS.md" ".ai/PROJECT_RULES.md is the single source of truth"
assert_contains "$PROJECT_DIR/CLAUDE.md" ".ai/PROJECT_RULES.md is the single source of truth"
assert_contains "$PROJECT_DIR/GEMINI.md" ".ai/PROJECT_RULES.md is the single source of truth"
assert_contains "$PROJECT_DIR/.cursor/rules/project-lifecycle.mdc" "alwaysApply: true"
assert_contains "$PROJECT_DIR/.cursor/rules/project-lifecycle.mdc" ".ai/PROJECT_RULES.md is the single source of truth"

"$PROJECT_DIR/scripts/check-harness.sh"

echo "test-new-full-project: ok"
