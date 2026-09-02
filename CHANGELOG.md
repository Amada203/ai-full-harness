# Changelog

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
