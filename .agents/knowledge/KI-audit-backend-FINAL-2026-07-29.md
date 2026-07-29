# Backend FINAL — 2026-07-29 (post-fix)

Post-`b1986fa` + honesty closure.

## PASS
- Battles participant-scoped; winnerId client-locked; `derivePvpWinnerId` + `surrenderedBy`
- Create: no client `surrenderedBy` / `createdByServer` / `winnerId` / `rewardsSettled`
- `resolvePvPBattle` requires `createdByServer === true` (CF match/duel/bot stamp)
- Clan trophies immutable; memberIds membership/self-join
- Energy: path-1 cannot increase; FitRPG path uses `fitrpgEconomyUnchanged`
- `clanId`: clear or set only if `auth.uid` already in target clan `memberIds`
- `adjustEnergy`: spend writes `pendingEnergyCharges[chargeId]`; refund consumes unused charge within 15m TTL
- Activity allowlist + rate/caps; offline isPvP mint skipped client-side
- CF search/leaderboards strip via `stripUserForPublic`
- FitRPG delete → `cleanupFitRPGAccount` only
- App Check on all FitRPG `fitRpgOnCall`
- Deploy via `scripts/deploy-fitrpg-safe.sh` (rules + targeted functions) — **deployed OK**

## Residuals (accepted)
1. Participant HP forge on stamped battles → ranked outcome trust among cheaters
2. Any auth `users` read (full doc) — needs publicProfiles split to fix
3. Notifications create open to any signed-in; treasuryGold/totalReps client-writable on clans
4. Shared recursive `deleteAccount` footgun for sibling apps (do not remove)

## Integrity verdict
**YES (honesty bar)** with residuals above. Operator App Attest still required outside code.
