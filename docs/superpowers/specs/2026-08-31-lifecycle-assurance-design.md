# Lifecycle Assurance Design

## Goal

Upgrade the full harness so first-principles reasoning, U-shaped thinking,
smoke testing, and adversarial review leave mandatory, auditable evidence
throughout the project lifecycle. Use risk-adjusted depth without allowing a
project to silently skip the minimum gate for its current stage.

## Non-Goal and Assurance Boundary

The harness cannot prove that an AI agent, developer, or reviewer wrote truthful
evidence or obeyed a prompt. Repository files and local shell scripts also
cannot force a user to run them. Absolute enforcement requires controls outside
the repository, such as protected branches, required CI checks, deployment
permissions, and human approval systems.

This design therefore provides three layers:

1. A rule layer that defines required behavior and forbids silent bypasses.
2. An evidence layer that makes stage decisions and reasoning auditable.
3. A mechanical gate layer that rejects missing files, placeholders, invalid
   states, incomplete dependencies, and unresolved critical findings.

## Risk Model

Every generated project starts at risk level `M`. The level is recorded in
`.ai/LIFECYCLE_STATE` and justified in the problem-framing evidence.

- `L`: narrow, reversible changes with no sensitive data, authorization,
  destructive operations, safety-critical decisions, or external release risk.
- `M`: the default for ordinary feature, data, integration, and API work, and
  for any task whose risk is uncertain.
- `H`: work involving secrets, identity, authorization, destructive or
  irreversible operations, regulated or sensitive data, financial/legal/medical
  outcomes, autonomous AI decisions, production security, or consequential
  external publication.

Risk may be raised at any stage. Lowering risk requires a written rationale and
a decision-history entry. High-risk release requires a non-placeholder human
approval reference. A high-risk prototype cannot be marked not applicable.

## Lifecycle State and Gates

`.ai/LIFECYCLE_STATE` is the machine-readable source for risk and gate status.
It uses a deliberately small `KEY=VALUE` format that the validator parses as
data and never executes as shell code.

The states are:

```text
RISK_LEVEL=M
CURRENT_GATE=plan
PLAN_STATUS=BLOCKED
DESIGN_STATUS=BLOCKED
PROTOTYPE_STATUS=BLOCKED
IMPLEMENTATION_STATUS=BLOCKED
RELEASE_STATUS=BLOCKED
GITHUB_STATUS=BLOCKED
RETROSPECTIVE_STATUS=BLOCKED
HUMAN_APPROVAL_REF=NONE
GITHUB_APPROVAL_REF=NONE
```

Gate transitions are monotonic for a release candidate. A failed or materially
changed dependency returns downstream gates to `BLOCKED`. `NA` is accepted only
for the prototype gate at risk `L` or `M`, with a concrete applicability
rationale in the prototype report. GitHub uses `APPROVED`, not `PASS`, to make
the human authorization requirement explicit.

## Evidence Files

The generated project adds `docs/lifecycle/` with focused templates:

- `PROBLEM_FRAMING.md`: observed facts, surface request, U-shaped descent to the
  root need, core goal, success metrics, first-principles constraints, rejected
  pseudo-requirements, risk answers, and rationale.
- `DESIGN_CHALLENGE.md`: root-problem restatement, assumptions, at least two
  options, selected path, alternatives, failure modes, adversarial findings,
  mitigations, and fallback.
- `PROTOTYPE_SMOKE_TEST.md`: applicability, minimum mainline, commands or steps,
  expected and actual evidence, and an explicit result.
- `SMOKE_TEST_REPORT.md`: pre-release mainline tests with repeatable commands,
  evidence, result, environment, and rollback signal.
- `ADVERSARIAL_REVIEW.md`: boundary, abnormal, malicious, biased, ethical,
  business-backfire, recovery, and rollback attacks; severity, disposition,
  owner, and verification evidence.
