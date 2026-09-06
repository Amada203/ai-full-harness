# U-Shaped Resynthesis and Cross-Repository Adversarial Acceptance — 2026-09-06 (Round 2)

Scope: the three-layer trust chain completed this round — project contract
(`ai-full-harness` templates), controller (`~/project-autopilot`), and the
owner-confirmed control ledger design — reviewed as ONE system, not three
green repositories.

## Surface

All suites are green: harness 12/12, controller 52/52  (now 58/58 after this
round), workflow security lint clean. The surface says: "done."

## U-Shaped Descent

1. Green tests inside each repository prove each layer rejects its own
   counterexamples. They prove nothing about the seams.
2. The root need, re-derived: bounded, auditable progress. Boundedness lives
   at the seams — an attacker does not attack a module; they attack the gap
   between two modules whose authors each believed the other enforced the
   rule.
3. For this system the seams are exactly three: project files → controller
   (policy/constitution/grant data crossing the YAML/JSON boundary),
   controller → ledger (chain verification and epoch semantics), and
   workflow → controller (who runs the harness gates before mutation).
4. Resurfacing: acceptance for this round means the seams carry explicit,
   tested contracts — not that more unit tests pass.

## Adversarial Findings (this round)

| ID | Severity | Attack | Result |
| --- | --- | --- | --- |
| B-1 | **P1** | Nested protected-directory drift: `src/config/settings.yml`, `app/deploy/x.yaml` were protected by the harness bash verifier but WRITABLE by the controller evaluator (root-anchored regex vs harness `*/dir/*` patterns) | CLOSED — controller now matches any-depth directory segments; parity fixture `test/cross-repo-parity.test.mjs` pins both sides |
| B-2 | P2 | YAML/JSON boundary: string `'3'` vs numeric `3` for `max_runs` caused false mismatches (fail-closed direction, but brittle and indistinguishable from attack) | CLOSED — normalized with non-numeric fail-closed |
| B-3 | P2 | Controller CLI required `autopilot_enabled`/`protected_paths` inside `POLICY.yml`, which the generated layout stores in `ENROLLMENT.yml`/`PROTECTED_PATHS.yml` | CLOSED — CLI assembles the effective policy from the three-file layout, regression-tested via real CLI invocation |
| B-4 | P2 | Revocation epoch semantics: strict equality against the issuance entry would deny a holder copy that legitimately advanced to a newer acknowledged epoch | CLOSED — epoch may only move forward (`cannot predate`), and `revoke` ledger entries remain the revocation decision point |
| B-5 | Verified sound | Ledger chain tamper/truncate/fork/replay; replay under partial consumption; budget exhaustion with later-epoch grants; grant numeric downgrade | Denied by existing fixtures |
| B-6 | Documented | Direct CLI invocation skips harness-side checks — enforced instead by workflow ordering (`needs: validate-contract`); integration-time constraint recorded in both READMEs | ACCEPTED with disclosure |
| B-7 | Documented | Ledger snapshot staleness = revocation lag; snapshots carry no timestamps by contract | ACCEPTED — snapshot freshness is an owner ledger-operations duty in the deployment checklist |

## Resynthesis

The deliverable that matters is not "a controller" but the seam contracts
now pinned by tests on both sides:

- Protected-path semantics: one fixture list, asserted in the controller,
  mirroring the harness verifier byte-for-byte in behavior.
- Grant numerics and epochs: normalization plus forward-only epochs at the
  YAML/JSON boundary.
- Policy assembly: the controller consumes the generated three-file layout,
  not an idealized single file.

## Decision

PASS for the local layer of all three artifacts after B-1..B-4 closed and
the suite grew 52 → 58 (all green). The platform remains NO-GO for remote
autonomous delivery pending the owner-executed pilot and multi-tool drills
recorded in the acceptance report; nothing in this round weakens that
boundary.
