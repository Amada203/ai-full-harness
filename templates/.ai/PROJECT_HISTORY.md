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
  `.ai/PROJECT_HISTORY.md`, `.ai/WORKFLOW.md`, `.ai/HARNESS_VERSION`
- Detailed knowledge base: `docs/product/`, `docs/technical/`, `docs/design/`,
  `docs/design-review/`, `docs/data/`
- Release artifacts: `dist/`

### Reason

- Avoid duplicating rules across tool-specific entry files.
- Keep current state, rules, history, and execution workflow separate.
- Make agent behavior stable across projects and machines.

### Impact

Future meaningful changes must update `.ai/PROJECT_CONTEXT.md` first and append
the decision or verification outcome here.
