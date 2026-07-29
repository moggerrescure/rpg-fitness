# KI: Client Tech Debt (FitRPG iOS)

## Scope
Критичный tech debt iOS-клиента `rpg-tracker/`. Читать перед фиксами multiplayer, economy, friends, build.

**Полный отчёт:** [docs/audit/2026-07-29-ios-client.md](../../docs/audit/2026-07-29-ios-client.md)

---

## P0 — Build Blocker

| Issue | Location | Fix |
|-------|----------|-----|
| `% ;` синтаксическая ошибка | `MultiplayerService.swift:241` | Удалить `% ;` — без этого проект **не собирается** |

---

## P1 — Server Authority Gaps

| Issue | Detail |
|-------|--------|
| **declineFriendRequest missing** | Клиент вызывает CF (`FirebaseService.swift:506-512`); export в `functions/src/index.ts` **отсутствует** |
| **Clan war client-side** | `startClanWar()` / `recordClanWarBattle()` (+2 очка) — CF `matchmakeClanWar` / `recordClanWarAttack` (+100) **не вызываются** |
| **Economy client-side** | Shop/equip через `syncCharacter`; CF `equipItem` **не вызывается** |
| **World boss client write** | `ensureWorldBossExists()` пишет в Firestore с клиента |
| **Dual friends** | UID (`Character.friends`) vs legacy username (`FirebaseService.friends` + UserDefaults); friends leaderboard по username |
| **No social auth UI** | `SocialAuthService` есть, Views не вызывают — anonymous-only |
| **Free training exploit** | `CameraTrackingVM` — 15 XP + 5 gold **per rep** без battle/лимитов |

---

## Open Firestore Rules (client impact)

Из `firestore.rules` — любой authed user может писать:

- `clans/*` — trophies, members, activeWar
- `world_bosses/*` — HP, spawn
- `battles/*` — combat state
- `matchmaking/*` — tickets

Подробности: [Firebase ecosystem audit](../../docs/audit/2026-07-29-firebase-ecosystem.md)

---

## P2 Quick Hits

- Daily quests: только reps tracked; PvP/dungeon/steps/equip/shop → 0%
- Widget: placeholder level 1, no App Group
- `InventoryView`: `showInventory` never triggered — экран недоступен
- Privacy/ToS: нет в `PlayerProfileView` (см. [KI-app-store-compliance](./KI-app-store-compliance.md))

---

## Fix Order (client)

```
F001 build → F002 decline → F003-F006 server paths → F007 friends unify
→ F008-F011 auth/economy caps → F013-F018 UX/App Store
```

32 findings total: F001–F032 в [полном аудите](../../docs/audit/2026-07-29-ios-client.md).

---

## Agent Tip

Не чини economy/clan war только на клиенте — сначала сверься с [KI-firebase-ecosystem](./KI-firebase-ecosystem.md). Client↔server mismatch table — в ios-client audit § Client↔Server Mismatches.
