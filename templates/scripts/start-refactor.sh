#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$ROOT_DIR/.ai/LIFECYCLE_STATE"; BASE="$ROOT_DIR/.ai/LIFECYCLE_BASELINE"
LOCK="$ROOT_DIR/.ai/.refactor-transition.lock"
fail(){ echo "refactor-start: $*" >&2; exit 1; }
[[ $# -eq 1 && "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]] || fail "invalid refactor id"
grep -Fxq 'PLAN_STATUS=PASS' "$STATE" || fail "plan gate must pass before refactoring"
grep -Fxq 'REFACTOR_ID=NONE' "$STATE" && grep -Fxq 'REFACTOR_STATUS=NONE' "$STATE" || fail "a refactor is already active"
node "$ROOT_DIR/scripts/project-continuity.mjs" audit >/dev/null 2>&1 || fail "continuity checkpoint must be consistent before refactoring"
mkdir "$LOCK" 2>/dev/null || fail "another refactor transition is active"
state_backup="$(mktemp)"; base_backup="$(mktemp)"; cp "$STATE" "$state_backup"; cp "$BASE" "$base_backup"; done_flag=0
cleanup(){ if [[ $done_flag -eq 0 ]]; then cp "$state_backup" "$STATE"; cp "$base_backup" "$BASE"; fi; rm -f "$state_backup" "$base_backup"; rmdir "$LOCK" 2>/dev/null || true; }
trap cleanup EXIT INT TERM
set_key(){ local f="$1" k="$2" v="$3" t; t="$f.tmp.$$"; awk -F= -v k="$k" -v v="$v" '$1==k{print k"="v;n++;next}{print}END{if(n!=1)exit 42}' "$f" > "$t" || { rm -f "$t"; fail "missing state key: $k"; }; mv "$t" "$f"; }
set_key "$STATE" REFACTOR_ID "$1"; set_key "$STATE" REFACTOR_STATUS PLANNED; set_key "$STATE" CURRENT_GATE design
for g in DESIGN PROTOTYPE IMPLEMENTATION RELEASE RETROSPECTIVE; do set_key "$STATE" "${g}_STATUS" BLOCKED; set_key "$BASE" "${g}_FINGERPRINT" UNRECORDED; done
set_key "$STATE" GITHUB_STATUS BLOCKED; set_key "$BASE" GITHUB_FINGERPRINT UNRECORDED
set_key "$STATE" HUMAN_APPROVAL_REF NONE; set_key "$STATE" GITHUB_APPROVAL_REF NONE
done_flag=1; echo "refactor-start: $1 planned; design and downstream gates invalidated"
