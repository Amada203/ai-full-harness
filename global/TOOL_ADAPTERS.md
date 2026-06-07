# TOOL_ADAPTERS

Tool-specific entry files should stay thin.

They must:

1. Identify themselves as startup entry files.
2. Point to `.ai/PROJECT_CONTEXT.md`.
3. Point to `.ai/PROJECT_RULES.md`.
4. Point to recent `.ai/PROJECT_HISTORY.md`.
5. Point to `.ai/WORKFLOW.md`.
6. State that `.ai/PROJECT_RULES.md` is the single source of truth.

They must not duplicate the full project rules. Duplication causes drift across
Codex, Claude Code, Gemini CLI, Cursor, and future AI tools.
