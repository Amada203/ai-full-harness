# Central Control Ledger — Authority Split Design

Date: 2026-09-06. Status: **CONFIRMED by owner (this session)** for local
design and implementation. This confirmation authorizes local code and tests
only. It does not authorize repository creation, secrets, GitHub App
installation, branch-protection changes, pushes, or releases — those remain
per-action owner approvals recorded in the central deployment checklist.

## Root Problem

The narrow candidate grant (`.autopilot/GITHUB_GRANT.yml` +
`check-autopilot-grant.sh`) proves local eligibility but cannot prove issuer
provenance, enforce a globally consistent budget, or distribute revocation.
Any system that could self-issue those proofs would be indistinguishable
from an attacker. The trust root for "who may grant" must therefore live
outside the project and outside the controller.

## Authority Split (confirmed)

| Authority | Owner | Enforcement |
| --- | --- | --- |
| Grant issuance, revocation epochs, global run budget, issuer identity | **Central control ledger** (append-only, digest-chained, externally held) | Entries are signed/held by the owner's trusted issuer; consumers verify chains, never create them |
| Constitution, policy, protected paths, enrollment | Project owner data in the project repo | Fingerprinted, fail-closed local validators |
| Candidate branch/draft PR execution | `project-autopilot` controller | Verifies grant **and** ledger chain before any GitHub write; dry-run without both |
| Merge, release, deploy, workflow/permission/secret changes | Always human, per action | Outside every grant; controller exposes no such capability |
| Ledger itself | Never writable by project or controller | Append-only JSONL with SHA-256 entry chain; deployment held as owner secret/protected artifact |

First-principles invariants: the ledger cannot enlarge a grant (scope fields
are advisory copies verified against the grant and the stricter wins);
revocation is monotonic (`revocation_epoch` only increases); consumption is
deduplicated by run id and budget is `min(local grant budget, ledger global
budget)`; a malformed, truncated, forked, or replayed chain fails closed.

## Ledger Data Contract

Append-only JSONL; each line is one entry. `entry_hash = sha256(prev_hash ||
canonical_json(entry_without_entry_hash))`. Genesis entries carry
`prev_hash: "GENESIS"`.

```jsonc
// type: "issue" — one per grant_id; duplicates fail verification
{ "type": "issue", "grant_id": "GRANT-2026-0001", "issuer": "central-control-plane",
  "repository_id": "Amada203/demo", "task_digest": "<sha256>",
  "approval_digest": "<sha256>", "allowed_paths": ["src/"],
  "branch_prefix": "autopilot", "allowed_actions": ["candidate_branch", "draft_pr"],
  "expires_at": "2026-09-30T00:00:00Z", "max_runs": 5,
  "revocation_epoch": 1, "prev_hash": "...", "entry_hash": "..." }
// type: "revoke" — bumps the epoch for a grant
{ "type": "revoke", "grant_id": "GRANT-2026-0001", "revocation_epoch": 2,
  "reason_ref": "owner-ref", "prev_hash": "...", "entry_hash": "..." }
// type: "consume" — global budget bookkeeping, deduplicated by run_id
{ "type": "consume", "grant_id": "GRANT-2026-0001", "run_id": "<opaque>",
  "prev_hash": "...", "entry_hash": "..." }
```

Verification of a grant against a ledger snapshot passes only when: the
chain hashes link correctly; exactly one `issue` entry matches every grant
field (repository, task digest, approval digest, paths, prefix, actions,
expiry, budget); no `revoke` entry has an epoch greater than the grant's
epoch; `consume` count for the grant is below `max_runs`; and the requester's
run id is not already consumed (replay). Everything else denies with a
structured reason.

## Non-Goals

- No remote ledger service in this delivery: the snapshot is a file the
  owner distributes; a hosted ledger is a future, separately authorized step.
- No signature scheme beyond the digest chain is required locally; if the
  owner later holds the ledger behind an external identity, chain plus
  distribution channel replaces local crypto.
- The controller never repairs, extends, or reorders a ledger.
