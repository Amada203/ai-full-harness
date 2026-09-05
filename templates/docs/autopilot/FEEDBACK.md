# Autopilot Feedback Contract

Project Autopilot may report Harness problems only as sanitized review items.
Feedback is never approval to change the project contract or the central
Harness repository.

## Required Fields

```yaml
schema_version: 1
project_id: <repository-or-project-id>
controller_sha: <40-character-controller-sha>
observed_failure: <short sanitized summary>
violated_invariant: <Harness rule or gate that failed>
proposed_test: <minimal regression test idea>
risk: L|M|H
decision: REVIEW
```

`decision` must remain `REVIEW`. The project, controller, or generated agent
must not write `APPROVED`, `APPLIED`, or any equivalent self-approval state.

## Sanitization Rules

Feedback must exclude:

- Credentials, tokens, cookies, signing keys, and secret names that reveal
  deployment details.
- Personal data, customer data, financial records, medical records, legal
  material, and regulated data.
- Exploit steps, payloads, or operational security details.
- Arbitrary source snippets, database exports, or unbounded logs.

When classification is uncertain, stop and request human review. Do not guess
and do not send the feedback automatically.

## Upgrade Boundary

Harness upgrade feedback can create a review notification or preview PR for
Harness-controlled files. It cannot approve itself, merge itself, change
business code, change secrets, alter branch protection, or publish a central
Harness release.
