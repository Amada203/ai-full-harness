# WORKFLOW

This file defines how AI agents should execute tasks in this project.

## Standard Task Flow

1. Read `.ai/PROJECT_CONTEXT.md`.
2. Read `.ai/PROJECT_RULES.md`.
3. Read recent `.ai/PROJECT_HISTORY.md` entries.
4. Read `.ai/WORKFLOW.md`.
5. Read relevant files under `docs/` if the task touches product, technical,
   design, or data behavior.
6. Analyze the request and identify:
   - task goal
   - affected modules
   - current stage and gate
   - required documentation updates
   - required verification
7. Make the smallest useful change.
8. Run test and debug checks appropriate to the project.
9. Run final meaningful verification.
10. Update harness or docs files when required.
11. Report the result, verification evidence, risks, and any needed human check.

## Stage 0 Plan

- Clarify goals, non-goals, scope, affected surfaces, risks, and constraints.
- Do not write PRD files until the user accepts the Plan.

## Stage 1 PRD

- Update `docs/product/PRD.md`.
- Update `docs/technical/TECHNICAL_PRD.md`.
- Stop for user confirmation before UI design.

## Stage 2 UI Design

- Create or update a standalone HTML mockup under `docs/design-review/` for
  every visible UI flow or screen that needs user confirmation.
- The standalone HTML mockup must be directly openable in a browser and must
  show the actual UI layout, states, navigation, copy, and visual tokens clearly
  enough for user review.
- Use file names like `<feature>-mockups.html`, such as
  `v5.5-missing-screens-mockups.html`.
- Create or update UI specs and related notes under `docs/design-review/`.
- Update `docs/design/` for durable UI rules or tokens.
- Stop for explicit user confirmation before implementing visible UI changes.

## Stage 3 Development

- Implement only confirmed scope.
- Keep code style consistent with the existing project.
- Update `.ai/PROJECT_CONTEXT.md` before changing behavior, design, or execution
  order.
- Update docs when product, technical, design, or data contracts change.

## Stage 3.5 Test and Debug

- Run targeted tests for changed logic.
- Run type checks, lint checks, build checks, or app-specific verification when
  available.
- Reproduce and debug reported failures before claiming completion.
- For UI work, run or open the implementation and verify it against the
  confirmed standalone HTML mockup before moving to UI parity.
- Record meaningful debugging findings or decisions in `.ai/PROJECT_HISTORY.md`.

## Stage 4 UI Parity

- Compare implementation against confirmed mockups and specs.
- Record UI parity notes under `docs/design-review/`.
- Clear P0 visual and interaction differences before claiming completion.

## Stage 5 Release Artifact

- Build the deliverable.
- Place versioned artifacts under `dist/`.
- Update `dist/README.md` with version, build command, verification, and usage
  instructions.

## Stage 6 GitHub

- Commit, push, create PRs, publish, or deploy only after explicit user approval.
- Before commit or push, inspect changed files and run verification.

## Final Response Checklist

When finishing a task, report:

- what changed
- important files touched
- verification command and result
- remaining risk or skipped verification
- any required human check
