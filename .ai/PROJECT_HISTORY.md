# Full Harness source history

## 2026-09-05 — continuity requirements specification

Consolidated the latest user requirements into the portable-continuity design:
registration migration, evidence-based interruption recovery, refactoring,
first-directory approval and bounded GitHub preauthorization. Explicitly pending
confirmation; no new permission, global write or knowledge-base initialization.

## 2026-09-05 — source-project multi-tool foundation

Added shared source-project context/rules/history plus thin Codex/generic,
Claude, Gemini and Cursor entries. These are distinct from the existing consumer
templates and installation adapters. Preserved the unmerged-worktree boundary,
explicit Git approval and current NO-GO status.

Added tests/test-source-agent-entries.mjs for shared-source ordering, thin entry
shape and Cursor activation. Initial execution failed because source entries
were absent. Structural verification is not live tool-switch acceptance.

Fresh verification completed: source entry, new-project generator, lifecycle,
architecture, Autopilot contract and workflow static suites passed; git diff
--check passed. No merge, global registration, commit or publication performed.

Added read-only `bin/check-global-registration` plus shell regressions. It audits
presence of the Full Harness marker, legacy references and symlink targets without
writing global files. It does not perform the default-route migration.

## 2026-09-06 — continuity Tasks 1-2

Added generated project UUID identity, an atomic continuity checkpoint, and a
read-only audit covering uninitialized/no-commit repositories, index/worktree
drift, HEAD/branch drift, ignored files, corrupt records, out-of-root symlinks
and inert malicious notes. Integrated the same audit command into Codex, Claude,
Gemini and Cursor entries plus shared workflow rules. Full generator, lifecycle,
architecture, Autopilot contract/workflow and whitespace suites passed. No real
cross-tool semantic-resume claim, global install, commit, push or release.

## 2026-09-06 — generic refactor Gate

Added a stable refactor ID/status, locked transactional start/transition tools,
design/downstream invalidation, plan and recovery records, and design/
implementation gate integration. Regressions cover continuity prerequisite,
unsafe/duplicate start, skipped/concurrent transitions, missing evidence,
failed smoke and fingerprint drift. Full Harness suites passed. A generic
fixture does not prove an actual project's data migration or truthful evidence;
that remains a project-specific acceptance requirement.

## 2026-09-06 — knowledge-base binding increment

Added a read-only preview and approval-bound local binding command. Canonical
project/Vault identity, generated project UUID, path collision and symlink
checks prevent approval replay and implicit directory creation. Machine-local
bindings are ignored under `.ai-local/`; no real Vault directory was created.
Focused binding regressions passed. Versioned allowlist sync and conflict/
partial-failure state remained the next increment.

## 2026-09-06 — knowledge-base sync increment

Added versioned `.ai/KNOWLEDGE_SYNC.yml` and generated `knowledge-sync.mjs`.
Sync is project-to-Vault only, allowlisted to Markdown, digest-tracked and
conflict-stopping. Manual mirror edits, symlinks, pre-existing files, secrets
and path escapes are rejected; partial writes record only completed entries,
release the lock, and can resume idempotently. Focused binding/sync, generator,
and full Harness regressions passed. No real Vault directory, GitHub write,
global registration or publication was performed.

## 2026-09-06 — grant contract and successor acceptance

Successor agent resumed the interrupted delivery: snapshotted and then
verified the whole worktree (12 suites green), implemented the externally
issued narrow GitHub candidate grant (`GITHUB_GRANT.yml` +
`check-autopilot-grant.sh` + adversarial fixtures), fixed three real defects
the fixtures exposed (awk gsub silent truncation, protected-list comma
split, default-branch allow), ran disposable-repo continuity drills, and
produced the first-principles/U-shape re-evaluation, adversarial review, and
requirement-by-requirement acceptance report. Remote, controller, ledger,
and real cross-tool evidence remain NO-GO boundaries; nothing was pushed,
published, or registered.

## 2026-09-06 — control ledger authority split confirmed

The owner confirmed the central control ledger authority split for local
design and implementation: issuance, revocation, global budget, and issuer
identity belong to an append-only digest-chained ledger held outside both
the project and the controller; the project keeps policy/constitution
authority; the controller executes only grant+ledger-verified candidate
work; merge/release/deploy/permission changes stay human per action. The
data contract and invariants are recorded in
docs/superpowers/specs/2026-09-06-control-ledger-design.md. This unblocks
the separate project-autopilot controller repository.

## 2026-09-06 — controller repository implemented locally

With the ledger authority split confirmed, built the independent
`~/project-autopilot` controller repository (own git, local commit only):
gate-ordered orchestrator, safe policy parsing, L/M/H lanes, exact state
machine, constitution/controller pinning, kill switches, candidate branch
and draft-PR orchestration with dry-run and idempotent run ids, fail-closed
canary, sanitized REVIEW-only feedback, and ledger chain verification.
52 adversarial tests and workflow static security checks pass. Recorded
deviation: zero-dependency Node ESM + node:test (no npm/network); octokit
integrates behind the narrow client interface later. Added the owner-facing
central deployment checklist; remote pilot and pinned release remain
owner-authorized external steps. Nothing was pushed or released.

## 2026-09-06 — adversarial round 2: cross-repo seams

U-shaped resynthesis shifted review focus from per-repo completeness to the
three trust-chain seams. Found and closed a P1: nested protected-directory
drift (controller allowed src/config/, app/deploy/ paths the harness
verifier refuses); plus YAML/JSON numeric normalization, three-file policy
assembly in the CLI, and forward-only revocation-epoch semantics. Recorded
(accepted-with-disclosure) items: workflow-ordered harness gate enforcement
and ledger snapshot freshness as owner duty. Full review:
docs/reviews/2026-09-06-u-shaped-cross-repo-adversarial-round2.md. Controller
suite 52 -> 58 green; harness 12/12 green. Local GO unchanged; platform
NO-GO boundary unchanged.

## 2026-09-06 — round 3: consolidation to 2.4.0

Overall review closed the last inconsistencies: released 2.4.0 (changelog
consolidated), pinned the grant contract in the canonical generator test,
restored README/adapter/global doc parity, refreshed the stale project
context to the merged reality, and verified controller npm scripts plus the
documented pinned-release workflow path. Harness 12/12 and controller 58/58
green. Local GO / remote NO-GO is now stated identically everywhere.
