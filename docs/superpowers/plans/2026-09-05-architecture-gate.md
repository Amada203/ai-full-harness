# Architecture Evidence Implementation Plan

**Goal:** Require an Archify architecture artifact in the existing Stage 1 design gate.

**Architecture:** Keep PRD and technical PRD paths. Add architecture source, generated HTML and a digest-bound delivery receipt under docs/architecture. Use a pinned external Archify installation via ARCHIFY_HOME; missing tools block design, not project creation. Generation is explicit; checking never repairs or downloads.

**Tech Stack:** Node.js, existing Bash lifecycle gates, Archify standalone CLI.

1. Add a real showcase fixture and validate it with installed Archify.
2. Implement scripts/architecture.mjs build/check with tool-content pin, regular-file checks, semantic-source links, native delivery receipt and HTML/source digest checks.
3. Include architecture in design fingerprints and require checks before recording design. Add protected script and lock paths.
4. Update templates and operator instructions: all projects require a top-level diagram; additional diagrams are justified by the problem, not invented for a quota. Architecture is proposed at design and reconciled against implementation before release.
5. Run negative controls for missing evidence, changed HTML/JSON/tool and incomplete technical references, then full generator/lifecycle regressions. Preserve outputs as local evidence; no commit or publication.

Visual browser evidence and perceptual review remain separate from deterministic deliver. This change does not certify unresolved Autopilot deployment issues.
