# FitRPG — App Store Connect ASO package (EN-US)

**Date:** 2026-07-29  
**Bundle:** `com.borisdev.rpg-tracker` · **Apple ID:** `6785639478`  
**Current ASC name:** `rpg-tracker` → **replace immediately**  
**Version:** 1.0 · **Brand maturity:** Challenger (metadata must work hard)  
**Verified against:** repo audits (`KI-audit-FINAL-DROP-2026-07-29`), PrivacyInfo, `fitrpg-legal/`, Xcode Info keys  
**Honest caveat:** Strong metadata improves discoverability and conversion. It does **not** guarantee top charts. Rankings also need ratings volume, retention, downloads, and update velocity.

---

## COPY THESE NOW

Paste these five fields first (≈5 minutes). Full blocks further below.

| Field | Paste value |
|-------|-------------|
| **Name** (27/30) | `FitRPG: Fitness Workout RPG` |
| **Subtitle** (25/30) | `Camera Reps · Arena Clans` |
| **Keywords** (99/100) | `gamify,exercise,tracker,train,pushup,squat,pullup,dungeon,boss,raid,pvp,guild,hiit,gym,quest,battle` |
| **Promotional Text** (142/170) | `Real squats and push-ups power your hero. Camera counts reps. Fight in Arena, raid bosses with your clan, clear fitness islands. Free. No IAP.` |
| **Primary category** | Health & Fitness |
| **Secondary category** | Games → Role Playing |

Store-facing paste blocks below are humanizer-cleaned (no em dashes in Description / Promo / Review Notes).

| URL | Paste value |
|-----|-------------|
| **Privacy Policy** | `https://borisserz.github.io/fitrpg-legal/privacy.html` |
| **Support URL** | `https://borisserz.github.io/fitrpg-legal/support.html` |
| **Marketing URL** | `https://borisserz.github.io/fitrpg-legal/index.html` |
| **Copyright** | `2026 Boris Serzhanovich` |

**Also flip before Submit:** Version Release → **Manually release this version** · Remote Config `fitrpg_screenshot_fill` = **false** · Home-screen display name in next binary: change `CFBundleDisplayName` from `RPG Tracker` → `FitRPG`.

---

## 1. App Information

### Name (≤30) — primary + alternates

| Option | Text | Chars | Notes |
|--------|------|------:|-------|
| **Primary (use this)** | `FitRPG: Fitness Workout RPG` | 27 | Brand + high-intent fitness + RPG. Leaves 3 chars unused. |
| Alternate A | `FitRPG: Workout RPG Arena` | 25 | Stronger “Arena” discovery; weaker pure “fitness” signal. |
| Alternate B | `FitRPG Train & Battle` | 21 | Cleaner brand voice; wastes keyword space (Challenger mistake). |

**Do not** keep `rpg-tracker`. It has zero brand and zero search value.

### Subtitle (≤30)

| Option | Text | Chars | Notes |
|--------|------|------:|-------|
| **Primary (use this)** | `Camera Reps · Arena Clans` | 25 | Differentiator + social/PvP without repeating title words. |
| Alternate A | `Camera Reps · PvP Raids` | 23 | If you prefer raid keyword in subtitle (then drop `raid` from Keywords). |
| Alternate B | `Rep Tracker · Boss Raids` | 24 | Weaker camera story; use only if camera slides are weak. |

**Rule used:** no word reuse vs title (`FitRPG`, `Fitness`, `Workout`, `RPG`).

### Categories — recommendation

| Slot | Choice | Why |
|------|--------|-----|
| **Primary** | **Health & Fitness** | Matches Xcode `LSApplicationCategoryType = healthcare-fitness`. Same shelf as Zombies, Run!. Users searching workout / fitness / exercise motivation find you. FitRPG’s wedge is *real exercise → game power*, not a pure RPG download. |
| **Secondary** | **Games → Role Playing** | Captures browse traffic for RPG/fantasy players who will still understand the fitness hook from screenshots. |

**Tradeoff (read once):** Primary **Games / Role Playing** can look cooler in Games charts, but you compete with thousands of pure RPGs and lose the Health & Fitness browse/search lane that already validates “fitness game” hybrids. For a Challenger launch, **Health & Fitness primary** is the better discovery bet. Revisit after 30–60 days of ASC Analytics if Games traffic dominates.

### Content Rights

