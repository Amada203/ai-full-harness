# Project Autopilot Platform Design

## Decision

Build a two-repository, GitHub-native autonomous-delivery platform:

1. `ai-full-harness` remains the central policy, lifecycle, versioning,
   upgrade-notification, and feedback-governance repository.
2. `project-autopilot` is a separate central repository containing the pinned,
   reusable automation that observes a specific project and proposes, tests,
   canaries, promotes, or rolls back business-code changes under that project's
   approved policy.

A generated project is a consumer of both systems, not a third platform. It
does not clone either controller repository in normal use. GitHub Actions
retrieves a pinned Autopilot release and runs the project-local workflows in
GitHub-hosted runners.

The initial delivery is an integration foundation in `ai-full-harness` plus a
separate `project-autopilot` repository. Creating the GitHub App, configuring
its private key, granting repository access, creating private remote
repositories, adding secrets, enabling branch protection, and publishing a
release are external administrator actions and are explicitly out of scope for
an unattended local implementation.

## First-Principles Model

The desired outcome is not simply "an AI that edits code automatically." It is
a system that can make bounded progress without obtaining unlimited authority.

The governing invariants are:

1. A project owner, not project content, grants write and release authority.
2. The Autopilot cannot enlarge its own authority, policy, scope, credentials,
   or protected-path list.
3. A candidate change is distinct from a merged change, a production release,
   and a Harness upgrade.
4. No ordinary autonomous action can write directly to the default branch.
5. Autonomous validation must not execute untrusted candidate code while
   privileged credentials are present.
6. A failed check, missing policy, unknown risk, stale lifecycle evidence, or
   unavailable controller fails closed.
7. A project can report a potential Harness defect, but it cannot modify or
   publish the Harness itself.

"Immutable" means immutable to the Autopilot identity and its normal project
workflows. A GitHub organization or repository administrator remains the root
authority and can revoke the App, alter a branch rule, or disable automation;
no repository-only design can honestly prevent its administrator from doing so.

## Architecture

```text
ai-full-harness (private central repository)
  ├─ generator and lifecycle gates
  ├─ immutable-policy schema and generated templates
  ├─ Harness release manifest and migration descriptions
  ├─ Upgrade Broker: detects compatible enrolled projects and opens upgrade PRs
  └─ Feedback Inbox: receives sanitized, review-only improvement proposals
                   │
                   │ GitHub App installation token, repository-scoped
                   ▼
Project A (generated consumer repository)
  ├─ .ai/ lifecycle evidence and Harness version
  ├─ .autopilot/ owner-approved enrollment and policy
  ├─ project-local enrollment, observation, and upgrade-receiver workflows
  └─ business code, tests, and protected deployment environments
                   ▲
                   │ pinned reusable workflow/action; ordinary project token
                   │
project-autopilot (private central repository)
  ├─ controller and policy validator
  ├─ candidate-branch / PR / canary / rollback automation
  ├─ autonomy-state evaluator
  └─ feedback emitter
```

`ai-full-harness` and `project-autopilot` version independently. A project
pins both versions by immutable release reference (a full commit SHA in GitHub
workflow `uses:` statements), records them in its state files, and receives
notifications when a compatible newer version is available. A Harness upgrade
only updates Harness-controlled files through a dedicated preview branch or
PR; it never rewrites business code or project-specific policy.

## GitHub Identities and Deployment

### GitHub App

The GitHub App is a GitHub-hosted, repository-scoped machine identity, not an
application a developer downloads or installs on a computer. It is used only
where the central systems need to discover or write across private project
repositories, such as creating a Harness-upgrade PR or receiving feedback.

It must be installed by the account or organization administrator with **Only
select repositories** selected. Its permissions are deliberately minimal:

- repository contents: read/write only for creating a non-default branch;
- pull requests and issues: read/write;
- checks/statuses and metadata: read;
- no administration, organization administration, Actions-secret read, or
  branch-protection bypass permission.

The App creates a short-lived installation token during a workflow run. Its
private key is kept only as a protected central GitHub secret. It is never
committed into a project, printed, or passed to untrusted project code.

Project-local Autopilot workflows use the repository's built-in `GITHUB_TOKEN`
for same-repository operations, with explicit minimum `permissions:`. The App
is therefore not a prerequisite for local observation or candidate PR creation;
it is the recommended cross-private-repository identity for central upgrade and
feedback coordination.

### No Persistent Server in Phase 1

GitHub-hosted Actions run the initial service. The Upgrade Broker performs
scheduled discovery as a reliable fallback; immediate repository notifications
may be added later through a webhook service, but a webhook endpoint is not
needed for the first release. A self-hosted runner is unnecessary unless a
project must reach an internal network, local database, special hardware, or
other resource GitHub-hosted runners cannot access.

