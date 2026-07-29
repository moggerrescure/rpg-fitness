# App Store DROP readiness — FitRPG — 2026-07-29 (evening)

Supersedes: [LAST](./KI-audit-merged-LAST-2026-07-29.md) for **submit gate**. Base HEAD `d143f99` + **uncommitted WIP** from parallel fix batches (UI / combat / clan+invites). Two P0 compile/logic fixes applied during this audit (not committed).

## Verdict

| | |
|--|--|
| **Overall** | **CONDITIONAL** |
| **Drop readiness score** | **86 / 100** |
| Code / honesty bar | **READY** (post-audit fixes; build green) |
| App Store Connect operator | **CONDITIONAL** — URLs / notes / Attest / TF smoke |
| Git tree for archive | **NOT READY until commit** — large WIP + new assets |

**Blockers (must clear before Submit for Review):** ASC paste + App Attest enrollment + commit/archive signed build + TestFlight smoke.  
**Soft polish (non-blocking):** clan war UX depth; client HP sync among humans; matchmaking copy “~30s”; widget depth.

---

## Evidence this pass

| Check | Result |
|-------|--------|
| Merge conflict markers in app sources | None (orphan remnant fixed) |
| Duplicate `surrenderMatch` | Single path in `MultiplayerService` (+ UI confirm in Arena/Camera) |
| Xcode | **26.3** (`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`); CLT at `/Library/Developer/CommandLineTools` |
| Build | **`rpg-tracker` Debug `generic/platform=iOS` `CODE_SIGNING_ALLOWED=NO` → BUILD SUCCEEDED** (after fixes) |
| Helper tests | `battleHelpers.test.ts` + `economyHelpers.test.ts` → **OK** (tsx `--test`) |
| Legal GH Pages | privacy / support / terms → **HTTP 200** |
| Deploy path | FitRPG only via `scripts/deploy-fitrpg-safe.sh` (rules+scoped CF; includes sibling orphans intentionally) |

### P0 fixed during this audit

1. **`ClanDashboardView.swift`** — truncated switch remnant after closing `}` (parallel-edit corruption) → compile break. Removed orphan lines.
2. **Clan war skirmish bot IDs** — `cwar_bot_*` failed `isBotPlayerId` (`hasPrefix("bot")`) so bots dealt **0** damage. Renamed to `bot_cwar_*` + broadened detector (`hasPrefix("bot") || contains("_bot_")`).

---

## Checklist

| Area | Status | Evidence |
|------|--------|----------|
| Auth (guest + Apple/Firebase) | **YES** | Anonymous auto-sign-in; SIWA capability; Google Sign-In; Profile link/upgrade |
| Energy honesty / refunds | **YES** | Arena 10 ENERGY cards + disable; WB 15; `adjustEnergy` spend/refund/regen; rules `fitrpgEnergyNotIncreased` |
| PvP 1v1 + 3v3 bots damage | **YES** | Host-only `botCombatTimer` + `applyBotCombatTick`; bot ids `bot_*` / `bot_fallback_*` |
| PvP settle | **YES** | `resolvePvPBattle` CF; server stamp / derive winner; honors `surrenderedBy` |
| Surrender E2E | **YES** | Client `applyLocalSurrender` → Firestore `surrenderedBy` → `resolvePvPBattle` (client-initiated; CF settles rewards) |
| Matchmaking status / bot fallback | **PARTIAL** | UI “Searching for Opponents… ~30s”; CF `fillTeammatesWithBots` / `triggerOpponentBotFallback` + local fallback |
| Clan create/join/leave/war | **YES** | Client create/join/leave + leader handoff on leave; war via `matchmakeClanWar` / `recordClanWarAttack`; skirmish **no arena energy** |
| Friend invite deep links | **YES** | `rpgfitness://friend?uid=`; `onOpenURL` → `sendFriendRequest`; scheme in Debug+Release |
| 3v3 / duel notification deep links | **YES** | `NotificationManager` → `pendingDeepLink` duel/friends/clanwar; MainHub routes |
| HealthKit / workouts → combat | **YES** | HK Share+Update strings; sync XP/gold (no fake WB DMG); camera free-train → `awardWorkoutRewards` |
| Notifications | **YES** | Auth request + daily reminder; invite banners; center deep-links |
| Privacy / Support / ASC metadata | **PARTIAL** | In-app Legal + public URLs live; **operator must paste into ASC**; App Store ID `6785639478` documented |
| App Attest / anti-cheat | **PARTIAL** | Release `AppAttest` + DeviceCheck fallback; all FitRPG callables `enforceAppCheck`; **console enrollment operator** |
| IAP / StoreKit | **N/A (YES)** | No StoreKit usage; free app — do not claim IAP in metadata |
| Crash / known P0 from KI | **YES (closed in code)** | Prior REAUDIT3/LAST P0s closed; this pass fixed compile + clan-bot damage |
| Shared Firebase safety | **YES** | FitRPG delete → `cleanupFitRPGAccount` only; never recursive `deleteAccount` from client; safe deploy script |

