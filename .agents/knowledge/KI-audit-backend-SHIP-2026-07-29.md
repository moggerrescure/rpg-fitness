# Backend Ship Audit — 2026-07-29

## Closed vs deep audit P0

| Finding | Fix |
|---------|-----|
| Any-auth battle + client `winnerId` forge | Rules: `participantUids` required; no client `winnerId`. CF `derivePvpWinnerId` + `surrenderedBy` |
| Client energy refill | Rules: energy may only decrease; `adjustEnergy` spend/refund/regen |
| Clan trophies any-auth | trophies immutable on client update; create starter 1000; `memberIds` gate |
| Activity / offline PvP mint | Tighter caps + reason allowlist; block pvp reasons; client skips local PvP mint |
| search/leaderboards overshare | `stripUserForPublic` |

## New / updated CF

- `adjustEnergy` — spend | refund | regen
- `resolvePvPBattle` — ignores client winnerId
- `acceptFriendDuel` / `joinTeam` / bot fallback — set `participantUids`

## Deploy note

Never full `functions` deploy. FitRPG never calls recursive `deleteAccount`.
