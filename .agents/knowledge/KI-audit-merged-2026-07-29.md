# Merged Audit — App Store Readiness — 2026-07-29

Sources: iOS `acf146b1` · backend `cec717cd`. Token-efficient combined verdict.

## Verdict

**NOT ready for App Store.**

Client has account-deletion / auth / economy / quest blockers. Server has open Firestore writes + client-authoritative economy/PvP. Ship only after TOP fixes below.

## Client P0

| # | Finding |
|---|--------|
| 1 | Delete account Auth — linked users: no `user.delete()` (5.1.1v) |
| 2 | Auth hang — anonymous fail → eternal spinner |
| 3 | WB energy — spend on Attack, no refund on exit |
| 4 | Camera denied UI — blank workout, no Settings CTA |
| 5 | Free training economy — «UNLIMITED» vs silent cap 50 + double awards |
| 6 | Dead daily quests — steps/calories/dungeon/gold types stuck |

## Server P0

| # | Finding |
|---|--------|
| 1 | Open Firestore rules — `users` / `clans` / `battles` / `matchmaking` broadly writable |
| 2 | Client economy — `syncCharacter` overwrites gold/XP/energy (+ sibling-field risk) |
| 3 | PvP rewards client — `awardBattleRewards` still client-side |
| 4 | World boss no energy — `attackWorldBoss` does not spend energy |
| 5 | `resolvePvE` trust — client outcome/rewards trusted |
| 6 | `acceptFriendRequest` force-friend |

(Backend audit also: `recordClanWarAttack` trusts `won`; `deleteAccount` recursive wipe cross-app; WB cycle double-reward race.)

## TOP 10 fix order (merged)

1. **Firestore rules** — lock `users`/`clans`/`battles`/`matchmaking` (server writes / field-scoped only)
2. **Delete account Auth** — always `user.delete()` after reauth (client + FitRPG-scoped CF)
3. **Server economy** — stop client `syncCharacter` overwrites; server-authoritative gold/XP/energy
4. **PvP rewards server-side** — remove client `awardBattleRewards` trust path
5. **World Boss energy** — server spend on attack + client refund/prepaid alignment
6. **Auth hang + camera denied UI** — retry UI; Settings CTA
7. **Free training** — honest cap UI + single reward path
8. **Daily quests** — wire progress or drop dead types from pool
9. **`resolvePvE` + friend accept** — stop trusting client outcome; no force-friend
10. **Surface multiplayer CF errors** — friend duel / clan war / matchmaking toasts (stop silent bot «success»)

## Counts snapshot

| Side | P0 | Notes |
|------|----|-------|
| iOS | 6 | + P1×22 P2×18 |
| Backend | 6+ | open rules + economy/PvP trust chain |

## Deploy

`scripts/deploy-fitrpg-safe.sh` only. No sibling CF wipe. See [KI-firebase-ecosystem](./KI-firebase-ecosystem.md).

## Related

- [KI-audit-ios-2026-07-29](./KI-audit-ios-2026-07-29.md)
- [KI-audit-backend-2026-07-29](./KI-audit-backend-2026-07-29.md)
- [KI-app-store-compliance](./KI-app-store-compliance.md)
