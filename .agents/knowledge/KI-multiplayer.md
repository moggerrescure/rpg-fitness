# Multiplayer (FitRPG)

Updated: 2026-07-29 (friend duel CF + energy hold)

## Server callables (live)

`matchmakeClanWar`, `cancelClanWarSearch`, `processClanWarPhases`, `recordClanWarAttack`, `joinTeam`, `matchWithOpponent` (`myTicketId`), `fillTeammatesWithBots`, `triggerOpponentBotFallback`, `acceptFriendDuel`, `declineFriendDuel`, `attackWorldBoss`, `resolvePvEBattle` (XP/gold capped).

Deploy: `scripts/deploy-fitrpg-safe.sh` (never wipe Food/Workout orphans).

## Energy

Queue / friend duel / 3v3 lobby charge 10 energy up front; refund via `refundEnergy` if `leaveMatch` before battle becomes active.

## Clan war results UI

`ClanVM` snapshots last `active` war; when cron clears `activeWar`, shows `WarResultOverlay` + small XP/gold.

## Still open

- Shop purchase still client gold write (equip is CF)
- Full server-authoritative PvP rewards
- XCTest / TestFlight smoke
