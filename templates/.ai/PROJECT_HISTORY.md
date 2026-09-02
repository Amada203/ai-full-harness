# PROJECT_HISTORY

This file records important decisions and verification history. Focus on why
decisions were made, not just what changed.

---

## {{TODAY}}: Initialize Full Harness

### Background

The project needs a durable AI Project Harness so Codex, Claude Code, Cursor,
Gemini, and other local coding agents can share one context, one rule source,
and one workflow.

### Decision

Use the strong-hierarchy harness structure:

- Root entry files: `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`,
  `.cursor/rules/project-lifecycle.mdc`
- Core harness files: `.ai/PROJECT_CONTEXT.md`, `.ai/PROJECT_RULES.md`,
  `.ai/LIFECYCLE_STATE`, `.ai/LIFECYCLE_BASELINE`,
  `.ai/PROJECT_HISTORY.md`, `.ai/WORKFLOW.md`, `.ai/HARNESS_VERSION`
- Detailed knowledge base: `docs/product/`, `docs/technical/`, `docs/design/`,
  `docs/design-review/`, `docs/data/`, `docs/lifecycle/`
- Release artifacts: `dist/`

### Reason

- Avoid duplicating rules across tool-specific entry files.
- Keep current state, rules, history, and execution workflow separate.
- Make first-principles reasoning, U-shaped thinking, smoke testing, and
  adversarial review produce auditable evidence with mechanical stage gates.
- Default to risk level M and require deeper evidence or human approval for
  high-risk work.
- Make agent behavior stable across projects and machines.
- Detect evidence changed after review and automatically invalidate downstream
  approvals when an upstream gate is re-recorded.
- Return reusable learning through review-only improvement proposals rather
  than autonomous rule mutation.

### Impact

Future meaningful changes must update `.ai/PROJECT_CONTEXT.md` first and append
the decision or verification outcome here.

Local validators enforce file, state, freshness, dependency, and
critical-finding invariants. Generated CI checks the fixed final gate. Branch
protection, permissions, and identity-backed approval systems remain necessary
outside the repository trust boundary.
