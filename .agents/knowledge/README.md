# Knowledge Index (FitRPG)

Краткие KI-карточки для агентов. Читать перед проектированием/фиксами вместо полного обхода репо.

| Card | Когда читать |
|------|----------------|
| [KI-ios-app.md](./KI-ios-app.md) | UI, ViewModels, клиентский стейт, HealthKit/камера |
| [KI-firebase-backend.md](./KI-firebase-backend.md) | Cloud Functions, Firestore, auth, remote config |
| [KI-multiplayer.md](./KI-multiplayer.md) | Matchmaking, clan war, world boss, friends/teams |
| [KI-firebase-ecosystem.md](./KI-firebase-ecosystem.md) | Shared Firebase deploy safety; never wipe sibling CF |
| [KI-app-store-compliance.md](./KI-app-store-compliance.md) | App Store Review, блокеры, privacy/deletion/UGC |
| [KI-feature-reality.md](./KI-feature-reality.md) | REAL/PARTIAL/MOCK/BROKEN матрица, моки, CF bypass (historical counts — prefer LAST audit) |
| [KI-audit-drop-READY-2026-07-29.md](./KI-audit-drop-READY-2026-07-29.md) | **DROP gate CONDITIONAL (86/100)** — build green post WIP fixes; ASC + commit blockers |
| [KI-firebase-operator-checklist-2026-07-29.md](./KI-firebase-operator-checklist-2026-07-29.md) | Firebase Console + RC `fitrpg_*` values |
| [KI-xcode-asc-operator-2026-07-29.md](./KI-xcode-asc-operator-2026-07-29.md) | Xcode/ASC manual steps; iOS **18.6** floor |
| [KI-audit-merged-LAST-2026-07-29.md](./KI-audit-merged-LAST-2026-07-29.md) | Prior LAST CONDITIONAL — code READY; ASC residual (superseded by DROP card for submit) |
| [KI-audit-merged-REAUDIT3-FIX-2026-07-29.md](./KI-audit-merged-REAUDIT3-FIX-2026-07-29.md) | Prior REAUDIT3-FIX YES (code) — superseded by LAST |
| [KI-audit-merged-REAUDIT3-2026-07-29.md](./KI-audit-merged-REAUDIT3-2026-07-29.md) | Prior REAUDIT3 CONDITIONAL (superseded) |
| [KI-audit-merged-FINAL-2026-07-29.md](./KI-audit-merged-FINAL-2026-07-29.md) | Prior FINAL YES (overstated vs REAUDIT3 UX) |
| [KI-audit-merged-SHIP-2026-07-29.md](./KI-audit-merged-SHIP-2026-07-29.md) | Ship pass (superseded by FINAL) |
| [KI-audit-merged-REAUDIT2-2026-07-29.md](./KI-audit-merged-REAUDIT2-2026-07-29.md) | Prior YES (overstated — superseded by SHIP) |
| [KI-audit-merged-REAUDIT-2026-07-29.md](./KI-audit-merged-REAUDIT-2026-07-29.md) | Prior CONDITIONAL YES (P0 only) |
| [KI-audit-merged-2026-07-29.md](./KI-audit-merged-2026-07-29.md) | Original NOT ready + TOP 10 |
| [KI-audit-ios-2026-07-29.md](./KI-audit-ios-2026-07-29.md) | iOS P0×6 P1×22 P2×18, feature matrix, client fix order |
| [KI-audit-backend-2026-07-29.md](./KI-audit-backend-2026-07-29.md) | Server P0: open rules, economy/PvP trust, deploy notes |

## Audits (2026-07-29)

**Start here (KI):** [KI-audit-drop-READY-2026-07-29](./KI-audit-drop-READY-2026-07-29.md) — **CONDITIONAL 86/100** (build green; ASC + commit).  
Prior: [LAST](./KI-audit-merged-LAST-2026-07-29.md).  
**Long-form dumps:** [MASTER — Full Audit](../../docs/audit/2026-07-29-MASTER.md)

| Report | Focus |
|--------|-------|
| [DROP READY](./KI-audit-drop-READY-2026-07-29.md) | Submit gate after parallel WIP + build verify |
| [LAST](./KI-audit-merged-LAST-2026-07-29.md) | Final 3-lens audit on `d143f99` |
| [REAUDIT3-FIX](./KI-audit-merged-REAUDIT3-FIX-2026-07-29.md) | Celebrations, energy omit, HK Update key, Block |
| [REAUDIT3](./KI-audit-merged-REAUDIT3-2026-07-29.md) | Prior CONDITIONAL (holes) |
| [FINAL merged](./KI-audit-merged-FINAL-2026-07-29.md) | Prior YES (UX overstated) |
| [FINAL backend](./KI-audit-backend-FINAL-2026-07-29.md) | Energy rules + refund ledger + battle stamp |
| [FINAL iOS](./KI-audit-ios-FINAL-2026-07-29.md) | Free-train, quests, Health, co-op copy |
| [SHIP merged](./KI-audit-merged-SHIP-2026-07-29.md) | Prior ship pass |
| [MASTER](../../docs/audit/2026-07-29-MASTER.md) | Сводный: scores, P0/P1, roadmap, deploy ban |
| [Feature reality](../../docs/audit/2026-07-29-feature-reality.md) | REAL/PARTIAL/MOCK/BROKEN matrix, CF bypass |
| [App Store readiness](../../docs/audit/2026-07-29-app-store-readiness.md) | Historical 4/10 NOT READY |
| [iOS client](../../docs/audit/2026-07-29-ios-client.md) | F001–F032, broken flows, client↔server |
| [Firebase ecosystem](../../docs/audit/2026-07-29-firebase-ecosystem.md) | Shared project deploy risks (prefer KI-audit) |

## MCP memory (экономия токенов)

1. **codebase-memory-mcp**
   - `project: "rpg-tracker"` — iOS app (~2k nodes)
   - `project: "rpg-fitness-functions"` — Cloud Functions
   - Избегать `project: "rpg-fitness"` для обычных задач (включает `.agents/skills`, ~21k nodes)
   - Workflow: `search_graph` → `trace_path` → `get_code_snippet`; архитектура: `get_architecture`

2. **code-review-graph**
   - Локальная БД: `/.code-review-graph/graph.db` (собрана на `main@341308d`)
   - Impact / flows / communities — после того как MCP видит этот repo root

3. **Файловая память**
   - ADR: `docs/adr/`
   - Эти KI-карточки: `.agents/knowledge/`

## Git note

Локальный stash: `stash@{0}` — WIP правки `functions/src/index.ts` (+437 lines: `vertexProxy`, `deleteAccount`, …). **Merge before any functions deploy.** Не терять при чистке stash.
