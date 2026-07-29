# Multiplayer (FitRPG)

Updated: 2026-07-29 (post TOP-10 fix + re-audit)

## Verdict

**Core economy/PvP server path ready for App Store P0.** Residual P1 UX/matchmaking edges remain. Details: [KI-audit-backend-REAUDIT-2026-07-29](./KI-audit-backend-REAUDIT-2026-07-29.md).

## Server callables (live)

Prior set plus: `resolvePvPBattle`, `awardActivityRewards`, `cleanupFitRPGAccount`.

Also: `matchmakeClanWar`, `cancelClanWarSearch`, `processClanWarPhases`, `recordClanWarAttack`, `joinTeam`, `matchWithOpponent`, `fillTeammatesWithBots`, `triggerOpponentBotFallback`, `acceptFriendDuel`, `declineFriendDuel`, `attackWorldBoss`, `resolvePvEBattle`, `equipItem`, `purchaseItem`, `declineFriendRequest`, `acceptFriendRequest`, …

Deploy: `scripts/deploy-fitrpg-safe.sh` only.

## What works

- Rules: economy fields / friends / progressions CF-only; gold client decrease only
- Shop buy → `purchaseItem`; equip → `equipItem`
- Online PvP settle → `resolvePvPBattle`
- World boss: energy charge + rate limit; cycle settlement lock
- Clan war: server rolls win; rewards in `recordClanWarAttack`
- FitRPG delete → `cleanupFitRPGAccount` (never recursive `users/{uid}`)

## Still open (P1)

- Combat state still client-written (rewards locked)
- Friend duel / clan CF error surfacing
- Ticket races / 3v3 invite edges
- App Check on 1st-gen callables

## Do not re-flag as missing

`declineFriendRequest`, `cancelClanWarSearch`, `purchaseItem`, `acceptFriendDuel`, `shopCatalog.ts`, `world_bosses` write:false, `resolvePvPBattle`, `awardActivityRewards`, `cleanupFitRPGAccount`.
