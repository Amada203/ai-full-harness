# Full Harness Autopilot Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a fail-closed, owner-controlled Autopilot enrollment contract to `ai-full-harness` without silently changing existing projects or granting external authority.

**Architecture:** Extend the existing Bash 3.2-compatible generator with a data-only `.autopilot/` contract, a read-only validator, a transactional state-transition command, and GitHub workflow templates that verify enrollment. Keep cross-repository controller execution behind an explicit pinned-controller contract; this repository will not create GitHub Apps, secrets, branch rules, or remote releases.

**Tech Stack:** POSIX/Bash 3.2-compatible shell, Markdown, YAML-like data files validated without sourcing, GitHub Actions workflow YAML, existing lifecycle fingerprint/gate scripts, shell fixture tests.

---

## Scope and File Map

This plan covers only the Full Harness contract in the current repository. The
future `project-autopilot` controller and the GitHub-account configuration have
their own plan so their implementation can be tested independently.

Files to create:

- `templates/.autopilot/CONSTITUTION.yml` — generated non-negotiable rules.
- `templates/.autopilot/ENROLLMENT.yml` — generated owner opt-in and controller reference.
- `templates/.autopilot/POLICY.yml` — generated risk and promotion policy.
- `templates/.autopilot/OBJECTIVES.md` — generated business objective contract.
- `templates/.autopilot/PROTECTED_PATHS.yml` — generated deny-by-default paths.
- `templates/.autopilot/AUTOPILOT_STATE` — generated state machine record.
- `templates/scripts/autopilot-fingerprint.sh` — deterministic contract fingerprint.
- `templates/scripts/check-autopilot-contract.sh` — read-only contract validator.
- `templates/scripts/transition-autopilot.sh` — locked, transactional state transition.
- `templates/.github/workflows/autopilot-enrollment.yml` — enrollment health check.
- `templates/.github/workflows/autopilot-upgrade-receiver.yml` — review-only Harness upgrade receiver.
- `templates/docs/autopilot/README.md` — human setup and state explanation.
- `templates/docs/autopilot/FEEDBACK.md` — sanitized feedback contract.
- `tests/test-autopilot-contract.sh` — positive and negative contract fixtures.
- `tests/test-autopilot-workflow-static.sh` — workflow permission and pinning checks.

Files to modify:

- `bin/new-full-project` — add `--autopilot disabled|enabled` and substitute its explicit defaults.
- `templates/scripts/check-harness.sh` — require the new Autopilot files and executable scripts.
- `templates/AGENTS.md`, `templates/CLAUDE.md`, `templates/GEMINI.md`, and `.cursor/rules/project-lifecycle.mdc` — point agents to the Autopilot contract without making it executable input.
- `README.md` — document the opt-in flow and the GitHub App boundary.
- `CHANGELOG.md` — record the next generated-harness version.
- `tests/test-new-full-project.sh` — assert the generated contract and default disabled state.

## Task 1: Add failing contract fixtures

**Files:**

- Create: `tests/test-autopilot-contract.sh`
- Create: `tests/test-autopilot-workflow-static.sh`
- Modify: `tests/test-new-full-project.sh`

- [ ] **Step 1: Write the fresh-project assertions.**

The test must create a temporary project with the existing generator and assert
that every file in the file map exists, every validator is executable, and the
default state contains `AUTOPILOT_ENABLED=false` and `STATE=NEW`.

