# Full Harness Global Entry

When the user asks to create a project with the full harness, including
"用完整 Harness 新建项目", "完整 Harness", or "full harness project":

1. Do not start coding immediately.
2. Ask only for missing essentials: project name, target parent directory, and
   tech stack when relevant.
3. Run `~/ai-full-harness/bin/new-full-project <project-name> <target-parent>`.
4. If known, pass `AI_PROJECT_STACK` and `AI_PROJECT_DESCRIPTION`.
5. Open the generated project and read its root entry file.
6. Then read `.ai/PROJECT_CONTEXT.md`, `.ai/PROJECT_RULES.md`, recent
   `.ai/PROJECT_HISTORY.md`, and `.ai/WORKFLOW.md`.
7. Start at Stage 0 Plan.

For generated projects, `.ai/PROJECT_RULES.md` is the single source of truth.
Project entry files are startup pointers only.
