# Multiplayer (FitRPG)

Updated: 2026-07-29 (SHIP — honesty bar)

## Verdict

**Core multiplayer + economy ready for App Store (honesty bar).** Details: [KI-audit-merged-SHIP-2026-07-29](./KI-audit-merged-SHIP-2026-07-29.md).

## Server callables (live)

Prior set plus: `resolvePvPBattle`, `awardActivityRewards`, `cleanupFitRPGAccount`, **`adjustEnergy`**.

All FitRPG 1st-gen HTTPS callables: **App Check enforced** (`fitRpgOnCall`).

Deploy: `scripts/deploy-fitrpg-safe.sh` only.

## What works

- Battles: `participantUids`; client cannot set `winnerId`; CF derives winner / honors `surrenderedBy`
- Energy increases only via `adjustEnergy` (spend/refund/regen)
- Clan trophies immutable for clients; `memberIds` membership checks
- Online PvP settle → `resolvePvPBattle`
- World boss: energy + rate limit; client pre-check 15 energy
- FitRPG delete → `cleanupFitRPGAccount` (never recursive `users/{uid}`)

## Residual (non-blocking)

- Combat HP still client-synced among participants
- Story co-op not shipped (removed from UI)

## Do not re-flag as missing

`adjustEnergy`, participant battle rules, server-derived PvP winner, energy no client refill, clan trophies lock.
