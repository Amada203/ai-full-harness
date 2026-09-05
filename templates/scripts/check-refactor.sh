#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$ROOT_DIR/.ai/LIFECYCLE_STATE"
fail() { echo "refactor-check: $*" >&2; exit 1; }
[[ $# -eq 1 && "$1" =~ ^(design|implementation)$ ]] || fail "Usage: check-refactor.sh design|implementation"
value() {
  local count
  count="$(awk -F= -v key="$1" '$1 == key { count++ } END { print count + 0 }' "$STATE")"
  [[ "$count" == 1 ]] || fail "State key must occur exactly once: $1"
  awk -F= -v key="$1" '$1 == key { sub(/^[^=]*=/, ""); print }' "$STATE"
}
complete() {
  [[ -f "$ROOT_DIR/$1" && ! -L "$ROOT_DIR/$1" ]] || fail "Missing regular refactor evidence: $1"
  ! grep -Fq '<!-- REQUIRED' "$ROOT_DIR/$1" || fail "Refactor evidence is incomplete: $1"
  ! LC_ALL=C grep -Eq '(^|[^A-Za-z])TBD([^A-Za-z]|$)' "$ROOT_DIR/$1" || fail "Refactor evidence contains TBD: $1"
}
refactor_id="$(value REFACTOR_ID)"
status="$(value REFACTOR_STATUS)"
if [[ "$refactor_id" == NONE ]]; then
  [[ "$status" == NONE ]] || fail "REFACTOR_STATUS must be NONE when REFACTOR_ID is NONE"
  exit 0
fi
[[ "$refactor_id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]] || fail "Invalid refactor id"
case "$status" in PLANNED|IN_PROGRESS|PASS|BLOCKED) ;; *) fail "Invalid refactor status" ;; esac
plan="docs/lifecycle/REFACTOR_PLAN.md"
complete "$plan"
grep -Fxq "Refactor ID: $refactor_id" "$ROOT_DIR/$plan" || fail "Refactor plan id does not match state"
for section in '## Root Need and Behavioral Baseline' '## Preserved Contracts and Callers' \
  '## Architecture Delta' '## Incremental Stages' '## Data Compatibility and Migration' \
  '## Rollback Boundary' '## Verification Plan' '## Approval'; do
  grep -Fxq "$section" "$ROOT_DIR/$plan" || fail "Missing refactor plan section: $section"
done
grep -Fxq 'Decision: APPROVED' "$ROOT_DIR/$plan" || fail "Refactor plan requires Decision: APPROVED"
[[ "$status" != BLOCKED ]] || fail "Blocked refactor cannot advance a lifecycle gate"
[[ "$1" == design ]] && exit 0
[[ "$status" == PASS ]] || fail "Implementation requires REFACTOR_STATUS=PASS"
recovery="docs/lifecycle/REFACTOR_RECOVERY.md"
complete "$recovery"
grep -Fxq "Refactor ID: $refactor_id" "$ROOT_DIR/$recovery" || fail "Refactor recovery id does not match state"
for section in '## Actual Change and Stage Completion' '## Compatibility Results' \
  '## Migration and Partial-Failure Drill' '## Smoke and Regression Evidence' \
  '## Rollback and Restore Drill' '## Adversarial Findings' '## Architecture Reconciliation'; do
  grep -Fxq "$section" "$ROOT_DIR/$recovery" || fail "Missing refactor recovery section: $section"
done
grep -Fxq 'Result: PASS' "$ROOT_DIR/$recovery" || fail "Refactor recovery requires Result: PASS"
awk -F'|' '
  function trim(v){gsub(/^[[:space:]]+|[[:space:]]+$/, "", v); return toupper(v)}
  NF >= 5 && trim($2) ~ /^R-[A-Z0-9._-]+$/ { s=trim($(NF-1)); if (s=="PASS") pass=1; else bad=1 }
  END { exit pass && !bad ? 0 : 1 }
' "$ROOT_DIR/$recovery" || fail "Refactor recovery needs PASS-only verification cases"
if awk -F'|' '
  function trim(v){gsub(/^[[:space:]]+|[[:space:]]+$/, "", v); return toupper(v)}
  NF >= 7 { sev=trim($2); st=trim($3); if ((sev=="P0" || sev=="P1") && st!="CLOSED") open=1 }
  END { exit open ? 0 : 1 }
' "$ROOT_DIR/$recovery"; then fail "Open P0/P1 refactor finding"; fi
