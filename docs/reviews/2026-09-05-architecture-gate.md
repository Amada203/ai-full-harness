# Architecture Gate verification — 2026-09-05

## Scope

The confirmed change adds architecture evidence to Stage 1 without moving PRDs.
Implementation is in the existing codex/autopilot-contract worktree and remains
uncommitted. The main /Users/apple/ai-full-harness generator has not been changed
by this architecture increment. The prior Autopilot NO-GO remains in force.

## Verified

- `node tests/test-architecture.mjs`: PASS, actual installed Archify used.
- Negative controls: missing source/receipt, changed source bytes, changed HTML,
  missing technical node references, different tool hash, unavailable explicit tool.
- `bash tests/test-lifecycle-gates.sh`: PASS; includes architecture fingerprint
  staleness and existing upstream/downstream gate behavior.
- `bash tests/test-new-full-project.sh`: PASS.
- `bash tests/test-autopilot-workflow-static.sh`: PASS.
- `bash tests/test-autopilot-contract.sh`: PASS.
- Node/shell syntax checks and `git diff --check`: PASS.

Initial lifecycle rerun was interrupted by editing the running shell test file;
the file was frozen and the complete test rerun exited zero.

Archify delivery: 9/9 showcase, no composition errors or warnings. Fixture HTML
SHA-256: 04b8520b81d040398c44c0c6486d6687791b9ddeb423cbe7557e62b6613e38cc.
Browser evidence: PASS at 1440x900, 1600x1000, 1920x1080, 2048x1320, with light/dark
endpoint captures. Chrome required sandbox escalation after initial SIGABRT.
Perceptual review: inspected largest light image; readable but excess whitespace,
so no polished final-project visual acceptance is claimed. This graph is a
three-node integration fixture, not the architecture of a completed business app.

## Boundaries and rollout

The lock pins the entire local Archify skill content (excluding node_modules,
.git and .DS_Store), version 2.17.0-dev.1. An upstream commit/release and portable
distribution are not attested. New machines and CI must supply matching contents
via ARCHIFY_HOME or the documented skill locations; missing tools block design.
The wrapper never downloads, updates, repairs or treats a different tool as valid.

Node references establish traceability, not correctness. Design review must
evaluate facts, assumptions, trust boundaries, failure and recovery. Browser
and perceptual evidence are separate from delivery validation. Repository-local
receipts and locks are not an external approval identity or trust root.

Generated HTML is not edited; source/HTML/receipt and tool lock participate in
design freshness. Tool/control changes require owner review. Existing projects
need a reviewed Harness upgrade; no silent migration or release occurred.

Obsidian 00-项目总览 and 11-Harness 2.2 与 Project Autopilot 双系统方案 were updated
with actual implementation status and unresolved deployment boundaries.
