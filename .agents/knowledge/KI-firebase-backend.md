# KI: Firebase backend

## Project
Firebase project id (из setup guide): `serzhanovich-ecosystem-ce700`

## Repo artifacts
| File | Role |
|------|------|
| `functions/src/index.ts` | Все Cloud Functions |
| `firestore.rules` | Security rules |
| `firestore.indexes.json` | Composite indexes (leaderboards и др.) |
| `remote_config.json` | Force-update keys: `rpg_minimum_ios_version`, `rpg_recommended_ios_version` |
| `firebase.json` | Deploy targets |

## Auth (client)
- Anonymous bootstrap + link Apple/Google (`SocialAuthService` / `AuthManager`)
- App Check debug factory in DEBUG

## Functions map (server authority)
Callable: clan war attack/matchmake, world boss attack, friends search/request/accept, team invite/join, matchmaking + bot fallbacks, equip, resolve PvE, leaderboards.  
Scheduled: clan war phases every 5m; world boss cycle hourly.  
Trigger: `onMatchmakingTicketCreated` (Firestore).

## Client sync surface
`FirebaseService` — character/clan sync, world boss attack, leaderboards (with fallbacks).  
Правила и CF — источник истины для sensitive действий; клиентские таймеры/моки в мультиплеере считаются tech debt.

## Local WIP
`git stash@{0}`: незакоммиченные правки `functions/src/index.ts` (сняты перед pull). Проверить перед работой над functions.

## Agent tip
MCP project: `rpg-fitness-functions`. Для полного текста экспортов — `functions/src/index.ts` (граф CF тонкий: мало AST-функций).
