# Project Autopilot Controller Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the separate `project-autopilot` controller that can evolve project business code under a pinned Full Harness contract while failing closed on policy, security, lifecycle, or verification failures.

**Architecture:** Implement a trusted Node.js controller as a pinned GitHub Action and reusable workflow. The controller reads only the generated project's validated `.autopilot/` contract and Full Harness gates, uses a narrow GitHub token for same-repository candidate branches/PRs, and accepts a separately injected GitHub App installation token only in trusted central coordination jobs. Candidate-code execution never receives privileged credentials.

**Tech Stack:** Node.js 20, TypeScript, `@octokit/rest`, `yaml` parser with schema validation, `vitest`, GitHub Actions, deterministic fixture repositories, and npm package scripts.

---

## Scope and File Map

Create a new private repository named `project-autopilot` with these files:

- `package.json` — pinned Node/npm scripts and production dependencies.
- `tsconfig.json` — strict TypeScript compilation for Node 20.
- `action.yml` — local GitHub Action entrypoint with explicit inputs and outputs.
- `.github/workflows/ci.yml` — tests, typecheck, static workflow security checks.
- `.github/workflows/reusable-autopilot.yml` — trusted reusable workflow contract.
- `src/contracts.ts` — typed Full Harness and Autopilot data contracts.
- `src/policy/parse.ts` — safe YAML subset parser with schema errors.
- `src/policy/evaluate.ts` — L/M/H promotion and protected-path evaluator.
- `src/lifecycle/full-harness.ts` — read-only lifecycle gate invocation and result parser.
- `src/state-machine.ts` — enrollment, pause, revoke, and safe-stop transitions.
- `src/github-client.ts` — token-scoped GitHub operations behind an interface.
- `src/candidate.ts` — candidate branch, evidence, PR, and rollback-plan orchestration.
- `src/canary.ts` — canary-window and rollback-signal evaluator.
- `src/safety.ts` — constitution fingerprint, secret-boundary, and kill-switch checks.
- `src/feedback.ts` — sanitized review-only feedback emitter.
- `src/controller.ts` — observe/run entrypoint and action result summary.
- `src/index.ts` — CLI/action adapter.
- `tests/fixtures/` — valid, malformed, stale, unsafe, and L/M/H policy fixtures.
- `tests/policy.test.ts` — policy and protected-path tests.
- `tests/state-machine.test.ts` — legal and illegal transition tests.
- `tests/safety.test.ts` — constitution, secret, pinning, and safe-stop tests.
- `tests/candidate.test.ts` — fake GitHub client candidate/PR tests.
- `tests/feedback.test.ts` — sanitizer and REVIEW-only feedback tests.
- `tests/controller.test.ts` — end-to-end fixture orchestration tests.
- `scripts/check-workflow-security.mjs` — static workflow security checker.
- `scripts/build-release.mjs` — deterministic `dist/` packaging and manifest.
- `README.md` — controller contract and integration examples.

## Task 1: Bootstrap the controller repository and failing tests

**Files:**

- Create: `package.json`, `tsconfig.json`, `tests/controller.test.ts`
- Create: `tests/fixtures/valid-project/.autopilot/*`

- [ ] **Step 1: Define npm scripts and strict compiler settings.**

Use scripts named `test`, `test:watch`, `typecheck`, `build`, `lint:workflow`,
and `ci`. TypeScript must use strict mode, `noUncheckedIndexedAccess`, and
`noEmitOnError`.

- [ ] **Step 2: Add the first controller test.**

The valid fixture must run in `dryRun` mode and return a summary with
`decision: OBSERVE`, `state: OBSERVE_ONLY`, and zero GitHub mutations.

- [ ] **Step 3: Run the test and typecheck.**

Run: `npm test -- --run` and `npm run typecheck`

Expected: FAIL because controller contracts and implementation do not exist.

## Task 2: Implement safe contract parsing and policy evaluation

