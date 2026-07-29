# iOS Client Audit — FitRPG

**Date:** 2026-07-29  
**App:** `rpg-tracker/rpg-tracker/` (SwiftUI)  
**HEAD:** `main@341308d`  
**Method:** Static analysis + сверка с `functions/src/index.ts`, `firestore.rules`  
**Build note:** Сборка в CI-окружении не выполнялась; байтовая проверка подтверждает `% ;` на `MultiplayerService.swift:241`

---

## Executive Summary

FitRPG iOS-клиент функционально насыщен (HealthKit, камера/AI, PvP, кланы, world boss, Live Activity), но **не собирается** из-за P0 синтаксической ошибки и содержит **критический tech debt**: экономика, clan war и world boss в основном client-authoritative; dual friends system; отсутствие social auth UI; daily quests и widget не работают как задумано.

**Findings:** 32 (F001–F032): 1× P0, 11× P1, 15× P2, 5× P3

---

## Summary (key bullets)

- **P0:** `MultiplayerService.swift:241` — синтаксическая ошибка `% ;` — проект не компилируется
- **P0/P1:** Клиент вызывает `declineFriendRequest`, но такого callable **нет** на сервере — отклонение заявки в друзья падает
- **P1:** Clan war полностью на клиенте (`startClanWar`, `recordClanWarBattle` +2 очка) — серверные `matchmakeClanWar` / `recordClanWarAttack` (+100) **не используются**
- **P1:** Экономика (gold, покупка, экипировка) — клиент пишет в Firestore напрямую; CF `equipItem` не вызывается — чит/рассинхрон
- **P1:** Firestore rules слишком открыты: любой auth-пользователь может писать `clans`, `battles`, `world_bosses`, `matchmaking`
- **P1:** `ensureWorldBossExists()` создаёт world boss на клиенте и пишет в Firestore — обход серверного цикла
- **P1:** Две параллельные системы друзей: UID (`Character.friends`) vs legacy username (`FirebaseService.friends` + UserDefaults); leaderboard «friends» фильтрует по username
- **P1:** `SocialAuthService` есть, UI входа Apple/Google **нет** — все остаются anonymous
- **P1:** Privacy Policy / ToS **отсутствуют** в `PlayerProfileView` — блокер App Store (см. также [App Store audit](./2026-07-29-app-store-readiness.md))
- **P2:** Daily quests: прогресс считается только для reps; PvP/dungeon/steps/equip/shop — всегда 0%
- **P2:** Widget — статические placeholder-данные, App Group не настроен
- **P2:** Free training даёт 15 XP + 5 gold **за каждый rep** без лимитов
- **P2:** `InventoryView` подключён, но `showInventory` нигде не становится `true`
- **Solid:** Gates pipeline, Firestore listeners, matchmaking CF core, PvP transactions, `resolvePvEBattle`, Live Activity + camera tracker, UI/Theme polish

---

## Findings (F001–F032)

