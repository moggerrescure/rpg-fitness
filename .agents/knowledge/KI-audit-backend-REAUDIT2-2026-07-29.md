# Backend Re-Audit 2 — 2026-07-29 (P1 closure)

After P1 multiplayer / App Check batch + `scripts/deploy-fitrpg-safe.sh`.

## Verdict

**FitRPG server callables ready for App Store full-readiness bar** on economy + multiplayer integrity. Shared Food/Workout `deleteAccount` unchanged and unused by FitRPG.

## P1 closed this pass

| # | Finding | Fix |
|---|---------|-----|
| 1 | `matchWithOpponent` without `myTicketId` | Server still requires both ticket IDs; client always creates own ticket first |
| 2 | `acceptTeamInvite` bypassed `joinTeam` | Lobby accept goes through `joinTeam` CF; private lobby requires `pendingInvites`; syncs `battles.localTeam` |
| 3 | App Check on 1st-gen FitRPG callables | All FitRPG `https.onCall` via `fitRpgOnCall` (`enforceAppCheck: true`). Shared `vertexProxy` / `imageProxy` / `deleteAccount` untouched |
| 4 | Combat rewards / economy | Still CF-locked from P0 (no regression) |

## P0 still intact (verified in source + deploy)

- Field-scoped rules (economy / friends / progressions)
- `resolvePvPBattle`, `awardActivityRewards`, `cleanupFitRPGAccount`
- WB energy + rate limit; clan war server roll; friend accept requires pending
- FitRPG never calls recursive shared `deleteAccount`

## Residual (non-blocking)

- Battle combat HP/reps still client-writable (rewards locked)
- Node 20 deprecation warning on deploy
- App Check requires App Attest enrollment in Firebase console for Release builds (client ships provider)

## Deploy

`scripts/deploy-fitrpg-safe.sh` — rules released; FitRPG functions updated 2026-07-29 (App Check + joinTeam).

## Related

- [KI-audit-merged-REAUDIT2-2026-07-29](./KI-audit-merged-REAUDIT2-2026-07-29.md)
- [KI-multiplayer](./KI-multiplayer.md)
