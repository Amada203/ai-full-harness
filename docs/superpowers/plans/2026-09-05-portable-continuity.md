# Portable Continuity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Full Harness projects safely resumable across interruptions and AI tools, support controlled refactoring and opt-in Obsidian mirrors, and prepare—but never silently grant—bounded GitHub automation authority.

**Architecture:** A portable Node.js continuity command records and audits repository facts without executing project-provided commands. Generated projects share one `.ai` authority and thin tool adapters. Knowledge-base binding and global registration use preview/apply separation, with apply operations gated by explicit user approval; GitHub automation consumes externally issued, scope-bounded grants rather than project self-assertions.

**Tech Stack:** Node.js 18+, Git CLI read-only plumbing, JSON schemas, Bash fixture tests, existing Full Harness lifecycle scripts, GitHub Actions, Markdown documentation.

---

## File map

- `templates/scripts/project-continuity.mjs`: create and audit machine-readable checkpoints.
- `templates/.ai/CONTINUITY_CHECKPOINT.json`: generated initial no-evidence checkpoint.
- `templates/.ai/PROJECT_RULES.md`, `templates/.ai/WORKFLOW.md`, tool entries: common startup/recovery protocol.
- `templates/docs/lifecycle/REFACTOR_PLAN.md`: behavior, migration, rollback and staged verification record.
- `templates/scripts/check-harness.sh`, `check-lifecycle-gate.sh`, `lifecycle-fingerprint.sh`: require continuity/refactor evidence without making volatile checkpoints gate inputs.
- `bin/knowledge-base`: preview, bind and sync an explicitly approved Obsidian project mirror.
- `bin/check-global-registration`, `bin/install-ai-full-harness`: preview/apply/restore registration migration.
- `templates/.autopilot/GITHUB_GRANT.yml`: disabled grant reference only; no self-issued approval.
- `tests/test-continuity.mjs`, `test-refactor-recovery.sh`, `test-knowledge-base.sh`, `test-global-registration.sh`: adversarial fixtures.

## Task 1: Deterministic interruption checkpoint and audit

- [x] Add failing tests covering a clean repository, no-commit repository, staged/unstaged/untracked changes, branch/HEAD change, corrupt checkpoint, symlink escape, ignored secret exclusion, and a malicious command string that is recorded as inert text and never executed.
- [x] Run `node tests/test-continuity.mjs`; observed failure because the command/template did not exist.
- [x] Implement `project-continuity.mjs snapshot|audit` using argument-array Git subprocesses, canonical project-root checks, index/worktree SHA-256 digests, a fixed schema and atomic same-directory rename. Exclude `.git`, the checkpoint itself, ignored files and out-of-root symlinks.
- [x] Make audit classify `CONSISTENT`, `CHANGED`, `STALE_EVIDENCE`, `INVALID`, and `UNINITIALIZED`; only snapshot writes. Never execute a command stored in JSON. `UNKNOWN` remains reserved for future external scanners and is not emitted by this local command.
- [x] Add the initial checkpoint template/project identity and require the script/schema structurally in `check-harness.sh`.
- [x] Run focused tests, generator tests, lifecycle tests and `git diff --check`.
- [x] Update source context/history and the authorized existing Obsidian notes with evidence and limitations.

## Task 2: Startup integration across tools

- [x] Write failing generated-project tests proving Codex, Claude, Gemini and Cursor all invoke the same read-only continuity audit before relying on prior progress.
- [x] Update thin entries and `.ai/PROJECT_RULES.md`/`WORKFLOW.md`; no tool-specific state copies.
- [x] Test corrupt/changed/uninitialized checkpoint behavior and disclose that entries are the portable fallback when hooks are unavailable.
- [x] Run all generation and source-entry tests.

## Task 3: Controlled refactoring and recovery

