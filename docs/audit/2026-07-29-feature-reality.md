# Feature Reality Audit — FitRPG

**Date:** 2026-07-29  
**Scope:** Все фичи клиента `rpg-tracker/rpg-tracker/` + сверка с `functions/src/index.ts`  
**Method:** Grep + трассировка UI → VM/Service → Firestore/CF  
**Legend:** **REAL** — работает end-to-end · **PARTIAL** — играбельно, но с заглушками/обходом сервера · **MOCK** — UI есть, логика фиктивна · **BROKEN** — не компилируется / мёртвый код / явно сломано

---

## Summary counts

| Status | Count | Share |
|--------|-------|-------|
| **REAL** | 6 | 19% |
| **PARTIAL** | 21 | 66% |
| **MOCK** | 4 | 12% |
| **BROKEN** | 1 | 3% |
| **Total features** | 32 | 100% |

**Verdict:** Продукт **демонстрируем**, но **не production-ready** — большинство фич PARTIAL с client-authoritative economy и обходом Cloud Functions.

---

## Feature reality matrix (full)

| Feature | Status | Evidence (file:line) | What is mocked/missing | User-visible impact |
|---------|--------|----------------------|------------------------|---------------------|
| **Auth (anon)** | REAL | `AuthManager.swift:14-33`, `FitRPGApp.swift:77-97` | — | Анонимный вход при старте работает |
| **Auth (Apple/Google)** | MOCK | `SocialAuthService.swift:17-58` — реализация есть; **ни один View не вызывает** `signInWithApple`/`signInWithGoogle` | UI линковки аккаунта нет | Пользователь всегда аноним; прогресс привязан к anon UID |
| **Onboarding** | PARTIAL | `FitRPGApp.swift:98-104`, `RPGOnboardingView.swift` | Только `@AppStorage("hasCompletedOnboarding")`, без сервера | Сброс onboarding = переустановка/очистка данных |
| **Force update** | PARTIAL | `VersionManager.swift:19-44`, `RemoteConfigManager.swift`, `UpdateRequiredView.swift:8` | App Store URL = `id0000000000` (заглушка) | Hard/soft update работает, но кнопка «Ascend Now» ведёт в никуда |
| **Network gate** | REAL | `NetworkMonitor.swift:17-30`, `FitRPGApp.swift:72-76`, `NoInternetView.swift` | Retry-кнопка не перепроверяет сеть (P2) | Блокирующий экран без сети |
| **MainHub tabs** | REAL | `MainHubView.swift:17-58` | — | 5 табов: Home, Training, Arena, Clan, World Boss |
| **Character / class** | REAL | `ClassSelectionVM.swift:23-94`, Firestore `users/{uid}` | Username-check при ошибке сети пропускается (`:58-59`) | Создание персонажа через Firestore |
| **Skill tree** | PARTIAL | `ConstellationSkillTreeView.swift:428` → `syncCharacter` | Stat points только на клиенте, без CF | Можно накрутить очки через клиент |
| **Shop** | PARTIAL | `ArmoryShopView.swift:88-125` | Gold списывается клиентом; StoreKit нет | Покупки работают, но без серверной валидации |
| **Inventory / equip** | PARTIAL | `InventoryView.swift:308`, `FirebaseService.swift:913-925` | CF `equipItem` **не вызывается**; `showInventory` unreachable | Экипировка без проверки владения; экран inventory недоступен из UI |
| **XP / gold** | PARTIAL | `FirebaseService.swift:243-327`, `awardBattleRewards`, `awardWorkoutRewards` | Награды PvP/workout/clan reps пишутся клиентом | Работает, но читабельно |
| **Daily quests** | MOCK | `DailyQuestEngine.swift:92-101`, `MainHubView.swift:838-902` | Progress=0 для pvp/dungeon/steps/calories/shop/equip; **нет claim/reward** | UI «completed», награды не выдаются |
| **HealthKit sync** | PARTIAL | `HealthKitService.swift:44-84`, `FirebaseService.swift:560-585` | Конверсия steps/kcal → XP/gold/damage на клиенте | Синк реален, античит HealthKit — нет |
| **Camera AI reps** | PARTIAL | `CameraManager.swift:56-63`, `AITrackerEngine.swift`, `CameraTrackingView.swift:361` | На устройстве — Vision REAL; `SimulatedCameraFeed` / `simulateRepetition()` не используются; симулятор — пустая камера | Free training: 15 XP + 5 gold **за rep** без лимитов |
| **Live Activity** | REAL | `LiveActivityManager.swift:12-99`, `CameraTrackingVM.swift:196` | — | Dynamic Island / Lock Screen при тренировке |
| **Push notifications** | PARTIAL | `FitRPGApp.swift:127-128`, `NotificationManager.swift:23-35`, CF `sendPushNotification` | `aps-environment: development`; FCM token race до load character | Push частично |
| **In-app notifications** | PARTIAL | `NotificationManager.swift:39-107`, Firestore subcollection | Кнопка **«Send Test Notification»** в prod UI (`NotificationCenterView.swift:61-71`) | Реальный listener; debug-кнопка видна пользователю |
| **Friends** | PARTIAL | `FriendsVM.swift`, CF `sendFriendRequest`/`acceptFriendRequest` | Legacy `firebaseService.friends` (UserDefaults usernames) параллельно UID-friends; `declineFriendRequest` CF missing | Friends tab REAL; decline broken; Clan «add ally by name» — MOCK |
| **Duels** | PARTIAL | `MultiplayerService.swift:389-496`, CF `matchWithOpponent` | Friend duel fallback → random matchmaking (`FirebaseService.swift:532-537`); награды клиентом | Дуэли работают; fallback маскирует «не найден» |
| **Team 3v3 lobby** | PARTIAL | `TeamLobbyView.swift`, `MultiplayerService.swift:126-297` | `startTeamBattle` **всегда** заполняет ally+opp ботами (`:250-274`) | «GO NOW» = solo vs bots, не real matchmaking |
| **Matchmaking PvP** | PARTIAL | `MultiplayerService.swift:531-651`, CF paths | Локальные fallback-таймеры 10s/20s; `% ;` на `:241` ломает build; PvP timer client-side | Real PvP возможен, но бот — частый исход |
| **PvE story / dungeon** | PARTIAL | `DungeonVM.swift`, `DungeonRunView.swift` | Локальные boss timers; победа → CF `resolvePvEBattle` | Играбельно; combat локальный, лут через CF |
| **World boss** | PARTIAL | `FirebaseService.swift:40-75`, CF `attackWorldBoss` | Клиент создаёт локального босса если Firestore пуст (`ensureWorldBossExists :57-74`) | Рейд работает; при пустой БД — client spawn |
| **Clan create/join** | REAL | `FirebaseService.swift:376-639` | Client-generated clan id `clan_{uuid}` | Создание/вступление через Firestore |
| **Clan war** | MOCK | `FirebaseService.swift:712-845`, `ClanVM.swift:102-112` | CF `matchmakeClanWar`/`recordClanWarAttack` **не вызываются**; client matchmaking +2 score | Война «работает» в UI, без серверной авторитетности |
| **Leaderboards** | PARTIAL | `FirebaseService.swift:848-910` | CF `getLeaderboards` **не вызывается**; friends board по legacy username | Данные реальные, обход CF; friends board часто пуст |
| **Profile** | PARTIAL | `PlayerProfileView.swift` | **Нет** Privacy/Terms/Delete/Link account; achievements hardcoded unlocked | Compliance-фичи отсутствуют |
| **Widget** | MOCK | `FitRPGWidget.swift:26-47` | `getTimeline` всегда level=1; нет App Group | Виджет показывает фиктивный прогресс |
| **Discord onboarding** | REAL | `discord-onboarding/app.js:2`, `index.html` | Не интегрирован в iOS app | Web-воронка → Discord invite |
| **Sounds / haptics** | PARTIAL | `BattleArenaView.swift:1590,1613`, `Theme.swift:117` | Haptics точечно; нет audio engine | Минимальная тактильность |
| **Boss Raid (Arena tab)** | PARTIAL | `BossRaidView.swift:1016-1024` | Награды **только** `syncCharacter`, без `resolvePvEBattle` | Победа = клиентский XP/gold |
| **BattleEngine (legacy)** | BROKEN | `BattleEngine.swift:16-85` | `startBossRaid`/`startBotDuel` **нигде не вызываются** | Мёртвый код |

