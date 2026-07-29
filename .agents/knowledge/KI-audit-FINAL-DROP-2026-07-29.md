# App Store FINAL DROP audit — FitRPG — 2026-07-29 (night)

**Supersedes:** [KI-audit-drop-READY-2026-07-29.md](./KI-audit-drop-READY-2026-07-29.md)  
**Base HEAD (end of audit):** `4ec489b` (chain: `737a559` polish → `c3483eb` iOS 18.6 → `2b2b510` equip/train honesty → `37afc8f` onboarding → `4ec489b` screenshot fill)  
**Tree:** remaining uncommitted parallel WIP (clan war UX helpers, economy regen extract, ClassSelection iPad, Build 2) — **not** required for code READY bar; commit separately after TF smoke of main.

## Verdict

| | |
|--|--|
| **Overall** | **CONDITIONAL** |
| **Score** | **88 / 100** |
| **One-liner** | Code + Debug build are drop-capable after equip/train honesty fixes, but Submit still blocked on operator ASC/Attest/TF smoke and a FitRPG-safe CF deploy (unequip + screenshot fill). |

| Lens | Status |
|------|--------|
| Code / honesty | **READY** (post-audit P0 fixes; **BUILD SUCCEEDED**) |
| Firebase deploy delta | **CONDITIONAL** — `equipItem` unequip + `fillScreenshotWallet` in WIP; must deploy via `scripts/deploy-fitrpg-safe.sh` |
| App Store Connect / human | **CONDITIONAL** — URLs paste, App Attest, TF smoke, screenshots |
| Git archive | **CONDITIONAL → READY after commit** of this WIP |

**Do not treat as “Submit for Review pressed.”**

---

## Evidence this pass

| Check | Result |
|-------|--------|
| Git | `main` @ `4ec489b` (equip/train/screenshot commits landed mid-audit); leftover WIP: clan war helpers/UI, `computePassiveRegen`, ClassSelection width, Build **2** in pbxproj |
| Merge markers | None in app/functions sources |
| Xcode | **26.3** (`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`) |
| Build | **`rpg-tracker` Debug `generic/platform=iOS` `CODE_SIGNING_ALLOWED=NO` → BUILD SUCCEEDED** (`-derivedDataPath /tmp/fitrpg-final-dd`) |
| Helper tests | `battleHelpers.test.ts` + `economyHelpers.test.ts` → **OK** |
| Legal GH Pages | privacy / support / terms → **HTTP 200** (GET) |
| iOS deployment | **18.6** on app + widget (pbxproj) |
| Deploy path | FitRPG only via `scripts/deploy-fitrpg-safe.sh` (now lists `fillScreenshotWallet`) |

### P0 closed on path to this FINAL audit (code on `main`)

1. **Compile / train toast honesty** (`2b2b510` + audit verify): `awardWorkoutRewards` uses `@escaping` completion; Camera waits CF before +ENERGY UI.
2. **Free-train gold sync:** stats sync uses **pre-reward gold** so rules accept write; gold mint via `awardActivityRewards`.
3. **Equip/unequip:** optimistic UI + CF `unequip:true` (`2b2b510` / `4ec489b` deploy list).
4. **Screenshot fill:** gated CF + RC/DEBUG Profile (`4ec489b`); keep RC **false** for Review.

---

## Checklist

| Area | Status | Evidence |
|------|--------|----------|
| Auth (guest + Apple/Google) | **YES** | Anonymous auto-sign-in; SIWA; Google Sign-In; Profile link/upgrade |
| Energy regen / spend / refund | **YES** | `adjustEnergy` ops + rules `fitrpgEnergyNotIncreased`; Arena 10 / WB 15 |
| Energy train (+5 / +40 day) | **YES** | CF `op: "train"`; client waits CF before +ENERGY toast; rollback on failure |
| PvP bots damage | **YES** | Host `botCombatTimer` + `applyBotCombatTick`; `isBotPlayerId` (`bot` prefix / `_bot_`) |
| Surrender | **YES** | Client `surrenderedBy` → `resolvePvPBattle`; helpers honor surrender |
| Matchmaking / bot fallback | **PARTIAL** | CF fill + local fallback; UI “~30s” approximate |
| Clan create/join/leave/war | **YES** | Leave handoff; war skirmish **no arena energy**; `bot_cwar_*` |
| Invites / deep links | **YES** | `rpgfitness://friend?uid=`; notification duel/friends/clanwar |
| HealthKit → combat | **YES** | HK strings; sync XP/gold (no fake WB DMG); free-train → rewards CF |
| Notifications | **YES** | Auth + daily reminder; deep-link routing |
| Privacy / ASC metadata | **PARTIAL** | Public URLs live **200**; **operator must paste into ASC** |
| App Attest / App Check | **PARTIAL** | Release App Attest + DeviceCheck; callables `enforceAppCheck`; **console enrollment human** |
| IAP / StoreKit | **N/A (YES)** | No StoreKit; free app — do not claim IAP |
| Equip / purchase | **YES*** | Optimistic equip/unequip + rollback; CF unequip flag; purchase CF. *Unequip CF must be deployed |
| RC update screen | **YES** | `fitrpg_*` keys; **min_version = app version, not iOS 18.6** |
| iOS 18.6 floor | **YES** | pbxproj targets 18.6; ASC Availability operator |
| Screenshot fill | **PARTIAL** | Gated CF + RC `fitrpg_screenshot_fill` (default false); DEBUG Profile button; keep RC **false** for Review |
| Shared Firebase safety | **YES** | `cleanupFitRPGAccount` only; never bare `firebase deploy --only functions` |

