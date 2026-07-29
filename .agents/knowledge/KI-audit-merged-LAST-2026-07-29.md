# LAST comprehensive audit — FitRPG — 2026-07-29

Tree: **`main` HEAD `d143f99`** (includes REAUDIT3-FIX; working tree clean; up to date with `origin/main`).

Three lenses in one report. Ruthless honesty bar: **no reward/economy lies → code READY**; App Store Connect still open → overall **CONDITIONAL**.

## Overall: **CONDITIONAL**

| Lens | Verdict |
|------|---------|
| A) Core features / mechanics | **READY** — gates below REAL/PARTIAL; no BROKEN P0 |
| B) UI/UX honesty | **READY** |
| C) Apple Guidelines (code) | **READY** |
| C) Apple Guidelines (ASC operator) | **CONDITIONAL** — paste URLs / review notes / Attest |

Supersedes: [REAUDIT3-FIX](./KI-audit-merged-REAUDIT3-FIX-2026-07-29.md), [REAUDIT3](./KI-audit-merged-REAUDIT3-2026-07-29.md), FINAL/SHIP/REAUDIT2.

---

## A) Core features / mechanics

| Gate | Status | Evidence (HEAD) | Pri |
|------|--------|-----------------|-----|
| Auth + delete | **REAL** | SIWA+Google in Profile; `cleanupFitRPGAccount` + Auth delete | — |
| Quests | **REAL** | `DailyQuestEngine.claim` → `awardBattleRewards(reason: quest)` → CF allowlist | — |
| Free-train | **REAL** | FINISH-once `awardWorkoutRewards` / `reason: workout` | — |
| Arena 1v1 / 3v3 energy + surrender | **REAL** | cards `10 ENERGY` + disable; `adjustEnergy` spend/refund ledger; `surrenderMatch` | — |
| Story CF awards | **REAL** | `awardStoryStageRewards` → `awardActivityRewards` + `completedStoryStage` | — |
| World Boss 15 energy | **REAL** | UI `ATTACK BOSS (15 ENERGY)`; CF `WORLD_BOSS_ATTACK_ENERGY = 15` | — |
| Clan | **PARTIAL** | create/join + war CF wired; not full social polish | P2 |
| Friends + block | **REAL** | report Firestore; block syncs `users/{uid}/blocked/{targetUid}` + local cache | — |
| Health Sync | **REAL** | HK read → CF `health_sync`; no fake WB DMG; copy XP/gold only | — |
| Offline PvP no mint | **REAL** | client skips mint; CF rejects pvp/duel/arena activity reasons | — |
| Energy `adjustEnergy` + rules omit block | **REAL** | spend/refund/regen CF; `fitrpgEnergyNotIncreased` / `fitrpgGoldNotIncreased` require field present | — |
| Battle stamp | **REAL** | `createdByServer` required in `resolvePvPBattle` | — |
| PvP/PvE settlement honesty | **REAL** | derive winner server-side; Duel/Story/BossRaid screens use CF amounts; fail → toast / no victory | — |

**P0 open:** none (code).

**P1 soft (not ship-blockers for honesty bar):** none remaining (closed 2026-07-29 soft polish).

~~1. UGC block list is **device-local** (not server sync) — Report path is REAL.~~ → **FIXED**: Firestore `users/{uid}/blocked/{targetUid}`, owner-only rules, merge on login.
~~2. Legacy `BossRaidResultOverlay` still shows opaque **«XP BTY / GOLD BTY»** (engine path); primary Boss Raid result screen uses CF `xpEarned`/`goldEarned`.~~ → **FIXED**: overlay uses `BattleEngine.raidRewardSettlement` CF amounts / settling / fail.
~~3. `CameraTrackingView` nameless HP boss fallback label **«WORLD BOSS»** if `bossName == nil` (story/raid pass names).~~ → **FIXED**: fallback **«BOSS»**.

**P2:** Clan war UX polish; widget / Live Activity depth; nutrition labels if ASC asks.

---

## B) UI/UX honesty

| Check | Status |
|-------|--------|
| Celebrations match server | **YES** — PvP `lastPvPSettlement`; Story settling→CF/zero; BossRaid/Dungeon no victory on CF fail |
| Energy costs on cards | **YES** — Arena 10; WB 15 |
| No co-op / WORLD BOSS lies on Arena | **YES** — Story solo ship path; Boss Raid card **LOCAL RAID** |
| Toasts on CF fail | **YES** — `lastActionError` + MainHub |
| Onboarding | **YES** — no clan-raid overclaim |
| Deep links | **YES** — `rpgfitness://friend?uid=` |

Residual: none for soft polish (block sync + overlay amounts + nameless boss closed).

---

## C) Apple Guidelines

| Item | Status |
|------|--------|
| `NSHealthUpdateUsageDescription` | **YES** — Debug+Release pbxproj |
| `NSHealthShareUsageDescription` / Camera | **YES** |
| SIWA (+ Google) | **YES** — capability + Profile UI |
| Delete account | **YES** — FitRPG-scoped cleanup |
| IAP | **N/A** — no StoreKit |
| Privacy strings + `PrivacyInfo.xcprivacy` | **YES** — tracking false |
| UGC block + report | **YES** (block syncs Firestore `blocked/` + local; report shared `reports`) |
| LegalURLs | **YES** in-app; public GH Pages **HTTP 200** |
| ATT | **N/A** — no tracking |
| ASC operator | **CONDITIONAL** — see residuals |

---

## What works

- Economy mint paths gated by CF + caps (`FitRPGEconomyCaps` mirrors server).
- Ranked PvP requires server stamp; client `winnerId` ignored on settle.
- Energy increases CF-only; omit-then-reintroduce closed in rules.
- Reward UI no longer hardcodes +250/+60; fails surface toasts.
- Auth delete, SIWA, legal pages, HealthKit Update key, App Check Release path present.

## Remaining residuals only

### Operator / ASC (not code)
1. Paste Privacy / Support / Terms = `LegalURLs.public*` into App Store Connect (pages live on GitHub Pages).
2. Review notes: delete path, HK read-only, camera on-device, free/no IAP, SIWA+Google.
3. App Attest enrollment for Release App Check.
4. Nutrition Labels / age rating if ASC requires.
5. Confirm App Group / TestFlight smoke (1v1, 3v3, clan war, WB empty).

### Code soft (optional polish)
- ~~Server-sync block list; pass amounts into `BossRaidResultOverlay`; replace nameless «WORLD BOSS» fallback with «BOSS».~~ **CLOSED** 2026-07-29 soft polish (working tree; deploy rules via `scripts/deploy-fitrpg-safe.sh`).

### FIX note (2026-07-29 soft polish)
Soft residuals from this LAST audit are closed in code:
1. `BlockedUsersStore` ↔ `users/{uid}/blocked/{targetUid}` (owner-only rules; no self-block; merge on login; `cleanupFitRPGAccount` wipes `blocked/`).
2. `BossRaidResultOverlay` shows CF settled `+xp/+gold` or settling/fail (no «XP BTY / GOLD BTY»).
3. `CameraTrackingView` nameless fallback → `BOSS`.

---

## Agents / method

Static re-verify of HEAD `d143f99` against REAUDIT3-FIX claims + grep of celebration/energy/Apple surfaces. Legal URLs probed live (200). Helper unit tests not re-executed in this pass (tsx sandbox IPC); prior economy/battle helper asserts remain in-tree.