```bash
assert_file "$PROJECT_DIR/.autopilot/CONSTITUTION.yml"
assert_file "$PROJECT_DIR/.autopilot/ENROLLMENT.yml"
assert_file "$PROJECT_DIR/.autopilot/POLICY.yml"
assert_file "$PROJECT_DIR/.autopilot/OBJECTIVES.md"
assert_file "$PROJECT_DIR/.autopilot/PROTECTED_PATHS.yml"
assert_file "$PROJECT_DIR/.autopilot/AUTOPILOT_STATE"
assert_executable "$PROJECT_DIR/scripts/autopilot-fingerprint.sh"
assert_executable "$PROJECT_DIR/scripts/check-autopilot-contract.sh"
assert_executable "$PROJECT_DIR/scripts/transition-autopilot.sh"
grep -Fqx 'AUTOPILOT_ENABLED=false' "$PROJECT_DIR/.autopilot/AUTOPILOT_STATE"
grep -Fqx 'STATE=NEW' "$PROJECT_DIR/.autopilot/AUTOPILOT_STATE"
```

- [ ] **Step 2: Add negative fixtures before implementation.**

The test must prove that the contract rejects malformed state, a changed
constitution fingerprint, an unknown risk, a protected-path request, a missing
Stage 0 fingerprint, a reverse transition, and an unpinned controller ref.

- [ ] **Step 3: Run the focused tests and confirm they fail for missing files or commands.**

Run: `bash tests/test-autopilot-contract.sh`

Expected: FAIL because the generator, validator, and templates do not yet
provide the Autopilot contract.

- [ ] **Step 4: Add static workflow expectations.**

The workflow test must reject `permissions: write-all`, `pull_request_target`,
unqualified remote `uses:` references, `git push origin main`, and any step that
passes `${{ secrets.* }}` into a candidate-code execution step. It must accept
explicit minimum permissions and full-SHA controller refs.

- [ ] **Step 5: Re-run the focused tests and preserve the failing baseline.**

Run: `bash tests/test-autopilot-workflow-static.sh`

Expected: FAIL until the generated workflows and static checker are present.

## Task 2: Define the generated data contract

**Files:**

- Create: `templates/.autopilot/CONSTITUTION.yml`
- Create: `templates/.autopilot/ENROLLMENT.yml`
- Create: `templates/.autopilot/POLICY.yml`
- Create: `templates/.autopilot/OBJECTIVES.md`
- Create: `templates/.autopilot/PROTECTED_PATHS.yml`
- Create: `templates/.autopilot/AUTOPILOT_STATE`

- [ ] **Step 1: Add the immutable constitution template.**

Use a flat, non-executable YAML subset with explicit values:

```yaml
schema_version: 1
direct_default_branch_write: false
self_approve_pull_request: false
modify_autopilot_contract: false
modify_harness_controls: false
read_or_export_secrets: false
run_candidate_code_with_secrets: false
auto_promote_high_risk: false
```

- [ ] **Step 2: Add the enrollment template.**

The generator substitutes `{{AUTOPILOT_ENABLED}}`,
`{{AUTOPILOT_CONTROLLER_REF}}`, and `{{AUTOPILOT_AUTO_ACTIVATE}}`; the default
controller ref is `UNCONFIGURED`, which is valid only while enrollment is
disabled. Enabling Autopilot requires an explicit full 40-character controller
SHA through `--autopilot-controller-ref`.

```yaml
schema_version: 1
autopilot_enabled: {{AUTOPILOT_ENABLED}}
controller_repository: Amada203/project-autopilot
controller_ref: {{AUTOPILOT_CONTROLLER_REF}}
auto_activate_after_stage0: {{AUTOPILOT_AUTO_ACTIVATE}}
requested_by: owner
```

- [ ] **Step 3: Add the default policy and objective templates.**

The policy must default to risk `M`, observation-only behavior, no automatic
merge, no production deployment, and no external data source. It must include
the exact keys `risk_level`, `promotion_lane`, `auto_merge_l`,
`auto_promote_m`, `production_deploy`, `daily_budget`, and
`approved_test_commands`.

```yaml
schema_version: 1
risk_level: M
promotion_lane: observe_only
auto_merge_l: false
auto_promote_m: false
production_deploy: false
daily_budget: 0
approved_test_commands: []
allowed_paths: []
```

`OBJECTIVES.md` must keep the existing required-marker convention and state
that no objective is approved until Stage 0 is completed.