**Files:**

- Create: `src/contracts.ts`, `src/policy/parse.ts`, `src/policy/evaluate.ts`
- Create: `tests/policy.test.ts`, `tests/fixtures/`

- [ ] **Step 1: Define exact types.**

Use discriminated unions with these exact members:

```text
RiskLevel = 'L' | 'M' | 'H'
PromotionLane = 'observe_only' | 'candidate_pr' | 'canary' | 'auto_merge'
AutopilotState = 'NEW' | 'STAGE0_PASSED' | 'GITHUB_CONNECTED' | 'REGISTERED' |
                 'OBSERVE_ONLY' | 'ACTIVE' | 'PAUSED' | 'REVOKED' | 'SAFE_STOP'
```

- [ ] **Step 2: Parse the generated YAML subset without executing values.**

Reject duplicate keys, unknown keys, anchors, custom tags, executable strings,
missing schema versions, invalid booleans, and malformed path lists. Return a
typed error containing file, key, and reason.

- [ ] **Step 3: Implement promotion evaluation.**

Return a decision object with `action`, `requiresHumanApproval`, `reason`, and
`touchedProtectedPath`. Enforce: unknown risk becomes H; H never auto-promotes;
policy changes are H; protected paths always require human review; disabled or
observe-only projects never mutate GitHub.

- [ ] **Step 4: Add policy fixtures and tests.**

Cover valid disabled, valid L, valid M, valid H, unknown risk, automatic-H,
protected-path overlap, missing tests, duplicate keys, and malicious scalar
values.

- [ ] **Step 5: Run focused tests.**

Run: `npm test -- policy.test.ts`

Expected: all policy tests pass.

## Task 3: Implement lifecycle, state, and safety gates

**Files:**

- Create: `src/lifecycle/full-harness.ts`, `src/state-machine.ts`, `src/safety.ts`
- Create: `tests/state-machine.test.ts`, `tests/safety.test.ts`

- [ ] **Step 1: Wrap the Full Harness read-only gate.**

Execute only the project-provided `scripts/check-harness.sh`,
`scripts/check-lifecycle-gate.sh plan`, and
`scripts/check-autopilot-contract.sh` with an argument array and a fixed working
directory. Never source `.ai/` or `.autopilot/` files. Convert non-zero exits to
structured failures without attempting repair.

- [ ] **Step 2: Implement the exact state transition table.**

Allow only the transitions documented by the Full Harness contract. Require an
owner reason for `ACTIVE`, `REVOKED`, and recovery from `SAFE_STOP`; reject all
skips, reversals, duplicate transitions, and disabled-to-active requests.

- [ ] **Step 3: Verify constitution and controller pins.**

Require the constitution fingerprint to match the controller's expected digest,
the controller ref to be a full 40-character SHA, and the project policy to be
unchanged since the last accepted fingerprint. Fail before any GitHub write.

- [ ] **Step 4: Add pause/revoke and repeated-failure handling.**

Read a protected pause/revoke signal at job start and before each external
operation. Three consecutive policy, lifecycle, or verification failures enter
`SAFE_STOP`; recovery records a reason and requires an owner action.

- [ ] **Step 5: Test all gates.**

Cover stale gates, malformed control data, constitution tampering, unpinned
refs, pause/revoke, all invalid transitions, and safe-stop recovery.

- [ ] **Step 6: Run focused tests.**

Run: `npm test -- state-machine.test.ts safety.test.ts`

Expected: all lifecycle and safety tests pass.

## Task 4: Implement candidate branch and PR orchestration

**Files:**

- Create: `src/github-client.ts`, `src/candidate.ts`
- Create: `tests/candidate.test.ts`

- [ ] **Step 1: Define a narrow GitHub client interface.**

Expose only `createBranch`, `createCommit`, `openPullRequest`, `addLabels`,
`addComment`, `requestChecks`, and `readRepositoryMetadata`. Do not expose
branch-protection, secret-read, permission-write, or self-approval methods.

