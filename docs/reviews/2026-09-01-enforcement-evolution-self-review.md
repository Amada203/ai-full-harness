# Enforcement and Controlled Evolution Self-Review

Date: 2026-09-01

Risk Level: H

This iteration changes controls inherited by every newly generated project, so
it receives high-risk review depth. It does not authorize commit, push,
publication, deployment, global installation, or branch-protection changes.

## First-Principles Review

### Observable Gap

Version 2.1 could prove that required evidence existed when a gate command ran,
but it could not prove that the evidence remained unchanged afterward. Manual
status edits could also leave downstream approvals looking valid after an
upstream change, and local checks were not automatically exercised by a remote
repository.

### Root Need

The root need is not “more checklist fields.” It is a trustworthy transition
model with four properties:

1. A passed gate is bound to specific content.
2. Changed upstream content invalidates dependent decisions.
3. Remote submission checks the strongest applicable gate rather than a mutable
   stage selector.
4. Project learning can improve the harness without allowing projects to
   rewrite their own governing system.

### Non-Negotiable Constraints

- Fingerprints must be deterministic and portable on Bash 3.2-era systems.
- State, baseline, and Markdown evidence are data, never executable input.
- Failed recording must leave state and baseline unchanged.
- Local dependency installation and generated caches must not create false
  implementation staleness.
- Project symlinks must not cause hashing of files outside the project.
- Self-evolution must remain proposal-only until a separate human review.
- Existing project-specific rules must not be overwritten by a blind upgrader.

## U-Shaped Reconstruction

The design descends from “make the process stricter” to specific failure modes:
stale evidence, orphaned downstream approval, CI gate downgrade, concurrent
mutation, ambiguous manifests, external symlink targets, and self-approved rule
changes. It rebuilds upward with a separate baseline, a read-only fingerprinter,
a transactional recorder, fixed final-gate CI, and review-only improvement
proposals.

The recorder does not bypass the checker. It writes the candidate fingerprint,
runs the ordinary checker, and rolls back both state and baseline on failure.
Only a successful record operation invalidates downstream state and approval
references.

## Smoke-Test Evidence

Automated tests exercise:

- Version 2.2 project generation and structural validation.
- Initial `UNRECORDED` fingerprints and executable lifecycle tools.
- Evidence-complete but unrecorded gate rejection.
- Successful recording and deterministic re-checking.
- Plan, implementation, release, GitHub approval, and retrospective staleness.
- Automatic downstream status/fingerprint reset and approval-reference clearing.
- Failed-record rollback of both baseline and state.
- Concurrent recorder lock rejection.
- Newline-containing path rejection.
- Tracked source changes causing staleness while dependency caches do not.
- Symlink additions causing staleness without following external targets.
- Symlinked lifecycle evidence rejection.
- Fixed `github` CI enforcement.
- Retrospective `NONE` and complete `PROPOSED` paths.
- Rejection of contradictory applicability and self-approved/self-applied
  proposal decisions.

Primary verification commands:

```bash
bash tests/test-new-full-project.sh
bash tests/test-lifecycle-gates.sh
bash -n bin/new-full-project bin/install-ai-full-harness templates/scripts/*.sh tests/*.sh
git diff --check
```

The generated-project contract audit also verifies deterministic plan
fingerprints, absence of unresolved template placeholders, structural success,
and fail-closed behavior for a fresh plan gate.

## Adversarial Findings

| Severity | Status | Attack | Disposition |
|---|---|---|---|
| P1 | CLOSED | Keep `PASS` after changing reviewed evidence. | Recorded/current fingerprints differ and the gate reports stale. |
| P1 | CLOSED | Re-record an upstream gate while preserving old release/GitHub approval. | Recorder blocks all downstream gates and clears downstream references. |
| P1 | CLOSED | Lower `CURRENT_GATE` so CI checks an earlier stage. | Workflow invokes the literal `github` gate. |
| P1 | CLOSED | Fail validation after the recorder starts mutating. | State and baseline backups are restored transactionally. |
| P1 | CLOSED | Run two recorders concurrently. | Project-local lock rejects the second recorder before mutation. |
| P1 | CLOSED | Use newline paths to create an ambiguous manifest. | Fingerprinter fails closed. |
| P1 | CLOSED | Replace approval evidence with an external symlink. | Lifecycle evidence and controls must be non-symlink regular files. |
| P1 | CLOSED | Add a project symlink that reads an external target into the digest. | The link text is hashed; the target is never followed. |
| P1 | CLOSED | Mark an improvement both `NONE` and `PROPOSED`, or append `APPLIED`. | Applicability must be unique and approval/application claims are forbidden. |
| P2 | CLOSED | Install or update dependencies after implementation review. | Git-ignored dependencies and common generated caches are excluded. |
| P2 | RESIDUAL | Write plausible but false evidence. | Requires domain tests and human review; content hashes prove equality, not truth. |
| P2 | RESIDUAL | Forge an approval-reference string. | Requires identity-backed approvals and audit logs. |
| P2 | RESIDUAL | Disable or edit CI as repository administrator. | Requires branch protection, required checks, and repository permissions. |
| P2 | RESIDUAL | Run on a host without SHA-256 tooling. | A labeled `cksum` fallback preserves portability but has weaker collision resistance. |
| P2 | RESIDUAL | Depend on ignored runtime files or mutable submodule contents. | Add project-specific fingerprint controls; default scope targets tracked and non-ignored project content. |
| P2 | RESIDUAL | Upgrade an existing customized project automatically. | Deferred until a version-aware, non-overwriting migrator is designed and tested. |
| P3 | RESIDUAL | Seek an independent reviewer in this run. | Current collaboration policy prohibited spawning a reviewer without an explicit user request; review was self-adversarial. |

## Decision

Version 2.2 materially strengthens repository-observable discipline: it detects
unrecorded and stale evidence, invalidates downstream approvals, provides fixed
CI enforcement, and makes harness learning reviewable but non-executable.

It still cannot honestly guarantee that every actor follows the process. Strong
enforcement requires the generated repository to enable the workflow as a
required branch check, protect control files and release credentials, and bind
high-risk approvals to real identities. Ordinary new-project commands also use
this harness only when the full-harness generator/trigger is selected; no global
installation was performed by this change.
