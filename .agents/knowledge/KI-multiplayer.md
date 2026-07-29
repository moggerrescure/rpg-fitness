# Multiplayer (FitRPG)

Updated: 2026-07-29 (post-audit follow-up)

## Server callables (live)

`matchmakeClanWar`, `cancelClanWarSearch` (leader + searching only), `processClanWarPhases`, `recordClanWarAttack`, `joinTeam`, `matchWithOpponent` (requires `myTicketId` + host uid), `fillTeammatesWithBots` (host-only), `triggerOpponentBotFallback` (host-only), `attackWorldBoss`, `resolvePvEBattle` (XP/gold capped).

Audit agent P0 CF list was deployed via `scripts/deploy-fitrpg-safe.sh` (do not full-deploy — orphans tryonWorker/tagGarment).

## Clan war flow

1. `matchmakeClanWar` → `searching` (~120s) or immediate pair
2. Leader can `cancelClanWarSearch` while searching
3. Cron every 5m: pair searching clans, else bot after timeout; reset `warAttacksUsed`
4. `recordClanWarAttack`: max 3 attacks; increments opponent `opponentClanScore` for real clans

## Client guards

- Duplicate PvP rewards blocked via `rewardsAwardedBattleIds`
- Matchmaking errors → toast (error style) + Arena queue caption
- Team invite opens Arena tab (2), not Train
- World boss: `worldBossStatus` loading/empty/error (no infinite spinner)

## Still open

- Friend duel accept still client-writes battles (needs CF)
- Energy not charged on friend duel / 3v3 lobby; no cancel refund
- Shop purchase still client gold write
- `ClanVM.showWarResults` UI exists but not fed from cron completion
- PvP rewards still primarily client `awardBattleRewards`