- [x] Add failing fixtures for missing baseline/plan, incomplete migration/rollback, failed smoke, unresolved P0/P1, unsafe/duplicate refactor start, skipped transitions and concurrent transition locks.
- [x] Add `REFACTOR_PLAN.md` and `REFACTOR_RECOVERY.md` with preserved contracts/callers, data compatibility, incremental stages, rollback boundaries, smoke/regression/adversarial and restore evidence.
- [x] Extend lifecycle state/fingerprints so a declared refactor invalidates design/development/release gates while an unused template does not block ordinary work.
- [ ] Verify a real interrupted business refactor resumes from actual Git/checkpoint state, including a project-specific partial data migration; generic fixtures cannot prove this requirement.
- [x] Run full lifecycle, architecture and generator suites.

## Task 4: Knowledge-base preview, first-use confirmation and sync

- [x] Add failing tests proving `preview` creates nothing, `bind` requires an explicit approval token tied to canonical Vault/project paths, and a new machine/path requires new confirmation.
- [x] Implement local uncommitted binding outside generated content, allowlisted Markdown-only one-way sync, content digests and atomic writes.
- [x] Reject symlink destinations, collisions, manual mirror divergence, source outside allowlist, credentials/customer data patterns, overwrite/delete requests and ambiguous partial failures.
- [x] Make retries idempotent and record `SYNCED`, `PENDING`, `CONFLICT`, or `BLOCKED`; never create a different Vault automatically.
- [ ] Test permission denial; interrupted/partial sync resume is covered. Authorized notes were synced after material milestones.

## Task 5: Safe default-generator registration migration

- [ ] Expand read-only audit tests for paired/duplicate/broken old and new markers, personal-rule preservation, symlinks, concurrent modification and paths containing spaces.
- [ ] Implement `preview-default` producing exact target/digest/diff with zero writes.
- [ ] Implement `apply-default --approval-ref` only after explicit user approval; compare preimage digest, back up, atomically replace known marked blocks, and refuse unknown conflicts.
- [ ] Implement `restore --backup --approval-ref` without overwriting later user edits.
- [ ] Test idempotence, rollback and fresh tool-task routing; do not register a temporary worktree.
- [ ] Ask separately before modifying `~/.codex`, `~/.claude`, `~/.gemini` or Cursor rules.

## Task 6: Externally authorized GitHub candidate scope

- [x] Define a signed/external grant reference with repository ID, task digest, allowed paths/actions, branch prefix, expiry, run/count/cost ceilings, issuer and revocation epoch; project files cannot issue it. (`templates/.autopilot/GITHUB_GRANT.yml`, `scripts/check-autopilot-grant.sh`)
- [x] Add adversarial tests for forged local approval, wrong repository/task, path overlap, expired/revoked/replayed grants and concurrent budget consumption. (`tests/test-autopilot-grant.sh`)
- [ ] Wire grant verification to the central control-ledger design only after its authority split is explicitly approved.
- [ ] Keep merge/default-branch, release/deploy, workflow/permission/secret/App/ruleset changes outside the grant and subject to per-action confirmation.
- [ ] Run a disposable private GitHub pilot only under separate remote-write authorization.

## Task 7: Full cross-tool and completion audit

- [ ] Exercise real Codex/Claude/Gemini/Cursor startup where installed; record unavailable tools as unverified, not passed.
- [ ] Simulate abrupt interruption, dirty resume, branch switch and refactor recovery in a disposable generated repository.
- [ ] Verify architecture generation/check, all lifecycle gates, knowledge sync conflict behavior, registration preview/rollback, Autopilot pause/revoke/SAFE_STOP and grant denial.
- [ ] Create a requirement-by-requirement acceptance report distinguishing local, remote and human evidence.
- [ ] Request explicit approval before any commits, pushes, PRs, releases, global registration, first knowledge-directory creation or GitHub configuration.

## Completion rule

Green unit tests alone are insufficient. Completion requires every matrix item in the approved specification to have authoritative evidence, including real cross-tool resume and separately authorized remote controls. Any missing or indirect evidence keeps the overall decision `NO-GO`.