- [ ] **Step 2: Implement a fake client for tests.**

Record every attempted operation, reject a default-branch write, reject a
self-approval call, and allow assertions on branch name, PR body, labels, and
rollback evidence.

- [ ] **Step 3: Implement candidate creation.**

Create a deterministic branch name from project slug, objective digest, and run
id. Write only business-code candidate changes and generated evidence files;
reject `.autopilot/`, `.ai/`, workflow, CODEOWNERS, deployment, and secret path
changes. Open a PR with risk, changed paths, smoke result, adversarial result,
rollback plan, and controller SHA.

- [ ] **Step 4: Implement dry-run behavior.**

`dryRun=true` produces the full decision and proposed PR body but performs zero
GitHub mutations. Observe-only and H-lane modes always use dry-run semantics.

- [ ] **Step 5: Test candidate restrictions.**

Cover L candidate PR, M candidate PR, H plan-only, protected-path rejection,
default-branch rejection, self-approval rejection, duplicate run idempotency,
and dry-run zero-mutation behavior.

- [ ] **Step 6: Run focused tests.**

Run: `npm test -- candidate.test.ts`

Expected: all candidate tests pass.

## Task 5: Implement canary, rollback, and promotion decisions

**Files:**

- Create: `src/canary.ts`
- Modify: `src/policy/evaluate.ts`, `src/candidate.ts`
- Create: `tests/fixtures/canary/`, `tests/controller.test.ts`

- [ ] **Step 1: Define canary input and output schemas.**

Inputs must include baseline metric, candidate metric, minimum observation count,
maximum error rate, rollback threshold, and window expiry. Outputs must be one
of `PASS`, `ROLLBACK`, or `INCONCLUSIVE` with observed values and reason.

- [ ] **Step 2: Implement fail-closed canary evaluation.**

Never promote on missing, stale, contradictory, or insufficient metrics. A
rollback signal wins over a promotion signal. An inconclusive M canary returns
to `PAUSED` and creates no merge action.

- [ ] **Step 3: Enforce L/M/H promotion lanes.**

L may request auto-merge only after all required checks pass and the policy
explicitly enables it. M may request promotion only after a PASS canary and
explicit policy opt-in. H always returns `requiresHumanApproval=true`.

- [ ] **Step 4: Test promotion and rollback.**

Cover successful L, successful M, failed M rollback, insufficient metrics,
missing metric, contradictory metric, H human approval, and unknown-risk H.

- [ ] **Step 5: Run focused tests.**

Run: `npm test -- controller.test.ts`

Expected: all promotion and rollback tests pass.

## Task 6: Implement sanitized feedback and Harness-upgrade boundaries

**Files:**

- Create: `src/feedback.ts`, `tests/feedback.test.ts`
- Modify: `src/controller.ts`

- [ ] **Step 1: Define review-only feedback schema.**

Required fields are `project_id`, `controller_sha`, `observed_failure`,
`violated_invariant`, `proposed_test`, `risk`, and `decision: REVIEW`. Reject
`APPLIED`, `APPROVED`, credentials, tokens, personal data, customer data,
security exploit details, arbitrary source snippets, and unbounded logs.

- [ ] **Step 2: Implement sanitizer.**

Redact common secret forms, truncate fields to fixed limits, normalize newlines,
and reject rather than guess when a sensitive classification is uncertain.

- [ ] **Step 3: Implement Harness-upgrade handling.**

Accept only a signed/validated central manifest with compatibility range,
migration path, affected Harness-controlled paths, and rollback reference.
Create a review notification/preview instruction; never modify business code,
project policy, secrets, history, or the default branch.

- [ ] **Step 4: Test feedback and upgrade rejection.**

