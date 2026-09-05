# AI Full Harness

Generated projects include `scripts/project-continuity.mjs`. Run `audit` before
trusting recorded progress and `snapshot` after a verified work unit or before a
planned tool switch. It fingerprints Git HEAD/branch/index and non-ignored
tracked/untracked worktree content without executing checkpoint text. Results
distinguish `UNINITIALIZED`, `CONSISTENT`, `CHANGED`, `STALE_EVIDENCE`, and
`INVALID`. This recovers persisted facts, not unsaved editor/model memory, and
does not approve requirements or replace lifecycle Gates.

Structural refactors use `start-refactor.sh`, `check-refactor.sh`, and
`transition-refactor.sh`. Starting a refactor requires a consistent checkpoint
and passed plan, invalidates design and later Gates, and binds the design
fingerprint to a stable refactor ID/plan. PASS requires compatibility, partial
migration, rollback/restore, smoke and adversarial recovery evidence. These
generic gates cannot prove a project's migration is truthful or safe; project-
specific drills and human review remain necessary.

### Optional local knowledge mirror

Generated projects carry a versioned `.ai/KNOWLEDGE_SYNC.yml` Markdown allowlist
and `scripts/knowledge-sync.mjs`. The project repository remains authoritative;
the Vault copy is a one-way traceability mirror. First preview the exact local
paths without writing anything:

```bash
~/ai-full-harness/bin/knowledge-base preview \
  --project /absolute/path/to/project \
  --vault "/absolute/path/to/Obsidian Vault" \
  --folder project-name
```

After reviewing those paths, explicitly approve that same request by passing
the displayed `approvalRef` to `bind`. Only then is the Vault project directory
and ignored `.ai-local/knowledge-base.json` created. Audit or synchronize with:

```bash
node scripts/knowledge-sync.mjs audit
node scripts/knowledge-sync.mjs sync
```

Manual mirror edits, deletion, pre-existing files, symlinks, malformed policy,
and partial failures stop or remain pending; they are never silently overwritten
or copied back into the repository. The approval reference binds exact paths but
is not cryptographic proof of a human identity, so agent rules and an external
approval system are still required for strong unattended enforcement.

### Architecture design evidence (local candidate)

All newly generated projects require a top-level Archify diagram at Stage 1.
PRD paths stay unchanged. Author `docs/architecture/ARCHITECTURE.archify.json`,
map each node to `ARCH:<id>` in the technical PRD, then run
`node scripts/architecture.mjs build` and `check`. Design fingerprints include
the architecture directory and `.ai/ARCHIFY_LOCK.json`; a missing artifact,
changed HTML, missing node reference or different tool snapshot blocks design.

Install the pinned Archify skill on each authoring/CI machine and set
`ARCHIFY_HOME` when outside the standard skill directories. The current lock
identifies the locally installed `2.17.0-dev.1` snapshot by SHA-256, not an
attested upstream release. Remote rollout needs a reviewed, reproducible tool
distribution. No automatic download, tool update or existing-project migration
is performed. Archify is MIT licensed; preserve its license/notices when
redistributing the tool. Browser evidence and visual judgment are separate from
the deterministic delivery receipt. See generated docs/architecture/README.md.

Strong-hierarchy AI Project Harness for long-lived projects and multi-agent
workflows.

This package is intentionally separate from `~/ai-workflow-config`. It keeps the
existing lightweight harness unchanged while providing a fuller structure for
projects that need durable context, rules, history, workflow, and documentation
layers.

Version 2.3 adds a disabled-by-default, owner-controlled Project Autopilot
enrollment contract on top of the freshness-aware enforcement introduced in
2.2. First-principles reasoning,
U-shaped thinking, smoke testing, and adversarial review produce mandatory
evidence; recorded fingerprints detect later changes, upstream re-recording
invalidates downstream approvals, and CI checks the fixed final gate.

## Structure

Generated projects use:

```text
project/
├── AGENTS.md
├── CLAUDE.md
├── GEMINI.md
├── .cursor/rules/project-lifecycle.mdc
├── .ai/
│   ├── PROJECT_CONTEXT.md
│   ├── PROJECT_RULES.md
│   ├── LIFECYCLE_STATE
│   ├── LIFECYCLE_BASELINE
│   ├── PROJECT_HISTORY.md
│   ├── WORKFLOW.md
│   └── HARNESS_VERSION
├── .autopilot/
│   ├── CONSTITUTION.yml
│   ├── ENROLLMENT.yml
│   ├── POLICY.yml
│   ├── OBJECTIVES.md
│   ├── PROTECTED_PATHS.yml
│   └── AUTOPILOT_STATE
├── docs/
│   ├── product/PRD.md
│   ├── technical/TECHNICAL_PRD.md
│   ├── design/
│   ├── design-review/
│   ├── data/
│   ├── lifecycle/
│   └── autopilot/
├── scripts/
│   ├── autopilot-fingerprint.sh
│   ├── check-autopilot-contract.sh
│   ├── check-harness.sh
│   ├── check-lifecycle-gate.sh
│   ├── lifecycle-fingerprint.sh
│   ├── record-lifecycle-gate.sh
│   └── transition-autopilot.sh
├── .github/workflows/
│   ├── harness-gates.yml
│   ├── autopilot-enrollment.yml
│   └── autopilot-upgrade-receiver.yml
└── dist/
```

