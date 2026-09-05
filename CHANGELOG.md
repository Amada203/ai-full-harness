# Changelog

## Unreleased — Narrow GitHub candidate grant contract

- Added a disabled-by-default `.autopilot/GITHUB_GRANT.yml` reference and a
  fail-closed `scripts/check-autopilot-grant.sh` verifier for externally
  issued, task-scoped candidate authority (candidate branch / draft PR only).
- The verifier denies forged self-approval, wrong repository or task,
  expired, revoked, replayed, or over-budget grants, path traversal,
  protected paths, default branches, and out-of-scope actions, and suspends
  eligibility when the Autopilot contract check fails.
- `evaluate` proves local eligibility only; issuer provenance stays with the
  trusted central control plane. Adversarial fixtures cover every denial.
- Registration default-route migration (preview/apply/restore) and central
  control-ledger wiring remain explicitly authorized future work.

## Unreleased — Architecture design evidence

- Add Archify source/HTML/delivery receipt workflow under docs/architecture.
- Require pinned tool contents, showcase validation, technical node references,
  and artifact/source digests in the existing design gate.
- Include architecture and tool lock in design fingerprints. Keep original PRD
  paths and require reviewed adoption for existing projects.
- Local tool snapshot is 2.17.0-dev.1; an upstream release/distribution is not
  attested. Browser measurements and visual judgment are separate evidence.

## 2.3.0 — 2026-09-04

- Added a disabled-by-default, data-only Project Autopilot enrollment contract.
- Added deterministic contract fingerprints and a fail-closed validator that
  never sources project-controlled Autopilot data.
- Added locked, transactional enrollment state transitions with rollback and
  automatic `SAFE_STOP` after repeated failures.
- Added read-only enrollment and review-only Harness upgrade receiver workflows
  with pinned actions and explicit minimum permissions.
- Added operator guidance for GitHub App authorization, manual safety
  boundaries, sanitized Harness feedback, and business-code separation.
- Kept existing projects unchanged; adoption requires an explicit,
  version-aware reviewed migration.

## 2.2.0 — 2026-09-01

- Added deterministic lifecycle fingerprints and stale-evidence detection.
- Added transactional gate recording with downstream status, fingerprint, and
  approval invalidation.
- Added fixed final-gate GitHub Actions enforcement.
- Added review-only retrospective harness improvement proposals.
- Excluded ignored dependencies, virtual environments, and generated caches
  from implementation fingerprints while retaining source-change detection.
- Fingerprinted symlink definitions without following external targets and
  prohibited symlinked lifecycle control/evidence files.
- Documented external enforcement and migration boundaries explicitly.

## 2.1.0 — 2026-08-31

- Added risk-adjusted lifecycle state and evidence gates.
- Applied first-principles reasoning, U-shaped thinking, smoke testing, and
  adversarial review throughout the generated project lifecycle.
