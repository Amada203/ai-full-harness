# NEW_PROJECT_TRIGGER

Use this trigger only for the full harness.

When the user says "用完整 Harness 新建项目", "完整 Harness", "full harness
project", or equivalent:

1. Do not start coding immediately.
2. Ask only for missing essentials:
   - project name
   - target parent directory
   - intended tech stack, if relevant
3. Run:

```bash
~/ai-full-harness/bin/new-full-project <project-name> <target-parent>
```

If description or stack is known:

```bash
AI_PROJECT_STACK="..." AI_PROJECT_DESCRIPTION="..." \
  ~/ai-full-harness/bin/new-full-project <project-name> <target-parent>
```

4. Open the generated project.
5. Read root entry file, then `.ai/PROJECT_CONTEXT.md`,
   `.ai/PROJECT_RULES.md`, recent `.ai/PROJECT_HISTORY.md`, and
   `.ai/WORKFLOW.md`.
6. Start at Stage 0 Plan.

Do not use this trigger for ordinary "新建项目" requests unless the user says
"完整 Harness" or explicitly asks to use this full harness.