## Generated Project Contract

Every newly generated project receives these owner-controlled data files:

```text
.autopilot/
  CONSTITUTION.yml
  ENROLLMENT.yml
  POLICY.yml
  OBJECTIVES.md
  PROTECTED_PATHS.yml
  AUTOPILOT_STATE
```

They are data, never sourced or executed. The generator validates their schema
and creates the project in a disabled-but-complete state.

### Constitution: immutable to the Autopilot

`CONSTITUTION.yml` supplies fixed non-negotiables. Its fingerprint is compiled
into the pinned Autopilot release and is verified before every action. The
Autopilot refuses to run if the file differs, is malformed, or asks it to:

- push or merge directly to the default branch;
- approve its own PR;
- alter `.autopilot/`, `.ai/`, GitHub workflow, access-control, deployment,
  secret, or protected-path files;
- modify branch protection, GitHub App installation, or permissions;
- use secrets while executing code fetched from a candidate branch;
- automatically merge or deploy high-risk work.

The generated repository also places those files under `CODEOWNERS` and
required-check recommendations. This does not replace GitHub branch protection;
the setup guide makes enabling protected branches a required administrator
step.

### Project policy: explicit, reviewable delegation

`POLICY.yml` holds the project owner's choices, including allowed source paths,
risk classification rules, approved test commands, canary and rollback checks,
daily time/cost budget, trusted data sources, and the escalation destination.
`OBJECTIVES.md` is the human-readable business objective and success metric.
`PROTECTED_PATHS.yml` is a deny-by-default list with explicit allowed paths.

The policy has three bounded promotion lanes:

| Lane | Autopilot action after required checks pass |
| --- | --- |
| L | Open a candidate PR; auto-merge only when the project has explicitly enabled it, every required check passes, and no protected path is touched. |
| M | Open a candidate PR, then run the defined canary and rollback-signal window; promotion is automatic only if the project policy explicitly allows this lane. |
| H | Analyse and prepare a PR/canary plan only. A named human approval and protected deployment environment are always required before merge or production release. |

Unknown risk is H. A policy change is never considered an L or M change.

### Enrollment state machine

`AUTOPILOT_STATE` is data with these legal transitions:

```text
NEW -> STAGE0_PASSED -> GITHUB_CONNECTED -> REGISTERED
    -> OBSERVE_ONLY -> ACTIVE
ACTIVE -> PAUSED | REVOKED | SAFE_STOP
PAUSED -> ACTIVE | REVOKED
SAFE_STOP -> PAUSED | REVOKED
```

The normal new-project path is intentionally low-touch:

1. The creator explicitly chooses `autopilot: enabled` in the new-project
   generator and completes the existing Stage 0 evidence.
2. The initial commit is pushed to the project's GitHub repository. The
   generated enrollment workflow validates the Harness, Stage 0 fingerprint,
   constitution, policy, and no-secret configuration.
3. If the GitHub App is installed for that selected repository, the central
   Broker discovers the valid enrollment and records `REGISTERED`.
4. A successful health check moves the project through `OBSERVE_ONLY` to
   `ACTIVE` automatically when `auto_activate_after_stage0: true` is in the
   owner-approved initial policy. Otherwise it stays in observation mode.

For a brand-new project, the initial generated commit is the reviewable policy
approval. No separate Bootstrap PR or activation click is required after the
owner has explicitly enabled Autopilot. A Bootstrap PR remains available for
adopting Autopilot into an existing project, or when the owner chooses manual
activation.

The unavoidable human actions are intentionally narrow:

1. an account/organization administrator creates and installs the GitHub App,
   selecting the repositories it may access;
2. a project owner chooses to enable Autopilot and commits the initial policy;
3. an owner configures any genuinely required API/deployment credentials;
4. a human approves H-lane changes, policy/permission changes, and production
   actions protected by the repository's release environment.

The first action is a GitHub permission grant, not a local installation. It is
normally needed once per project when the App is installed for selected
repositories; selecting all repositories is technically possible but not the
recommended default because it over-broadens authority.

## Autonomous Operation

In `ACTIVE`, project-local schedules and events invoke the pinned Autopilot
controller. The controller may inspect only configured, allowed inputs. It
uses the Full Harness lifecycle as a hard prerequisite:

1. form a problem frame with observed facts, first-principles constraints, and
   U-shaped root-cause reasoning;
2. produce a candidate branch, never a default-branch mutation;
3. run the declared unit, integration, smoke, and adversarial checks;
4. require the relevant lifecycle gate fingerprint to remain current;
5. open a PR containing evidence, risk classification, rollback plan, and
   feedback candidates;
6. promote only according to the L/M/H lane and branch/environment controls;
7. record outcome, rollback if policy signals a failure, and enter `SAFE_STOP`
   after repeated policy, test, or security failures.

