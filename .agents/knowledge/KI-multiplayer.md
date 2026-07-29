# KI: Multiplayer / social combat

## Client
- `MultiplayerService` — tickets, listen to battle, leave match, bot fallbacks
- UI: `BattleArenaView`, `TeamLobbyView`, `FriendBattlePrepSheet`, `BossRaidView`, `WorldBoss*`, `ClanDashboardView`, `FriendsView`
- VMs: `BattleVM`, `ClanVM`, `FriendsVM`, `DungeonVM` (waves / story)

## Server
- Matchmaking: `matchWithOpponent`, `onMatchmakingTicketCreated`, `fillTeammatesWithBots`, `triggerOpponentBotFallback`
- Clan war: matchmake / record attack / scheduled phase processor
- World boss: `attackWorldBoss` + hourly cycle
- Friends/teams: request/accept/search, `inviteToTeam3v3`, `joinTeam`

## Design intent
Урон боссам, clan wars, loot generation — на сервере (Cloud Functions). Клиент слушает Firestore/realtime и отображает.

## Risk zones (часто ломается)
- Расхождение клиентского `BattleEngine` / локальных таймеров с CF
- Matchmaking host/guest listeners (`listenToTicketAsHost`, `listenToBattle`)
- Bot fallback race conditions
- Clan sync vs war phase schedule
- Leaderboard indexes (`firestore.indexes.json` must be deployed)

## Agent tip
При баге: сначала воспроизвести call chain View → MultiplayerService/FirebaseService → имя callable в `functions/src/index.ts` через `trace_path` / `search_code`.
