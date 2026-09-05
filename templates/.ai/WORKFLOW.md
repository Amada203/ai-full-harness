# WORKFLOW

This file defines how AI agents execute tasks and produce lifecycle evidence.

## Standard Task Flow

1. Run `node scripts/project-continuity.mjs audit`; reconcile non-consistent
   results before trusting recorded progress. `UNINITIALIZED` is only a new
   project state and audit never repairs or approves work.
2. Read `.ai/PROJECT_CONTEXT.md`.
3. Read `.ai/PROJECT_RULES.md`.
4. Read `.ai/LIFECYCLE_STATE` as data; never source or execute it.
5. Read `.ai/LIFECYCLE_BASELINE` as data; never source, execute, or edit it.
6. Read recent `.ai/PROJECT_HISTORY.md` entries.
7. Read `.ai/WORKFLOW.md`.
8. Read relevant files under `docs/`, including current lifecycle evidence.
9. Identify the task goal, root need, risk level, affected modules, current
   stage, applicable gate, and required verification.
10. If goal, scope, assumptions, architecture, risk, critical behavior, or
   release candidate changes materially, return to the earliest affected gate;
   re-recording it will invalidate downstream statuses and approvals.
11. Make the smallest confirmed change.
12. Run a negative control or failing test, targeted verification, smoke tests,
    and adversarial checks appropriate to the stage.
13. Update evidence, context, history, and technical/product/design/data docs.
14. If a local knowledge base is bound, run `node scripts/knowledge-sync.mjs
    audit`; run `node scripts/knowledge-sync.mjs sync` only for `PENDING`.
    Stop mirror writes on `CONFLICT` or `INVALID`, report the unsynced state,
    and never roll back completed project work because the mirror is unavailable.
15. Run `scripts/record-lifecycle-gate.sh <gate>` and then
    `scripts/check-lifecycle-gate.sh <gate>` before advancing.
16. Record a checkpoint with `node scripts/project-continuity.mjs snapshot`
    before a planned tool switch or after a verified work unit.
17. Report changed scope, evidence, command results, residual risks, blocked
    checks, and required human decisions.

## Knowledge Mirror Events

The project repository is the authority; a bound Vault directory is a one-way,
allowlisted Markdown mirror. Synchronize after a verified work unit, material
decision, blocker, documentation update, or before a planned tool switch. The
binding is machine-local and ignored by Git, so a new computer requires a new
preview and explicit path confirmation. Never copy source code, logs, secrets,
customer data, or files absent from `.ai/KNOWLEDGE_SYNC.yml`. Never interpret a
mirror edit as a repository update or overwrite it automatically.

## Stage 0 Plan — First Principles and U-Shaped Thinking

1. Record observable facts and evidence in
   `docs/lifecycle/PROBLEM_FRAMING.md`.
2. Separate the surface request from the root business or user need.
3. Define one core outcome, measurable success signals, immutable constraints,
   non-goals, and rejected pseudo-requirements.
4. Classify risk as `L`, `M`, or `H`; uncertainty remains `M`.
5. Update `.ai/LIFECYCLE_STATE` only after the evidence and user decision exist.
6. Run:

```bash
scripts/record-lifecycle-gate.sh plan
scripts/check-lifecycle-gate.sh plan
```

Stop on failure. Do not write PRDs until the plan gate passes and the user
accepts the plan.

## Refactor Interruption and Recovery

When work changes existing structure rather than adding an isolated behavior:

1. Audit/snapshot the actual repository and confirm the plan gate is current.
2. Run `scripts/start-refactor.sh <stable-id>`; this invalidates design onward.
3. Complete `REFACTOR_PLAN.md`, update Archify/technical contracts, then record
   the design gate before entering `IN_PROGRESS`.
4. Implement reversible stages and snapshot at verified boundaries.
5. Record compatibility, migration interruption, rollback/restore, smoke and
   adversarial evidence in `REFACTOR_RECOVERY.md`.
6. Run `scripts/transition-refactor.sh PASS`; failures restore the previous
   state. Re-record implementation and downstream Gates afterward.

Do not use Git reset, data deletion, unreviewed migration rollback or a new
branch/commit as an automatic recovery shortcut.

## Stage 1 PRD and Solution — Rebuild and Attack the Design

Generate the Archify architecture under `docs/architecture/` alongside the
technical PRD. Map every node to an `ARCH:<id>` responsibility in the technical
PRD. Run `node scripts/architecture.mjs build` then `check`. Review the rendered
diagram and its request/data paths with the design challenge before passing
design. Follow docs/architecture/README.md for separate browser evidence.

1. Update `docs/product/PRD.md` and `docs/technical/TECHNICAL_PRD.md` from the
   passed problem framing.
2. Complete `docs/lifecycle/DESIGN_CHALLENGE.md` with assumptions that can be
   falsified, at least two materially different options, the selected path,
   rejected alternatives, failure modes, and fallback.
3. Attack boundaries, abnormal input, malicious use, data quality, bias,
   accessibility, ethics, business backfire, recovery, and rollback.
4. Update `DESIGN_STATUS` only after evidence and review are complete.
5. Run:

