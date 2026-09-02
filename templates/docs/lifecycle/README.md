# Lifecycle Assurance

This directory stores the evidence required to move through project gates. The
four methods are working disciplines, not decorative review labels:

- **First-Principles Reasoning:** separate observed facts and immutable
  constraints from inherited solutions.
- **U-Shaped Thinking:** descend from the surface request to the root need, then
  rebuild a solution from evidence and constraints.
- **Smoke Testing:** run the smallest representative mainline before investing
  in exhaustive detail or approving release.
- **Adversarial Review:** actively attack assumptions, boundaries, failure
  behavior, data, model evaluation, Agent logic, tool authority, security,
  ethics, and business consequences.

## Risk Levels

- `L`: narrow and reversible work without sensitive or consequential behavior.
- `M`: the default for ordinary feature, data, integration, and API work, and
  for uncertain risk.
- `H`: sensitive data, authorization, destructive behavior, regulated or
  safety-critical outcomes, autonomous AI decisions, production security, or
  consequential external publication.

Risk can be raised at any time. Lowering risk requires rationale in
`PROBLEM_FRAMING.md` and a decision entry in `.ai/PROJECT_HISTORY.md`.

## Record and Check Commands

After evidence is complete and the matching status is set, record the gate and
then run the read-only check:

```bash
scripts/record-lifecycle-gate.sh plan
scripts/check-lifecycle-gate.sh plan
scripts/record-lifecycle-gate.sh design
scripts/check-lifecycle-gate.sh design
scripts/record-lifecycle-gate.sh prototype
scripts/check-lifecycle-gate.sh prototype
scripts/record-lifecycle-gate.sh implementation
scripts/check-lifecycle-gate.sh implementation
scripts/record-lifecycle-gate.sh release
scripts/check-lifecycle-gate.sh release
scripts/record-lifecycle-gate.sh github
scripts/check-lifecycle-gate.sh github
scripts/record-lifecycle-gate.sh retrospective
scripts/check-lifecycle-gate.sh retrospective
```

The recorder calls the same checker transactionally. If validation fails, state
and baseline are restored. If it succeeds, downstream statuses become
`BLOCKED`, downstream fingerprints become `UNRECORDED`, and obsolete approval
references are cleared. Later edits inside a recorded evidence scope make the
gate stale until it is reviewed and recorded again.

Never edit `.ai/LIFECYCLE_BASELINE` manually. Update `.ai/LIFECYCLE_STATE` only
after the required evidence and real verification exist.

## Controlled Harness Learning

At retrospective, complete `IMPROVEMENT_PROPOSAL.md` in one of two ways:

- `Applicability: NONE - <concrete reason>` when no reusable harness change is
  justified.
- `Applicability: PROPOSED` with all sections complete and
  `Proposal Decision: REVIEW`.

The project may propose a change but never applies it to the source harness or
marks it approved. That requires separate human review and implementation.

## Status Vocabulary

- `BLOCKED`: evidence or approval is incomplete; do not advance.
- `PASS`: evidence is complete and the gate checks pass.
- `NA`: allowed only for a risk-`L` or risk-`M` prototype with a concrete
  explanation in `PROTOTYPE_SMOKE_TEST.md`.
- `APPROVED`: used only for the GitHub gate after explicit user authorization.

## Enforcement Boundary

The local validator can detect missing files, incomplete markers, inconsistent
state, unresolved critical findings, absent approval references, unrecorded
evidence, and evidence changed after recording. GitHub Actions checks the fixed
final `github` gate, but repository administrators must still make that workflow
a required branch check. The harness cannot prove evidence truthfulness or
approval identity; deployment permissions and external approval systems remain
necessary for stronger organizational enforcement.
