# Autopilot Enrollment

Autopilot is disabled by default. A generated project carries the contract files
needed for later enrollment, but it does not grant autonomous authority until
the owner opts in and the lifecycle gates pass.

## One-Time Enrollment Flow

1. Create the project with an explicit pinned controller:

   ```bash
   /Users/apple/ai-full-harness/bin/new-full-project \
     --autopilot enabled \
     --autopilot-controller-ref <40-character-controller-sha> \
     <project-name> <target-parent>
   ```

2. Complete Stage 0 problem framing and record the plan gate:

   ```bash
   scripts/record-lifecycle-gate.sh plan
   scripts/check-lifecycle-gate.sh plan
   scripts/transition-autopilot.sh STAGE0_PASSED
   ```

3. Commit and push the project to GitHub only after the owner approves that
   external action.

4. If central coordination is used, a repository administrator installs the
   GitHub App for selected repositories in GitHub. The App is not downloaded to
   a computer.

5. Let the `Autopilot Enrollment` workflow validate Harness structure, Stage 0,
   and the `.autopilot/` contract before moving beyond observation.

For pull requests, the workflow runs protected-path validation from a detached
copy of the base commit, so candidate code cannot replace the validator it is
being checked by. This is still not a complete trust root: configure that check
as an externally enforced required workflow or ruleset, require owner review for
workflow and Harness-control changes, and protect the default branch. A workflow
stored only in the project cannot prevent an administrator from replacing the
workflow itself.

## Manual Boundaries

The owner or repository administrator must still approve:

- GitHub App installation or repository authorization.
- Initial secrets and environment configuration.
- Any policy, permission, protected-path, workflow, or Harness-control change.
- High-risk release lanes.
- Recovery from `SAFE_STOP`.

Ordinary L/M candidate work can be automated only after explicit policy opt-in,
fresh fingerprints, a passed Stage 0 gate, and a valid pinned controller SHA.

## State Summary

Autopilot state is stored in `.autopilot/AUTOPILOT_STATE` as data. Do not source
or execute this file.

Legal transitions are:

```text
NEW -> STAGE0_PASSED -> GITHUB_CONNECTED -> REGISTERED -> OBSERVE_ONLY -> ACTIVE
ACTIVE -> PAUSED | REVOKED | SAFE_STOP
PAUSED -> ACTIVE | REVOKED
SAFE_STOP -> PAUSED | REVOKED
```

Use `scripts/transition-autopilot.sh` for state changes. It locks
`.autopilot/.transition.lock`, validates current fingerprints, writes atomically,
and rolls back on failure.

To change only `.autopilot/POLICY.yml`, first remain in `OBSERVE_ONLY` or pause
an active controller, edit and review the policy, then explicitly accept its
new fingerprint with:

```bash
scripts/transition-autopilot.sh --accept-policy "Owner review reference or reason"
```

This command refuses `ACTIVE`, `SAFE_STOP`, and `REVOKED`, requires an audit
reason, and rejects any simultaneous constitution, enrollment, objectives, or
protected-path change. Resume or enter `ACTIVE` only after the policy validator
passes with the newly accepted fingerprint.

## Harness Upgrades

Harness upgrades arrive as review-only instructions or preview pull requests.
They may update Harness-managed files after owner review, but they do not modify
business code directly. Projects can reject or pause an upgrade without losing
their current business code.
