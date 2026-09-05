# Full Harness source-authoring rules

This is the shared rule source for tools developing the Harness itself, subject
to system/developer instructions and explicit user authority. Root tool entries
are pointers only. Do not copy generated-project stage status into this source
project or silently make template rules govern the wrong repository.

## Startup and continuation

Read current context, these rules, recent history and the relevant plan/source.
Inspect branch, HEAD, dirty files and current test evidence. A conversation
summary is a locator, not proof. Investigate conflicting/stale handoff records;
do not discard user edits, reset the checkout or assume interrupted work passed.

Keep one shared state across Codex, Claude, Gemini and Cursor. Record progress
at meaningful changes, verification, blockers and planned interruptions. Record
unfinished work and the next allowed action. An abrupt interruption requires
reconstruction from Git and actual files; automatic checkpoint validation is
not yet implemented.

## Lifecycle and refactoring

Separate facts, assumptions, constraints and root outcomes before solution work.
Use regressions to reproduce behavior defects and adversarial cases to challenge
authority, stale evidence and recovery. Preserve a tested behavioral baseline
when refactoring; use incremental changes and explicit rollback guidance.
Update architecture, contracts and affected tests together. Do not reuse stale
gate evidence or silently change project policy to make an upgrade pass.

For template changes, run relevant generator, contract and lifecycle regressions.
For architecture changes, run tests/test-architecture.mjs and distinguish
deterministic checks, browser behavior and visual review. Tool-entry tests prove
structural consistency only, not real cross-model recovery or semantic agreement.
Do not describe local test results as remote deployment, perfect enforcement
or completed autonomous evolution.

## Approval and synchronization

Require explicit user approval for commit, push, PR creation, release, deploy,
global tool registration, credential or GitHub permission changes. Development
approval is not publication approval. Do not silently install dependencies or
overwrite another tool's global rules while adding local adapters.

Update context when approach/status/blockers change; append verified milestones
to history. Mirror material decisions and evidence to the user-designated
Obsidian location when authorized. If unavailable, report pending sync rather
than inventing another destination or claiming completion. Keep private Vault
paths and credentials out of shared adapters. No periodic sync service exists.
