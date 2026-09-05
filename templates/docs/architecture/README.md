# Architecture evidence

All projects produce a top-level Archify architecture during Stage 1. Keep
product requirements in docs/product/PRD.md and technical responsibilities in
docs/technical/TECHNICAL_PRD.md. No duplicate PRDs are needed.

Author ARCHITECTURE.archify.json from confirmed requirements using the Archify
skill. Use stable component IDs, meaningful edge labels and showcase quality.
Each component must have an `ARCH:<id>` responsibility reference in the technical
PRD, which links `[Architecture](../architecture/ARCHITECTURE.html)`.
Document assumptions, trust boundaries, external dependencies, human decisions,
failure and recovery in DESIGN_CHALLENGE.md. Explain non-applicability instead
of inventing services. Keep the top-level view readable; create additional
workflow, data-flow or security diagrams only when the problem requires them.

Set ARCHIFY_HOME to an installation matching .ai/ARCHIFY_LOCK.json. The harness
also discovers ~/.agents/skills/archify and ~/.codex/skills/archify. Node.js 18+
is required. The tool is an authoring dependency, not a business runtime.
No install or update is performed automatically. Other agents follow the same
commands and fail closed if the pinned tool is unavailable.

```sh
node scripts/architecture.mjs build
node scripts/architecture.mjs check
```

Build generates ARCHITECTURE.html and ARCHITECTURE.receipt.json; do not edit
these generated files. JSON, HTML and receipt are tracked in Git. A fresh project
has no approved architecture: author it after Stage 0. Design cannot pass before
delivery. Architecture changes invalidate design and dependent gates.

After delivery use Archify `visual-check` on the exact HTML and inspect its
screenshots. Record browser result and perceptual result independently in
DESIGN_CHALLENGE.md with the artifact digest; receipt validation alone proves
neither. Before release, reconcile components and relationships with code and
record discrepancies in ADVERSARIAL_REVIEW.md. Code semantics and honest review
cannot be proven by file hashes or ARCH references.

Tool upgrades require a reviewed lock change and regeneration. Do not accept a
different tool merely because it reports the same version. Existing projects
adopt these requirements through an owner-reviewed Harness upgrade.
