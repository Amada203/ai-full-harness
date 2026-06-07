# GLOBAL_RULES

These rules apply across all projects created by the full harness.

## Purpose

Global rules define startup behavior and safety baselines. They do not replace
project-specific rules.

## Baselines

- Understand existing files before changing them.
- Prefer the smallest useful change.
- Do not perform unrelated refactors.
- Do not delete existing functionality unless the user explicitly asks.
- Do not overwrite user files silently.
- Do not commit secrets, tokens, credentials, private connection strings, or
  local caches.
- Do not commit, push, publish, deploy, or create a PR unless the user
  explicitly asks.
- Run meaningful verification before claiming completion.

## Rule Priority

Project rules in `.ai/PROJECT_RULES.md` override global defaults except safety
baselines. If a project rule conflicts with a safety baseline, stop and ask for
explicit user direction.
