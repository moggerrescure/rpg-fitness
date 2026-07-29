# ADR-0001: Architecture overview (FitRPG / rpg-fitness)

## Status
Accepted

## Date
2026-07-29

## Context
Нужна стабильная карта системы для агентов: где живёт клиент, бэкенд и вспомогательные артефакты, чтобы не сканировать весь репозиторий (включая `.agents/skills`) и не жечь токены.

## Decision
Приложение — iOS SwiftUI-клиент + Firebase (Auth, Firestore, Cloud Functions, Remote Config, FCM, App Check). Источник правды по геймплею и мультиплееру — Cloud Functions; клиент синхронизирует персонажа/клан через `FirebaseService` и матчи через `MultiplayerService`.

### Layout
| Путь | Роль |
|------|------|
| `rpg-tracker/rpg-tracker/` | iOS app (SwiftUI): Views / ViewModels / Services / Models / Helpers |
| `rpg-tracker/FitRPGWidget/` | WidgetKit extension |
| `functions/src/index.ts` | Cloud Functions (matchmaking, clan war, world boss, friends/teams, leaderboards, PvE resolve, equip) |
| `discord-onboarding/` | Web-портал онбординга Discord (gh-pages) |
| `firestore.rules`, `firestore.indexes.json`, `remote_config.json` | Firebase config |
| `.agents/skills/` | Агентские скиллы — **не** runtime приложения |

### Клиентские слои
- **Entry:** `FitRPGApp` → auth / onboarding / version gate / network gate → `MainHubView`
- **Views → ViewModels → Services → Models** (Services — hotspot: `syncCharacter`, `syncClan`, matchmaking listeners)
- **Домены (кластеры графа):** character/XP/equip, clans, friends/duels, matchmaking/PvP, dungeon waves, HealthKit/camera reps, Apple/Google auth, version/Remote Config

### Backend callable / schedules (основные)
- Clan war: `matchmakeClanWar`, `recordClanWarAttack`, `processClanWarPhases` (*/5)
- World boss: `attackWorldBoss`, `processWorldBossCycle` (hourly)
- Social: `sendFriendRequest`, `acceptFriendRequest`, `searchPlayers`
- Teams/PvP: `inviteToTeam3v3`, `joinTeam`, `matchWithOpponent`, `fillTeammatesWithBots`, `triggerOpponentBotFallback`, `onMatchmakingTicketCreated`
- Economy/combat: `equipItem`, `resolvePvEBattle`, `getLeaderboards`

## Consequences
- Для навигации по коду использовать MCP-проекты `rpg-tracker` и `rpg-fitness-functions`, не полный `rpg-fitness` (там шум от skills).
- Локальный review-graph: `.code-review-graph/graph.db` в корне репо.
- Известный долг: часть функций/экранов может быть сломана или не доведена — чинить точечно по симптомам, не «рефакторить всё».