Answer: **No** — this app does **not** contain, show, or access third-party content (unless you knowingly ship licensed music, stock art, or partner UGC feeds you do not own).

If any asset is third-party licensed, switch to **Yes** and keep license docs ready for Review. Usernames/clan text are player UGC, covered by your Terms + report/block, not this toggle.

---

## 2. Version metadata (EN-US)

### Promotional Text (≤170) — updatable anytime

```
Real squats and push-ups power your hero. Camera counts reps. Fight in Arena, raid bosses with your clan, clear fitness islands. Free. No IAP.
```

**(142/170)**

Optional A/B later (still ≤170):

```
Turn bodyweight training into combat. Camera-tracked reps fuel Arena fights, clan wars, and boss raids. Free FitRPG. No subscriptions.
```

### Description (≤4000) — conversion only (Apple does not index this)

```
FitRPG turns real workouts into RPG combat.

Do the reps. Deal the damage. Camera tracking counts squats, push-ups, and more on your iPhone. Frames stay on device. Every clean set fuels your hero's energy, XP, and gear.

WHY IT CLICKS
• Real exercise drives the game. No fake "tap to train" loop as the core loop.
• Camera pose tracking for bodyweight reps during training and dungeon runs.
• Apple Health sync (optional): steps, active energy, and workouts grant in-game rewards. Read-only. FitRPG never writes to Health.
• Pick a class, equip gear, and grow a character that gets stronger when you do.

BATTLE & MULTIPLAYER
• Arena: 1v1 and 3v3 matchmaking. Race reps. Climb ranks.
• Clans: create or join a guild, fight clan wars, stay accountable.
• Boss raids and World Boss events: hit hard together.
• Story map: clear fitness islands as you progress.

BUILT FOR SHORT SESSIONS
Train when you have a few minutes. Sync Health when you already logged a workout. Jump into Arena when you want competition. Guest play works; Sign in with Apple or Google when you want a durable account.

FREE TO PLAY
FitRPG is free. No in-app purchases and no subscriptions in this version.

IMPORTANT
FitRPG is entertainment and fitness motivation, not medical advice, diagnosis, or treatment. Talk to a doctor before starting a new exercise program. Exercise at your own risk.

Privacy Policy: https://borisserz.github.io/fitrpg-legal/privacy.html
Support: https://borisserz.github.io/fitrpg-legal/support.html
```

**Above-the-fold (first ~3 lines):** product promise + camera proof + combat payoff. No keyword stuffing. No medical claims. No IAP language beyond "free / no IAP" (accurate per audit: StoreKit not shipped).

**Social proof placeholders** (add only when true):

```
***** "Finally a fitness game where the reps are real." (replace with a real review)
Loved by early TestFlight testers (replace with rating count once live)
```

### Keywords (≤100) — comma-separated, no spaces after commas

**Primary set (pairs with Name + Subtitle above):**

```
gamify,exercise,tracker,train,pushup,squat,pullup,dungeon,boss,raid,pvp,guild,hiit,gym,quest,battle
```

**(99/100)**

**Excluded on purpose (already covered by Name/Subtitle):** `fitrpg`, `fitness`, `workout`, `rpg`, `camera`, `reps`, `arena`, `clans`  
**Excluded on purpose (policy):** competitor names (Habitica, Zombies Run, etc.), competitor trademarks, irrelevant spam.

**If you switch Subtitle to** `Camera Reps · PvP Raids`, use this Keywords set instead (drops `raid`):

```
gamify,exercise,tracker,train,pushup,squat,pullup,dungeon,boss,pvp,guild,hiit,gym,quest,battle,clan
```

(Verify length ≤100 after edit; `clan`/`clans` stemming may still collide with “Clans” — prefer keeping primary subtitle.)

### What’s New (1.0)

First release — keep short and honest:

```
FitRPG 1.0 is here.

Train with camera-tracked bodyweight reps, sync Apple Health for bonus rewards, battle in Arena 1v1 and 3v3, join clans, raid bosses, and clear fitness islands.

Thanks for playing. Email bugs to borisserzh5@gmail.com.
```

### Copyright

```
2026 Boris Serzhanovich
```

---

## 3. URLs (already live)

