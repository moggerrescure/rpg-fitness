# Backend Re-Audit — 2026-07-29 (post-fix)

After TOP server P0 fixes + `scripts/deploy-fitrpg-safe.sh` deploy to `serzhanovich-ecosystem-ce700`.

## Verdict

**Economy / PvP much closer to ready.** Client can no longer freely mint gold/XP/gear via Firestore. Remaining gaps are P1 (matchmaking ticket edge cases, App Check on all callables, combat state still partly client-written).

## Fixed (was P0)

| # | Finding | Fix |
|---|---------|-----|
| 1 | Open `users` / `clans` / `battles` / `matchmaking` writes | Field-scoped rules; economy protected; matchmaking own-ticket; clan `activeWar` CF-only; battles `rewardsSettled` CF-only |
| 2 | `syncCharacter` economy overwrite | Client strips protected fields + merge; gold increases CF-only |
| 3 | PvP rewards client-side | New `resolvePvPBattle` + settlement map on battle doc |
| 4 | `attackWorldBoss` no energy | Server charges 15 energy + hourly rate limit |
| 5 | `resolvePvEBattle` trust | Caps + `won===true` + hourly rate limit; loot chance capped |
| 6 | `acceptFriendRequest` force-friend | Requires pending request |
| 7 | `recordClanWarAttack` trusts `won` | Server `rollClanWarWin`; single reward path in CF |
| 8 | `deleteAccount` recursive wipe | New `cleanupFitRPGAccount` (scoped field delete). Shared `deleteAccount` left for Food/Workout — FitRPG must not call it |
| 9 | WB cycle double-reward | `rewardsSettled` lock in transaction |

## New callables (deployed)

`resolvePvPBattle`, `awardActivityRewards`, `cleanupFitRPGAccount`

## Still open (P1 / residual)

- Battle combat HP/reps still client-writable (rewards locked)
- Matchmaking update still allows `targetUid` / invitees — OK for invites; watch team-join race
- `deleteAccount` (Food/Workout) still recursive — ecosystem risk if mis-invoked from FitRPG (client fixed)
- App Check not enforced on 1st-gen FitRPG callables
- `pendingWorldBossXp` applied as side counter (client should fold into progressions on next sync — optional polish)
- Node 20 runtime deprecation warning on deploy

## Deploy

`scripts/deploy-fitrpg-safe.sh` — rules released; new+updated functions success 2026-07-29.

## Related

- [KI-audit-merged-REAUDIT-2026-07-29](./KI-audit-merged-REAUDIT-2026-07-29.md)
- [KI-multiplayer](./KI-multiplayer.md)
