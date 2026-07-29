# iOS Re-Audit 2 — 2026-07-29 (P1 closure)

After client P1 multiplayer UX + Release App Check / push entitlements.

## Verdict

**Client P1 App Store blockers from REAUDIT closed.** Solo story works; co-op gated honestly. Friend duel no longer fakes bot success.

## P1 closed this pass

| # | Finding | Status |
|---|---------|--------|
| 1 | Friend duel CF/lookup fail → bot queue as success | **FIXED** — error toast; `completion(false)`; no `startMatchmaking` fallback |
| 2 | Clan war CF silent `print` | **FIXED** — `FirebaseService.lastActionError` → MainHub toast |
| 3 | Story co-op dead paths | **GATED** — mode prompt; co-op shows unavailable + Play Solo CTA |
| 4 | App Check Release | **FIXED** — `FitRPGAppCheckProviderFactory` (App Attest / DeviceCheck); DEBUG still debug factory |
| 5 | Push `aps-environment=production` | **FIXED** — `rpg-tracker.Release.entitlements` for Release config |
| 6 | Matchmaking `myTicketId` race | **FIXED** — create own ticket before `matchWithOpponent` |
| 7 | 3v3 `acceptTeamInvite` client write | **FIXED** — calls `joinTeam` CF |
| 8 | FitRPG recursive `deleteAccount` | **VERIFIED** — only `cleanupFitRPGAccount` |

## Residual (cosmetic / non-blocking)

- Background auto-surrender PvP UX (product choice, not blocker)
- Story co-op feature itself not built (honest gate, not fake multiplayer)
- Combat HP still client-synced (rewards CF-only)

## Related

- [KI-audit-merged-REAUDIT2-2026-07-29](./KI-audit-merged-REAUDIT2-2026-07-29.md)