| Field | URL | Status |
|-------|-----|--------|
| Privacy Policy | https://borisserz.github.io/fitrpg-legal/privacy.html | Use this (audit: HTTP 200) |
| Support | https://borisserz.github.io/fitrpg-legal/support.html | Use this |
| Marketing | https://borisserz.github.io/fitrpg-legal/index.html | Fine for v1 (legal hub). Upgrade later to a real landing page. |
| Terms (link in Privacy / in-app) | https://borisserz.github.io/fitrpg-legal/terms.html | Not a separate ASC field; keep live |

**Contact email (ASC App Review + Support):** `borisserzh5@gmail.com`

**If Pages ever 404:** re-host `fitrpg-legal/` (see `fitrpg-legal/README.md`). Do not invent a Notion URL unless you publish it first.

**Minimal marketing page outline (optional later):** hero “FitRPG — workouts power combat” · 3 feature bullets (camera / Arena / clans) · App Store badge · Privacy/Support/Terms links · same contact email. No medical claims.

---

## 4. App Review Information

### Sign-in

| Field | Value |
|-------|-------|
| Sign-in required? | Yes for full multiplayer sync (guest works for core solo flows) |
| Demo username | `REVIEW_USER_PLACEHOLDER` ← replace |
| Demo password | `REVIEW_PASS_PLACEHOLDER` ← replace |

Provide a **pre-leveled Apple/Google-linked or email-capable test account** if guest alone is flaky under App Check. Guest + SIWA + Google are all supported.

### Review Notes (paste)

```
FitRPG App Review notes (v1.0)

WHAT THE APP IS
Fitness RPG: real bodyweight reps (camera pose tracking on-device) and optional Apple Health reads (steps, active energy, workouts) award in-game XP/gold/energy. Combat modes: Arena 1v1/3v3, clans/clan wars, boss raids, world boss, dungeon runs, fitness island map.

HOW TO START
1) Launch, allow guest auth (Anonymous Firebase) OR Sign in with Apple / Google.
2) Complete class selection / short onboarding if shown.
3) Hub: Train (camera) or Health sync from Profile.
4) Arena: start matchmaking. If no humans are online, bots fill matches (bot_* ids) so combat is reviewable.
5) Clans: create/join; clan war attacks do not spend Arena energy.
6) Account deletion: Profile > Delete Account (FitRPG-scoped cleanup only).

PERMISSIONS
• Camera: on-device pose / rep counting. Video frames are NOT uploaded as training video.
• HealthKit: READ only (steps, activeEnergyBurned, workoutType). App does not write Health data. Update usage string exists because HealthKit requires it even for read-only flows.
• Notifications: optional; FCM for invites/events.
• No App Tracking Transparency prompt. We do not track across apps/sites for ads (NSPrivacyTracking = false).

APP CHECK / FIREBASE
Release builds use App Attest (DeviceCheck fallback). Callables enforce App Check. If a callable fails in review, retry on a real device with network. Contact: borisserzh5@gmail.com.

CRITICAL FLAGS FOR REVIEW
• Remote Config fitrpg_screenshot_fill MUST be false (default). Do not enable screenshot wallet fill for Review.
• fitrpg_update_required = false; fitrpg_min_version empty or 1.0 (app version, NOT iOS 18.6).
• No StoreKit / IAP / subscriptions in this binary. Economy uses in-game gold only.
• UGC: usernames + clan text. Report + block available. Please exercise those if testing social.

MINIMUM OS
iOS 18.6+.

CONTACT
borisserzh5@gmail.com
```

### Version release

**Choose: Manually release this version.**

| Mode | Tradeoff |
|------|----------|
| **Manual (recommended for 1.0)** | You control go-live after Approved (fix listing typos, swap screenshots, confirm RC flags, coordinate social). |
| Automatic | Ships the moment Approved. Faster, but you lose the last checklist breath. You previously had Auto selected — switch to Manual for launch day control. |

---

## 5. Privacy Labels (App Privacy) — tick list

**Source of truth:** `PrivacyInfo.xcprivacy` + `fitrpg-legal/privacy.html` + linked Firebase SDKs (Auth, Firestore, Functions, Messaging, Remote Config, Analytics, Crashlytics).  
**Tracking:** declare **No** tracking / do not use data for tracking. No ATT prompt expected.  
**Regulated Medical Device:** **No** (fitness gamification / entertainment only; not diagnosis or treatment).

### Data collected — ASC checklist

For each type below: **Collected = Yes**. Set **Linked to User** and **Tracking** as shown. Purposes match Apple’s labels.

