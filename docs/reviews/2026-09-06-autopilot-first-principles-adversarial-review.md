# Autopilot Platform — First-Principles and U-Shaped Re-evaluation with Adversarial Review

Date: 2026-09-06. Scope: the full `codex/autopilot-contract` worktree state
(Harness 2.3 Autopilot contract, architecture gate, portable continuity,
refactor gates, knowledge base, global registration, and the new narrow
GitHub candidate grant). This review was produced by the successor agent
after taking over an interrupted Codex delivery, per the harness's own
methodology: first-principles reasoning, U-shaped descent, smoke testing,
and adversarial review.

## Surface Request

"Finish the PRD implementation, re-examine the project from first principles
and U-shaped thinking, and run the project's full methodology for adversarial
acceptance."

## U-Shaped Descent to the Root Need

The surface asks for "completed autonomous development." Descending:

1. A user does not actually want "an AI that edits code." An AI that edits
   code without bounded authority is a liability amplifier, not a delivery
   system.
2. The root need is **bounded, auditable progress**: every autonomous action
   must be (a) authorized in advance by owner-approved data, (b) validated by
   deterministic evidence, (c) reversible, (d) stoppable.
3. Resurfacing, the correct completion criterion is therefore not "all
   features exist" but "all boundaries hold under counterexamples, and every
   gap is visible instead of hidden behind a green checkmark."

The implementation under review matches this descent: enrollment is
disabled by default; authority flows only from owner data files; candidate,
merged, released, and upgraded work are distinct; untrusted candidate code
never touches privileged credentials; everything fails closed.

## First-Principles Re-derivation and Verdicts

| Invariant | Implementation verdict |
| --- | --- |
| Authority comes from owner-approved data, never content or agent judgment | Holds. `CONSTITUTION.yml` capabilities are pinned `false` and fingerprinted; `POLICY.yml` keys are enumerated; `requested_by: owner` is mandatory. |
| A candidate is never a merge, release, or upgrade | Holds. Grants are limited to `candidate_branch`/`draft_pr`; `protected-diff` rejects control-path changes in PRs; upgrades are review-only receivers. |
| Fail closed on ambiguity | Holds in the validator and transition tooling (verified by fixtures). One sub-shell hazard was found and fixed during this review (see Attack Matrix A-6). |
| Evidence freshness invalidates downstream | Holds. Contract/policy fingerprints gate transitions; lifecycle plan gate gates `STAGE0_PASSED`; `--accept-policy` re-arms fingerprints. |
| The system cannot enlarge its own authority | Holds at the local layer. The grant verifier structurally rejects project-, owner-, or controller-issued grants; issuer provenance stays with the not-yet-built central ledger (explicitly NO-GO, not silently assumed). |

## Adversarial Attack Matrix

Findings from this review's own counterexample pass. P0/P1 must be CLOSED
before any merge; all three P1s below were found by the new grant fixtures
and fixed in this worktree.

| ID | Severity | Attack | Observed behavior before fix | Status |
| --- | --- | --- | --- | --- |
| A-1 | P1 | Empty grant output written back | Test helper used `awk '{ gsub(...) }'`, which prints nothing and truncated the grant to 0 bytes; downstream state silently diverged | CLOSED — explicit `; print`; fixture asserts sizes |
| A-2 | P1 | Protected-path list split collapse | `while IFS= read -r piece` reset IFS per read, so the comma-separated protected list stayed one string and overlap checks matched nothing | CLOSED — single `read -a` comma split (reused `list_items`) |
| A-3 | P1 | Default-branch write allowed | Grant branch check listed `main|master` as acceptable namespaces | CLOSED — default branches now deny unconditionally |
| A-4 | P2 | Fail-open via process substitution | `fail()` inside `< <(list_items …)` would only exit the sub-shell | CLOSED — protected list parsed in the main shell before candidate loop |
| A-5 | P2 | macOS/Linux portability of sed and string compare | BSD/GNU `sed -i` differences and `<` inside `[[ ]]` broke fixtures | CLOSED — portable dual-form used; `[[ a < b ]]` comparison fixed |
| A-6 | P2 | Grant symlink swap | A symlinked `GITHUB_GRANT.yml` must deny | Verified denied by fixture |
| A-7 | P3 | Dead security code drift | Framing validation listed a file never fingerprinted | Removed rather than left misleading |

Pre-existing Codex implementation was re-audited line by line for this
review: the contract validator (schema, duplicates, metacharacters,
constitution pinning, lane cross-checks, `protected-diff`), the transition
state machine (exact transition table, lock, transactional backup/restore,
reason requirements, `SAFE_STOP` at three failures), and the workflow static
checks. No new P0/P1 findings. One design clarification is recorded: the
validator intentionally tolerates an enabled-but-pre-Stage-0 project in
`NEW`/`STAGE0_PASSED` (read-only resting state), while any state beyond
`STAGE0_PASSED` requires a fresh plan gate — this matches the approved plan
and is now documented here.

## Residual Risk

- The harness proves structure, freshness, and refusal behavior; it cannot
  prove evidence truthfulness or bind an external approver's identity. The
  central control ledger remains the required trust root and is not built.
- `AUTOPILOT_STATE`, `GITHUB_GRANT.yml`, and policy files are writable by
  anyone with repository write access; fingerprint chains detect drift but
  cannot stop an administrator. This is the documented assurance boundary.
- Grant budget consumption is lock-protected per working copy, not
  globally across machines; a globally consistent budget needs the ledger.

## Decision

PASS for the local layer with the three P1 fixes closed and re-run suites
green. The platform-level GO remains NO-GO until the central ledger,
controller, and remote pilot items in the acceptance report carry real
evidence.