| ID | Severity | Area | Title | Evidence | Impact | Fix hint |
|----|----------|------|-------|----------|--------|----------|
| F001 | **P0** | Build | Синтаксическая ошибка в MultiplayerService | `MultiplayerService.swift:241` — `% ;` перед `let ticketIdToDelete` | Проект не собирается | Удалить `% ;` |
| F002 | **P1** | Friends | `declineFriendRequest` отсутствует на сервере | Клиент: `FirebaseService.swift:506-512`; сервер: нет export в `functions/src/index.ts` | Decline всегда fail (только print) | Добавить CF или клиентский Firestore update |
| F003 | **P1** | Clan war | Clan war обходит Cloud Functions | Клиент: `startClanWar()` :712-775, `recordClanWarBattle()` :822-845; сервер: `matchmakeClanWar`, `recordClanWarAttack` (+100 за win) | Две клановые войны, расхождение счёта (+2 vs +100), race conditions | Вызывать server CF; убрать client matchmaking |
| F004 | **P1** | Economy | Покупка/экипировка только на клиенте | `ArmoryShopView.swift:86-114`, `FirebaseService.equipItem` :913-926 — прямой `syncCharacter`; CF `equipItem` не вызывается | Gold/items можно накрутить через Firestore | Покупка/equip через CF + validation |
| F005 | **P1** | Security | Открытые Firestore rules | `firestore.rules:129-155` — write для clans/battles/world_bosses любому auth | Подмена clan war, boss HP, battle state | Ужесточить rules; sensitive ops только через CF |
| F006 | **P1** | World boss | Клиент создаёт world boss | `FirebaseService.ensureWorldBossExists()` :57-75 | Любой клиент может засpawnить/перезаписать boss | Только сервер `processWorldBossCycle`; клиент — read-only |
| F007 | **P1** | Friends | Dual friends system | Legacy: `addFriend(name:)` :206-213, `leaderboards["friends"]` :870; UID: `FriendsVM`, `Character.friends`; Clan tab: `ClanDashboardView` ~1338 | Старые друзья по имени ≠ новые по UID; friends LB пустой | Удалить legacy; мигрировать на UID |
| F008 | **P1** | Auth | Social login без UI | `SocialAuthService.swift` — только service; grep — нет вызовов из Views | Anonymous-only; потеря прогресса при reinstall | UI Sign in with Apple/Google в onboarding/profile |
| F009 | **P1** | App Store | Privacy/ToS отсутствуют | `PlayerProfileView.swift` — нет ссылок; `MANUAL_SETUP_GUIDE.md:53-56` устарел | Rejection Guideline 5.1.1 | Добавить Link + реальные URL |
| F010 | **P1** | PvE/BattleEngine | Boss attack timer hardcoded 120s | `BattleEngine.tick()` :111-112 — `totalElapsed = 120 - battle.secondsRemaining` для всех типов | В 60s duels boss атакует в 2× реже | Использовать `battle.secondsRemaining` initial duration |
| F011 | **P1** | Economy | Free training XP/gold exploit | `CameraTrackingVM.swift:169-170` — `awardBattleRewards(15, 5)` per rep без battle | Бесконечный farm gold/XP | Лимит reps/session или только через workout sync |
| F012 | **P1** | 3v3 | Host lobby стартует bots локально | `startTeamBattle()` :239-297 — client-side bot fill; CF `fillTeammatesWithBots` только в другом path | Расхождение team state между клиентами | Единый path через CF |
| F013 | **P2** | Daily quests | Большинство квестов не трекаются | `DailyQuestEngine.progress()` :92-101 — только squats/pushups/pullups/dips; default → 0 | PvP/dungeon/steps/equip/shop квесты никогда не complete | Persist daily progress + hooks в соответствующих flows |
| F014 | **P2** | Widget | Placeholder data | `FitRPGWidget.swift:36-46` — hardcoded level 1 | Виджет бесполезен | App Group + write из `FirebaseService.syncCharacter` |
| F015 | **P2** | Network | Retry button noop | `NoInternetView.swift:147-151` — только flash animation | UX frustration offline | Trigger NWPathMonitor re-check или `NetworkMonitor` refresh |
| F016 | **P2** | Localization | RU onboarding + EN UI | `RPGOnboardingView.swift:12-69` RU; rest EN hardcode | Inconsistent UX; no App Store localization story | `Localizable.strings` или единый язык |
| F017 | **P2** | Accessibility | Zero a11y labels | grep `accessibilityLabel` — 0 matches | VoiceOver unusable | Labels на nav, buttons, progress bars |
| F018 | **P2** | Profile | Inventory unreachable | `PlayerProfileView` — `showInventory` :12, fullScreenCover :478; нет trigger | Мёртвый экран | Кнопка «Inventory» или удалить |
| F019 | **P2** | Achievements | Hardcoded unlocks | `PlayerProfileView.swift:452-455` — `First Rep`, `Gladiator` unlocked: true | Ложная прогрессия | Derive from `pvpWins`, stats |
| F020 | **P2** | Constellation | Unlock logic broken | `isNodeUnlocked()` :406-417 — сравнение baseStat > 10 + index/2 | Nodes unlock out of order / wrong | Track unlocked node IDs on Character |
| F021 | **P2** | Energy | No regen; consume doesn't block | `consumeEnergy` :549-557; PvP `min(10, energy)` :534-535; `scheduleEnergyRestored` never called | Energy meaningless | Regen timer + block when energy=0 |
| F022 | **P2** | HealthKit | Authorization flag inaccurate | `HealthKitService.requestAuthorization()` :40-41 — `isAuthorized = true` always | Sync fails silently if denied | Check `authorizationStatus` per type |
| F023 | **P2** | FCM | Token lost before character load | `updateFCMToken` :929-933 — guard `currentCharacter`; FCM in `FitRPGApp` :49-54 at launch | Push notifications miss | Queue token until character exists |
| F024 | **P2** | Version gate | Placeholder App Store URL | `UpdateRequiredView.swift:8` — `id0000000000` | Hard update → broken link | Real App Store ID |
| F025 | **P2** | Class creation | Username check not lowercase | `ClassSelectionVM.swift:46-48` — `username` exact match, not `usernameLower` | Duplicate names differing case | Check `usernameLower` field |
| F026 | **P2** | Class creation | Starter gear not in ownedEquipmentIds | `ClassSelectionVM` :66-80 — только equip IDs, default owned list из Character init | Edge case: server equip validation may reject | Explicit `ownedEquipmentIds` on create |
| F027 | **P2** | BattleVM | Potential double world boss damage | `BattleVM` :99 — `attackWorldBoss` on complete; `BattleEngine` :263-265 per rep if `isGlobalWorldBoss` | Inflated boss damage (if path used) | Single damage submission path |
| F028 | **P3** | Dead code | Legacy friends in ClanDashboard | `ClanDashboardView` ~1338 — `removeFriend(name:)` | Confusion, duplicate UI | Remove or redirect to FriendsView |
| F029 | **P3** | Dead code | Legacy components | `MainHubView` — `SlotCard`, `QuestRow` :1058-1126 | Bloat | Delete if unused |
| F030 | **P3** | MainHub | Unused state | `MainHubView` — `showTeamLobby` :12 never toggled | Dead state | Wire or remove |
| F031 | **P3** | CF unused | `getLeaderboards`, `searchPlayers` CF | Server exports exist; client uses Firestore direct | Duplicate logic; index dependency on client | Pick one path |
| F032 | **P3** | CF unused | `inviteToTeam3v3` CF | Server :535; client `sendTeamInvite` writes Firestore directly :177-198 | Inconsistent invite flow | Use CF or remove |

