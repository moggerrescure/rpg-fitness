# Multiplayer (FitRPG)

Updated: 2026-07-29 (shop CF)

## Server callables (live)

`matchmakeClanWar`, `cancelClanWarSearch`, `processClanWarPhases`, `recordClanWarAttack`, `joinTeam`, `matchWithOpponent`, `fillTeammatesWithBots`, `triggerOpponentBotFallback`, `acceptFriendDuel`, `declineFriendDuel`, `attackWorldBoss`, `resolvePvEBattle`, `equipItem`, `purchaseItem` (catalog in `shopCatalog.ts`).

Deploy: `scripts/deploy-fitrpg-safe.sh`.

## Client economy notes

- Energy hold/refund for PvP queue/friend/3v3
- Shop buy → `purchaseItem`; equip → `equipItem`
- Clan war results overlay when cron clears active war

## Still open

- Full server-authoritative PvP battle rewards (still mostly client `awardBattleRewards`)
- XCTest suite / TestFlight smoke checklist
- ASC Privacy URL paste (pages live at borisserz.github.io/fitrpg-legal)
