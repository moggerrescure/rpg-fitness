# iOS Re-Audit — 2026-07-29 (post-fix)

After client P0 fixes aligned with server economy lock.

## Verdict

**Client P0 blockers addressed.** Not all P1 (story co-op, App Check Release, push entitlements, friend-duel error UX) closed.

## P0 status

| # | Finding | Status |
|---|---------|--------|
| 1 | Delete account Auth | **FIXED** — always `Auth.user.delete()` after `cleanupFitRPGAccount` |
| 2 | Auth hang Connecting… | **FIXED** — `authError` + Retry UI |
| 3 | WB energy no refund | **FIXED** — no client prepaid; server charges on damage submit |
| 4 | Camera denied blank | **FIXED** — Settings CTA overlay |
| 5 | Free training UNLIMITED / double rewards | **FIXED** — cap UI; per-rep no longer awards; finish path only |
| 6 | Dead daily quests | **FIXED** — steps/calories/dungeon/gold wired |

## Also changed

- `syncCharacter` merge without economy/friends overwrite
- Online PvP → `resolvePvPBattle` (not client `awardBattleRewards`)
- Activity rewards → `awardActivityRewards` CF

## Remaining P1 (sample)

- Story co-op dead paths
- Friend duel CF fail → bot queue messaging
- Clan CF silent errors → toasts
- Background auto-surrender PvP UX
- App Check Release provider
- Push `aps-environment=production`
- `matchWithOpponent` myTicketId race / 3v3 invite edge cases

## Related

- [KI-audit-merged-REAUDIT-2026-07-29](./KI-audit-merged-REAUDIT-2026-07-29.md)