---

## Broken / Incomplete Flows

### 1. Сборка проекта

1. Xcode компилирует `MultiplayerService.swift`
2. Парсер падает на строке 241 (`% ;`)
3. **Результат:** app не собирается

### 2. Отклонение friend request

1. Friends → входящая заявка → Decline
2. `FriendsVM.declineRequest` → `FirebaseService.declineFriendRequest`
3. CF `declineFriendRequest` **не существует**
4. **Результат:** заявка остаётся в Firestore (только log)

### 3. Clan war (лидер)

1. Clan tab → Start War → `FirebaseService.startClanWar()`
2. Client ищет ticket в `matchmaking` или создаёт свой
3. Client напрямую пишет `activeWar` в **оба** clan documents
4. PvP win → `recordClanWarBattle(won:)` → +2 локально
5. Server `processClanWarPhases` / `recordClanWarAttack` не участвуют
6. **Результат:** war state рассинхронен между клиентами; scoring ≠ server design

### 4. Daily quest «Gear Up» / «Visit Shop»

1. Home → Daily Missions показывает quest из pool
2. User opens shop, buys/equips item
3. `DailyQuestEngine.progress()` returns 0 для `.equipItem`/`.visitShop`
4. **Результат:** квест навсегда incomplete

### 5. Inventory из профиля

