# FINAL Audit — FitRPG — 2026-07-29 (post-fix)

Independent re-verification after ship commit `b1986fa`, then honesty P0/P1 closure (working tree; not yet committed unless user asks).

## Overall verdict

**YES (honesty bar)** — P0 economy/UI honesty holes closed; listed P1 closed or accepted as residual.

| Area | Verdict |
|------|---------|
| App Store guidelines (delete, privacy strings, legal URLs, no fake IAP) | Mostly PASS |
| Economy integrity (anti-cheat) | YES with residuals (HP forge among stamped battles; full users read) |
| UI honesty (no lies) | YES (free-train, quests, Health Sync, Story co-op marketing) |
| Feature completeness | Solo story + PvP/clans/WB; multiplayer story co-op not shipped (copy fixed) |

## Backend gates

| Gate | Result |
|------|--------|
| Battles `participantUids` / no client `winnerId` / server derive | PASS |
| Energy client cannot increase | **PASS** — path-1 `fitrpgEnergyNotIncreased()` + economy helper |
| `adjustEnergy` spend/refund/regen | **PASS** — spend ledger `pendingEnergyCharges` + chargeId; refund TTL 15m |
| Clan trophies immutable + memberIds | PASS |
| `clanId` client | **PASS** — leave/noop or join only if uid already in clan `memberIds` |
| Activity allowlist + no offline PvP mint | PASS |
| Ranked settle stamp | **PASS** — `createdByServer` required; CF match/duel/bot set it |
| CF PII strip search/leaderboards | PASS |
| Direct `users` read | **RESIDUAL** — any signed-in can read full user docs |
| `cleanupFitRPGAccount` only from FitRPG | PASS |
| App Check FitRPG callables | PASS |

## iOS gates

| Gate | Result |
|------|--------|
| 30s background surrender | PASS |
| No WB MM energy leak | PASS |
| `rpgfitness://` scheme + friend → Friends | PASS |
| Free-train FINISH cap honesty | **PASS** — counter + quests only on FINISH |
| WB 15 energy pre-check | PASS |
| Story co-op marketing | **PASS** — Arena SOLO badge; onboarding cleaned |
| Offline PvP no mint | PASS |
| Health Sync CF → `lastActionError` | PASS |
| Health Sync no WB damage claim | PASS |
| Quest single path | PASS |
| Clan LB Refresh real fetch | PASS |
| Delete / App Check Release / push / Legal | PASS (+ operator App Attest) |

## Closed this pass (was P0/P1)

1. Rules energy path-1 + clanId join validation
2. `adjustEnergy` refund ledger
3. Free-train FINISH awards; no mid-session counter/quest ticks
4. Health Sync honest copy + CF errors
5. Co-op marketing cleanup
6. Clan Refresh completion; friend deep link nav
7. Battle create blocks `surrenderedBy`/`createdByServer`; settle requires stamp

## Accepted residuals

- Participant-writable HP on **server-stamped** battles (cheaters in a real match can still forge HP before settle)
- Local bot fallback without CF stamp → no ranked mint (by design)
- Full `users/{uid}` readable by any signed-in (field-level read needs `publicProfiles` split)
- Notifications: any auth can create into another user’s subcollection
- Shared `deleteAccount` kept for sibling apps (FitRPG uses `cleanupFitRPGAccount`)
- Operator: Firebase App Attest enrollment for Release

## Operator checklist (not code)

- [ ] Firebase App Attest enrolled for Release
- [ ] ASC Privacy/Support/Terms = LegalURLs public HTTPS
- [ ] Privacy Nutrition Labels ↔ HealthKit
- [ ] Device smoke: Delete Account Apple/Google/anonymous

## Related

- [KI-audit-backend-FINAL-2026-07-29](./KI-audit-backend-FINAL-2026-07-29.md)
- [KI-audit-ios-FINAL-2026-07-29](./KI-audit-ios-FINAL-2026-07-29.md)
- Supersedes: [KI-audit-merged-SHIP-2026-07-29](./KI-audit-merged-SHIP-2026-07-29.md)
