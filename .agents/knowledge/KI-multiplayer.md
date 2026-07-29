# Multiplayer (FitRPG)

Updated: 2026-07-29 (REAUDIT2 — P1 closed)

## Verdict

**Core multiplayer + economy ready for App Store.** Details: [KI-audit-merged-REAUDIT2-2026-07-29](./KI-audit-merged-REAUDIT2-2026-07-29.md).

## Server callables (live)

Prior set plus: `resolvePvPBattle`, `awardActivityRewards`, `cleanupFitRPGAccount`.

Also: `matchmakeClanWar`, `cancelClanWarSearch`, `processClanWarPhases`, `recordClanWarAttack`, `joinTeam`, `matchWithOpponent`, `fillTeammatesWithBots`, `triggerOpponentBotFallback`, `acceptFriendDuel`, `declineFriendDuel`, `attackWorldBoss`, `resolvePvEBattle`, `equipItem`, `purchaseItem`, `declineFriendRequest`, `acceptFriendRequest`, …

All FitRPG 1st-gen HTTPS callables: **App Check enforced** (`fitRpgOnCall`).

Deploy: `scripts/deploy-fitrpg-safe.sh` only.

## What works

- Rules: economy fields / friends / progressions CF-only; gold client decrease only
- Shop buy → `purchaseItem`; equip → `equipItem`
- Online PvP settle → `resolvePvPBattle`
- World boss: energy charge + rate limit; cycle settlement lock
- Clan war: server rolls win; rewards in `recordClanWarAttack`
- FitRPG delete → `cleanupFitRPGAccount` (never recursive `users/{uid}`)
- Matchmaking: client creates ticket before `matchWithOpponent` (requires `myTicketId`)
- 3v3 lobby accept → `joinTeam` (pending invite + battle sync)
- Friend duel fail surfaces error (no bot-queue fake success)

## Residual (non-blocking)

- Combat state still client-written (rewards locked)
- Story co-op gated / not shipped

## Do not re-flag as missing

`declineFriendRequest`, `cancelClanWarSearch`, `purchaseItem`, `acceptFriendDuel`, `shopCatalog.ts`, `world_bosses` write:false, `resolvePvPBattle`, `awardActivityRewards`, `cleanupFitRPGAccount`, App Check on FitRPG callables, Release `aps-environment=production`.