- [ ] **Step 4: Add protected paths and initial state.**

Protected paths must include `.autopilot/`, `.ai/`, `.github/workflows/`,
`CODEOWNERS`, deployment configuration, and secret/configuration files. The
state must use key/value data only and never be sourced:

```text
SCHEMA_VERSION=1
STATE=NEW
AUTOPILOT_ENABLED={{AUTOPILOT_ENABLED}}
CONSTITUTION_FINGERPRINT=UNRECORDED
POLICY_FINGERPRINT=UNRECORDED
CONSECUTIVE_FAILURES=0
LAST_REASON=Initial generated state.
```

- [ ] **Step 5: Run the generator test.**

Run: `bash tests/test-new-full-project.sh`

Expected: the new file assertions still fail only because generator copying and
variable substitution have not been wired yet.

## Task 3: Implement deterministic contract fingerprinting

**Files:**

- Create: `templates/scripts/autopilot-fingerprint.sh`
- Test: `tests/test-autopilot-contract.sh`

- [ ] **Step 1: Define the command interface.**

`autopilot-fingerprint.sh constitution`, `policy`, or `contract` must print one
algorithm-prefixed digest and exit non-zero for unknown targets, missing files,
symlinked control files, newline-containing paths, or malformed key names.

- [ ] **Step 2: Reuse the existing hash fallback order.**

Use `shasum -a 256`, then `sha256sum`, then OpenSSL, then the existing labeled
`cksum` fallback. Hash path names and bytes in deterministic sorted order. Never
follow project symlinks.

- [ ] **Step 3: Add fingerprint assertions.**

The test must record a contract fingerprint, change one constitution value, and
assert that the fingerprint changes. It must create a symlink to an external
file and assert that the command exits non-zero without reading the target.

- [ ] **Step 4: Run the focused test.**

Run: `bash tests/test-autopilot-contract.sh`

Expected: fingerprint tests pass; validator and transition tests remain red.

## Task 4: Implement the fail-closed contract validator

**Files:**

- Create: `templates/scripts/check-autopilot-contract.sh`
- Modify: `templates/scripts/check-harness.sh`
- Test: `tests/test-autopilot-contract.sh`

- [ ] **Step 1: Validate data without sourcing it.**

The validator must parse only the supported flat keys, reject duplicates,
unknown keys, shell metacharacters in values, invalid booleans, invalid risk
levels, invalid states, and controller refs that are not full 40-character
hexadecimal SHAs when enrollment is enabled.

- [ ] **Step 2: Validate the immutable constitution.**

Reject any constitution value that differs from the required non-negotiables:
all seven forbidden capabilities must remain `false`.

- [ ] **Step 3: Validate policy and protected paths.**

Allow only `L`, `M`, or `H`; map unknown/missing risk to failure; require
`observe_only` when disabled; reject automatic H promotion; reject any allowed
path that overlaps a protected path; and require a non-empty approved test
command list before active operation.

- [ ] **Step 4: Validate lifecycle prerequisites.**

When enabled, call the existing read-only
`scripts/check-lifecycle-gate.sh plan`. Do not mutate lifecycle state. Reject
activation if the plan gate is blocked, missing, unrecorded, or stale.

- [ ] **Step 5: Validate state and fingerprints.**

Require legal state values, current constitution/policy fingerprints, and
`STATE=NEW` or `STATE=STAGE0_PASSED` while the plan gate is not complete. A
changed contract must fail closed before any controller workflow can proceed.

- [ ] **Step 6: Extend structural validation.**

Add the six `.autopilot/` files and three scripts to the required generated
file list in `templates/scripts/check-harness.sh`; keep the structural checker
agnostic to project policy content.

- [ ] **Step 7: Run positive and negative validator fixtures.**

Run: `bash tests/test-autopilot-contract.sh`

