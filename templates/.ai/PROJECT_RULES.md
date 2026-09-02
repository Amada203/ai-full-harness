# PROJECT_RULES

.ai/PROJECT_RULES.md is the single source of truth for this project's workflow,
stage gates, file roles, and AI-agent behavior. If an entry file or
tool-specific rule conflicts with this file, follow this file.

## Agent Startup Protocol

Before starting any task, an AI agent must:

1. Read `.ai/PROJECT_CONTEXT.md`.
2. Read `.ai/PROJECT_RULES.md`.
3. Read `.ai/LIFECYCLE_STATE` without sourcing or executing it.
4. Read `.ai/LIFECYCLE_BASELINE` without sourcing or executing it.
5. Read recent `.ai/PROJECT_HISTORY.md` entries. For release work, regression
   investigation, or resumed old tasks, read more history as needed.
6. Read `.ai/WORKFLOW.md`.
7. Read the relevant product, technical, design, data, and lifecycle evidence.
8. Identify the current stage, risk level, applicable gate, and next allowed
   action.
9. If a required file cannot be read, report that first and do not advance.

## Document and Directory Map

| Path | Role | Update Rule |
|---|---|---|
| `AGENTS.md` | Codex and generic AI entry file. | Keep thin and point to `.ai/` files only. |
| `CLAUDE.md` | Claude Code entry file. | Keep thin and do not duplicate rules. |
| `GEMINI.md` | Gemini CLI entry file. | Keep thin and do not duplicate rules. |
| `.cursor/rules/project-lifecycle.mdc` | Cursor project rule entry. | Keep thin and do not duplicate rules. |
| `.ai/PROJECT_CONTEXT.md` | Current project state, document index, blockers, next step, and active decisions. | Update before changing scope, behavior, design, risk, or execution order. |
| `.ai/PROJECT_RULES.md` | Unique rule source for workflow gates and AI behavior. | Update only when operating rules change. |
| `.ai/LIFECYCLE_STATE` | Machine-readable risk level and gate statuses. | Treat as data; update only when evidence supports the transition. |
| `.ai/LIFECYCLE_BASELINE` | Recorded gate fingerprints used to detect changed or stale evidence. | Never edit manually; update only through `record-lifecycle-gate.sh`. |
| `.ai/PROJECT_HISTORY.md` | Dated decisions, risk changes, verification, and rationale. | Append after meaningful changes; do not use as current state. |
| `.ai/WORKFLOW.md` | Standard task execution process. | Update when execution stages change. |
| `.ai/HARNESS_VERSION` | Harness template version used by this project. | Update only through a harness upgrade. |
| `docs/product/` | Product requirements, stories, rules, outcomes, and acceptance criteria. | Update during Stage 1 and when scope changes. |
| `docs/technical/` | Architecture, data model, contracts, failure design, and verification plan. | Update during Stage 1 and when technical contracts change. |
| `docs/design/` | Durable UI, interaction, visual, and accessibility guidance. | Update before or during Stage 2 design work. |
| `docs/design-review/` | Standalone HTML mockups, specs, screenshots, and UI parity reports. | Required before visible UI implementation. |
| `docs/data/` | Data dictionary, metric definitions, field rules, and delivery rules. | Update when data semantics change. |
| `docs/lifecycle/` | First-principles, U-shaped, smoke-test, adversarial, and retrospective evidence. | Complete the relevant file before changing its gate to a passing status. |
| `docs/lifecycle/IMPROVEMENT_PROPOSAL.md` | Review-only proposal for reusable harness learning. | Use `NONE - reason` or a complete `PROPOSED` record; never self-approve or self-apply it. |
| `dist/` | Versioned release artifacts and release notes. | Use only for deliverables and update `dist/README.md`. |
| `scripts/check-harness.sh` | Structural harness validator. | Keep aligned with required harness files. |
| `scripts/check-lifecycle-gate.sh` | Stage dependency and evidence validator. | Run for the current gate and keep aligned with lifecycle evidence. |
| `scripts/lifecycle-fingerprint.sh` | Deterministic evidence-scope fingerprint calculator. | Read-only; filenames with newlines are rejected. |
| `scripts/record-lifecycle-gate.sh` | Transactional gate recorder and downstream invalidator. | Use after evidence/status completion and before the read-only check. |
| `.github/workflows/harness-gates.yml` | Fixed final-gate CI enforcement. | Keep the literal `github` gate; do not select from `CURRENT_GATE`. |

