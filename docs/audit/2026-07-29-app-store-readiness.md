# App Store Readiness Audit — FitRPG

**Date:** 2026-07-29  
**App:** FitRPG (`rpg-tracker/`)  
**Score:** **4/10 — NOT READY**  
**Auditor context:** Сравнение с sibling-проектами WorkoutTracker, FoodTracker, workouttracker-privacy

---

## Executive Summary

FitRPG **не готов** к отправке в App Store Review. Обнаружено **7 блокеров reject-risk** (F-01–F-07), **7 предупреждений** (F-08–F-14) и **6 положительных сигналов** (F-15–F-20). Критичные пробелы: отсутствие удаления аккаунта, юридических ссылок, Privacy Manifest, корректной HealthKit-интеграции, medical disclaimer, валидного App Store ID для force-update и UGC moderation.

**Рекомендуемый порядок фиксов:** legal → deletion → privacy manifest → HealthKit → force update URL → UGC → push prod → widget → economy server → P0 tests → Apple Sign In UI (если Google) → localization

---

## Score Breakdown

| Category | Status | Notes |
|----------|--------|-------|
| Account & Data | ❌ Blocker | F-01, F-02 |
| Privacy & Compliance | ❌ Blocker | F-03, F-04, F-05 |
| App Metadata & Config | ❌ Blocker | F-06 |
| UGC & Safety | ❌ Blocker | F-07 |
| Auth & Analytics | ⚠️ Warning | F-08, F-09 |
| Push & Localization | ⚠️ Warning | F-10, F-11, F-12 |
| Widget & Economy | ⚠️ Warning | F-13, F-14 |
| Monetization & Platform | ✅ OK | F-15–F-20 |

---

## Reject-Risk Findings (P0)

### F-01 — Account Deletion

| Field | Detail |
|-------|--------|
| **Severity** | Reject-risk (Guideline 5.1.1(v)) |
| **Status** | ❌ Missing |

**Проблема:** UI для удаления аккаунта отсутствует. Cloud Function `deleteAccount` не реализована.

**Что есть, но не используется:**
- `reauthenticateForDeletion` — заготовка re-auth перед удалением
- `AuthManager.deleteCurrentUser` — метод существует, но нигде не вызывается из UI

**Требование Apple:** Приложения с регистрацией аккаунта обязаны предоставлять in-app удаление аккаунта и связанных данных.

**Fix:**
1. Добавить пункт «Удалить аккаунт» в `PlayerProfileView` (Settings)
2. Реализовать flow: re-auth → confirm → `deleteCurrentUser` + CF `deleteAccount` (Firestore cleanup)
3. Показать пользователю, какие данные будут удалены

---

### F-02 — Privacy Policy / Terms of Service / Support

| Field | Detail |
|-------|--------|
| **Severity** | Reject-risk (Guideline 5.1.1, 1.5) |
| **Status** | ❌ Missing |

**Проблема:**
- В `PlayerProfileView` нет ссылок на Privacy Policy, Terms of Service, Support
- Страницы FitRPG (privacy/terms/support) не опубликованы

**Fix:**
1. Опубликовать страницы (можно на базе `workouttracker-privacy/` как reference)
2. Добавить ссылки в Profile/Settings: Privacy, Terms, Support (mailto или web)
3. Указать URL в App Store Connect metadata

---

### F-03 — PrivacyInfo.xcprivacy Not in pbxproj

| Field | Detail |
|-------|--------|
| **Severity** | Reject-risk (Privacy Manifest requirement) |
| **Status** | ❌ Missing |

**Проблема:** Файл `PrivacyInfo.xcprivacy` не добавлен в Xcode project (`pbxproj`). Apple требует Privacy Manifest для приложений, использующих required reason APIs и сторонние SDK.

**Fix:**
1. Создать/обновить `PrivacyInfo.xcprivacy` с declared API reasons
2. Добавить файл в target через Xcode (появится в `pbxproj`)
3. Проверить, что Firebase/Analytics SDK privacy manifests подтягиваются

---

### F-04 — HealthKit Integration Issues

| Field | Detail |
|-------|--------|
| **Severity** | Reject-risk (Guideline 2.5.1, HealthKit) |
| **Status** | ❌ Misconfigured |

**Проблемы:**
1. **Info.plist:** `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription` — Health usage descriptions отсутствуют или некорректны в manifest
2. **`NSHealthUpdateUsageDescription` при `toShare:[]`:** Запрошено описание write-access, но массив `toShare` пуст — несоответствие
3. **Auto-request on launch:** HealthKit authorization запрашивается автоматически при старте приложения без контекста для пользователя

