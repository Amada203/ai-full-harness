#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; STATE="$ROOT_DIR/.ai/LIFECYCLE_STATE"
fail(){ echo "refactor-transition: $*" >&2; exit 1; }
[[ $# -eq 1 ]] || fail "Usage: transition-refactor.sh IN_PROGRESS|PASS|BLOCKED"
LOCK="$ROOT_DIR/.ai/.refactor-transition.lock"
mkdir "$LOCK" 2>/dev/null || fail "another refactor transition is active"
backup=""; committed=1
cleanup(){ if [[ -n "$backup" && $committed -eq 0 ]]; then cp "$backup" "$STATE"; fi; [[ -z "$backup" ]] || rm -f "$backup"; rmdir "$LOCK" 2>/dev/null || true; }
trap cleanup EXIT INT TERM
current="$(awk -F= '$1=="REFACTOR_STATUS"{print $2}' "$STATE")"; pair="$current:$1"
case "$pair" in PLANNED:IN_PROGRESS|IN_PROGRESS:PASS|IN_PROGRESS:BLOCKED|BLOCKED:IN_PROGRESS) ;; *) fail "Illegal refactor transition: $pair" ;; esac
backup="$(mktemp)"; cp "$STATE" "$backup"; committed=0
tmp="$STATE.tmp.$$"; awk -F= -v v="$1" '$1=="REFACTOR_STATUS"{print "REFACTOR_STATUS="v;n++;next}{print}END{if(n!=1)exit 42}' "$STATE" > "$tmp" || { rm -f "$tmp"; fail "invalid state"; }; mv "$tmp" "$STATE"
case "$1" in IN_PROGRESS) "$ROOT_DIR/scripts/check-refactor.sh" design >/dev/null ;; PASS) "$ROOT_DIR/scripts/check-refactor.sh" implementation >/dev/null ;; BLOCKED) ;; *) fail "Invalid target status" ;; esac
committed=1
echo "refactor-transition: $current -> $1"
