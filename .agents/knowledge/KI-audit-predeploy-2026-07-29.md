# Pre-deploy audit — FitRPG — 2026-07-29

Tree: **`main` HEAD `cb4b1e0`** (soft polish landed; working tree may have unrelated WIP).  
Build: **`BUILD SUCCEEDED`** (`rpg-tracker` / iOS Simulator `423AEF9B-…`, unsandboxed).

## Overall: **CONDITIONAL**

| Lens | Verdict |
|------|---------|
| Code / honesty / Apple (in-tree) | **READY** |
| ASC operator | **CONDITIONAL** — paste URLs, review notes, Attest |

Pairs with [FINAL DROP](./KI-audit-FINAL-DROP-2026-07-29.md) (submit gate). This card = fresh build + soft-polish spot-check only.

---

## Spot-check (green)

| Check | Evidence |
|-------|----------|
| No hardcoded PvP celebration +250/+60 | `DuelResultOverlay` → `lastPvPSettlement` CF amounts / settling / fail |
| Offline PvP no mint | `awardBattleRewards(isPvP:)` early-return; engine still passes caps as args only |
| No XP BTY / GOLD BTY | `BossRaidResultOverlay` → `raidRewardSettlement` settled/fail |
| Camera nameless boss | `CameraTrackingView` fallback **`BOSS`** (not WORLD BOSS) |
| Block sync | `BlockedUsersStore` ↔ `users/{uid}/blocked/{targetUid}`; merge on login |
| Block rules | nested `match /blocked/{targetUid}` owner-only, no self-block |
| Energy/gold omit block | `fitrpgEnergyNotIncreased` / `fitrpgGoldNotIncreased` require field present |
| `awardStoryStageRewards` | `@escaping` completion → `awardActivityRewards` |
| `NSHealthUpdateUsageDescription` | Debug+Release `project.pbxproj` |
| Imports | `FirebaseAuth` (BlockedUsersStore, PlayerProfile, …); `AVFoundation` (CameraTrackingView) |

`WORLD BOSS` copy remains only on real World Boss surfaces (`WorldBossDashboardView`) — intentional.

---

## ASC residuals only (operator)

1. Paste Privacy / Support / Terms = `LegalURLs.public*` into App Store Connect.
2. Review notes: delete path, HK read-only, camera on-device, free/no IAP, SIWA+Google.
3. App Attest enrollment for Release App Check.
4. Nutrition Labels / age rating if ASC asks.
5. TestFlight smoke: 1v1, 3v3, clan war, WB empty, story CF settle, block sync across devices.

---

## Method

- Fresh `xcodebuild` → **BUILD SUCCEEDED** (unsandboxed).
- Grep/read of celebration, rules, block store, Health keys, imports.
- No commit/push; polish not re-touched.
