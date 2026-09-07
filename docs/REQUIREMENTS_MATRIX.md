# Requirements → Evidence Matrix (living document)

Updated: 2026-09-07. Rule: every row must point at evidence that exists
today; a row without authoritative evidence is NO by definition, regardless
of how green the test suites are. Update this file in the same commit as
any change that affects a row.

| # | Requirement (from PRD/design specs) | Evidence | Status |
| --- | --- | --- | --- |
| 1 | First-principles / U-shape / smoke / adversarial across lifecycle | harness templates + `tests/test-lifecycle-gates.sh` (archify-bound suites local-only) | YES (local) |
| 2 | Archify architecture evidence at design gate | `tests/test-architecture.mjs`, `docs/reviews/2026-09-05-architecture-gate.md` | YES (local; tool distribution open) |
| 3 | Default "new project" route = Full Harness | `bin/check-global-registration` audit only; preview/apply/restore migration unimplemented | NO |
| 4 | Cross-tool step-resume | `tests/test-continuity.mjs`, `test-source-agent-entries.mjs`; real multi-tool drill not run | PARTIAL |
| 5 | Interruption audit & recovery | continuity drill + `tests/test-continuity.mjs` | YES (local) |
| 6 | Refactor protocol & recovery | `tests/test-refactor-recovery.sh`; real data-migration drill not run | PARTIAL |
| 7 | Knowledge base bind + one-way sync | `tests/test-knowledge-base.mjs`, `test-knowledge-sync.mjs`; parent-symlink boundary (F7) closed 2026-09-07; crash-recovery journal open | PARTIAL |
| 8 | Narrow GitHub candidate grant | `tests/test-autopilot-grant.sh` + controller execution-point binding (F1) `test/review-round4.test.mjs` | YES (local) |
| 9 | Central control ledger authority | spec confirmed; `bin/autopilot-ledger` + controller chain verification; tip anchoring; no signed service | PARTIAL |
| 10 | Controller candidate branch / draft PR only | `test/controller.test.mjs`, `test/candidate.test.mjs`, client contract `test/client-contract.test.mjs` | YES (local) |
| 11 | Durable cross-run budget & safe-stop | workflow reservation step (2026-09-07) + `requireRunReservation` fixtures; production e2e unexercised | PARTIAL |
| 12 | Evidence gates promotion | F8 regressions: FAIL/missing evidence ⇒ diagnostic PR + human approval | YES (local) |
| 13 | Pinned controller release | tag `v0.1.0` (commit b2e5d9a) pushed 2026-09-07 | YES |
| 14 | Harness upgrade notification & migration | receiver workflow only; central pusher/migration unimplemented | NO |
| 15 | Sanitized REVIEW-only feedback | `tests/feedback.test.mjs`; delivery/ adoption loop unimplemented | PARTIAL |
| 16 | Harness self-evolution | REVIEW proposal templates; no verified run loop | NO |
| 17 | Deployment (App, secrets, protection, pilot) | harness branch protection ON; controller protection blocked by free plan; App = owner web-form step (checklist §6); no pilot | NO |
| 18 | Both CIs green on GitHub | `Harness CI` (harness-suites) + `Controller CI` (test, cross-repo) | YES |

Overall: **NO-GO for unattended promotion.** Blocking rows for GO: 3, 9
(signed service), 11 (production e2e), 14, 16, 17.