Cover sanitized REVIEW feedback, sensitive feedback requiring confirmation,
attempted self-approval, applied decision, secret payload, malformed manifest,
incompatible version, and business-path migration.

- [ ] **Step 5: Run focused tests.**

Run: `npm test -- feedback.test.ts`

Expected: all feedback and upgrade-boundary tests pass.

## Task 7: Wire the action and reusable workflow

**Files:**

- Create: `src/index.ts`, `action.yml`, `.github/workflows/reusable-autopilot.yml`
- Modify: `src/controller.ts`
- Test: `tests/controller.test.ts`

- [ ] **Step 1: Define action inputs and outputs.**

Inputs are `mode`, `project-directory`, `policy-path`, `dry-run`, and
`repository-token`. Outputs are `decision`, `state`, `pr-number`,
`requires-human-approval`, and `failure-reason`. Never define an input that
accepts a private key or raw organization credential in a project-local job.

- [ ] **Step 2: Use explicit workflow permissions.**

The reusable workflow must declare minimum permissions, reject
`pull_request_target`, use a pinned controller ref, avoid `secrets: inherit`,
and separate validation/candidate jobs from any protected deployment job.

- [ ] **Step 3: Implement trusted checkout boundaries.**

Controller code runs from its pinned release. Validation may inspect candidate
files without privileged credentials. Candidate project code receives no App
private key, no central token, and no production secret.

- [ ] **Step 4: Add workflow static checks.**

Implement `scripts/check-workflow-security.mjs` to reject unpinned actions,
write-all permissions, default-branch pushes, self-approval, untrusted checkout
with secrets, and secret interpolation into candidate commands.

- [ ] **Step 5: Run action and workflow tests.**

Run: `npm run typecheck && npm test && npm run lint:workflow`

Expected: PASS with no live GitHub credentials.

## Task 8: Build, pin, publish, and pilot (owner-authorized external steps)

**Files:**

- Create: `scripts/build-release.mjs`, `README.md`, `.github/workflows/ci.yml`
- Modify: `package.json`

- [ ] **Step 1: Build a deterministic release artifact.**

Compile to `dist/`, include a manifest with controller version, commit SHA,
constitution schema version, supported Harness range, and rollback reference.
Fail the build if generated files contain unresolved template markers or if the
workflow security checker fails.

- [ ] **Step 2: Add continuous integration.**

Run typecheck, unit tests, fixture tests, static workflow checks, and build on
every push and pull request with read-only permissions.

- [ ] **Step 3: Prepare private GitHub configuration.**

An owner must create the private `Amada203/project-autopilot` repository, register
the GitHub App, install it only on selected repositories, store the App private
key in a protected central secret, enable Actions access to the private
controller, configure required checks, and create protected deployment
environments. The plan does not automate these account mutations.

- [ ] **Step 4: Publish a pinned release.**

Tag and publish a release only after CI passes. Record the full commit SHA in
the Full Harness template and regenerate a disposable pilot project so the
generated workflow never references a mutable branch or tag.

- [ ] **Step 5: Exercise the pilot project.**

Use a disposable repository to test Stage 0 enrollment, observation-only mode,
L/M/H fixtures, protected-path rejection, pause/revoke, safe-stop recovery,
Harness-upgrade notification, sanitized feedback, and rollback. Preserve the
run summaries as evidence before enabling any non-dry-run lane.

## Completion Criteria

- The controller cannot mutate a project before Full Harness and Autopilot
  contract validation passes.
- Constitution, policy, state, and controller pins are checked before every
  external operation.
- L/M/H behavior matches the policy table; H and unknown risk never auto-promote.
- Candidate jobs never receive privileged credentials or production secrets.
- Every mutation is a candidate branch/PR operation with evidence and rollback.
- Feedback and Harness upgrades remain review-only and cannot self-approve.
- Safe-stop, pause, revoke, and rollback are tested without a live GitHub account.
- The published controller is referenced by full commit SHA in generated projects.
