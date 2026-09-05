# Central Deployment Checklist — Owner-Authorized External Steps

Date: 2026-09-06. This checklist records, but does not perform, the account
and repository actions that remain manual by design. Each step requires its
own explicit owner approval at execution time. Nothing in either local
repository executes these steps.

## 1. Repositories

- [ ] Create private remote `Amada203/ai-full-harness` sync target (local
      `main` currently leads origin by commits; push requires approval).
- [ ] Create private remote `Amada203/project-autopilot` and push the local
      controller repository (initial local commit `e352e49`).
- [ ] Record the controller's full commit SHA; generated projects must pin
      it in `ENROLLMENT.yml` / workflow `uses:` — never a branch or tag.

## 2. GitHub App (central identity)

- [ ] Register the GitHub App with **Only select repositories**.
- [ ] Minimal permissions: contents read/write (non-default branches only in
      practice), pull requests read/write, checks/metadata read. No
      administration, no secrets read, no bypass.
- [ ] Store the App private key only as a protected central secret. Never
      commit it, print it, or pass it to candidate jobs.

## 3. Repository controls

- [ ] Enable branch protection on both central repositories and on pilot
      projects: required checks (`check-harness`, `check-lifecycle-gate.sh
      github`, `check-autopilot-contract.sh`), no force push, no deletion.
- [ ] Create a protected deployment environment for production; only H-lane
      human-approved releases may target it.
- [ ] Configure required reviewers for any workflow run touching
      `.autopilot/`, `.ai/`, or workflow paths (CODEOWNERS is generated).

## 4. Ledger operations (per the confirmed authority split)

- [ ] Hold the append-only ledger snapshot outside both repositories;
      entries are created only by the owner's trusted issuer.
- [ ] Issue grants as `issue` entries matching the project's
      `.autopilot/GITHUB_GRANT.yml`; revoke by appending `revoke` entries
      with a higher epoch; record `consume` entries per run.
- [ ] Distribute snapshots to controllers; a stale snapshot fails closed.

## 5. Pilot (disposable private project)

- [ ] Generate a disposable project with
      `--autopilot enabled --autopilot-controller-ref <full-SHA>`.
- [ ] Exercise: Stage 0 enrollment, observe-only, L/M/H fixtures,
      protected-path rejection, grant allow/deny, pause, revoke, SAFE_STOP
      recovery, upgrade notification, sanitized feedback, rollback.
- [ ] Preserve run summaries as local evidence before enabling any
      non-dry-run lane; real cross-tool resume drills stay human evidence.

## Explicitly out of scope for automation

Creating or deleting repositories, installing or revoking the App, storing
or rotating secrets, changing branch protection, merging to default
branches, publishing releases, and deploying — each remains a separate,
individually approved human action.