---

## Residual risks (human before submit)

### P0 — submit blockers (operator / process)

1. **Commit + archive** signed Release build (current tree is large uncommitted WIP; assets untracked).
2. **ASC App Information**: paste Privacy / Support / Terms = `LegalURLs.public*` (pages already 200).
3. **Firebase App Check**: enroll App Attest for FitRPG iOS app (Release).
4. **TestFlight smoke**: guest auth; 1v1 bot damage; surrender settle; 3v3 bot fill; friend deep link; clan create/leave handoff; clan war skirmish (no energy charge); WB 15 energy empty state; Delete Account.

### P1 — should know / may ask in review

1. Combat HP still **client-synced** among human participants (integrity residual; App Check + CF settlement mitigate economy).
2. Surrender is **client-written** `surrenderedBy` then CF settle (acceptable; peer can also observe).
3. Matchmaking wait copy is approximate (“~30s”); bot fallback may feel sudden.
4. Clan war UX still **PARTIAL** polish vs core social depth.
5. Shared-project secrets historically in `remote_config.json` — ops rotate if still live (ecosystem, not FitRPG-only).

### P2 — polish

1. Duplicate `PrivacyInfo.xcprivacy` Copy Bundle Resources warning.
2. Widget / Live Activity depth.
3. Nutrition Labels / age rating confirmation in ASC.

---

## Operator ASC checklist

1. [ ] Paste Privacy URL: `https://borisserz.github.io/fitrpg-legal/privacy.html`
2. [ ] Paste Support URL: `https://borisserz.github.io/fitrpg-legal/support.html`
3. [ ] Paste Terms (license) if required: `https://borisserz.github.io/fitrpg-legal/terms.html`
4. [ ] Review notes: Sign in with Apple + Google + guest; Delete Account (FitRPG-scoped); HealthKit **read-only**; camera on-device for reps; **no IAP**; UGC report+block
5. [ ] App Attest / App Check enrollment for Release
6. [ ] Privacy Nutrition Labels match HK read + `PrivacyInfo.xcprivacy` (tracking false)
7. [ ] Confirm App Group `group.com.borisdev.rpg-tracker` if widget ships
8. [ ] Screenshots / preview video current (post UI polish)
9. [ ] Age rating / export compliance
10. [ ] Never deploy with bare `firebase deploy --only functions` — only `scripts/deploy-fitrpg-safe.sh`

---

## What was fixed this session (user batches → status)

| Theme | Status | Notes |
|-------|--------|-------|
| Equipment icons (armor/ring/amulet) | **DONE** | New `shop_*_epic` imagesets + Equipment wiring |
| Notifications polish | **DONE** | Manager + NotificationCenter deep-links |
| Choose Hero / avatar panel | **DONE** | `BattleAvatar` + class avatars assets |
| HUD name/level | **DONE** | MainHub / arena HUD polish in WIP |
| Tavern / truncation / ellipsis | **DONE** | Friends/Clan/UI polish in WIP |
| Bots deal damage 1v1/3v3 | **DONE** | Host bot combat timer + tick |
| Surrender E2E | **DONE** | Client forfeit → CF settle |
| Clan create/join/leave/handoff | **DONE** | Leave promotes next member; empty deletes clan |
| War skirmish energy honesty | **DONE** | Local skirmish; no arena MM energy |
| Buffs / boss UI honesty | **DONE** | Prior REAUDIT3 + WB 15 ENERGY; no Arena WORLD BOSS lie |
| Friend / 3v3 deep links | **DONE** | URL scheme + notification routing |
| Audit-time compile remnant | **DONE** | ClanDashboard orphan cases |
| Audit-time clan bot id | **DONE** | `bot_cwar_*` + detector |

Rules+functions for clan/energy path: **already deployed** (per session context); iOS WIP still needs commit/archive.

---

## Agents / method

Static spot-check of parallel WIP vs LAST/SHIP KIs; conflict/orphan scan; Xcode full build; helper unit tests; live Legal URL probe. No ASC API calls. Do **not** treat this card as “submit pressed” — operator gate remains.