## Mandatory Operating Disciplines

### First-Principles Reasoning

- Separate observed facts, derived constraints, and assumptions.
- Define the core outcome and measurable success before selecting a solution.
- Do not treat an inherited system, requested feature, or prior decision as an
  immutable constraint.

### U-Shaped Thinking

- Descend from the surface request to the root need using evidence.
- Identify pseudo-requirements that do not serve the root need.
- Rebuild the solution upward from facts, constraints, and the core outcome.

### Smoke Testing

- Define the smallest representative end-to-end mainline.
- Record repeatable commands or steps, expected result, actual evidence, and an
  explicit result.
- A failed or blocked smoke test sends work back to the earliest invalid stage.

### Adversarial Review

- Attack boundaries, abnormal and malicious inputs, permissions, data quality
  and bias, model evaluation and drift, Agent logic and tool authority, prompt
  injection, accessibility, ethics, business backfire, recovery, and rollback.
- Every finding has a severity, disposition, owner, and verification evidence.
- Open P0 or P1 findings block implementation and release gates.

## Risk Classification

- `L` is limited to narrow, reversible work with no sensitive data,
  authorization, destructive behavior, regulated outcome, autonomous AI
  decision, production security, or consequential external publication.
- `M` is the default for ordinary feature, data, API, and integration work and
  whenever risk is uncertain.
- `H` applies when any high-impact trigger above is present.
- Risk may be raised at any time. Lowering risk requires a rationale in
  `docs/lifecycle/PROBLEM_FRAMING.md` and a dated decision in
  `.ai/PROJECT_HISTORY.md`.
- A risk-`H` prototype cannot use `NA`. A risk-`H` release requires a concrete
  `HUMAN_APPROVAL_REF`.

## Lifecycle State Rules

- `.ai/LIFECYCLE_STATE` is never sourced or executed as shell code.
- `.ai/LIFECYCLE_BASELINE` is never sourced, executed, or edited manually.
- Valid passing values are `PASS`, prototype-only `NA`, and GitHub-only
  `APPROVED`. All incomplete stages remain `BLOCKED`.
- Do not change a gate to a passing value until its evidence is complete and
  its verification has actually run.
- Recording a changed upstream gate resets every downstream status and
  fingerprint to `BLOCKED`/`UNRECORDED` and clears downstream approval
  references. This is the supported transition path; do not preserve stale
  approvals manually.
- A gate cannot be skipped silently. If a gate is not applicable, use only the
  explicitly supported `NA` path and record a concrete reason.
- Exceptions do not convert a failed check to a pass. Record the exception,
  owner, impact, expiry, and external approval; keep the gate blocked unless
  project rules explicitly support that exception.
- After evidence is complete and its status is set, run
  `scripts/record-lifecycle-gate.sh <gate>` and then
  `scripts/check-lifecycle-gate.sh <gate>`. A non-zero exit means stop, report
  the evidence gap, and return to the earliest invalid stage.
- Any later change inside a recorded gate's evidence scope makes that gate
  stale until it is reviewed and recorded again.

## Delivery Sequence

```text
Stage 0 problem framing -> Stage 1 challenged PRD and solution -> Stage 2
prototype/UI smoke -> Stage 3 confirmed development -> Stage 3.5 smoke and
adversarial review -> Stage 4 parity -> Stage 5 release -> Stage 6 GitHub only
after explicit approval -> Stage 7 retrospective
```