| ASC data type | Linked to User? | Used for Tracking? | Purposes | Why |
|---------------|-----------------|--------------------|----------|-----|
| **Health** | Yes | No | App Functionality | HealthKit reads (workouts etc.) when permitted |
| **Fitness** | Yes | No | App Functionality | Steps, active energy, workout-derived rewards |
| **Name** | Yes | No | App Functionality | Display / character name |
| **User ID** | Yes | No | App Functionality | Firebase Auth UID |
| **Email Address** | Yes | No | App Functionality | Only if user shares via Apple/Google Sign-In |
| **Device ID** | Yes | No | App Functionality | FCM / push token, Firebase install identifiers for messaging & abuse prevention |
| **Gameplay Content** | Yes | No | App Functionality | Class, XP, gold, energy, equipment, clan, battle results |
| **Other User Content** | Yes | No | App Functionality | Clan descriptions / UGC text visible to others |
| **Product Interaction** | Yes | No | Analytics, App Functionality | Firebase Analytics + gameplay interaction signals (per PrivacyInfo) |
| **Crash Data** | **No** | No | App Functionality | Crashlytics (PrivacyInfo: not linked) |

### Do **not** tick (unless behavior changes)

| Type | Why not |
|------|---------|
| Photos or Videos | Camera frames processed on-device; not uploaded as media |
| Precise / Coarse Location | Not a core feature |
| Purchase History / Payment Info | No IAP |
| Advertising Data | No ad network / no tracking declaration |
| Sensitive Info | Not collected |
| Contacts, Browsing History, Search History | Not collected |

### Privacy Policy URL (required)

`https://borisserz.github.io/fitrpg-legal/privacy.html` — must match labels (already describes Auth, HK read-only, on-device camera, Analytics/Crashlytics, no data sale).

---

## 6. Age Ratings — suggested questionnaire answers

Approximate expected rating: **12+** (cartoon/fantasy combat + user interaction). Final letter rating is Apple’s computation.

| Topic (ASC questionnaire language varies) | Suggested answer | Rationale |
|-------------------------------------------|------------------|-----------|
| Cartoon or Fantasy Violence | Infrequent / Mild | RPG combat, bosses; not realistic gore |
| Realistic Violence | None | No photoreal combat |
| Sexual Content / Nudity | None | |
| Profanity or Crude Humor | None (unless UGC allows it — moderate via report) | Prefer None; UGC moderated |
| Alcohol, Tobacco, Drugs | None | |
| Horror / Fear Themes | None or Infrequent | Boss fantasy only; not horror-first |
| Mature / Suggestive Themes | None | |
| Medical / Treatment Information | None as “medical app”; wellness/fitness motivation yes if asked | Not a medical device |
| Unrestricted Web Access | No | No embedded open browser |
| Gambling / Contests | No real-money gambling | In-game competition only |
| User-Generated Content | Yes | Usernames, clan text; report/block present |
| Age Assurance / Kids | Not directed to children under 13 | Aligns with Privacy Policy |

---

## 7. ASO strategy

### Brand maturity & score context

Challenger app. Current ASC name `rpg-tracker` is an F on Title. Filling empty Description / Keywords / Promo / Categories / Privacy is the highest-ROI hour you can spend before Submit.

### Keyword map

| Tier | Terms | Where they live |
|------|-------|-----------------|
| Primary | fitness, workout, RPG, FitRPG | Name |
| Differentiator | camera, reps, arena, clans | Subtitle |
| Secondary | gamify, exercise, tracker, train, pushup, squat, pullup, dungeon, boss, raid, pvp, guild, hiit, gym, quest, battle | Keywords field |
| Long-tail (description / screenshots, not Keywords) | fitness RPG, workout game, bodyweight combat, clan war, world boss, HealthKit rewards | Description + screenshot captions |

**Cannot assess without paid tools:** exact search volume, difficulty, current rankings.

### Screenshot order (iPhone — conversion)

You have 10 slides. **First 3 get ~90% of attention** in search results.

**Recommended ASC upload order:**