- `RETROSPECTIVE.md`: observable facts, causal chain, violated constraint,
  counterfactual, systemic corrective action, owner, and verification date.
- `README.md`: lifecycle-to-method mapping, status vocabulary, and gate commands.

Required fields use an HTML marker beginning with `<!-- REQUIRED:`. Structural
validation permits an untouched project to be created, while stage validation
rejects markers in evidence required for that gate.

## Stage Mapping

| Existing stage | Required method | Required evidence and gate |
|---|---|---|
| Stage 0 Plan | First principles + U-shaped thinking | Problem framing; `plan` gate |
| Stage 1 PRD / solution | First principles + U-shaped thinking + adversarial review | PRDs and design challenge; `design` gate |
| Stage 2 prototype / UI design | Smoke test + design adversarial review | Prototype smoke or justified `NA`; `prototype` gate |
| Stage 3 development | Confirmed assumptions + incremental verification | Scope remains within passed design; downstream gates reset after material change |
| Stage 3.5 Test and Debug | Smoke test + adversarial review | Pre-release smoke and adversarial review; `implementation` gate |
| Stage 4 UI parity | Adversarial comparison | P0/P1 interaction or visual findings resolved before implementation passes |
| Stage 5 release | Smoke test + adversarial release decision | Dependency chain, approval for risk `H`; `release` gate |
| Stage 6 GitHub | Explicit human authorization | Release passed, approval reference recorded; `github` gate |
| Stage 7 retrospective | U-shaped thinking + first principles | Root-cause retrospective; `retrospective` gate |

## Mechanical Validator

`scripts/check-harness.sh` remains the structural validator. It verifies all
required harness, lifecycle, and validator files, checks single-source-of-truth
pointers, and validates shell syntax.

`scripts/check-lifecycle-gate.sh <gate>` validates one gate and all of its
dependencies. Supported gates are `plan`, `design`, `prototype`,
`implementation`, `release`, `github`, and `retrospective`.

The validator must:

- reject unknown arguments, duplicate or missing state keys, invalid risk or
  status values, required markers, and legacy placeholder tokens;
- require the product and technical PRDs before the design gate;
- require `Result: PASS` in applicable smoke reports;
- allow prototype `NA` only with a reason and never at risk `H`;
- reject open P0 or P1 adversarial findings;
- require a human approval reference for high-risk release;
- require a separate approval reference for GitHub actions;
- print a concise reason and exit non-zero on failure;
- never source or execute lifecycle state content.

The validator performs syntactic and consistency checks. It does not claim to
judge the semantic quality or truthfulness of evidence.

## Generator Robustness

The project generator must not treat binary or local metadata as text
templates. It removes `.DS_Store` files from generated output and performs
placeholder substitution only on text files. This closes the failure found by
running the existing creation test against the current working directory.

## Testing Strategy

The generator test first asserts the new files, version, executable validator,
and absence of copied `.DS_Store` metadata. A lifecycle test then proves:

1. A fresh project passes structural validation but fails the `plan` gate.
2. Completed plan evidence passes the `plan` gate.
3. A downstream gate cannot pass while a dependency is blocked.
4. Prototype `NA` is accepted with a reason at `M` and rejected at `H`.
5. Applicable smoke tests require `Result: PASS`.
6. Open P0/P1 findings block implementation and release.
7. High-risk release requires a human approval reference.
8. GitHub remains blocked without a distinct user-approval reference.
9. A complete valid evidence chain reaches release.
10. Retrospective validation requires root-cause evidence.

Final verification runs shell syntax checks, both test scripts, generated
project structural validation, all positive gate fixtures, and explicit
negative/adversarial cases.

## Rollout

The harness template version becomes `2.1.0`. Newly generated projects receive
the lifecycle system automatically. Existing generated projects require an
explicit template upgrade; changing this repository alone does not rewrite
them. No commit, push, publication, or deployment is part of this change.
