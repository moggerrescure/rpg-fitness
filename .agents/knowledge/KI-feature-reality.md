# KI: Feature Reality (FitRPG)

## Scope
Статус фич: REAL / PARTIAL / MOCK / BROKEN. Моки, заглушки, client bypass CF.

**Полный отчёт:** [docs/audit/2026-07-29-feature-reality.md](../../docs/audit/2026-07-29-feature-reality.md)  
**Master:** [docs/audit/2026-07-29-MASTER.md](../../docs/audit/2026-07-29-MASTER.md)

---

## Counts (2026-07-29)

| Status | # | % |
|--------|---|---|
| REAL | 6 | 19% |
| PARTIAL | 21 | 66% |
| MOCK | 4 | 12% |
| BROKEN | 1 | 3% |

---

## Compact matrix

| Feature | Status |
|---------|--------|
| Anon auth, network gate, MainHub, character/class, clan create/join, Live Activity | **REAL** |
| Onboarding, force update, skill tree, shop, inventory, XP/gold, HealthKit, camera (device), push, in-app notifications, friends, duels, team lobby, PvP matchmaking, dungeon, world boss, leaderboards, profile, sounds, Boss Raid | **PARTIAL** |
| Apple/Google auth UI, daily quests, clan war, widget | **MOCK** |
| BattleEngine legacy; **build** (`MultiplayerService:241` `% ;`) | **BROKEN** |

---

## P0 mocks / blockers

1. **Build** — `MultiplayerService.swift:241` `% ;`
2. **Auth UI** — `SocialAuthService` без кнопок в Views
3. **Delete account** — нет UI; CF только в stash
4. **Privacy/Terms** — нет ссылок в app
5. **Clan war** — client path; CF `matchmakeClanWar`/`recordClanWarAttack` не вызываются
6. **Rewards** — PvP/Boss Raid/workout — client `syncCharacter`, не CF

---

## CF bypass (high risk)

| Client does | Should use CF |
|-------------|---------------|
| Shop gold -= | purchase CF |
| equip → syncCharacter | `equipItem` |
| clan war start/score | `matchmakeClanWar`, `recordClanWarAttack` |
| Boss Raid victory | `resolvePvEBattle` |
| leaderboards Firestore | `getLeaderboards` |
| world boss spawn | `processWorldBossCycle` only |

---

## Designed bots (OK) vs accidental mocks

- **OK:** `fillTeammatesWithBots`, `triggerOpponentBotFallback`, matchmaking timers — real path жив
- **Bad:** Team lobby `startTeamBattle` always bots; clan war CF unused; friend duel → random fallback

---

## Fix order (features → REAL)

1. Phase 0: build fix  
2. Compliance UI (auth, legal, delete)  
3. Phase 2: no deploy until stash merge  
4. Wire CF + server economy  
5. Daily quests, widget, team lobby real matchmaking, friends cleanup  
6. Tests + dead code removal  

---

## Agent tip

Перед фичей: проверь статус в [feature-reality audit](../../docs/audit/2026-07-29-feature-reality.md). Если **MOCK** или **PARTIAL** с CF bypass — не «допиливай UI», сначала server path. `MANUAL_SETUP_GUIDE.md` claim «мультиплеер полностью на CF» — **устарел**.
