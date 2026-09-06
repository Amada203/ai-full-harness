#!/usr/bin/env bash
set -euo pipefail

# Adversarial fixtures for the owner-side central control ledger tool:
# chain tampering, duplicate issuance, revocation epochs, budget
# exhaustion, and cross-verification by the controller's own parser.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

LEDGER="$TMP_DIR/ledger.jsonl"
GRANT="$TMP_DIR/grant.yml"
TOOL="$ROOT_DIR/bin/autopilot-ledger"

[[ -x "$TOOL" ]] || { echo "autopilot-ledger must be executable" >&2; exit 1; }

deny_expect() {
  local label="$1"
  shift
  if "$TOOL" "$@" >/dev/null 2>&1; then
    echo "Expected failure: $label" >&2
    exit 1
  fi
}

"$TOOL" init "$LEDGER" >/dev/null

sed -e 's/^grant_present: false/grant_present: true/' \
    -e "s/^grant_id: NONE/grant_id: GRANT-T-001/" \
    -e "s/^issuer: NONE/issuer: central-control-plane/" \
    -e "s/^external_authority_ref: NONE/external_authority_ref: ledger\/t-001/" \
    -e "s/^approval_digest: NONE/approval_digest: $(printf 'b%.0s' {1..64})/" \
    -e "s/^repository_id: NONE/repository_id: Amada203\/demo/" \
    -e "s/^task_digest: NONE/task_digest: $(printf 'a%.0s' {1..64})/" \
    -e 's/^allowed_paths: \[\]/allowed_paths: [src\/]/' \
    -e 's/^branch_prefix: NONE/branch_prefix: autopilot/' \
    -e 's/^allowed_actions: \[\]/allowed_actions: [candidate_branch]/' \
    -e 's/^expires_at: NONE/expires_at: 2099-01-01T00:00:00Z/' \
    -e 's/^max_runs: 0/max_runs: 2/' \
    "$ROOT_DIR/templates/.autopilot/GITHUB_GRANT.yml" > "$GRANT"

"$TOOL" issue "$LEDGER" "$GRANT" >/dev/null
deny_expect "duplicate issuance" issue "$LEDGER" "$GRANT"

"$TOOL" verify "$LEDGER" "$GRANT" >/dev/null

"$TOOL" consume "$LEDGER" GRANT-T-001 run-1 >/dev/null
"$TOOL" verify "$LEDGER" "$GRANT" >/dev/null
"$TOOL" consume "$LEDGER" GRANT-T-001 run-2 >/dev/null
deny_expect "verification after exhausted budget" verify "$LEDGER" "$GRANT"
deny_expect "consume beyond budget" consume "$LEDGER" GRANT-T-001 run-3
deny_expect "replayed run id" consume "$LEDGER" GRANT-T-001 run-1

"$TOOL" revoke "$LEDGER" GRANT-T-001 7 owner-rev-1 >/dev/null
deny_expect "newer epoch revocation" verify "$LEDGER" "$GRANT"

# Chain tampering is detected on every verify.
printf '{"type":"issue","grant_id":"GRANT-X","prev_hash":"%s","entry_hash":"forged"}\n' \
  "$(tail -1 "$LEDGER" | python3 -c 'import json,sys; print(json.load(sys.stdin)["entry_hash"])')" >> "$LEDGER"
deny_expect "forged tail entry" verify "$LEDGER"

"$TOOL" init "$TMP_DIR/second.jsonl" >/dev/null
sed 's/^grant_id: GRANT-T-001/grant_id: GRANT-T-002/' "$GRANT" > "$TMP_DIR/grant-2.yml"
"$TOOL" issue "$TMP_DIR/second.jsonl" "$TMP_DIR/grant-2.yml" >/dev/null
deny_expect "duplicate grant issuance on any ledger" issue "$TMP_DIR/second.jsonl" "$TMP_DIR/grant-2.yml"
sed 's/^grant_present: true/grant_present: false/' "$GRANT" > "$TMP_DIR/grant-off.yml"
deny_expect "issue of a disabled grant" issue "$TMP_DIR/second.jsonl" "$TMP_DIR/grant-off.yml"

# Cross-repo: the controller's own parser must accept this tool's snapshot
# and reject a tampered one, whenever the sibling repository is present.
if [[ -d "$ROOT_DIR/../project-autopilot/src" ]]; then
  node - "$LEDGER" "$ROOT_DIR/../project-autopilot" <<'NODE'
const { readFileSync } = require('node:fs');
const ledgerFile = process.argv[2];
const controllerDir = process.argv[3];
import(join(controllerDir, 'src', 'ledger.mjs')).then(async ({ parseLedger }) => {
  const { join } = await import('node:path');
  const lines = readFileSync(ledgerFile, 'utf8').split('\n').filter((l) => l.trim() !== '');
  // Drop the forged tail and revocation for the clean-parse assertion.
  const clean = lines.filter((l) => !l.includes('forged') && !l.includes('"revoke"')).join('\n');
  const entries = parseLedger(clean);
  if (entries.length < 3) throw new Error('expected issue + consumes');
  let threw = false;
  try {
    parseLedger(readFileSync(ledgerFile, 'utf8'));
  } catch {
    threw = true;
  }
  if (!threw) throw new Error('controller parser accepted a forged chain');
  console.log('controller cross-verification: ok');
  process.exit(0);
}).catch((error) => { console.error(error.message); process.exit(1); });
function join(...parts) { return parts.join('/'); }
NODE
else
  echo "controller repository not present; cross-verification skipped"
fi

echo "autopilot ledger test passed."
