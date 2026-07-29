# KI: App Store Compliance (FitRPG)

## Scope
App Store Review readiness для `rpg-tracker/`. Блокеры, порядок фиксов, ссылки на sibling-проекты.

**Score:** 4/10 — **NOT READY**

**Полный отчёт:** [docs/audit/2026-07-29-app-store-readiness.md](../../docs/audit/2026-07-29-app-store-readiness.md)

---

## Reject-Risk Blockers (P0)

| ID | Issue | Fix hint |
|----|-------|----------|
| **F-01** | Account deletion: нет UI, нет CF `deleteAccount` | Profile → delete flow; `AuthManager.deleteCurrentUser` + CF cleanup |
| **F-02** | Privacy/Terms/Support: нет ссылок в `PlayerProfileView`, нет FitRPG pages | Publish pages; add links in Settings |
| **F-03** | `PrivacyInfo.xcprivacy` не в pbxproj | Add to Xcode target |
| **F-04** | HealthKit: нет Health в manifest; `NSHealthUpdateUsageDescription` при `toShare:[]`; auto-request on launch | Fix plist; defer request to user action |
| **F-05** | Нет fitness medical disclaimer | Onboarding + settings text |
| **F-06** | `UpdateRequiredView` App Store ID = `id0000000000` | Real ID from App Store Connect |
| **F-07** | UGC (username/clan) без report/block | Report UI + CF moderation queue |

---

## Warnings (P1)

| ID | Issue |
|----|-------|
| F-08 | Sign in with Apple — no UI (required if Google visible) |
| F-09 | Analytics/Crashlytics not in Privacy Manifest |
| F-10 | `aps-environment` = development (need production) |
| F-11 | RU/EN localization mix |
| F-12 | Review Notes not prepared |
| F-13 | Widget placeholder, no App Group |
| F-14 | Client-side gold shop (cheat risk) |

---

## OK (no action)

F-15 gold-only (no IAP) · F-16 iOS 26.2 · F-17 ATT absent (correct) · F-18 Discord OK · F-19 age rating OK · F-20 not crypto

---

## Fix Order

```
legal → deletion → privacy manifest → HealthKit → force update URL
→ UGC → push prod → widget → economy server → P0 tests
→ Apple Sign In UI (if Google) → localization
```

---

## Sibling Reference

| Project | Path |
|---------|------|
| WorkoutTracker | `/Users/borisserzhanovich/projects/WorkoutTracker-repo` |
| FoodTracker | `/Users/borisserzhanovich/projects/FoodTracker` |
| Privacy templates | `/Users/borisserzhanovich/projects/workouttracker-privacy/` |

WorkoutTracker: 12+ tests. FitRPG: **0 tests** — добавить P0 suite перед submit.

---

## Agent Tip

Перед App Store работой читай этот KI + полный audit. Не трогай код без явного запроса на конкретный F-XX fix. Privacy/HealthKit/deletion — отдельные PR по fix order.