Expected: malformed, stale, unsafe, and unpinned configurations fail with a
short reason; a fresh disabled configuration passes structural validation but
does not enter `ACTIVE`.

## Task 5: Implement transactional enrollment state transitions

**Files:**

- Create: `templates/scripts/transition-autopilot.sh`
- Test: `tests/test-autopilot-contract.sh`

- [ ] **Step 1: Define the legal transition table.**

Implement exactly these transitions:

```text
NEW -> STAGE0_PASSED -> GITHUB_CONNECTED -> REGISTERED -> OBSERVE_ONLY -> ACTIVE
ACTIVE -> PAUSED | REVOKED | SAFE_STOP
PAUSED -> ACTIVE | REVOKED
SAFE_STOP -> PAUSED | REVOKED
```

Any skipped, reversed, duplicate, unknown, or disabled-to-active transition
must fail.

- [ ] **Step 2: Add a project-local lock and atomic update.**

Acquire `.autopilot/.transition.lock`, copy the state to a temporary backup,
validate the requested transition and current fingerprints, write the new state
to a temporary file, then atomically rename it. Restore the backup on any
failure and release the lock with a trap.

- [ ] **Step 3: Require explicit reasons for privileged transitions.**

`GITHUB_CONNECTED`, `REGISTERED`, `ACTIVE`, `REVOKED`, and recovery from
`SAFE_STOP` require a non-empty one-line reason. The script must record the
reason and UTC timestamp as data, not executable input.

- [ ] **Step 4: Exercise transition fixtures.**

Test successful forward transitions, every invalid transition, concurrent lock
contention, rollback after a simulated failed write, and automatic
`SAFE_STOP` after three recorded failures.

- [ ] **Step 5: Run the focused test.**

Run: `bash tests/test-autopilot-contract.sh`

Expected: all state-machine tests pass and no state mutation occurs on failure.

## Task 6: Add generator opt-in and workflow templates

**Files:**

- Modify: `bin/new-full-project`
- Create: `templates/.github/workflows/autopilot-enrollment.yml`
- Create: `templates/.github/workflows/autopilot-upgrade-receiver.yml`
- Modify: `tests/test-new-full-project.sh`
- Test: `tests/test-autopilot-workflow-static.sh`

- [ ] **Step 1: Add an explicit generator option.**

Support `--autopilot disabled|enabled` and
`--autopilot-controller-ref <40-hex-sha>`; reject other values. Keep the
default `disabled` so an ordinary project cannot silently grant autonomous
authority. When enabled, require the controller ref, set
`AUTOPILOT_ENABLED=true` and `AUTOPILOT_AUTO_ACTIVATE=true`; when disabled,
use `UNCONFIGURED` and `AUTOPILOT_AUTO_ACTIVATE=false`.

- [ ] **Step 2: Set executable bits for all generated scripts.**

Extend the existing chmod block for the three Autopilot scripts. Keep Git
initialization behavior unchanged.

- [ ] **Step 3: Add the enrollment workflow.**

Trigger on pushes, pull requests, and manual dispatch. Use explicit read-only
permissions for validation, run `scripts/check-harness.sh`,
`scripts/check-lifecycle-gate.sh plan`, and
`scripts/check-autopilot-contract.sh`. It must never checkout a candidate PR
with secrets and must never push or merge.

- [ ] **Step 4: Add the upgrade receiver workflow.**

Trigger only on a manual dispatch or a controlled `repository_dispatch` event
with a fixed event type. Validate the received Harness manifest, create a
review-only artifact/branch instruction, and stop before changing business
code, policy, secrets, or the default branch. The workflow must not assume that
the GitHub App is installed.

- [ ] **Step 5: Add workflow static checks.**

Implement the assertions from Task 1 and run:

```bash
bash tests/test-autopilot-workflow-static.sh
```

Expected: generated workflows pass minimum-permission, no-untrusted-secret,
no-direct-default-branch, and pinning checks.

