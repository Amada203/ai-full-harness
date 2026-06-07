# PROJECT_RULES

.ai/PROJECT_RULES.md is the single source of truth for this project's workflow,
stage gates, file roles, and AI-agent behavior. If any entry file or
tool-specific rule conflicts with this file, follow this file.

## Agent Startup Protocol

Before starting any task, an AI agent must:

1. Read `.ai/PROJECT_CONTEXT.md`.
2. Read `.ai/PROJECT_RULES.md`.
3. Read recent `.ai/PROJECT_HISTORY.md` entries. For release work, regression
   investigation, or resumed old tasks, read more history as needed.
4. Read `.ai/WORKFLOW.md`.
5. Identify the current stage and next gate.
6. If required files cannot be read, report that first instead of starting
   implementation.

## Document and Directory Map

| Path | Role | Update Rule |
|------|------|-------------|
| `AGENTS.md` | Codex and generic AI entry file. | Keep thin. Point to `.ai/` harness files only. |
| `CLAUDE.md` | Claude Code entry file. | Keep thin. Tool-specific entry only; do not duplicate rules. |
| `GEMINI.md` | Gemini CLI entry file. | Keep thin. Tool-specific entry only; do not duplicate rules. |
| `.cursor/rules/project-lifecycle.mdc` | Cursor project rule entry. | Keep thin. Tool-specific entry only; do not duplicate rules. |
| `.ai/PROJECT_CONTEXT.md` | Current project state, document index, current status, blockers, next step, active decisions. | Update before changing scope, behavior, design, or execution order. Keep compact. |
| `.ai/PROJECT_RULES.md` | Unique rule source for workflow gates, file roles, and AI behavior. | Update only when operating rules change. |
| `.ai/PROJECT_HISTORY.md` | Dated record of meaningful decisions, verification, and rationale. | Append after meaningful changes. Do not use as current state. |
| `.ai/WORKFLOW.md` | Standard task execution process. | Update when the agent execution process changes. |
| `.ai/HARNESS_VERSION` | Harness template version used by this project. | Update only through harness template upgrades. |
| `docs/product/` | Product requirements, user stories, business rules, and acceptance criteria. | Update during Stage 1 and when product scope changes. |
| `docs/technical/` | Architecture, data model, API contracts, and verification plans. | Update during Stage 1 and whenever technical contracts change. |
| `docs/design/` | UI, interaction, visual, and design-token guidance. | Update before or during Stage 2 design work. |
| `docs/design-review/` | HTML mockups, specs, screenshots, and UI parity reports. | Required before visible UI implementation. |
| `docs/data/` | Data dictionary, metric definitions, field rules, and delivery rules. | Update when data semantics or delivery rules change. |
| `dist/` | Versioned release artifacts and release notes. | Use only for deliverables; update `dist/README.md` for each release. |
| `scripts/check-harness.sh` | Local harness structure validator. | Keep aligned with required harness files. |

## Delivery Sequence

Follow this sequence:

```text
Plan -> PRD -> UI HTML design -> user confirmation -> development -> UI parity
check -> release artifact -> GitHub only after explicit approval
```

## Stage Gates

- Stage 0 Plan must be accepted before writing PRD files.
- Stage 1 PRD must be confirmed before UI design.
- Stage 2 UI HTML design must be confirmed before implementing visible UI
  changes.
- Stage 3 Development must stay within confirmed scope unless the user approves
  a scope change.
- Stage 4 UI parity must clear P0 visual and interaction differences before
  completion is claimed.
- Stage 5 Release artifact must include versioned output and `dist/README.md`
  notes when a deliverable is produced.
- Stage 6 GitHub actions require explicit user approval.

## General Development Rules

- Understand existing code and documents before modifying anything.
- Prefer the smallest useful change.
- Do not perform unrelated refactors.
- Do not remove existing functionality unless the user explicitly requests it.
- Match existing project style and architecture.
- For product, technical, design, or data questions, read the relevant `docs/`
  directory before acting.

## Documentation Update Rules

- Current state changes: update `.ai/PROJECT_CONTEXT.md`.
- Important technical or business decisions: append to `.ai/PROJECT_HISTORY.md`.
- Rule changes: update `.ai/PROJECT_RULES.md`.
- Workflow changes: update `.ai/WORKFLOW.md`.
- Product scope changes: update `docs/product/`.
- Technical contract changes: update `docs/technical/`.
- UI or interaction changes: update `docs/design/` and `docs/design-review/`.
- Data definition or delivery changes: update `docs/data/`.

## Verification

- Run the smallest meaningful verification command before claiming completion.
- For UI work, verify against the confirmed mockup or design spec.
- For release work, verify artifact name, version, and install/deploy notes.
- Report commands that could not be run and why.
- Do not treat assumptions as verification.

## Git and Release Rules

- Check changed files before committing.
- Commit messages must explain the purpose of the change.
- Do not commit, push, create PRs, publish, or deploy unless the user explicitly
  asks.
- Do not commit temporary files, secrets, unrelated build outputs, or local
  caches.

## Secrets

- Do not commit `.env`, API keys, tokens, local credentials, private database
  connection strings, or local tool caches.
- Use `.env.example` for documented environment variables.

## Project-Specific Rules

- Add project-specific business, technical, data, or delivery rules here.
