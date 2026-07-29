# Backend Audit — 2026-07-29

Agent: `cec717cd-2240-43aa-bb67-21fe601156aa`. Token-efficient summary only.

## Verdict

**Economy / PvP NOT App Store ready.** Open Firestore rules + client-authoritative gold/XP/energy. Shop CF path is better; core economy/PvP still trust the client.

## TOP P0

| # | Finding |
|---|--------|
| 1 | `users` / `clans` / `battles` / `matchmaking` broadly writable (any auth) |
| 2 | `syncCharacter` overwrites economy + risk to sibling-app fields on shared `users/{uid}` |
| 3 | PvP rewards still client-side (`awardBattleRewards`) |
| 4 | `attackWorldBoss` — no energy spend |
| 5 | `resolvePvEBattle` trusts client outcome/rewards |
| 6 | `acceptFriendRequest` can force-friend |
| 7 | `recordClanWarAttack` trusts client `won` |
| 8 | `deleteAccount` `recursiveDelete(users/{uid})` — **cross-app wipe** |
| 9 | `processWorldBossCycle` double-reward race |

## Corrections vs stale notes

Do **not** treat these as missing/open:

- `shopCatalog.ts` — committed in `b73e79f` (not untracked)
- Live CF already exist: `declineFriendRequest`, `cancelClanWarSearch`, `purchaseItem`, `acceptFriendDuel`
- `world_bosses` — already `write: false` (stale “client spawn” note obsolete)

## Deploy

Always `scripts/deploy-fitrpg-safe.sh`. Never wipe sibling CF (`tryonWorker`, `tagGarment`, Food/Workout proxies). See [KI-firebase-ecosystem](./KI-firebase-ecosystem.md).

## Related

- [KI-multiplayer](./KI-multiplayer.md) — live callables + open gaps
- Full ecosystem dump (may be stale on corrections): `docs/audit/2026-07-29-firebase-ecosystem.md`