## Stage Gates

- **Stage 0 Plan:** apply First-Principles Reasoning and U-Shaped Thinking;
  complete `PROBLEM_FRAMING.md`; pass the `plan` gate before writing PRDs.
- **Stage 1 PRD and solution:** complete product and technical PRDs plus
  `DESIGN_CHALLENGE.md`; compare at least two real options; pass the `design`
  gate before prototype or UI design.
- **Stage 2 prototype and UI design:** produce the minimum executable prototype
  smoke evidence. Visible UI work also requires a directly openable standalone HTML mockup
  under `docs/design-review/`. Pass the `prototype` gate and obtain user
  confirmation before visible UI implementation.
- **Stage 3 Development:** implement only confirmed scope. Any material change
  resets affected downstream statuses to `BLOCKED`.
- **Stage 3.5 Test and Debug:** complete targeted checks,
  `SMOKE_TEST_REPORT.md`, and `ADVERSARIAL_REVIEW.md`; pass the
  `implementation` gate.
- **Stage 4 UI parity:** compare against confirmed mockups and specs. Any open
  P0/P1 visual or interaction finding blocks the implementation gate.
- **Stage 5 Release:** build and verify versioned deliverables, update
  `dist/README.md` when an artifact exists, and pass the `release` gate.
- **Stage 6 GitHub:** Ask whether to submit to GitHub only after verified, user-acceptable
  work is ready. Record explicit approval separately, pass the `github` gate,
  and then perform only the approved commit, push, PR, publish, or deploy action.
- **Stage 7 Retrospective:** apply U-Shaped Thinking and First-Principles
  Reasoning to evidence-backed root causes; complete `RETROSPECTIVE.md`, choose
  a concrete no-change reason or a review-only improvement proposal, and pass
  the `retrospective` gate. A project never edits the source harness itself.

## General Development Rules

- Understand existing code and documents before modifying anything.
- Prefer the smallest useful change and avoid unrelated refactors.
- Do not remove functionality unless the user explicitly requests it.
- Match existing project style and architecture.
- Update `.ai/PROJECT_CONTEXT.md` before changing behavior, design, risk, or
  execution order.
- Append material decisions, risk changes, debugging findings, and verification
  outcomes to `.ai/PROJECT_HISTORY.md`.

## Verification

- Run the smallest meaningful check during development and the full applicable
  gate before advancing.
- For behavior changes, use a failing test or negative control before the fix,
  then prove it passes after the fix.
- For UI work, verify against the confirmed mockup or design spec.
- For release work, verify artifact identity, version, usage, rollback, and
  smoke evidence.
- Report commands that could not run and why. Assumptions are not verification.

## Git and Release Rules

- Check changed files and verification evidence before any Git operation.
- Never commit, push, create a PR, publish, or deploy without explicit user
  approval for that action.
- GitHub approval must be distinct from design, implementation, or release
  approval and recorded in `GITHUB_APPROVAL_REF`.
- Do not commit secrets, temporary files, unrelated build output, or local
  caches.

## Secrets

- Do not commit `.env`, API keys, tokens, credentials, private connection
  strings, private customer data, or local tool caches.
- Use `.env.example` for documented environment variables without live values.

## Enforcement Boundary

Local rules and validators can mechanically reject missing evidence,
placeholders, inconsistent statuses, incomplete dependencies, unresolved P0/P1
findings, absent approval references, unrecorded evidence, and changed evidence
after review. CI checks the fixed final `github` gate. These controls cannot
prove evidence is honest, bind an approval to a real identity, prevent a user
with repository access from editing controls, or make CI required. Stronger
guarantees require enabling branch protection/required checks, deployment
permissions, audit logs, and external human approval systems.

## Project-Specific Rules

- Add project-specific business, technical, data, security, or delivery rules
  here without weakening the safety and gate requirements above.
