# KI: Firebase Ecosystem (shared project)

## Scope
Firebase backend FitRPG в **shared** project `serzhanovich-ecosystem-ce700` (~5 apps). Читать **до любого deploy** functions/rules.

**Полный отчёт:** [docs/audit/2026-07-29-firebase-ecosystem.md](../../docs/audit/2026-07-29-firebase-ecosystem.md)

---

## ⛔ NEVER Deploy Without Merge

| Action | Risk |
|--------|------|
| `firebase deploy --only functions` из rpg-fitness (committed) | **Wipes** Food/Workout CF: `vertexProxy`, `imageProxy`, `deleteAccount`, `moderateSharedWorkout`, `onReportCreated` |
| `firebase deploy --only firestore:rules` из rpg-fitness | **Breaks Yoga** — нет `yoga_*` block |
| `firebase deploy --only firestore:rules` из FoodTracker | **Locks out FitRPG** — нет RPG block |
| Full `remote_config.json` deploy | Overwrites food/workout keys |

**Перед functions deploy:** merge `git stash@{0}` (+437 lines shared AI) в main.

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
| F06 | Client spawns `world_bosses/current` |
| F07 | Any auth writes any `battles/*` |
| F08 | `deleteAccount` → `recursiveDelete(users/{uid})` **cross-app wipe** (RPG + Stepper + Workout subcollections) |

---

## Open Writes (rules summary)

```
clans/*          → allow write: if request.auth != null   ❌
world_bosses/*   → allow write: if request.auth != null   ❌
battles/*        → allow write: if request.auth != null   ❌
matchmaking/*    → allow write: if request.auth != null   ❌
users/{uid}      → owner full write (gold, xp, trophies) ❌
```

---

## Other Critical Notes

- **Secrets in git:** `remote_config.json` — `fatsecret_secret`, `pexels_api_key` (plaintext)
- **Missing CF:** `declineFriendRequest` (client calls, no export)
- **Dead CF vs client:** `equipItem`, `matchmakeClanWar`, `recordClanWarAttack`, `getLeaderboards`, `searchPlayers`, `inviteToTeam3v3` — exported but client bypasses
- **Safe deploy:** indexes additive ✅; Yoga functions `--only functions:yoga` ✅

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
1. Merge stash → main (no deploy until done)
2. Rules hardening + yoga block merge
3. Economy CF + deny client gold writes
4. Clan war single path
5. App Check on sensitive callables
6. deleteAccount scope fix
7. Rotate leaked secrets
```

32 findings: F01–F32 в [полном аудите](../../docs/audit/2026-07-29-firebase-ecosystem.md).

---

## Agent Tip

Legacy KI [KI-firebase-backend](./KI-firebase-backend.md) — function map. Этот KI — **deploy safety + ecosystem risks**. При правках rules diff против `Yoga1/firebase/firestore.rules` и `FoodTracker/firestore.rules`.