---

## Critical mock/stub list

### P0 — блокеры продакшена / compliance / чит

| # | Issue | Evidence |
|---|-------|----------|
| 1 | **Build broken** — `% ;` в MultiplayerService | `MultiplayerService.swift:241` |
| 2 | Apple/Google Sign-In не подключены к UI | `SocialAuthService.swift` vs отсутствие вызовов в Views |
| 3 | Delete account / reauth не подключены | `AuthManager.deleteCurrentUser`, `SocialAuthService.reauthenticateForDeletion` без UI; CF `deleteAccount` только в stash |
| 4 | Privacy Policy / Terms отсутствуют в app | Нет ссылок в `PlayerProfileView`; guide устарел |
| 5 | Clan war обходит Cloud Functions | Client `startClanWar`/`recordClanWarBattle` vs CF `matchmakeClanWar`/`recordClanWarAttack` |
| 6 | PvP/Boss Raid/workout награды без серверной валидации | `awardBattleRewards`, `BossRaidView.triggerVictory` |

### P1 — функциональные заглушки

| # | Issue | Evidence |
|---|-------|----------|
| 7 | Daily quests — нет трекинга и выплат | `DailyQuestEngine.swift:99` |
| 8 | Widget — статические placeholder-данные | `FitRPGWidget.swift:36-47` |
| 9 | Force update App Store link заглушка | `UpdateRequiredView.swift:8` — `id0000000000` |
| 10 | Team lobby «GO NOW» — всегда bots | `MultiplayerService.swift:250-274` |
| 11 | CF `equipItem` / `getLeaderboards` / `searchPlayers` / `inviteToTeam3v3` не используются | Client дублирует логику |
| 12 | Dual friends: UID vs username legacy | `FirebaseService.swift:206-218`, `ClanDashboardView.swift:1418` |
| 13 | Test notification button в prod UI | `NotificationCenterView.swift:61-71` |
| 14 | Hardcoded achievements always unlocked | `PlayerProfileView.swift:452,455` |