## Create a Full Harness Project

```bash
AI_PROJECT_STACK="React + Node.js" \
AI_PROJECT_DESCRIPTION="Internal analytics workspace" \
  ~/ai-full-harness/bin/new-full-project analytics-workspace ~/Projects
```

Autopilot remains inert unless it is explicitly enabled with a pinned controller
commit:

```bash
~/ai-full-harness/bin/new-full-project \
  --autopilot enabled \
  --autopilot-controller-ref <40-character-controller-sha> \
  analytics-workspace ~/Projects
```

After generation, complete and record Stage 0 before advancing enrollment. If
central coordination is desired, authorize the GitHub App for selected
repositories in GitHub; the App is a hosted machine identity and is not
downloaded to a computer. The initial App authorization and secrets, changes to
policy/permissions/protected paths/Harness controls, high-risk releases, and
`SAFE_STOP` recovery remain manual owner or administrator actions. Ordinary L/M
candidate work is automated only after explicit policy opt-in.

Generated projects describe sanitized, review-only Harness feedback in
`docs/autopilot/FEEDBACK.md`. Harness upgrades arrive as notifications,
instructions, or preview pull requests and never directly modify business code.
Existing projects are not silently upgraded: they require a version-aware,
reviewed migration and explicit project confirmation.

## Optional Global Install

The installer uses a separate trigger phrase so it does not replace the existing
lightweight harness:

```text
用完整 Harness 新建一个项目
```

Run only when you want AI tools to recognize that trigger globally:

```bash
~/ai-full-harness/bin/install-ai-full-harness
```

## Rule Precedence

- Global rules start projects and enforce safety baselines.
- Project rules live in `.ai/PROJECT_RULES.md`.
- Project rules override global defaults except safety rules:
  no secrets, no destructive changes without explicit approval, no
  commit/push/publish/deploy without explicit approval.

## Lifecycle Gates

Every project starts at risk level `M`. Use `L` only for narrow, reversible
work with no high-impact trigger; use `H` for sensitive data, authorization,
destructive behavior, regulated or safety-critical outcomes, autonomous AI
decisions, production security, or consequential publication.

```bash
scripts/check-harness.sh
scripts/record-lifecycle-gate.sh plan
scripts/check-lifecycle-gate.sh plan
scripts/record-lifecycle-gate.sh design
scripts/check-lifecycle-gate.sh design
scripts/record-lifecycle-gate.sh prototype
scripts/check-lifecycle-gate.sh prototype
scripts/record-lifecycle-gate.sh implementation
scripts/check-lifecycle-gate.sh implementation
scripts/record-lifecycle-gate.sh release
scripts/check-lifecycle-gate.sh release
scripts/record-lifecycle-gate.sh github
scripts/check-lifecycle-gate.sh github
scripts/record-lifecycle-gate.sh retrospective
scripts/check-lifecycle-gate.sh retrospective
```

The recorder validates transactionally, stores the gate fingerprint, and clears
downstream statuses, fingerprints, and obsolete approval references. Gate checks
validate dependencies and fail on missing, incomplete, unrecorded, or stale
evidence, failed smoke tests, open P0/P1 findings, or missing approvals.

GitHub Actions always runs `check-lifecycle-gate.sh github`; it does not trust
mutable `CURRENT_GATE`. To make this non-bypassable for merges, configure the
workflow as a required check in repository branch protection.

Autopilot pull-request validation executes the protected-diff checker from the
base commit and rejects changes to state, policy, workflows, validator scripts,
deployment configuration, and owner-added protected paths. Because a repository
administrator can still replace project-local workflow definitions, production
enrollment also requires an organization or repository ruleset/required workflow
that the candidate branch cannot redefine.

## Controlled Self-Evolution

Retrospectives can create a complete `IMPROVEMENT_PROPOSAL.md` in `REVIEW`
state. A project never edits the source harness automatically and never marks
its own proposal approved or applied. This keeps learning continuous while
retaining human control over rule changes and migrations.

Project Autopilot feedback follows the same separation of authority: a project
may propose a regression test and sanitized evidence, but cannot approve or
apply a Harness change itself.

## Assurance Boundary

The harness provides behavioral rules, auditable evidence, freshness checks,
automatic downstream invalidation, and CI configuration. It cannot prove
evidence is truthful, bind an approval to a real human, stop an administrator
from editing controls, or enable branch protection on its own. Required checks,
deployment permissions, audit logs, and external approval systems are still
needed for stronger enforcement. Existing projects are not silently upgraded;
safe migration remains a separate, version-aware operation.
