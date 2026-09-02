# Lifecycle Assurance Self-Review

Date: 2026-09-01

Risk Level: H

The update is classified as high risk for review depth because it changes the
rules and mechanical controls that guide future AI-agent decisions across every
generated project. This classification does not authorize commit, publication,
or deployment.

## First-Principles Review

### Observed Facts

- The original harness had one durable rule source and a documented stage
  sequence.
- Its structural check verified file presence and entry-file pointers, but did
  not validate lifecycle evidence or stage decisions.
- First-principles analysis, U-shaped thinking, smoke testing, and adversarial
  review were not represented as mandatory artifacts.
- The project generator attempted placeholder substitution on every copied
  file, including local binary metadata.
- Prompt instructions and editable repository files cannot prove evidence is
  truthful or bind an approval to a real identity.

### Surface Request

Ensure all projects follow the harness throughout their lifecycle without
leaving process gaps.

### Root Need

The root need is predictable project governance: an agent should know the next
allowed action, reviewers should see the evidence behind each decision, and
automatable omissions should fail closed before work advances.

### Non-Negotiable Constraints

- Do not claim absolute enforcement from prompts or local files.
- Keep `.ai/PROJECT_RULES.md` as the single behavioral source of truth.
- Do not commit, push, publish, or deploy without explicit approval.
- Keep generated projects portable across local Bash environments.
- A failed critical mainline or unresolved critical finding cannot coexist with
  a passing downstream gate.

### Rejected Pseudo-Requirements

- Duplicating full rules into every tool-specific entry file was rejected
  because it creates drift.
- Treating a completed checklist as proof of semantic quality was rejected
  because local syntax checks cannot assess truthfulness.
- Making every project use the same review depth was rejected because low-risk
  work would carry unnecessary overhead; all projects retain a mandatory
  minimum, with deeper requirements at risk H.

## U-Shaped Reconstruction

The solution descends from “make agents follow a process” to the underlying
failure modes: hidden assumptions, missing evidence, skipped mainlines,
unresolved critical findings, and ambiguous approval. It then rebuilds the
workflow through three separable controls:

1. Rules define required behavior and reset conditions.
2. Evidence templates make reasoning and verification auditable.
3. Gate scripts reject mechanically detectable omissions and contradictions.

External controls remain a fourth organizational layer rather than being
misrepresented as a repository feature.

## Smoke-Test Evidence

The following automated paths are exercised by the repository tests:

- A full project can be generated with special characters in stack and
  description values.
- Binary `.DS_Store` metadata is not rendered into the generated project.
- A fresh project passes structural validation but fails the plan gate.
- Completed problem framing passes the plan gate.
- Design cannot pass with incomplete PRDs or design challenge evidence.
- A risk-M prototype may use a justified non-applicable result.
- A risk-H prototype cannot use a non-applicable result.
- Prototype and pre-release smoke reports need a passing case, reject failed
  cases, and reject other non-passing case states.
- A complete high-risk dependency chain can reach release only with a human
  approval reference.
- GitHub remains blocked without its own explicit approval reference.
- Retrospective validation requires root-cause evidence.

Primary commands:

```bash
bash tests/test-new-full-project.sh
bash tests/test-lifecycle-gates.sh
```

## Adversarial Findings

| Severity | Status | Attack | Result |
|---|---|---|---|
| P1 | CLOSED | Put binary metadata in the template tree. | Generator deletes `.DS_Store` output and renders text files only. |
| P1 | CLOSED | Delete placeholder markers but leave an empty evidence shell. | Gates require the expected document sections. |
| P1 | CLOSED | Add duplicate, unknown, malformed, or executable-looking lifecycle state. | Parser treats state as data, validates every line and key, and never sources it. |
| P1 | CLOSED | Mark the overall smoke result PASS while retaining a failed or blocked case. | Gates require a passing case and reject FAIL or other non-PASS case states. |
| P1 | CLOSED | Write a lowercase or alternate unresolved status for a P0/P1 attack. | P0/P1 rows must use `CLOSED`; every other status blocks. |
| P1 | CLOSED | Remove lifecycle-state discovery from an agent entry file. | Structural validation rejects the altered entry file. |
| P1 | CLOSED | Skip the prototype for a high-risk project. | Risk H rejects `PROTOTYPE_STATUS=NA`. |
| P1 | CLOSED | Advance a downstream gate while an earlier gate is blocked. | Each gate recursively validates all dependencies. |
| P2 | CLOSED | Leave ambiguous legacy placeholders in default context or data documentation. | Generator defaults now state when Stage 0 must resolve missing context; data templates use explicit required evidence markers. |
| P2 | RESIDUAL | Write plausible but false evidence. | Requires human review or domain-specific automated checks; Markdown cannot establish truth. |
| P2 | RESIDUAL | Forge an approval-reference string. | Requires an external identity-backed approval system and audit log. |
| P2 | RESIDUAL | Never run the local gate command. | Requires CI-required checks and protected branches outside this repository. |
| P2 | RESIDUAL | Edit or bypass controls with repository administrator access. | Requires repository permissions, branch protection, and deployment policy. |

## Decision

The optimized harness provides fail-closed behavior for the syntactic,
structural, dependency, critical-finding, and approval-reference properties it
can observe locally. It does not provide an absolute guarantee that every actor
will be honest or that every environment will execute the checks.

For stronger operational enforcement, configure the generated project's CI to
run the applicable gate, make it a required branch-protection check, restrict
release credentials, and connect high-risk or GitHub approvals to an
identity-backed system.
