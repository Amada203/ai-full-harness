# Requirement-by-Requirement Acceptance Report — 2026-09-06

Evidence classes:
- **L** = local deterministic evidence (tests, fixtures, drills run in this
  worktree on 2026-09-06, successor agent).
- **R** = remote evidence (GitHub repositories, App, secrets, runners,
  branches, PRs). None exists; remote actions were never authorized.
- **H** = human evidence (owner approval decisions, real multi-tool judgment,
  project-specific business acceptance).

Overall decision: **NO-GO for end-to-end autonomous delivery; GO for the
local contract layer** (merge candidate for `main`, version 2.3.0 + new
grant contract). Completion rule honored: green unit tests alone did not
promote any remote or human requirement.

## 1. Full Harness Autopilot Contract (v2.3.0 plan)

| Requirement | Evidence | Class | Result |
| --- | --- | --- | --- |
| Data-only `.autopilot/` contract, default disabled | `tests/test-new-full-project.sh`, `tests/test-autopilot-contract.sh` | L | PASS |
| Enable requires passed, fresh Stage 0 plan gate + pinned controller SHA | validator logic + fixtures | L | PASS |
| Legal/illegal enrollment transitions, transactional rollback, lock contention, `SAFE_STOP` after 3 failures | `tests/test-autopilot-contract.sh` transition fixtures | L | PASS |
| Constitution/policy/protected-path tamper, unknown risk, stale fingerprints fail closed | validator negative fixtures | L | PASS |
| Read-only enrollment + review-only upgrade workflows, minimum permissions, pinning checks | `tests/test-autopilot-workflow-static.sh` | L | PASS |
| No sourcing/executing of project-controlled data | code audit + shell metacharacter rejection fixtures | L | PASS |

## 2. Narrow GitHub candidate grant (this review's addition)

| Requirement | Evidence | Class | Result |
| --- | --- | --- | --- |
| Grant reference cannot be self-issued; disabled default | `tests/test-autopilot-grant.sh` | L | PASS |
| Forged/wrong-repo/wrong-task/expired/revoked/replayed/over-budget deny | grant adversarial fixtures | L | PASS |
| Path scope, protected paths, traversal, default branch, action ceiling deny | grant adversarial fixtures | L | PASS |
| Budget consumption locked/atomic/bounded | consume-run fixture (3 of 4 succeed) | L | PASS |
| Issuer provenance verification | requires central control ledger | R | **NOT DONE — explicit NO-GO boundary** |
| Actual candidate branch/draft PR write under a grant | requires authorized remote pilot | R | **NOT DONE** |

## 3. Portable continuity

| Requirement | Evidence | Class | Result |
| --- | --- | --- | --- |
| Snapshot/audit classifications (CONSISTENT/CHANGED/STALE_EVIDENCE/INVALID) | `tests/test-continuity.mjs` + live drill: dirty → CHANGED(10), branch switch → STALE_EVIDENCE(11), corrupt → INVALID(2) | L | PASS |
| Four tool entries invoke the same read-only audit | `tests/test-source-agent-entries.mjs` | L | PASS |
| Real cross-tool semantic resume (actual Codex/Claude/Gemini/Cursor sessions resuming one task) | not exercisable in this environment | H | **UNVERIFIED — not claimed** |
| Recovering unsaved in-memory work | out of scope by design | — | N/A (disclosed) |

## 4. Controlled refactoring

| Requirement | Evidence | Class | Result |
| --- | --- | --- | --- |
| Refactor gates invalidate design/downstream fingerprints; unsafe/duplicate/skipped transitions blocked | `tests/test-refactor-recovery.sh` | L | PASS |
| Real interrupted business refactor with project-specific data migration | needs a real project's migration | H | **UNVERIFIED — not claimable from generic fixtures** |

## 5. Knowledge base

| Requirement | Evidence | Class | Result |
| --- | --- | --- | --- |
| Preview creates nothing; bind bound to approval token + canonical paths | `tests/test-knowledge-base.mjs` | L | PASS |
| Allowlisted one-way sync, digests, conflict stop, partial resume | `tests/test-knowledge-sync.mjs` | L | PASS |
| OS-level permission-denial behavior | not covered by a fixture | L gap | OPEN (minor) |
| Existing authorized Obsidian notes synced | recorded in architecture gate review | H (owner-authorized) | DONE (documented) |

## 6. Architecture gate

| Requirement | Evidence | Class | Result |
| --- | --- | --- | --- |
| Archify source/HTML/receipt bound into design fingerprints; negative controls | `tests/test-architecture.mjs`, gate review 2026-09-05 | L | PASS |
| Pinned upstream Archify release / CI distribution | local snapshot 2.17.0-dev.1 only | R | **NOT ATTESTED** |

## 7. Registration migration

| Requirement | Evidence | Class | Result |
| --- | --- | --- | --- |
| Read-only registration audit | `tests/test-global-registration.sh` | L | PASS |
| `preview-default` / `apply-default` / `restore` default-route migration | deliberately deferred: mutates `~/.codex`, `~/.claude`, `~/.gemini`, Cursor rules; requires per-owner approval | H | **PENDING OWNER AUTHORIZATION** |

## 8. Controller repository (original Plan 2)

| Requirement | Evidence | Class | Result |
| --- | --- | --- | --- |
| `project-autopilot` controller (pinned reusable workflows, policy evaluator, candidate/PR executor, canary, feedback emitter) | repository does not exist locally or remotely; design evolved toward the grant + ledger model | R | **NOT STARTED — sequencing decision recorded below** |

Sequencing note: the original controller plan predates the portable-
continuity authority split. Its candidate-execution core is now gated by the
externally issued grant and the unwritten control ledger. Building the
controller before the owner confirms the ledger authority split (the spec's
explicitly pending confirmation) would create a component wired to a trust
root that does not exist. Recommendation: confirm the ledger design first,
then implement the controller against `GITHUB_GRANT.yml` + ledger contracts
in its own repository.

## 9. Regression and hygiene (this review)

| Check | Result |
| --- | --- |
| All 12 suites green after grant addition (`test-autopilot-{contract,grant}.sh`, `test-autopilot-workflow-static.sh`, `test-new-full-project.sh`, `test-lifecycle-gates.sh`, `test-{architecture,continuity,knowledge-base,knowledge-sync,source-agent-entries}.mjs`, `test-{refactor-recovery,global-registration}.sh`) | PASS |
| `bash -n` on all shell scripts; `node --check` on mjs scripts | PASS |
| Whitespace (`git diff --check`) | PASS |
| Disposable-repo continuity drill (snapshot → dirty → branch switch → corrupt → removed) | PASS |

## What would flip the overall decision

1. Owner confirms the control-ledger authority split (spec §5, pending).
2. Controller repository implemented against the grant/ledger contracts.
3. Owner-authorized remote pilot exercises enrollment, observe-only, L/M/H
   fixtures, grant allow/deny, revoke, rollback on disposable private repos.
4. Real multi-tool resume drill recorded as evidence.
