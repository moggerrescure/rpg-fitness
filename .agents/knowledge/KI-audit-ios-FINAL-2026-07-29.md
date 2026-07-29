# iOS FINAL — 2026-07-29 (post-fix)

Post-`b1986fa` + honesty closure.

## PASS
- 30s background surrender
- WB/bossRaid blocked from PvP MM (no energy leak)
- `rpgfitness` URL scheme; `rpgfitness://friend` sends request **and** opens Friends (`pendingDeepLink` + `FitRPGOpenFriendsSegment`)
- Free-train: daily cap + quests advanced **once on FINISH** via `awardWorkoutRewards` / `recordFreeTrainingRepsAwarded`
- WB Attack 15 energy gate
- Offline BattleEngine PvP does not mint via CF
- Health Sync: XP/gold only; no WB damage claim; CF fail → `lastActionError`
- Story Arena card badge **SOLO**; onboarding without co-op raids claim
- Clan LB Refresh bound to real fetch completion / `$leaderboards`
- Energy spend/refund pass `chargeId` to `adjustEnergy`
- Match create: skip overwrite when `createdByServer` already set
- Delete Auth + `cleanupFitRPGAccount`; Release App Check + production push entitlements; LegalURLs

## Residuals
- Local unstamped bot battle → ranked settle rejected (honest)
- HP forge residual is server-side among stamped matches
- Operator App Attest

## Honesty verdict
**YES (honesty bar)**.