The controller always checks out and executes trusted Autopilot code by pinned
SHA. It may analyse candidate project code in a constrained job, but no
repository, model, deployment, or central-App secret is exposed to that job.
Production deployment uses a separate protected GitHub Environment and is not
available to the candidate-analysis job.

## Harness Upgrade and Feedback Loops

### Harness upgrades

`ai-full-harness` publishes a signed release manifest with version,
compatibility range, migration, affected template paths, required checks, and
rollback reference. The Upgrade Broker finds compatible, enrolled repositories
and creates an issue plus a preview upgrade branch/PR. A project owner must
review and merge the Harness upgrade. The Broker cannot directly merge it.

The upgrade validator rejects a migration that changes business-code paths,
project objectives, project policy, stored secrets, or history. Updating the
Harness can invalidate appropriate lifecycle evidence; it cannot release the
project automatically.

### Feedback to the Harness

After an Autopilot run, `project-autopilot` produces a structured feedback
candidate. The project may automatically submit it to the central Feedback
Inbox only when it contains no secret, personal data, incident detail, source
snippet, customer data, or security-exploitation material. It is submitted as
`REVIEW`, never an applied change. Potentially sensitive or security-relevant
feedback remains local and asks the project owner for confirmation before
submission.

The central Harness uses the existing lifecycle process, smoke tests, and
adversarial review to accept, reject, or release any improvement. No project
can self-approve a Harness change.

## Failure Handling and Kill Switches

The controller must fail closed and record an auditable reason for malformed
state, missing or stale gates, unavailable GitHub identity, failed validation,
unrecognized risk, budget exhaustion, or protected-path access attempt.

Owners can pause or revoke a project by changing an externally protected
repository variable or disabling the GitHub App installation. The controller
checks the pause/revocation state at job start and before every external action.
Three consecutive failed or policy-rejected runs enter `SAFE_STOP`; resuming
requires an owner action and records the reason.

## Verification Strategy

The implementation must include local, deterministic tests and workflow-static
checks; no test may require a live GitHub account or production credential.

1. New-project generation creates valid Autopilot templates, explicit default
   disablement, and no credential placeholders.
2. Enabling Autopilot without a passed, fresh Stage 0 gate is rejected.
3. All legal enrollment state transitions pass, while every skipped, reversed,
   duplicate, malformed, or unknown transition fails.
4. A modified constitution fingerprint, malformed policy, unknown risk,
   protected-path request, or stale gate fails before code changes.
5. L/M/H fixture policies receive the correct PR, canary, approval, and
   release decisions; H and unknown risk never auto-promote.
6. Workflow checks reject broad `permissions: write-all`, `pull_request_target`
   checkout of untrusted code, unpinned remote actions, default-branch pushes,
   self-approval, and secret exposure to candidate jobs.
7. Upgrade fixtures can create a review-only proposal but cannot touch business
   code, policy, history, secrets, or default branch.
8. Feedback fixtures automatically accept only sanitized review-only feedback;
   sensitive feedback stops for confirmation.
9. Pause, revoke, failed check, and repeated-failure fixtures prevent further
   mutations and produce a safe-stop record.
10. Existing Full Harness generation, lifecycle, fingerprint, smoke, and
    adversarial tests remain green.

## Delivery Sequence

The work is intentionally decomposed so each layer has a testable boundary:

1. **Full Harness Autopilot Contract (this repository):** templates, schema
   validators, local enrollment-state tooling, workflow templates, static
   workflow security checks, upgrade/feedback data contracts, generator tests,
   and documentation. It ships as a new Harness version for new projects.
2. **Project Autopilot Controller (new repository):** pinned reusable
   workflows/action, policy evaluator, candidate/PR executor, safe-stop,
   feedback emitter, and its own test suite.
3. **Central GitHub configuration:** private remote repositories, GitHub App,
   organization/repository secrets, Actions access policy, branch protection,
   protected environments, and release process. This is an owner-authorized
   deployment checklist, not a script that silently changes account settings.
4. **Pilot project:** generate a disposable project, install the App for only
   that repository, exercise enrollment, observe-only, L/M/H fixtures,
   upgrade notification, feedback routing, revoke, and rollback.

Existing projects remain unchanged until a separate version-aware migration
proposal is reviewed and merged.

## Non-Goals

- No claim of absolute security or truthful AI evidence.
- This initial local delivery does not itself configure a GitHub account,
  install the App, create secrets, alter branch protection, commit, push,
  publish, deploy, or release. Once owner-authorized and configured, the
  Autopilot's bounded candidate-branch operations are governed by the policy
  above.
- No access to local machines, intranets, or databases in the first release.
- No autonomous H-lane production promotion.
- No self-modifying controller, policy, constitution, or Harness release path.
