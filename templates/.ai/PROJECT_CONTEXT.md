# PROJECT_CONTEXT

## Project Summary

Project: {{PROJECT_NAME}}

Goal: {{PROJECT_DESCRIPTION}}

Current Stage: Stage 0 Plan

Harness Version: {{HARNESS_VERSION}}

Risk Level: M

Current Lifecycle Gate: plan

## Current Approach

Use the standard delivery sequence:

```text
Problem framing -> challenged design -> prototype smoke -> confirmed
development -> pre-release smoke and adversarial review -> release -> GitHub
only after explicit approval -> retrospective
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
- Machine-readable gate state: `.ai/LIFECYCLE_STATE`
- Recorded gate fingerprints: `.ai/LIFECYCLE_BASELINE`
- Lifecycle reasoning and verification evidence: `docs/lifecycle/`

## Current Status

- Stage 0 Plan is active.
- Risk level defaults to M until `docs/lifecycle/PROBLEM_FRAMING.md` justifies a
  different level.
- The plan gate is blocked until problem framing is complete and validated.
- PRD has not been confirmed.
- UI design has not been confirmed.
- Implementation has not started.

## Blockers

- Awaiting first-principles problem framing, U-shaped root-need analysis, and
  user confirmation.

## Next Step

Complete `docs/lifecycle/PROBLEM_FRAMING.md`, update
`.ai/LIFECYCLE_STATE`, run `scripts/record-lifecycle-gate.sh plan` followed by
`scripts/check-lifecycle-gate.sh plan`, and stop for user confirmation before
writing PRD files.

## Active Decisions

- Root entry files are tool adapters only.
- `.ai/PROJECT_RULES.md` is the single source of truth.
- `.ai/WORKFLOW.md` defines task execution.
- `.ai/LIFECYCLE_STATE` is the machine-readable gate and risk state.
- `.ai/LIFECYCLE_BASELINE` detects unrecorded or changed gate evidence.
- Stage evidence lives under `docs/lifecycle/` and cannot be silently skipped.
- Harness learning is proposed for human review and never self-applied.
- Do not implement visible UI changes until HTML design is confirmed.
