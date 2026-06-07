# PROJECT_CONTEXT

## Project Summary

Project: {{PROJECT_NAME}}

Goal: {{PROJECT_DESCRIPTION}}

Current Stage: Stage 0 Plan

Harness Version: {{HARNESS_VERSION}}

## Current Approach

Use the standard delivery sequence:

```text
Plan -> PRD -> UI HTML design -> user confirmation -> development -> UI parity
check -> release artifact -> GitHub only after explicit approval
```

## Tech Stack

{{PROJECT_STACK}}

## Important Document Index

- Product requirements: `docs/product/PRD.md`
- Technical requirements: `docs/technical/TECHNICAL_PRD.md`
- Design guidance: `docs/design/`
- Design review and UI parity: `docs/design-review/`
- Data definitions and delivery rules: `docs/data/`
- Release artifacts: `dist/`

## Current Status

- Stage 0 Plan is active.
- PRD has not been confirmed.
- UI design has not been confirmed.
- Implementation has not started.

## Blockers

- Awaiting Plan clarification and user confirmation.

## Next Step

Draft the Stage 0 Plan summary and stop for user confirmation before writing
PRD files.

## Active Decisions

- Root entry files are tool adapters only.
- `.ai/PROJECT_RULES.md` is the single source of truth.
- `.ai/WORKFLOW.md` defines task execution.
- Do not implement visible UI changes until HTML design is confirmed.
