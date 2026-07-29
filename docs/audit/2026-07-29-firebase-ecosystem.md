# Firebase Ecosystem Audit — FitRPG

**Date:** 2026-07-29  
**Project:** `serzhanovich-ecosystem-ce700` (shared)  
**Sources:** `functions/src/index.ts`, `firestore.rules`, `firestore.indexes.json`, sibling repos  
**WIP:** `git stash@{0}` — +437 lines (`vertexProxy`, `deleteAccount`, …). **Не применялся.**

> ⛔ **DO NOT `firebase deploy` until stash merge + ecosystem checklist**

---

## Ecosystem map

| App | Repo | Collections / notes |
|-----|------|---------------------|
| **FitRPG** | `rpg-fitness` | `users`, `clans`, `world_bosses`, `battles`, `matchmaking` |
| **FoodTracker** | `FoodTracker` | `premium_recipes`, `academy_*`, `diets`, … |
| **WorkoutTracker** | `WorkoutTracker-repo` | `legendary_routines`, `shared_workouts`, `reports`, … |
| **Yoga1** | `Yoga1` | `yoga_users`, `yoga_leaderboard` (separate functions codebase `yoga`) |
| **Stepper** | `Stepper` | `users/{uid}/workouts` |

**Shared:** Auth UID pool, `users/{uid}` root, default functions codebase, one ruleset, Remote Config template.

**Isolation gaps:** FitRPG без префикса; `rpg-fitness/firestore.rules` **без** `yoga_*` → deploy rules откатывает Yoga.

---

## P0 security / break-other-apps

1. Deploy functions из rpg-fitness (committed) → **wipes** Food/Workout CF (`vertexProxy`, `deleteAccount`, moderation)
2. Deploy rules из rpg-fitness → **breaks Yoga** (no `yoga_*` block)
3. Deploy rules из FoodTracker → **locks FitRPG**
4. `deleteAccount` (Food/Workout) → `recursiveDelete(users/{uid})` → **cross-app wipe**
5. Client writes gold/xp/stats — rules owner full write
6. `clans` — any authed user writes any clan
7. `world_bosses`, `battles`, `matchmaking` — open write
8. Secrets in `remote_config.json` (fatsecret, pexels keys)

---

## Findings (F01–F32)

| ID | Sev | Title |
|----|-----|-------|
| F01 | P0 | Default codebase wipe on functions deploy |
| F02 | P0 | Rules deploy breaks Yoga |
| F03 | P0 | Food rules deploy locks RPG |
| F04 | P0 | Client writes gold/xp/stats |
| F05 | P0 | Any user writes any clan |
| F06 | P0 | Client can spawn/reset world boss |
| F07 | P0 | Any user writes any battle |
| F08 | P0 | deleteAccount cross-app wipe |
| F09 | High | resolvePvEBattle trusts client rewards |
| F10 | High | attackWorldBoss chunk bypass |
| F11 | High | joinTeam no membership proof |
| F12 | High | fillTeammates/triggerBot no host check |
| F13 | High | matchWithOpponent race |
| F14 | High | Clan war bypasses CF (client path) |
| F15 | High | BossRaid rewards client-only |
| F16 | High | PvP trophies client-side |
| F17 | High | removeFriend IDOR |
| F18 | High | Full user docs exposed |
| F19 | High | Notification spam vector |
| F20 | Med | declineFriendRequest missing |
| F21–F32 | Med/Low | CF trust, dead code, indexes, secrets, health sync |

Full detail: see audit transcript / [MASTER](./2026-07-29-MASTER.md) P0/P1 sections.

---

## Per-function checklist (summary)

| Verdict | Functions |
|---------|-----------|
| **OK** | `sendFriendRequest`, `acceptFriendRequest`, `onMatchmakingTicketCreated` |
| **WARN** | `matchmakeClanWar`, `processClanWarPhases`, `attackWorldBoss`, `equipItem`, `getLeaderboards`, `searchPlayers`, `inviteToTeam3v3` (many unused/dead vs client) |
| **FAIL** | `recordClanWarAttack`, `joinTeam`, `matchWithOpponent`, `resolvePvEBattle`, `fillTeammatesWithBots`, `triggerOpponentBotFallback`; **missing** `declineFriendRequest` |
| **Stash only** | `vertexProxy`, `imageProxy`, `deleteAccount`, `moderateSharedWorkout`, `onReportCreated` |

---

## Deploy safety

| Artifact | Safe locally | Dangerous in shared project |
|----------|--------------|----------------------------|
| `functions/src/index.ts` | Build, emulator | Full `firebase deploy --only functions` |
| `firestore.rules` | Edit + diff | Deploy without yoga+RPG+food+workout merge |
| `firestore.indexes.json` | Add indexes | Relatively safe (additive) |
| `remote_config.json` | Edit `rpg_*` only | Full template overwrites sibling keys |
| Yoga functions | — | `firebase deploy --only functions:yoga` ✅ |

---

## Recommended fix order (backend)

1. Stop deploy until stash merge + ecosystem checklist
2. Rules hardening (incremental): world_bosses, battles, matchmaking, users economy fields
3. Economy CF: server reward tables; deny client gold updates
4. Clan war single path: wire client → CF or remove dead CF
5. Matchmaking authz: host checks, transactions
6. App Check + rate limits on economy/combat callables
7. Indexes for clan war + matchmaking
8. deleteAccount scope: app-aware deletion
9. Secrets: rotate + Secret Manager
10. Hygiene: `declineFriendRequest`; wire or remove dead CF

---

## Related

- [MASTER audit](./2026-07-29-MASTER.md)
- [Feature reality](./2026-07-29-feature-reality.md)
- [KI-firebase-backend.md](../../.agents/knowledge/KI-firebase-backend.md)

*Generated: 2026-07-29*