**Fix:**
1. Добавить корректные Health usage descriptions в Info.plist
2. Убрать `NSHealthUpdateUsageDescription` если write не нужен (`toShare:[]`)
3. Перенести HealthKit request на explicit user action (кнопка «Подключить Health» в onboarding/settings)
4. Добавить HealthKit capability в entitlements если используется

---

### F-05 — Fitness Medical Disclaimer

| Field | Detail |
|-------|--------|
| **Severity** | Reject-risk (Guideline 1.4.1 — Physical Harm) |
| **Status** | ❌ Missing |

**Проблема:** Приложение использует fitness/health data (HealthKit, workout tracking), но не содержит medical disclaimer.

**Fix:**
1. Добавить disclaimer в onboarding и/или settings:
   > «FitRPG не является медицинским приложением. Проконсультируйтесь с врачом перед началом программы упражнений.»
2. Указать в App Store description

---

### F-06 — UpdateRequiredView Invalid App Store ID

| Field | Detail |
|-------|--------|
| **Severity** | Reject-risk (broken functionality) |
| **Status** | ❌ Placeholder |

**Проблема:** `UpdateRequiredView` содержит placeholder App Store ID `id0000000000`. Force-update flow ведёт на несуществующую страницу.

**Fix:**
1. Заменить на реальный App Store ID после создания listing в App Store Connect
2. Использовать Remote Config для ID (как в WorkoutTracker)

---

### F-07 — UGC Without Report/Block

| Field | Detail |
|-------|--------|
| **Severity** | Reject-risk (Guideline 1.2 — User Generated Content) |
| **Status** | ❌ Missing |

**Проблема:** User-generated content (username, clan name/description) доступен другим пользователям, но нет механизмов report/block.

**Fix:**
1. Добавить «Пожаловаться» на профиль/clan
2. Добавить block user (скрыть из friends/matchmaking)
3. Backend: CF для report queue + moderation flag
4. Описать moderation policy в Terms

---

## Warning Findings (P1)

### F-08 — Sign in with Apple No UI

| Field | Detail |
|-------|--------|
| **Severity** | Warning |
| **Status** | ⚠️ Partial |

**Проблема:** `SocialAuthService` поддерживает Apple Sign In, но UI-кнопка отсутствует. Если Google Sign In виден пользователю — Apple **обязателен** (Guideline 4.8).

**Fix:** Добавить «Sign in with Apple» кнопку рядом с Google (если Google exposed).

---

### F-09 — Analytics/Crashlytics Not in Manifest

| Field | Detail |
|-------|--------|
| **Severity** | Warning |
| **Status** | ⚠️ Incomplete |

**Проблема:** Firebase Analytics и Crashlytics используются, но не отражены в Privacy Manifest / App Privacy labels.

**Fix:**
1. Declared data types в `PrivacyInfo.xcprivacy`
2. App Store Connect → App Privacy questionnaire

---

### F-10 — aps-environment: development

| Field | Detail |
|-------|--------|
| **Severity** | Warning |
| **Status** | ⚠️ Wrong env |

**Проблема:** Push notification entitlement `aps-environment` = `development`. Production build требует `production`.

**Fix:** Переключить на production перед Archive/Upload; проверить provisioning profile.

---

### F-11 — RU/EN Localization Mix

| Field | Detail |
|-------|--------|
| **Severity** | Warning |
| **Status** | ⚠️ Inconsistent |

**Проблема:** UI содержит смесь русских и английских строк без единой локализации.

**Fix:**
1. Выбрать primary locale (RU или EN)
2. Вынести все строки в `Localizable.strings`
3. App Store metadata на том же языке

---

### F-12 — Review Notes Needed

| Field | Detail |
|-------|--------|
| **Severity** | Warning |
| **Status** | ⚠️ Not prepared |

**Проблема:** Нет подготовленных Review Notes для Apple reviewer.

**Fix:** Подготовить notes:
- Demo account credentials
- HealthKit permission flow explanation
- Multiplayer/test mode instructions
- Feature flags / Remote Config keys

---

### F-13 — Widget Placeholder, No App Group

| Field | Detail |
|-------|--------|
| **Severity** | Warning |
| **Status** | ⚠️ Incomplete |

**Проблема:** `FitRPGWidget` — placeholder без App Group для shared data между app и widget extension.

**Fix:**
1. Настроить App Group entitlement
2. Shared UserDefaults/Container для character stats
3. Или убрать widget target до v1.1

---

### F-14 — Client-Side Gold Shop

| Field | Detail |
|-------|--------|
| **Severity** | Warning |
| **Status** | ⚠️ Security risk |

**Проблема:** `ArmoryShopView` — покупки за gold обрабатываются на клиенте без server validation. Возможен cheat/exploit.

