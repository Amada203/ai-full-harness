# Enforcement and Controlled Evolution Design

## Goal

Close the remaining gap between “a gate passed once” and “the evidence is still
valid now,” make GitHub integration fail closed, and turn retrospective learning
into reviewable harness-improvement proposals without allowing autonomous
self-modification.

## Scope

This iteration adds four related controls:

1. Content fingerprints for lifecycle evidence and implementation state.
2. A transactional gate-recording command that invalidates downstream gates.
3. A generated GitHub Actions workflow that requires the GitHub lifecycle gate.
4. A retrospective improvement-proposal artifact that never applies itself.

A general upgrader for existing projects is deferred. Safely merging a newer
harness into project-specific rules requires a version-aware migration design;
blind template copying would risk overwriting user policy and history.

## Alternatives Considered

### Recommended: recorded fingerprints plus fail-closed validation

Each passed gate records a deterministic fingerprint. Normal gate checks compare
the recorded fingerprint with current content and fail when evidence or relevant
project files have changed. A dedicated recorder validates the gate first and
then automatically blocks downstream states.

This provides explicit audit points, detects stale evidence, remains local and
portable, and separates read-only checking from controlled mutation.

### Alternative: timestamps

Store the time each gate passed and reject files modified later. This is simple
but unreliable across copies, rebases, restored files, clock skew, and build
systems that preserve or rewrite timestamps.

### Alternative: Git revisions only

Bind gates to a commit SHA. This is strong after commit but conflicts with the
harness rule that GitHub submission occurs only after the work is verified, and
it cannot represent uncommitted development evidence.

## Baseline State

Generated projects add `.ai/LIFECYCLE_BASELINE`:

```text
SCHEMA_VERSION=1
PLAN_FINGERPRINT=UNRECORDED
DESIGN_FINGERPRINT=UNRECORDED
PROTOTYPE_FINGERPRINT=UNRECORDED
IMPLEMENTATION_FINGERPRINT=UNRECORDED
RELEASE_FINGERPRINT=UNRECORDED
GITHUB_FINGERPRINT=UNRECORDED
RETROSPECTIVE_FINGERPRINT=UNRECORDED
```

The file is parsed as data and never sourced. Unknown, duplicate, malformed, or
missing keys fail validation.

## Fingerprint Scopes

`scripts/lifecycle-fingerprint.sh <gate>` prints one algorithm-prefixed digest.
It uses SHA-256 through `shasum`, `sha256sum`, or OpenSSL when available and a
clearly labeled POSIX `cksum` fallback when none is present.

Inputs are deterministic path-and-content manifests:

- `plan`: risk level plus `PROBLEM_FRAMING.md`.
- `design`: product PRD, technical PRD, design challenge, and `docs/data/`.
- `prototype`: prototype smoke report, durable design guidance, and design
  review artifacts.
- `implementation`: the full project file set except Git internals, mutable
  lifecycle state/baseline/history, release artifacts, retrospective/proposal
  evidence, locks, ignored dependencies, virtual environments, generated
  caches, local metadata, and temporary files.
- `release`: `dist/` plus the human-approval reference. It relies recursively
  on the implementation fingerprint for all implementation inputs.
- `github`: the GitHub-approval reference. It relies recursively on release.
- `retrospective`: retrospective and improvement-proposal evidence. It relies
  recursively on release.

Project paths containing a newline are rejected by the fingerprint command so
that newline-delimited manifests cannot become ambiguous. Spaces and ordinary
Unicode names remain supported.

Project symlinks are fingerprinted by link text without following their target,
so an external path cannot be read into the project digest. Lifecycle evidence
and control files must be ordinary project files and cannot be symlinks.

## Recording and Invalidation

`scripts/record-lifecycle-gate.sh <gate>` is the only documented way to record a
passing gate:

1. Acquire a project-local lock; fail if another record operation is active.
2. Compute the current fingerprint.
3. Temporarily write that fingerprint to the current gate baseline.
4. Run the normal lifecycle checker, including all dependencies and evidence.
5. On failure, restore the previous baseline and leave state unchanged.
6. On success, set `CURRENT_GATE`, keep the new current fingerprint, reset every
   downstream status and fingerprint to `BLOCKED` or `UNRECORDED`, and clear
   downstream approval references.
7. Release the lock on every exit path.

The normal `check-lifecycle-gate.sh <gate>` remains read-only. Every stage check
requires a recorded fingerprint and compares it with current input. Changed
content produces a “stale fingerprint” error even if the status still says
`PASS`.

Downstream reset order is:

```text
plan -> design -> prototype -> implementation -> release -> github
                                                \-> retrospective
```

Recording `github` also invalidates any earlier retrospective. Recording a
retrospective has no downstream mutation.

## GitHub Enforcement

Generated projects include `.github/workflows/harness-gates.yml`. On every push,
pull request, and manual dispatch it:

1. Checks out the repository.
2. Runs `scripts/check-harness.sh`.
3. Runs `scripts/check-lifecycle-gate.sh github`.

The workflow deliberately checks the GitHub gate instead of trusting
`CURRENT_GATE`. This matches the harness policy that GitHub actions occur only
after release verification and explicit GitHub approval. Repository
administrators must still configure this workflow as a required branch check;
the workflow file cannot protect itself from an administrator.

## Controlled Evolution

Generated projects add `docs/lifecycle/IMPROVEMENT_PROPOSAL.md`. The
retrospective gate accepts exactly one of two paths:

- `Applicability: NONE - <concrete rationale>`: no reusable harness change was
  identified.
- `Applicability: PROPOSED`: the file must contain observed recurring failure,
  violated invariant, proposed rule/template/test change, falsifying test,
  compatibility impact, adversarial risks, rollback, owner, and
  `Proposal Decision: REVIEW`.

The proposal is evidence, not executable instruction. No script copies it into
the source harness, modifies rules, or publishes it. A human must review it in
the harness repository through the same design, TDD, smoke, and adversarial
process used for any other change.

## Error Handling and Trust Boundary

- Record failure restores the previous baseline and keeps downstream state.
- Concurrent record attempts fail before mutation.
- Missing hash tools fall back to `cksum` and expose the algorithm in the
  recorded value.
- Newline-containing paths fail rather than producing an ambiguous manifest.
- Direct edits to state or baseline remain possible for a repository
  administrator; CI, branch protection, permissions, and identity-backed
  approval remain external requirements.
- A fingerprint proves content equality, not evidence truthfulness.

## Tests

Tests must prove:

1. Fresh projects contain an unrecorded baseline, recorder, fingerprint tool,
   improvement proposal, and GitHub workflow.
2. A passing status without a recorded fingerprint is blocked.
3. Recording a valid gate makes its check pass.
4. Modifying plan, design, prototype, implementation, release, GitHub approval,
   or retrospective inputs makes the corresponding gate stale.
5. Re-recording an upstream gate blocks all downstream states and clears stale
   approvals.
6. Failed recording restores the old fingerprint and state.
7. A concurrent record lock prevents mutation.
8. Newline-containing paths are rejected.
9. CI checks the fixed `github` gate rather than `CURRENT_GATE`.
10. Retrospective fails without an improvement decision, accepts a justified
    none path, and accepts a complete proposed path.
11. Existing generation and lifecycle adversarial tests remain green.

## Versioning

The generated harness version becomes `2.2.0`. This affects new projects only.
Existing projects are not modified automatically and must not be upgraded by
copying templates over project-specific files.
