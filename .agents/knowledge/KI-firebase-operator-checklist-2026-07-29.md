# FitRPG — Firebase / Google Cloud operator checklist

**Date:** 2026-07-29  
**Project (shared):** `serzhanovich-ecosystem-ce700`  
**App:** FitRPG (`rpg-tracker`, bundle `com.borisdev.rpg-tracker`, App Store ID `6785639478`)  
**Source of truth:** [KI-audit-drop-READY-2026-07-29.md](./KI-audit-drop-READY-2026-07-29.md) + this card

> **RU:** Делай только FitRPG-scoped шаги. Не трогай Food / Workout / Yoga функции, Storage buckets и RC-ключи чужих приложений.  
> **EN:** FitRPG-scoped only. Do not touch sibling apps’ functions, buckets, or Remote Config keys.

---

## 0) What NOT to touch / Что НЕ трогать

| Do NOT / Нельзя | Why / Почему |
|-----------------|--------------|
| `firebase deploy --only functions` (bare) | Wipes Food/Workout orphans (`tryonWorker`, `tagGarment`, …) |
| Recursive `deleteAccount` from FitRPG client | Shared `users/{uid}` — use `cleanupFitRPGAccount` only |
| Edit Food/Workout/Yoga Remote Config keys (`food_*`, `workout_*`, `yoga_*`) | Shared RC namespace |
| Disable App Check globally / for other apps | Breaks siblings |
| Delete shared Auth users wholesale | Same Auth project for ecosystem |
| Change shared Storage rules for non-FitRPG paths | Sibling assets |

**Safe deploy only:**
```bash
./scripts/deploy-fitrpg-safe.sh
```

---

## 1) Authentication / Auth

**Console:** Firebase → Authentication → Sign-in method

| Provider | Required | Notes |
|----------|----------|-------|
| **Anonymous** | YES | Guest auto-sign-in on launch |
| **Apple** | YES | SIWA capability in Xcode; ASC + Firebase Apple provider |
| **Google** | YES | Google Sign-In; OAuth client for iOS bundle ID |

**Checklist:**
- [ ] Anonymous enabled  
- [ ] Apple enabled (Services ID / Team ID / Key if web; native SIWA for iOS)  
- [ ] Google enabled (iOS client ID matches `GoogleService-Info.plist`)  
- [ ] Authorized domains include production hosts if any web auth  
- [ ] Profile “link/upgrade” guest → Apple/Google still works after TF build  

**RU:** Анонимный вход обязателен для онбординга; Apple + Google — для App Review 4.8 / account permanence.

---

## 2) App Check / App Attest

**Console:** Firebase → App Check → Apps → FitRPG iOS

| Env | Provider | Notes |
|-----|----------|-------|
| Release / TestFlight | **App Attest** (+ DeviceCheck fallback in code) | Enroll App Attest for bundle |
| Debug | Debug provider | Register debug tokens in Console |

**Code:** `FitRPGApp.swift` — Release `AppAttestProvider`, DEBUG `AppCheckDebugProviderFactory`. All FitRPG callables use `enforceAppCheck: true`.

**Checklist:**
- [ ] FitRPG iOS app registered in App Check  
- [ ] App Attest attestation enrolled for Release  
- [ ] DeviceCheck available as fallback  
- [ ] Debug token(s) registered for local/dev devices  
- [ ] Metrics show successful tokens after TF smoke (not all “missing”)  

**RU:** Без App Attest Release-сборки CF будут отклонять вызовы → «не работает сеть/энергия/матч».

---

## 3) Firestore — rules + indexes

**Deploy via safe script** (rules + indexes + scoped functions):
```bash
./scripts/deploy-fitrpg-safe.sh
```

**Honesty guards (already in `firestore.rules`):**
- `fitrpgEnergyNotIncreased` — client cannot raise `energy`
- `fitrpgGoldNotIncreased` — client cannot raise `gold`
- Protected keys include `lastTrainEnergyDay`, `trainEnergyAwardedToday`, `pendingEnergyCharges`, progressions, equip slots, …

**Checklist:**
- [ ] Rules deployed after any energy/economy change  
- [ ] Indexes deployed (Console → Firestore → Indexes: no red “needs index” in logs)  
- [ ] Spot-check: client write attempting `energy: 999` is denied  
- [ ] Reports UGC path `app == fitrpg` still writable by authenticated users  

---

## 4) Cloud Functions

**Only:** `scripts/deploy-fitrpg-safe.sh`  
**Includes FitRPG callables** such as: `adjustEnergy`, `awardActivityRewards`, `resolvePvPBattle`, `resolvePvEBattle`, matchmaking, clan war, world boss, friends, `cleanupFitRPGAccount`, …

### Energy ops (`adjustEnergy`)

| `op` | Effect |
|------|--------|
| `spend` | Deduct + ledger `chargeId` |
| `refund` | Refund against unused charge (TTL) |
| `regen` | Passive +1 / 5 min (server) |
| `train` | Camera free-train session: **+5** energy, **+40/day UTC** via `lastTrainEnergyDay` / `trainEnergyAwardedToday` |

