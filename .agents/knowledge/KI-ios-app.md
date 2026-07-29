# KI: iOS app (rpg-tracker)

## Scope
`rpg-tracker/rpg-tracker/` — SwiftUI FitRPG client.

## Entry
- `FitRPGApp.swift` + `AppDelegate`: Firebase configure, App Check (DEBUG), FCM, Google URL handler
- Gates: `NetworkMonitor` → `AuthManager` → onboarding (`hasCompletedOnboarding`) → `VersionManager` → main hub

## Structure
| Folder | Contents |
|--------|----------|
| Views | Hub, shop, inventory, battle, dungeon, clans, friends, world boss, profile, onboarding, camera/health sync |
| ViewModels | `BattleVM`, `DungeonVM`, `ClanVM`, `FriendsVM`, `CameraTrackingVM`, `ClassSelectionVM` |
| Services | `FirebaseService`, `MultiplayerService`, `HealthKitService`, `SocialAuthService`, `AuthManager`, `BattleEngine`, `AITrackerEngine`, `CameraManager`, Live Activity / notifications / Remote Config |
| Models | `Character`, `Equipment`, `Clan`, `Battle`, `Boss`, quests, notifications |

## Hotspots (high fan-in)
- `FirebaseService.syncCharacter` / `syncClan`
- `MultiplayerService.leaveMatch` / `listenToBattle` / matchmaking
- Equipment lookups `findArmor` / `findWeapon`
- Auth: Apple/Google via `SocialAuthService`

## Known product notes
- Shop (`ArmoryShopView`): клиентское gold, StoreKit не обязателен для релиза
- Privacy/ToS в profile: заглушки `yourdomain.com` (см. `MANUAL_SETUP_GUIDE.md`)
- Widget: `FitRPGWidget`

## Agent tip
Не читать весь Views-каталог. Ищи экран/VM по имени через graph `search_graph`, потом `trace_path` к Services.
