#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
printf '%s\n' 'legacy ai-workflow-config' > "$TEST_DIR/AGENTS.md"
out="$($ROOT_DIR/bin/check-global-registration "$TEST_DIR/AGENTS.md")"
grep -q 'trigger absent' <<<"$out"
grep -q 'read-only audit complete' <<<"$out"
printf '%s\n' 'full harness trigger' > "$TEST_DIR/registered.md"
out="$($ROOT_DIR/bin/check-global-registration "$TEST_DIR/registered.md")"
grep -q 'trigger absent' <<<"$out"
ln -s "$TEST_DIR/registered.md" "$TEST_DIR/symlink.md"
if "$ROOT_DIR/bin/check-global-registration" "$TEST_DIR/symlink.md" >/dev/null 2>&1; then exit 1; fi
echo 'test-global-registration: ok'