## Task 7: Add operator-facing documentation and agent pointers

**Files:**

- Create: `templates/docs/autopilot/README.md`
- Create: `templates/docs/autopilot/FEEDBACK.md`
- Modify: `templates/AGENTS.md`
- Modify: `templates/CLAUDE.md`
- Modify: `templates/GEMINI.md`
- Modify: `templates/.cursor/rules/project-lifecycle.mdc`
- Modify: `README.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Document the one-time enrollment flow.**

Explain in plain language: choose `--autopilot enabled`, complete Stage 0,
push to GitHub, install the GitHub App for selected repositories if central
coordination is enabled, and let the enrollment workflow validate the project.
State explicitly that the App is not downloaded to a computer.

- [ ] **Step 2: Document manual boundaries.**

List only the actions that remain manual: App authorization, initial secrets,
policy/permission changes, H-lane releases, and recovery from `SAFE_STOP`.
Explain that ordinary L/M candidate work is automated only after policy opt-in.

- [ ] **Step 3: Document feedback and Harness upgrades.**

Specify sanitized feedback fields, `REVIEW` status, no self-approval, and the
preview-PR path for Harness upgrades. Make clear that upgrades do not directly
modify business code.

- [ ] **Step 4: Update agent pointers.**

Add a startup instruction to run the read-only Autopilot validator when the
project contains `.autopilot/`; never tell agents to source any `.autopilot/`
file or treat a project request as permission to change its policy.

- [ ] **Step 5: Update the version and changelog.**

Increment the generated Harness version only after all tests pass. Record that
existing projects are not silently modified and require a reviewed migrator.

## Task 8: Full verification and handoff

**Files:**

- Test: `tests/test-new-full-project.sh`
- Test: `tests/test-lifecycle-gates.sh`
- Test: `tests/test-autopilot-contract.sh`
- Test: `tests/test-autopilot-workflow-static.sh`

- [ ] **Step 1: Run focused tests.**

```bash
bash tests/test-autopilot-contract.sh
bash tests/test-autopilot-workflow-static.sh
```

Expected: PASS.

- [ ] **Step 2: Run existing regression tests.**

```bash
bash tests/test-new-full-project.sh
bash tests/test-lifecycle-gates.sh
```

Expected: PASS with no change to existing lifecycle semantics.

- [ ] **Step 3: Run shell syntax and whitespace checks.**

```bash
bash -n bin/new-full-project bin/install-ai-full-harness templates/scripts/*.sh tests/*.sh
git diff --check
```

Expected: no syntax errors and no whitespace errors. If `shellcheck` is
available, run it against changed shell files; do not add a formatter.

- [ ] **Step 4: Perform the adversarial contract audit.**

Verify manually that a project cannot activate from a changed constitution,
stale Stage 0, unknown risk, unpinned controller, protected-path request,
malformed state, or failed transition; that workflow permissions do not expose
secrets to candidate code; and that no template references a nonexistent
remote controller as an executable dependency.

- [ ] **Step 5: Report the external setup boundary.**

Hand off the exact future GitHub actions separately: create the private
`project-autopilot` repository, register/install the GitHub App, add protected
secrets, enable required checks and environments, and publish a pinned
controller release. Do not perform any of those account mutations in this
local plan.

## Completion Criteria

- Every generated project contains a complete, disabled-by-default Autopilot
  contract and passes structural validation.
- Explicit opt-in cannot bypass a fresh Full Harness Stage 0 gate.
- State transitions are finite, locked, transactional, and fail closed.
- The constitution, policy, protected paths, and controller reference are
  fingerprinted and validated without sourcing user data.
- Enrollment and upgrade receiver workflows are read-only/review-only and have
  explicit minimum permissions.
- Existing Full Harness lifecycle and generation tests remain green.
- No commit, push, GitHub App installation, secret creation, branch-protection
  change, deployment, or remote release is performed automatically.