---

## Blockers vs soft polish

### P0 — submit / archive blockers (human + deploy)

1. **Commit Build 2** (pbxproj) if not already archived; leftover clan-war WIP is optional polish — do not block Archive of `4ec489b`+honesty commits.
2. **Deploy** FitRPG-scoped if console not yet updated after `4ec489b`: `./scripts/deploy-fitrpg-safe.sh` (confirm `equipItem` unequip + `fillScreenshotWallet`).
3. **ASC:** paste Privacy / Support / Terms URLs; Nutrition Labels; age/export; screenshots.
4. **App Check:** enroll **App Attest** for FitRPG iOS Release.
5. **TestFlight smoke:** guest auth; train energy toast honesty; equip/unequip; 1v1 bot dmg; surrender; 3v3 bot fill; friend deep link; clan leave handoff; clan war no energy; WB 15 empty; Delete Account; RC update gate **off** (`fitrpg_update_required=false`, `fitrpg_min_version` ≤ `1.0`).

### P1 — residual integrity / review notes

1. Human PvP HP still client-synced (App Check + CF settle mitigate economy).
2. Surrender is client-written `surrenderedBy` then CF settle.
3. Matchmaking wait copy approximate.
4. Keep `fitrpg_screenshot_fill` **false** except temporary screenshot sessions.
5. Shared-project secrets historically in `remote_config.json` — rotate if still live (ecosystem).

### P2 — polish

1. Duplicate `PrivacyInfo.xcprivacy` Copy Bundle Resources warning.
2. pngcrush noise on some Assets PNGs (non-fatal).
3. Widget / Live Activity depth; clan war UX depth.

---

## Operator checklist (what HUMAN must still do)

### Firebase (`KI-firebase-operator-checklist`)

- [ ] Only `./scripts/deploy-fitrpg-safe.sh` (never bare functions deploy)
- [ ] Auth: Anonymous + Apple + Google enabled
- [ ] App Check → App Attest for FitRPG iOS (+ debug tokens for local)
- [ ] RC day-1: `fitrpg_update_required=false`; `fitrpg_min_version` empty or `1.0` (**not** `18.6`); `fitrpg_update_url` = App Store link; `fitrpg_screenshot_fill=false` for Review
- [ ] Confirm `equipItem` unequip + `fillScreenshotWallet` live after deploy

### Xcode / ASC (`KI-xcode-asc-operator`)

- [ ] Signing Team `LSCCP92LMG`; SIWA / HK / Push / App Group
- [ ] Archive Release Any iOS Device; Build ≥ 2
- [ ] ASC min OS **18.6**; paste legal URLs; review notes (guest+SIWA+Google; FitRPG-scoped delete; HK read; on-device camera; **no IAP**; UGC report+block)
- [ ] Screenshots current; TF smoke checklist above

---

## Session delta since prior DROP audit (`KI-audit-drop-READY`)

| Topic | Prior DROP | FINAL DROP |
|-------|------------|------------|
| Git HEAD | `d143f99` + large uncommitted WIP | `4ec489b` on main (polish + honesty + screenshot fill; leftover clan WIP) |
| Score / verdict | CONDITIONAL **86** | CONDITIONAL **88** |
| Train energy | CF train + optimistic toast risk | Completion waits confirmed `trainAwarded`; gold sync rules fix |
| Equip | Art shipped; equip CF | Optimistic equip/unequip + CF `unequip:true` (needs deploy) |
| Screenshot fill | Not in prior card | Gated CF/UI (RC default false) |
| iOS floor | Documented | Confirmed 18.6 in pbxproj + build=2 |
| Build | SUCCEEDED after clan orphan/bot-id fixes | SUCCEEDED after `@escaping` + gold-sync fix |
| Prior DROP P0s | ClanDashboard orphan; `cwar_bot_*` → `bot_cwar_*` | Still in tree on main; no regression found |

---

## Agents / method

Spot-check of parallel WIP (equip, energy/train, MultiplayerService, ArmoryShop, adjustEnergy); conflict scan; helper unit tests; legal URL GET; Xcode full Debug build. No ASC API. No production Firebase mutate in this pass.