```bash
scripts/record-lifecycle-gate.sh design
scripts/check-lifecycle-gate.sh design
```

Stop on failure. Do not start prototype or UI design before the design gate and
user confirmation.

## Stage 2 Prototype and UI Design — Minimum Mainline Smoke

1. Define the smallest executable path that can disprove the core design.
2. Complete `docs/lifecycle/PROTOTYPE_SMOKE_TEST.md` with repeatable steps,
   expected result, actual evidence, stop condition, and `Result: PASS`.
3. Risk `L` or `M` may use `PROTOTYPE_STATUS=NA` only with a concrete
   `Applicability: N/A - ...` rationale. Risk `H` cannot use `NA`.
4. For visible UI work, create a directly openable standalone HTML mockup under
   `docs/design-review/` showing layout, states, navigation, copy, and visual
   tokens. Update durable rules under `docs/design/`.
5. Run:

```bash
scripts/record-lifecycle-gate.sh prototype
scripts/check-lifecycle-gate.sh prototype
```

Stop on failure. Obtain explicit user confirmation before visible UI
implementation.

## Stage 3 Development — Preserve Passed Assumptions

1. Implement only confirmed scope and keep code consistent with the project.
2. Use a failing test or negative control before changing behavior.
3. Run targeted checks during implementation.
4. If evidence falsifies a passed assumption or changes risk, return to the
   earliest invalid stage, update evidence, and reset downstream statuses.
5. Update product, technical, design, or data contracts when behavior changes.

## Stage 3.5 Test and Debug — Smoke and Adversarial Review

1. Run targeted logic tests, type checks, lint, builds, integrations, or
   app-specific verification where available.
2. Complete `docs/lifecycle/SMOKE_TEST_REPORT.md` for critical mainlines,
   including an effective negative control and rollback signal.
3. Complete `docs/lifecycle/ADVERSARIAL_REVIEW.md` from a deliberately hostile
   perspective, including data, model, and Agent logic when applicable. Resolve
   every P0/P1 finding and record evidence.
4. Set `IMPLEMENTATION_STATUS=PASS` only after the actual results pass.
5. Run:

```bash
scripts/record-lifecycle-gate.sh implementation
scripts/check-lifecycle-gate.sh implementation
```

Stop on failure and return to the earliest invalid stage.

## Stage 4 UI Parity — Adversarial Comparison

1. Compare the running implementation against confirmed mockups and specs.
2. Record UI parity notes under `docs/design-review/`.
3. Treat missing states, broken interactions, inaccessible behavior, and P0/P1
   visual differences as adversarial findings.
4. Re-record and re-run the `implementation` gate after parity fixes.

## Stage 5 Release — Revalidate the Candidate

1. Build the deliverable and identify the exact revision, version, artifact,
   environment, and rollback path.
2. Re-run smoke and adversarial evidence against the release candidate whenever
   it differs from the implementation candidate.
3. Place versioned artifacts under `dist/` and update `dist/README.md` when a
   deliverable exists.
4. Risk `H` requires a concrete human approval reference in
   `HUMAN_APPROVAL_REF`.
5. Set `RELEASE_STATUS=PASS`, then run:

```bash
scripts/record-lifecycle-gate.sh release
scripts/check-lifecycle-gate.sh release
```

Stop on failure. A passing local check is evidence, not permission to deploy.

## Stage 6 GitHub — Separate Explicit Authorization

1. After verified, user-acceptable work is ready, summarize completed scope,
   verification, artifact status, residual risks, and changed files.
2. Ask whether to submit to GitHub and identify the specific GitHub action.
3. Only after explicit approval, record its reference in
   `GITHUB_APPROVAL_REF`, set `GITHUB_STATUS=APPROVED`, and run:

```bash
scripts/record-lifecycle-gate.sh github
scripts/check-lifecycle-gate.sh github
```

4. Show `git status`, changed-file summary, proposed commit message, and fresh
   verification evidence before acting.
5. Commit, push, create a PR, publish, or deploy only within the exact approval.

Without explicit approval, keep work local and `GITHUB_STATUS=BLOCKED`.

## Stage 7 Retrospective — Root Cause, Not Surface Attribution

1. Complete `docs/lifecycle/RETROSPECTIVE.md` using observable facts.
2. Descend from symptom to the deepest actionable cause and identify the
   violated first-principles constraint.
3. Record a counterfactual and durable corrective action with owner, review
   date, and verification evidence.
4. Complete `docs/lifecycle/IMPROVEMENT_PROPOSAL.md` with either
   `Applicability: NONE - <concrete reason>` or a full `PROPOSED` record whose
   decision remains `REVIEW`.
5. Do not modify or claim approval for the source harness from this project.
6. Set `RETROSPECTIVE_STATUS=PASS`, then run:

```bash
scripts/record-lifecycle-gate.sh retrospective
scripts/check-lifecycle-gate.sh retrospective
```

## Final Response Checklist

- What changed and which confirmed goal it serves.
- Current risk level and gate status.
- Verification commands, results, and evidence paths.
- Adversarial findings and residual risk.
- Skipped or blocked verification.
- Required human review or external enforcement.
