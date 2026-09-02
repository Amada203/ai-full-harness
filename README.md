# AI Full Harness

Strong-hierarchy AI Project Harness for long-lived projects and multi-agent
workflows.

This package is intentionally separate from `~/ai-workflow-config`. It keeps the
existing lightweight harness unchanged while providing a fuller structure for
projects that need durable context, rules, history, workflow, and documentation
layers.

Version 2.2 adds freshness-aware enforcement. First-principles reasoning,
U-shaped thinking, smoke testing, and adversarial review produce mandatory
evidence; recorded fingerprints detect later changes, upstream re-recording
invalidates downstream approvals, and CI checks the fixed final gate.

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
│   ├── LIFECYCLE_STATE
│   ├── LIFECYCLE_BASELINE
│   ├── PROJECT_HISTORY.md
│   ├── WORKFLOW.md
│   └── HARNESS_VERSION
├── docs/
│   ├── product/PRD.md
│   ├── technical/TECHNICAL_PRD.md
│   ├── design/
│   ├── design-review/
│   ├── data/
│   └── lifecycle/
├── scripts/
│   ├── check-harness.sh
│   ├── check-lifecycle-gate.sh
│   ├── lifecycle-fingerprint.sh
│   └── record-lifecycle-gate.sh
├── .github/workflows/harness-gates.yml
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

## Lifecycle Gates

Every project starts at risk level `M`. Use `L` only for narrow, reversible
work with no high-impact trigger; use `H` for sensitive data, authorization,
destructive behavior, regulated or safety-critical outcomes, autonomous AI
decisions, production security, or consequential publication.

```bash
scripts/check-harness.sh
scripts/record-lifecycle-gate.sh plan
scripts/check-lifecycle-gate.sh plan
scripts/record-lifecycle-gate.sh design
scripts/check-lifecycle-gate.sh design
scripts/record-lifecycle-gate.sh prototype
scripts/check-lifecycle-gate.sh prototype
scripts/record-lifecycle-gate.sh implementation
scripts/check-lifecycle-gate.sh implementation
scripts/record-lifecycle-gate.sh release
scripts/check-lifecycle-gate.sh release
scripts/record-lifecycle-gate.sh github
scripts/check-lifecycle-gate.sh github
scripts/record-lifecycle-gate.sh retrospective
scripts/check-lifecycle-gate.sh retrospective
```

The recorder validates transactionally, stores the gate fingerprint, and clears
downstream statuses, fingerprints, and obsolete approval references. Gate checks
validate dependencies and fail on missing, incomplete, unrecorded, or stale
evidence, failed smoke tests, open P0/P1 findings, or missing approvals.

GitHub Actions always runs `check-lifecycle-gate.sh github`; it does not trust
mutable `CURRENT_GATE`. To make this non-bypassable for merges, configure the
workflow as a required check in repository branch protection.

## Controlled Self-Evolution

Retrospectives can create a complete `IMPROVEMENT_PROPOSAL.md` in `REVIEW`
state. A project never edits the source harness automatically and never marks
its own proposal approved or applied. This keeps learning continuous while
retaining human control over rule changes and migrations.

## Assurance Boundary

The harness provides behavioral rules, auditable evidence, freshness checks,
automatic downstream invalidation, and CI configuration. It cannot prove
evidence is truthful, bind an approval to a real human, stop an administrator
from editing controls, or enable branch protection on its own. Required checks,
deployment permissions, audit logs, and external approval systems are still
needed for stronger enforcement. Existing projects are not silently upgraded;
safe migration remains a separate, version-aware operation.