| Slot | Source slide | Job |
|------|--------------|-----|
| 1 | `01-home` — “Level up with real workouts.” | Hook |
| 2 | `10-dungeon` — “Camera tracks every rep.” | Differentiator (do not bury camera on slide 10) |
| 3 | `04-arena` — “Every battle starts here.” | Payoff / social proof of combat |
| 4 | `07-boss` or `09-worldboss` | Spectacle |
| 5 | `08-clan` | Retention / social |
| 6 | `06-matchmaking` | Ranked clarity |
| 7 | `05-islands` | Progression depth |
| 8 | `03-train` | Training grounds detail |
| 9 | `02-profile` | Gear / identity |
| 10 | remaining boss/worldboss | Depth |

Captions are indexed (Apple AI extraction since 2025) — keep the existing punchy lines; avoid stuffing competitor names.

### Icon / preview video

- **Icon:** Readable at small size. Prefer bold “FitRPG” mark / shield / hero silhouette over busy UI chrome. Avoid tiny text.
- **Preview video (high ROI on iOS):** 15–30s, muted-autoplay friendly: 3s hook (rep → damage number) → Arena clash → clan/boss beat → end card with name. Expect meaningful conversion lift vs screenshots alone.
- **Display name:** ship a binary with `CFBundleDisplayName = FitRPG` so the home screen matches the store name.

### Localization

- **v1:** EN-US only (UI is English-only). Correct choice.
- **Add RU** when you have RU screenshots + RU support capacity and RU traffic in ASC Analytics.
- **Add ES** after RU or when US Hispanic / LATAM installs show demand.
- Never machine-translate Keywords without a native pass (byte limits + tone).

### Competitor angles

| App | Their lane | Your wedge |
|-----|------------|------------|
| **Habitica** | Task/habit RPG (checklists → loot) | Real camera-counted reps and Health sync power combat — not checkbox fantasy |
| **Zombies, Run!** | Audio running stories + GPS | Strength/bodyweight combat + PvP Arena + clans; not outdoor audio narrative |
| Generic workout trackers | Logs and charts | Game loop, matchmaking, bosses, islands |

Own the sentence: **“Your reps are the combat system.”**

### 30-day post-launch iteration plan

| Day | Action |
|-----|--------|
| 0 | Manual release after Approved. Verify RC flags. Respond to every review in week 1. |
| 1–3 | Watch ASC impressions → product page views → units. Note which search terms appear (ASC Analytics). |
| 7 | First Promo Text swap if conversion weak (no new binary needed). |
| 14 | Screenshot PPO test: swap slot 2/3 (camera vs Arena). Icon test only if alternate icons are in the binary. |
| 21 | Keyword tweak from actual search terms (still no title/subtitle duplicates). |
| 30 | Decide category rethink only if data says Games browse >> Health browse. Plan RU if geo justifies. |

Prompt ratings after a clear win (Arena victory / island clear) via `SKStoreReviewController` (max 3/year).

### Honest limits

Metadata cannot buy #1. Without ratings, retention, and a working first session, even perfect Keywords stall. This package maximizes the listing; product quality and reviews carry the rest.

---

## 8. Pre-submit operator reminders (non-copy)

From `KI-xcode-asc-operator` / FINAL DROP audit:

- [ ] Paste Privacy / Support / Marketing URLs  
- [ ] Nutrition labels per §5  
- [ ] Age rating questionnaire per §6  
- [ ] Screenshots: 6.9" iPhone required; 13" iPad if iPad is supported  
- [ ] Review notes + demo credentials  
- [ ] Manual release  
- [ ] `fitrpg_screenshot_fill=false`  
- [ ] App Attest enrolled for FitRPG iOS  
- [ ] Next binary: display name `FitRPG` (not `RPG Tracker`)

---

## 9. Sources checked

- `.agents/knowledge/KI-audit-FINAL-DROP-2026-07-29.md` (no IAP; HK; camera on-device; bots; RC flags)  
- `.agents/knowledge/KI-xcode-asc-operator-2026-07-29.md` (legal URLs, Apple ID)  
- `rpg-tracker/PrivacyInfo.xcprivacy`  
- `fitrpg-legal/privacy.html` / `support.html` / `index.html`  
- Xcode `INFOPLIST_KEY_*` (camera, HealthKit, category healthcare-fitness, display name RPG Tracker)  
- `marketing/app-store-screenshots/app-store-screenshots.json` (10 iPhone slides)  
- Light competitor scan: Habitica, Zombies, Run! category positioning  

**Skills applied:** `aso` (metadata strategy + conversion), `humanizer` (copy pass), `app-store-review` (Review Notes / rejection risks).
