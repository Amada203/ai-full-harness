# AI Full Harness

Strong-hierarchy AI Project Harness for long-lived projects and multi-agent
workflows.

This package is intentionally separate from `~/ai-workflow-config`. It keeps the
existing lightweight harness unchanged while providing a fuller structure for
projects that need durable context, rules, history, workflow, and documentation
layers.

## Structure

Generated projects use:

```text
project/
├── AGENTS.md
├── CLAUDE.md
├── GEMINI.md
├── .cursor/rules/project-lifecycle.mdc
├── .ai/
│   ├── PROJECT_CONTEXT.md
│   ├── PROJECT_RULES.md
│   ├── PROJECT_HISTORY.md
│   ├── WORKFLOW.md
│   └── HARNESS_VERSION
├── docs/
│   ├── product/PRD.md
│   ├── technical/TECHNICAL_PRD.md
│   ├── design/
│   ├── design-review/
│   └── data/
├── scripts/check-harness.sh
└── dist/
```

## Create a Full Harness Project

```bash
AI_PROJECT_STACK="React + Node.js" \
AI_PROJECT_DESCRIPTION="Internal analytics workspace" \
  ~/ai-full-harness/bin/new-full-project analytics-workspace ~/Projects
```

## Optional Global Install

The installer uses a separate trigger phrase so it does not replace the existing
lightweight harness:

```text
用完整 Harness 新建一个项目
```

Run only when you want AI tools to recognize that trigger globally:

```bash
~/ai-full-harness/bin/install-ai-full-harness
```

## Rule Precedence

- Global rules start projects and enforce safety baselines.
- Project rules live in `.ai/PROJECT_RULES.md`.
- Project rules override global defaults except safety rules:
  no secrets, no destructive changes without explicit approval, no
  commit/push/publish/deploy without explicit approval.
