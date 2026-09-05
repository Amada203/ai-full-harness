# CC Switch / Codex historical provider recovery

**Date:** 2026-09-03

## Symptom

Opening a historical Codex task failed with:

```text
Model provider `cc-switch-official` not found
```

## Root cause

Historical task metadata still referenced the provider ID `cc-switch-official`.
The live `~/.codex/config.toml` had a `[model_providers.custom]` table but no
`[model_providers.cc-switch-official]` table.  The provider ID must resolve to
a table of the same name.

CC Switch keeps a complete Codex TOML profile per provider.  On this Mac,
`OpenAI Official` and `zuco` were separate profiles and neither used the
shared-config option.  A live-file-only repair would therefore be lost the
next time CC Switch changed providers.

## Repair

1. Created a permission-preserving backup:
   `~/.codex/backups/config.toml.20260903-170100.pre-cc-switch-alias.bak`.
2. Added the following non-secret compatibility table to both CC Switch Codex
   provider profiles (`OpenAI Official` and `zuco`) using the CC Switch UI:

   ```toml
   [model_providers.cc-switch-official]
   name = "CC Switch Official"
   wire_api = "responses"
   requires_openai_auth = false
   base_url = "http://127.0.0.1:15721/v1"
   ```

3. Left the active provider, selected model, provider credentials, and
   `auth.json` unchanged.

## Verification

The following checks were performed without sending a model prompt or making
an API request:

1. Confirmed the repair was absent before the change.
2. Switched `OpenAI Official` -> `zuco`; the generated config contained both
   `model_provider = "custom"` and the compatibility table.
3. Switched `zuco` -> `OpenAI Official`; the generated config retained the
   complete compatibility table.
4. Verified CC Switch now persists the table in both Codex provider profiles.
5. Ran `codex doctor`; it reported `config.toml parse ok` and loaded the
   official OpenAI provider.

Final state:

- Active provider: `OpenAI Official`
- Backup provider: `zuco`
- Live config contains the complete `cc-switch-official` compatibility table
- Both provider profiles retain the table across a provider switch

## Failover note

`zuco` is currently in CC Switch's Codex failover queue.  No automatic
failover threshold, health policy, or billing behavior was changed as part of
this repair.  Enabling automatic failover should be a separate, explicit
choice because it changes which provider receives future requests.

## Rollback

Use CC Switch to edit both Codex provider profiles, remove only the
`[model_providers.cc-switch-official]` table above, and save each profile.
Then select the desired provider.  Restoring only the live `config.toml` from
the backup is not durable because CC Switch rewrites it when switching.

## Reusable skill

Created and validated the local skill
`~/.codex/skills/repairing-cc-switch-codex-provider-alias/`.  Its baseline
test initially proposed changing the official profile's active provider to
the historical alias.  The final skill explicitly prevents that: the alias is
additive, while each profile retains its own active provider.  A second
independent scenario applied the final skill and preserved the active provider
while repairing every writable profile source.
