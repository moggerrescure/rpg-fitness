# KI: Firebase Ecosystem (shared project)

## Scope
Firebase backend FitRPG в **shared** project `serzhanovich-ecosystem-ce700` (~5 apps). Читать **до любого deploy** functions/rules.

**Deploy FitRPG:** always `scripts/deploy-fitrpg-safe.sh`. Never wipe sibling CF (`tryonWorker`, `tagGarment`, Food/Workout proxies).

**Backend audit (concise):** [KI-audit-backend-REAUDIT-2026-07-29](./KI-audit-backend-REAUDIT-2026-07-29.md)  
**Prior audit:** [KI-audit-backend-2026-07-29](./KI-audit-backend-2026-07-29.md)  
**Полный отчёт (может быть stale):** [docs/audit/2026-07-29-firebase-ecosystem.md](../../docs/audit/2026-07-29-firebase-ecosystem.md)

---

## ⛔ NEVER Deploy Without Merge

| Action | Risk |
|--------|------|
| `firebase deploy --only functions` из rpg-fitness (committed) | **Wipes** Food/Workout CF: `vertexProxy`, `imageProxy`, `deleteAccount`, `moderateSharedWorkout`, `onReportCreated` (+ risk to `tryonWorker` / `tagGarment`) |
| `firebase deploy --only firestore:rules` из rpg-fitness | **Breaks Yoga** — нет `yoga_*` block |
| `firebase deploy --only firestore:rules` из FoodTracker | **Locks out FitRPG** — нет RPG block |
| Full `remote_config.json` deploy | Overwrites food/workout keys |

**Перед functions deploy:** merge `git stash@{0}` (+437 lines shared AI) в main. Use only `scripts/deploy-fitrpg-safe.sh`.

### Stash@{0} Contents

- `vertexProxy`, `imageProxy` — AI proxy (Food/Workout)
- `deleteAccount` — `recursiveDelete(users/{uid})`
- `moderateSharedWorkout`, `onReportCreated` — UGC moderation

---

## P0 Risks

| ID | Risk |
|----|------|
| F01 | Deploy functions wipes sibling CF |
| F02/F03 | Rules deploy breaks Yoga / FitRPG |
| F04 | Client writes gold/xp/stats (`syncCharacter`) |
| F05 | Any auth writes any `clans/*` |
| F06 | ~~Client spawns `world_bosses/current`~~ — **corrected:** `world_bosses` already `write: false` |
| F07 | Any auth writes any `battles/*` |
| F08 | `deleteAccount` → `recursiveDelete(users/{uid})` **cross-app wipe** (RPG + Stepper + Workout subcollections) |

More P0s (PvP rewards client-side, resolvePvEBattle trust, force-friend, clan war `won`, world boss race): see [KI-audit-backend-2026-07-29](./KI-audit-backend-2026-07-29.md).

---

## Open Writes (rules summary — post 2026-07-29 harden)

```
clans/*          → create leader; update limited fields; activeWar CF-only ✅
battles/*        → create/update combat OK; rewardsSettled CF-only ✅
matchmaking/*    → own ticket (+ invite target) ✅
users/{uid}      → economy/friends/progressions CF-only; gold decrease OK ✅
world_bosses/*   → write: false ✅
```

FitRPG account delete: **`cleanupFitRPGAccount`** (scoped). Do **not** call shared `deleteAccount` recursive wipe from FitRPG.

---

## Other Critical Notes

- **Secrets in git:** `remote_config.json` — `fatsecret_secret`, `pexels_api_key` (plaintext)
- **Corrections (2026-07-29 audit):** `declineFriendRequest`, `cancelClanWarSearch`, `purchaseItem`, `acceptFriendDuel` exist & deployed; `shopCatalog.ts` committed @ `b73e79f`
- **Dead CF vs client (may still apply):** some exported CF still bypassed client-side — verify before re-flagging
- **Safe deploy:** indexes additive ✅; Yoga functions `--only functions:yoga` ✅; FitRPG → `scripts/deploy-fitrpg-safe.sh`

---

## Ecosystem Apps

| App | Isolation |
|-----|-----------|
| FitRPG | No prefix — `users`, `clans`, … |
| FoodTracker / WorkoutTracker | Curated + CF moderation |
| Yoga1 | `yoga_*` prefix + codebase `yoga` ✅ |
| Stepper | `users/{uid}/workouts` subcollection |

---

## Fix Order (backend)

```
1. Merge stash → main (no deploy until done) ✅
2. Rules hardening + yoga block merge ✅
3. Economy CF + deny client gold writes ✅
4. Clan war single path ✅
5. App Check on sensitive FitRPG callables ✅ (REAUDIT2)
6. deleteAccount scope fix ✅ (cleanupFitRPGAccount; shared deleteAccount for Food/Workout only)
7. Rotate leaked secrets (ops)
```

---

## Agent Tip

Legacy KI [KI-firebase-backend](./KI-firebase-backend.md) — function map. Этот KI — **deploy safety + ecosystem risks**. При правках rules diff против `Yoga1/firebase/firestore.rules` и `FoodTracker/firestore.rules`.