**Fix:**
1. Server-side purchase validation (Cloud Function)
2. Firestore security rules для gold balance
3. Не блокер для v1 если gold не IAP

---

## Positive Findings (OK)

### F-15 — Gold-Only Economy (No IAP)

✅ Магазин использует in-game gold, не real-money IAP. StoreKit не требуется для v1.

### F-16 — iOS 26.2 Deployment Target

✅ Современный deployment target. Liquid Glass / iOS 26 APIs доступны.

### F-17 — ATT Correctly Absent

✅ App Tracking Transparency не нужен — нет cross-app tracking / IDFA usage.

### F-18 — Discord Integration OK

✅ Discord deep link / community integration не нарушает guidelines.

### F-19 — Age Rating Appropriate

✅ Контент подходит для 12+ / Teen rating (fantasy combat, no real gambling).

### F-20 — Not Crypto/NFT

✅ Нет cryptocurrency, NFT, или blockchain mechanics. Guideline 3.1.5 не применим.

---

## Sibling Projects Reference

| Project | Path | Relevance |
|---------|------|-----------|
| WorkoutTracker | `/Users/borisserzhanovich/projects/WorkoutTracker-repo` | Reference implementation: 12+ tests, privacy pages, HealthKit flow, Remote Config |
| FoodTracker | `/Users/borisserzhanovich/projects/FoodTracker` | UI patterns, localization |
| workouttracker-privacy | `/Users/borisserzhanovich/projects/workouttracker-privacy/` | Privacy Policy / Terms templates |

---

## Test Coverage Gap

| Project | Test Count | Notes |
|---------|------------|-------|
| **FitRPG** | **0** | ❌ No unit/UI tests |
| WorkoutTracker | 12+ | Reference baseline |

**P0 tests to add before release:**
- Auth flow (sign in, sign out)
- Account deletion flow
- HealthKit authorization (mock)
- Character sync (Firestore)
- Shop purchase (gold deduction)
- Multiplayer matchmaking (integration)

---

## Fix Order (Recommended)

```
1. Legal pages (Privacy, Terms, Support)     → F-02
2. Account deletion UI + CF                   → F-01
3. PrivacyInfo.xcprivacy in pbxproj           → F-03, F-09
4. HealthKit manifest + deferred request      → F-04
5. Medical disclaimer                         → F-05
6. Force update App Store ID                  → F-06
7. UGC report/block                           → F-07
8. Push aps-environment production            → F-10
9. Widget App Group or remove                 → F-13
10. Server-side gold validation               → F-14
11. P0 test suite                             → Test gap
12. Apple Sign In UI (if Google visible)      → F-08
13. Localization cleanup                      → F-11
14. Review notes                              → F-12
```

---

## Pre-Submission Checklist

### Blockers (must fix)

- [ ] **F-01** Account deletion UI + Cloud Function
- [ ] **F-02** Privacy / Terms / Support links in app + published pages
- [ ] **F-03** PrivacyInfo.xcprivacy added to Xcode project
- [ ] **F-04** HealthKit descriptions correct; no auto-request on launch
- [ ] **F-05** Medical disclaimer in app
- [ ] **F-06** Real App Store ID in UpdateRequiredView
- [ ] **F-07** UGC report/block mechanism

### Warnings (should fix)

- [ ] **F-08** Sign in with Apple button (if Google exposed)
- [ ] **F-09** Analytics/Crashlytics in Privacy Manifest
- [ ] **F-10** aps-environment = production
- [ ] **F-11** Consistent RU or EN localization
- [ ] **F-12** Review Notes prepared
- [ ] **F-13** Widget App Group or removed from target
- [ ] **F-14** Server-side gold shop validation

### App Store Connect

- [ ] App Privacy questionnaire completed
- [ ] Screenshots (6.7", 6.5", iPad if universal)
- [ ] App description + keywords
- [ ] Support URL live
- [ ] Privacy Policy URL live
- [ ] Age rating questionnaire
- [ ] Export compliance (no encryption beyond HTTPS)

### Build

- [ ] Archive with Release configuration
- [ ] No DEBUG flags / App Check debug provider
- [ ] Version/build number incremented
- [ ] dSYMs uploaded for Crashlytics

---

## Related Documents

- KI-карточка: [`.agents/knowledge/KI-app-store-compliance.md`](../../.agents/knowledge/KI-app-store-compliance.md)
- iOS app overview: [`.agents/knowledge/KI-ios-app.md`](../../.agents/knowledge/KI-ios-app.md)
- Manual setup: `MANUAL_SETUP_GUIDE.md`

---

*Generated: 2026-07-29 | Next review: after P0 fixes*