1. Profile → нет кнопки Inventory
2. `showInventory` never `true`
3. **Результат:** `InventoryView` недоступен (только код)

### 6. Offline retry

1. Network lost → `NoInternetView` blocks app
2. User taps RETRY CONNECTION
3. Только visual flash; `NetworkMonitor` не триггерится
4. **Результат:** нужно дождаться auto-reconnect

### 7. Widget

1. User adds Character Progress widget
2. `getTimeline` returns hardcoded level 1 / 0 XP
3. **Результат:** виджет не отражает персонажа

### 8. App Store submission

1. Reviewer opens Profile
2. No Privacy Policy / Terms links (guide claims they exist — they don't)
3. Update gate links to `id0000000000`
4. **Результат:** likely rejection (см. [App Store audit](./2026-07-29-app-store-readiness.md))

### 9. Legacy friends (Clan → Friends sub-tab)

1. User adds friend by **username** string in clan friends section
2. Stored in `UserDefaults` `"saved_friends"`
3. New `FriendsView` uses UID-based `Character.friends`
4. **Результат:** два несовместимых списка; duel/challenge by name may fall back to bot (`startFriendDuel` :532-536)

---

## UI/UX Checklist

| Check | Status | Notes |
|-------|--------|-------|
| Empty states | **Partial** | No-clan, no friends search — OK; inventory/quests incomplete — weak |
| Loading states | **Good** | ProgressView в friends, world boss summon, class submit |
| Error states | **Partial** | ClassSelection errors OK; network/CF errors mostly `print()` only |
| Accessibility | **Fail** | 0 `accessibilityLabel`/`Hint` |
| Haptic | **Partial** | Tab bar haptic (`NavBarItem` :1174-1177); не везде |
| Sound | **Partial** | Push/local notifications; нет in-app SFX |
| Dark theme | **Good** | Consistent `Theme.*`, glassmorphic cards |
| Layout | **Good** | Custom bottom nav, safe padding for tab bar |
| Localization | **Fail** | RU onboarding + EN UI; no i18n infra |
| Toasts/overlays | **Good** | Duel/team invite overlays, floating toasts |

---

## Client ↔ Server Mismatches

| Server callable | Client usage | Mismatch |
|-----------------|-------------|----------|
| `matchmakeClanWar` | ❌ Not called | Client `startClanWar()` duplicates logic |
| `recordClanWarAttack` | ❌ Not called | Client `recordClanWarBattle` (+2 vs +100) |
| `equipItem` | ❌ Not called | Direct `syncCharacter` |
| `getLeaderboards` | ❌ Not called | `fetchLeaderboardsFallback` Firestore queries |
| `searchPlayers` | ❌ Not called | Client Firestore prefix search |
| `inviteToTeam3v3` | ❌ Not called | Direct Firestore `pendingInvites` update |
| `declineFriendRequest` | ✅ Called | **Missing on server** |
| `sendFriendRequest` | ✅ Called | OK |
| `acceptFriendRequest` | ✅ Called | OK |
| `joinTeam` | ✅ Called | OK |
| `matchWithOpponent` | ✅ Called | OK |
| `fillTeammatesWithBots` | ✅ Called (queue path) | Host lobby path bypasses |
| `triggerOpponentBotFallback` | ✅ Called | OK |
| `attackWorldBoss` | ✅ Called | + client `ensureWorldBossExists` write |
| `resolvePvEBattle` | ✅ Called | OK (boss raid, dungeon) |

---

## Widget / Live Activity / Health / Camera

### Widget (`FitRPGWidget.swift`)

- Timeline provider returns static data; comment explicitly says App Group «until configured»
- No `WidgetCenter.reloadTimelines` from main app
- Live Activity widget half **работает** (reads ActivityKit state)

### Live Activity (`LiveActivityManager.swift`)

- Start/update/end flow корректен
- `CameraTrackingVM` drives updates on each rep
- Race: `startLiveActivity` calls async `endLiveActivity` without await before new request (:22-27)
- Requires iOS 16.1+ / user permission — graceful degrade (print)

### HealthKit (`HealthKitService.swift`)

- Reads steps, active calories, workout minutes since `lastHealthSyncDate`
- Auto-request on launch (`FitRPGApp` :131-134)
- Rewards applied in `handleHealthSync` + world boss damage from steps/calories
- `isAuthorized` unreliable (F022)
- No write permissions (read-only — OK for use case)

### Camera / AI (`CameraManager`, `AITrackerEngine`, `CameraTrackingVM`)

- Vision body pose → rep counting per class exercise
- Form feedback + combo multiplier
- Integrates with BattleEngine (local PvE/bot) and MultiplayerService (PvP transaction)
- Dungeon mode skips PvP registration (`isDungeonMode`)
- Training without battle awards gold/XP per rep (F011 exploit)
- `CameraManager` uses `layer as! AVCaptureVideoPreviewLayer` — safe if class hierarchy correct

---

## What Looks Solid

- **Entry pipeline:** `FitRPGApp` — network gate → anonymous auth → onboarding → version overlay → `MainHubView`
- **Realtime sync:** Character/clan Firestore listeners с migration (`pvpTrophies`, `usernameLower`, `classTrophies`)
- **Matchmaking core:** Ticket lifecycle, jitter anti-race, bot fallbacks via CF, Firestore battle transactions for PvP reps
- **BattleVM nil-handling:** Explicit clear when `activeBattle == nil` (fix for stuck arena UI)
- **PvE server authority:** `resolvePvEBattle` for boss raids and dungeon victory loot
- **UI craft:** `Theme`, `AnimatedBackgroundView`, custom tab bar, duel/team overlays, RPG onboarding narrative
- **Deep links:** `rpgfitness://friend?uid=` handler in `FitRPGApp`
- **Privacy manifest:** `PrivacyInfo.xcprivacy` present (fitness + name data, UserDefaults CA92.1)
- **Remote Config version gate:** `VersionManager` + soft/hard update UX
- **Dungeon VM:** Self-contained 3-wave loop with server loot on victory

---

## Recommended Fix Order (client only)

1. **F001** — убрать `% ;` в `MultiplayerService.swift:241` (unblock build)
2. **F002** — decline friend: client-side Firestore update **или** ждать server CF
3. **F003 + F004 + F005 + F006** — перевести clan war, economy, world boss на server callables; убрать client writes
4. **F007** — unify friends на UID; удалить legacy UserDefaults/username paths + ClanDashboard old friends UI
5. **F009 + F011** — server-side или client caps на training rewards
6. **F010 + F012** — выровнять BattleEngine timer и 3v3 lobby с server paths
7. **F008 + F009** — Social auth UI + account linking в onboarding
8. **F013–F018, F014–F017, F024** — UX/App Store: quests tracking, widget App Group, Privacy/ToS, a11y, real App Store URL
9. **F019–F023, F025–F027** — polish: achievements, constellation, energy, HealthKit auth, FCM queue, usernameLower
10. **F028–F032** — dead code cleanup

---

## Related Documents

- KI-карточка: [`.agents/knowledge/KI-client-debt.md`](../../.agents/knowledge/KI-client-debt.md)
- App Store readiness: [docs/audit/2026-07-29-app-store-readiness.md](./2026-07-29-app-store-readiness.md)
- Firebase ecosystem: [docs/audit/2026-07-29-firebase-ecosystem.md](./2026-07-29-firebase-ecosystem.md)
- Architecture ADR: [docs/adr/0001-architecture-overview.md](../adr/0001-architecture-overview.md)

---

*Generated: 2026-07-29 | Next review: after F001 + P1 client fixes*