### P2 — tech debt / dead code

| # | Issue |
|---|-------|
| 15 | `SimulatedCameraFeed`, `simulateRepetition()`, `BattleEngine.startBotDuel/startBossRaid` — не используются |
| 16 | `CameraManager.isSimulator` выставляется, UI не переключается |
| 17 | `#if DEBUG` App Check debug factory — штатно для dev |
| 18 | Root scripts `connect_firestore.js`, `fix_firebase_leaderboard.js`, `clean_mocks.js` — артефакты |

---

## Designed bots vs accidental mocks

| Designed bots (intentional) | Real path alive? | Accidental / bypass mocks |
|-----------------------------|------------------|---------------------------|
| CF `fillTeammatesWithBots` + client timer 10s | Да: `matchWithOpponent` + tickets | Local fill if CF fail |
| CF `triggerOpponentBotFallback` + timer 20s | Да | Local battle doc creation |
| Clan war Shadow Bot + cron score sim (CF) | **Нет на клиенте** — CF не вызывается | Client `startClanWar` — другой path |
| Team lobby bot slots UI | Invite path REAL | `startTeamBattle` **всегда** bot opponents |
| Friend duel → matchmaking if not found | Masking, not labeled | User thinks friend duel, gets random/bot |

**Вывод:** Bot fallbacks для 1v1/3v3 queue **живы** (CF + Firestore), но **team lobby** и **локальные fallback-и** сводят real-path к bots-only.

---

## Client paths that bypass Cloud Functions

| Action | Client path | Server CF exists? | Risk |
|--------|-------------|-------------------|------|
| Equip item | `FirebaseService.equipItem` → `syncCharacter` | `equipItem` ✅ | Надеть чужой/несуществующий item |
| Shop purchase | `ArmoryShopView` gold -= client | — | Infinite gold |
| PvP rewards / trophies | `awardBattleRewards` → Firestore | — | Self-grant XP/gold/trophies |
| Boss Raid victory | `BossRaidView.triggerVictory` syncCharacter | `resolvePvEBattle` ✅ | XP/gold без server loot roll |
| Workout finish | `awardWorkoutRewards` | — | Rep → reward без camera proof |
| Health sync | `handleHealthSync` | partial (`attackWorldBoss`) | Inflate steps/calories |
| Clan war start/score | `startClanWar`, `contributeWarScore`, `recordClanWarBattle` | `matchmakeClanWar`, `recordClanWarAttack` ✅ | Fake wars/scores |
| Leaderboards | Direct Firestore queries | `getLeaderboards` ✅ | Same data, no server cache |
| Player search | `FirebaseService.searchPlayers` | `searchPlayers` ✅ | Duplicate impl |
| Team invite | Firestore + `NotificationManager` | `inviteToTeam3v3` ✅ | Inconsistent |
| World boss spawn | `ensureWorldBossExists` local write | `processWorldBossCycle` cron ✅ | Client can seed boss doc |
| Stat points / skill tree | `syncCharacter` | — | Inflate stats |
| Matchmaking battle end | Client winner + `awardBattleRewards` | — | Host/client dispute |

---

## Recommended fix order (make everything REAL)

1. **Compliance block** — UI: Sign in with Apple/Google, Privacy/Terms URLs, Delete Account flow
2. **Fix `MultiplayerService.swift:241`** — восстановить компиляцию (Phase 0)
3. **Server-authoritative economy** — CF для workout reward, PvP end, shop buy, stat spend
4. **Wire existing CFs** — `matchmakeClanWar`, `recordClanWarAttack`, `equipItem`, `getLeaderboards`; Boss Raid → `resolvePvEBattle`
5. **Daily quests** — Firestore progress doc + server claim
6. **Team 3v3 lobby** — real matchmaking после fill teammates, не hardcoded bots
7. **Remove legacy friends** — один источник: `Character.friends[]` UIDs
8. **Widget** — App Group + write from `FirebaseService.syncCharacter`
9. **Force update** — реальный App Store ID
10. **Cleanup** — dead code, gate debug UI `#if DEBUG`
11. **HealthKit anti-cheat** (later) — server caps, anomaly detection

---

## Related documents

- [Master audit](./2026-07-29-MASTER.md)
- [iOS client audit](./2026-07-29-ios-client.md)
- [Firebase ecosystem audit](./2026-07-29-firebase-ecosystem.md)
- [App Store readiness](./2026-07-29-app-store-readiness.md)
- KI: [`.agents/knowledge/KI-feature-reality.md`](../../.agents/knowledge/KI-feature-reality.md)

---

*Generated: 2026-07-29 | Source: mocks/stubs feature pass*
