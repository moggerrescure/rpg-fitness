# Multiplayer (FitRPG)

Updated: 2026-07-29 (post backend audit)

## Verdict

Economy/PvP **not App Store ready** — open rules + client-authoritative gold/XP/energy. Details: [KI-audit-backend-2026-07-29](./KI-audit-backend-2026-07-29.md).

## Server callables (live)

`matchmakeClanWar`, `cancelClanWarSearch`, `processClanWarPhases`, `recordClanWarAttack`, `joinTeam`, `matchWithOpponent`, `fillTeammatesWithBots`, `triggerOpponentBotFallback`, `acceptFriendDuel`, `declineFriendDuel`, `attackWorldBoss`, `resolvePvEBattle`, `equipItem`, `purchaseItem` (+ `shopCatalog.ts` @ `b73e79f`), `declineFriendRequest`.

Deploy: `scripts/deploy-fitrpg-safe.sh` only.

## What works (partial)

- Energy hold/refund: PvP queue / friend duel / 3v3
- Shop buy → `purchaseItem` (server catalog); equip → `equipItem`
- Clan war results overlay when cron clears active war
- `world_bosses` rules: `write: false`

## Still open (P0)

- Broad client writes: `users` / `clans` / `battles` / `matchmaking`
- `syncCharacter` economy overwrite (+ sibling fields risk)
- PvP rewards client-side
- `attackWorldBoss` no energy; `resolvePvEBattle` / `recordClanWarAttack` trust client
- `acceptFriendRequest` force-friend; `processWorldBossCycle` double-reward race
- `deleteAccount` recursiveDelete cross-app

## Do not re-flag as missing

`declineFriendRequest`, `cancelClanWarSearch`, `purchaseItem`, `acceptFriendDuel`, `shopCatalog.ts`, `world_bosses` write:false — already shipped.