**Health Sync must NOT call `op: "train"`** — only XP/gold via `awardActivityRewards` `reason: health_sync`.

**Checklist:**
- [ ] Deployed after `adjustEnergy` / economy changes  
- [ ] Logs: `adjustEnergy` train grants appear after FINISH WORKOUT  
- [ ] Daily cap: 9th session same UTC day still respects remaining budget (max 40)  
- [ ] Never deploy bare `functions`  

---

## 5) Remote Config — update / force-update screen

**Console:** Firebase → Remote Config → Parameters  
**Prefix:** `fitrpg_*` only

| Key | Type | Purpose | Example |
|-----|------|---------|---------|
| `fitrpg_min_version` | String | Hard gate — below = blocking full-screen | `1.0.1` |
| `fitrpg_latest_version` | String | Soft prompt — below = dismissible sheet | `1.0.2` |
| `fitrpg_update_required` | Boolean | Force hard update regardless of version | `false` |
| `fitrpg_update_title` | String | Sheet title (EN defaults in app) | `Update Available` |
| `fitrpg_update_message` | String | Body copy | `A new version of FitRPG is available…` |
| `fitrpg_update_url` | String | Full App Store URL (preferred) | `https://apps.apple.com/app/id6785639478` |
| `fitrpg_ios_app_store_id` | String | Numeric ID if URL empty | `6785639478` |

**Legacy fallbacks (optional):** `rpg_minimum_ios_version`, `rpg_recommended_ios_version`, `rpg_ios_app_store_id`

**Behavior:**
- **Hard:** `current < fitrpg_min_version` OR `fitrpg_update_required == true` → full-screen, no dismiss  
- **Soft:** `current < fitrpg_latest_version` → full-screen overlay with **Later**  
- Wired in `FitRPGApp` `.task` → `fetchCloudValues` + `VersionManager.checkVersion` → `UpdateRequiredView`

**Checklist:**
- [ ] Create all `fitrpg_*` keys above (empty min/latest = no gate)  
- [ ] Publish RC after edits  
- [ ] Soft test: set `fitrpg_latest_version` above current → soft UI + Later works  
- [ ] Hard test: set `fitrpg_min_version` above current → cannot dismiss  
- [ ] URL opens App Store product page  

---

## 6) FCM / Notifications

| Item | Status |
|------|--------|
| APNs key / cert in Firebase Cloud Messaging | Required for push |
| Client registers for remote notifications | `FitRPGApp` AppDelegate |
| `fcmToken` on user doc | Updated via MessagingDelegate |
| Local daily reminder + energy restored | `NotificationManager` (local) |

**Checklist:**
- [ ] APNs Auth Key uploaded for App ID  
- [ ] TF device receives invite / duel deep-link notifications if using FCM payloads  
- [ ] Local reminders still work without FCM  

---

## 7) Storage / Analytics / Other

| Service | FitRPG use | Action |
|---------|------------|--------|
| **Storage** | Minimal / none for core loop | Do not change sibling buckets |
| **Analytics** | Optional Firebase Analytics if linked | No FitRPG-specific console gate for drop |
| **Crashlytics** | If enabled in Xcode | Verify dSYMs for Release |
| **Vertex / image proxies** | Shared CF in safe deploy list | Do not remove; FitRPG may not call them |

---

## 8) Pre-submit smoke (after Console + deploy)

1. [ ] Guest anonymous sign-in  
2. [ ] Camera free-train FINISH → XP/gold + **+N ENERGY** toast/overlay; energy persists after relaunch  
3. [ ] Health Sync → XP/gold only, **no energy**  
4. [ ] Passive regen still works (+1 / 5 min via `regen`)  
5. [ ] World Boss empty energy copy mentions camera workout  
6. [ ] Arena spend/refund energy  
7. [ ] Soft + hard update RC gates  
8. [ ] Delete Account → `cleanupFitRPGAccount` only (siblings intact)  

---

## 9) Quick Russian summary / Кратко по-русски

1. **Auth:** Anonymous + Apple + Google.  
2. **App Check:** App Attest для Release; debug-токены для разработки.  
3. **Deploy:** только `./scripts/deploy-fitrpg-safe.sh` (rules + indexes + FitRPG CF).  
4. **Энергия:** клиент не может повысить; `adjustEnergy` (`spend`/`refund`/`regen`/`train`). Тренировка камерой: +5, лимит +40/сутки UTC. Health Sync — без энергии.  
5. **Remote Config:** ключи `fitrpg_min_version`, `fitrpg_latest_version`, `fitrpg_update_required`, `fitrpg_update_title/message/url`, `fitrpg_ios_app_store_id`.  
6. **Не трогать:** чужие функции, RC-ключи Food/Workout/Yoga, массовое удаление Auth.

---

## 10) Related docs

- Drop readiness: `.agents/knowledge/KI-audit-drop-READY-2026-07-29.md`  
- Deploy script: `scripts/deploy-fitrpg-safe.sh`  
- Legal URLs: `https://borisserz.github.io/fitrpg-legal/{privacy,support,terms}.html`
