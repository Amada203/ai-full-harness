# Lifecycle Enforcement and Controlled Evolution Implementation Plan

Status: Implemented and verified on 2026-09-01. The checkboxes below preserve
the original execution contract; completion evidence is recorded in
`docs/reviews/2026-09-01-enforcement-evolution-self-review.md`.

> **For Codex:** REQUIRED SUB-SKILL: Use executing-plans to implement this plan task by task.

**Goal:** Make lifecycle evidence tamper-evident and freshness-aware, automatically invalidate downstream approvals after upstream changes, enforce the final gate in CI, and turn retrospectives into controlled improvement proposals without allowing autonomous rule mutation.

**Architecture:** Add a deterministic, portable fingerprint layer beside the existing lifecycle state file. A dedicated recorder temporarily records a gate fingerprint, validates the complete gate through the ordinary read-only checker, and only then advances state while invalidating downstream evidence. CI always checks the fixed `github` gate, while retrospective proposals remain review-only artifacts.

**Tech Stack:** Bash 3.2+, POSIX command-line tools, GitHub Actions, Markdown templates, shell integration tests.

---

### Task 1: Specify the new generated-project contract with failing tests

**Files:**
- Modify: `tests/test-new-full-project.sh`
- Modify: `tests/test-lifecycle-gates.sh`

- [ ] Assert generated projects report harness version `2.2.0`.
- [ ] Assert `.ai/LIFECYCLE_BASELINE`, both lifecycle scripts, the improvement proposal, and the GitHub Actions workflow exist.
- [ ] Assert the generated lifecycle scripts are executable and syntactically valid.
- [ ] Add lifecycle tests proving an evidence-complete but unrecorded gate is rejected.
- [ ] Run `bash tests/test-new-full-project.sh` and `bash tests/test-lifecycle-gates.sh`; confirm the new assertions fail for the expected missing contract.

### Task 2: Implement deterministic lifecycle fingerprints

**Files:**
- Create: `templates/.ai/LIFECYCLE_BASELINE`
- Create: `templates/scripts/lifecycle-fingerprint.sh`
- Modify: `templates/scripts/check-harness.sh`

- [ ] Add one explicit fingerprint key for every lifecycle gate, initialized to `UNRECORDED`.
- [ ] Implement portable SHA-256 selection with a labeled checksum fallback.
- [ ] Define deterministic file scopes for plan, design, prototype, implementation, release, GitHub approval, and retrospective gates.
- [ ] Exclude mutable lifecycle bookkeeping, build output where inappropriate, local locks, temporary files, and retrospective proposal files from implementation scope.
- [ ] Reject filenames containing newlines instead of silently producing ambiguous manifests.
- [ ] Extend structural validation to require and syntax-check the new baseline and script.
- [ ] Run targeted fingerprint tests and syntax checks until they pass.

### Task 3: Add transactional gate recording and downstream invalidation

**Files:**
- Create: `templates/scripts/record-lifecycle-gate.sh`
- Modify: `templates/scripts/check-lifecycle-gate.sh`
- Modify: `tests/test-lifecycle-gates.sh`

- [ ] Make the read-only checker require a recorded, current fingerprint for every gate it validates.
- [ ] Implement a recorder lock that rejects concurrent recording attempts.
- [ ] Temporarily write the current fingerprint, then call the ordinary checker with no bypass mode.
- [ ] Restore baseline and state unchanged when validation fails.
- [ ] On success, advance `CURRENT_GATE`, retain the current fingerprint, reset every downstream status and fingerprint, and clear downstream approval references.
- [ ] Test successful recording, stale evidence detection, downstream reset, approval clearing, rollback, lock contention, and newline-path rejection.
- [ ] Run `bash tests/test-lifecycle-gates.sh` until all state-transition tests pass.

### Task 4: Integrate the new contract throughout generated projects

**Files:**
- Modify: `bin/new-full-project`
- Modify: `templates/PROJECT_RULES.md`
- Modify: `templates/AGENTS.md`
- Modify: `templates/CLAUDE.md`
- Modify: `templates/GEMINI.md`
- Modify: `templates/.cursor/rules/project-rules.mdc`
- Modify: `templates/.windsurf/rules/project-rules.md`
- Modify: `templates/.clinerules/project-rules.md`
- Modify: `templates/.github/copilot-instructions.md`
- Modify: `templates/docs/lifecycle/README.md`
- Modify: `rules/new-project-workflow.md`

- [ ] Copy and render the baseline in every generated project.
- [ ] Mark both lifecycle scripts executable.
- [ ] Tell every supported agent entry point to read baseline as well as state.
- [ ] Document the required `record` then `check` workflow and the fact that editing upstream inputs invalidates downstream approvals.
- [ ] Preserve `PROJECT_RULES.md` as the single source of truth.
- [ ] Run the generator integration test until it passes.

### Task 5: Add fixed CI enforcement and controlled improvement proposals

**Files:**
- Create: `templates/.github/workflows/harness-gates.yml`
- Create: `templates/docs/lifecycle/IMPROVEMENT_PROPOSAL.md`
- Modify: `templates/docs/lifecycle/RETROSPECTIVE.md`
- Modify: `templates/scripts/check-lifecycle-gate.sh`
- Modify: `templates/scripts/check-harness.sh`
- Modify: `tests/test-lifecycle-gates.sh`

- [ ] Make CI run structural validation and the fixed `github` lifecycle gate on pushes, pull requests, and manual runs.
- [ ] Ensure CI never trusts mutable `CURRENT_GATE` to select a weaker check.
- [ ] Allow retrospective completion only with either a concrete `NONE` reason or a complete `PROPOSED` improvement record in `REVIEW` state.
- [ ] Reject autonomous application or approval claims in the proposal template.
- [ ] Test both valid retrospective paths and incomplete or auto-applied proposal failures.
- [ ] Verify the workflow text explicitly invokes `check-lifecycle-gate.sh github`.

### Task 6: Update source documentation and version metadata

**Files:**
- Modify: `templates/.ai/HARNESS_VERSION`
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `templates/.ai/PROJECT_CONTEXT.md`
- Create: `docs/reviews/2026-09-01-enforcement-evolution-self-review.md`

- [ ] Bump the harness to `2.2.0`.
- [ ] Explain freshness guarantees, automatic invalidation, fixed CI enforcement, and controlled—not autonomous—self-evolution.
- [ ] State the residual controls explicitly: branch protection is external, proposals need human review, and existing projects are not silently upgraded.
- [ ] Record the second adversarial self-review and any residual risks.

### Task 7: Run full verification and adversarial checks

**Files:**
- Verify only; repair the files above if failures reveal defects.

- [ ] Run `bash tests/test-new-full-project.sh`.
- [ ] Run `bash tests/test-lifecycle-gates.sh`.
- [ ] Run `bash -n bin/new-full-project templates/scripts/*.sh tests/*.sh`.
- [ ] Run `git diff --check`.
- [ ] Scan all generated template text for unresolved placeholders.
- [ ] Run `shellcheck` if installed; otherwise record that the optional lint tool is unavailable.
- [ ] Generate one disposable project and manually verify record/check behavior through at least plan, design, and a stale-input failure.
- [ ] Do not commit, push, publish, or enable remote branch protection without explicit user approval.
