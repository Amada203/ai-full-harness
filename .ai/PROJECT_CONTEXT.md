# AI Full Harness — source project context

## Goal

Provide a portable, owner-governed lifecycle harness applying first principles,
U-shaped problem framing, smoke tests and adversarial review throughout delivery.
Support architecture diagrams, multi-tool development, reviewed upgrades and
review-only feedback from an independently versioned Project Autopilot.

## Current state

Overall system readiness: NO-GO for remote autonomous delivery; the local
layer is complete and PUBLISHED. Harness 2.4.0 is pushed to
github.com/Amada203/ai-full-harness (origin/main = 134512c), and the
controller is pushed to the private github.com/Amada203/project-autopilot
(origin/main = cfe4f13, created 2026-09-06). Global tool registration, the
GitHub App, secrets, branch protection, the ledger, and any remote pilot
have not been performed.

The generated project retains existing PRD paths. Archify diagram source, HTML
and receipt live under docs/architecture; design gates bind their fingerprints.
The Archify tool lock is a local snapshot, not an attested upstream release;
distribution to other machines and CI remains incomplete.

Generated-project adapters already reference templates/.ai rules. Source-project
adapters reference this .ai directory; these have different responsibilities.
The independent controller lives in its own repository, not this template tree.

## Open requirements and blockers

- Push/publication/global registration require their own explicit approvals
  (see docs/autopilot-central-deployment-checklist.md).
- The control-ledger authority split was owner-confirmed 2026-09-06; the
  ledger itself is designed but not deployed, and no external issuer exists.
- The controller is implemented and tested locally only: no pinned release,
  no GitHub App, no remote pilot, no real promotion/recovery evidence.
- Generated projects have local checkpoint snapshot/audit, four shared startup
  integrations, generic refactor gates, and the externally issued narrow GitHub
  candidate grant contract with adversarial fixtures. Real tool-switch
  acceptance, a project-specific interrupted data migration, OS-level
  knowledge-sync permission denial, the central control ledger, the separate
  controller repository, and any remote pilot remain.
- Knowledge-base binding and one-way sync are locally implemented. Preview is
  read-only and owner approval is bound to canonical project/Vault identity;
  machine-specific bindings live under ignored `.ai-local/`. A versioned
  Markdown allowlist, digest state, conflict stop, lock release and partial
  failure retry are covered by focused tests.
- Obsidian sync is performed by the current authorized agent; no background
  synchronization service or implicit Vault creation exists.

## Next allowed work

The user's continuity/registration/refactoring/knowledge-base/authorization
requirements are consolidated in
docs/superpowers/specs/2026-09-05-portable-continuity-design.md. This is pending
confirmation, not runtime permission or completed functionality.

Read-only registration audit is available at `bin/check-global-registration`;
default-route migration (preview/apply/restore) remains an explicitly
authorized operation. The 2026-09-06 first-principles/U-shape re-evaluation,
adversarial review, and requirement-by-requirement acceptance report live in
`docs/reviews/`; the overall platform decision is still NO-GO by the
completion rule, with the local contract layer GO for merge.

Portable continuity Tasks 1-3 and the knowledge-base binding/sync increment are
locally implemented in this worktree. Their
tests cover repository facts and entry integration; they do not prove semantic
agreement between models or recover unsaved in-memory work.

Verify the source adapters, generator, knowledge sync, and lifecycle regressions
in this worktree.
Keep missing capabilities visible; do not weaken Gates to produce a green demo.
Use README.md, docs/reviews and tests as evidence, not as approval to publish.

## Document ownership

.ai/PROJECT_RULES.md is the source-authoring rule document. This context records
current state; .ai/PROJECT_HISTORY.md records past work. templates/.ai governs
generated consumers. global/ and adapters/ describe installation, not evidence
that a particular tool installation has actually been updated.
