# FitRPG — что сделать в Xcode / ASC (кроме Archive)

**Date:** 2026-07-29  
**Minimum iOS (repo):** **18.6** (app + widget targets)  
**Marketing version:** `1.0` · Build: bump in Xcode before each upload  
**Bundle ID:** `com.borisdev.rpg-tracker` · Team: `LSCCP92LMG` · Store ID: `6785639478`

> **Важно:** Remote Config `fitrpg_min_version` — это **версия приложения** (`1.0`, `1.0.1`), **не** iOS 18.6.  
> Если в RC поставить `18.6`, все клиенты на `1.0` получат hard update-экран. iOS floor — только Xcode Deployment Target + ASC Availability.

---

## Уже в репо (не надо руками в коде)

- [x] Deployment Target **18.6** (rpg-tracker Debug/Release + FitRPGWidget)
- [x] Entitlements: SIWA, HealthKit, App Groups, Push (`development` Debug / `production` Release)
- [x] App Attest provider в Release (`FitRPGApp`)
- [x] Update screen + RC keys `fitrpg_*`
- [x] Privacy URL pages live

---

## В Xcode — проверить перед Archive (руками)

### Signing & Capabilities (target `rpg-tracker`)
1. [ ] **Signing & Capabilities** → Team `LSCCP92LMG`, Automatically manage signing ON  
2. [ ] Bundle ID `com.borisdev.rpg-tracker` совпадает с ASC + Firebase iOS app  
3. [ ] Capabilities присутствуют и без красных ошибок:
   - Sign in with Apple  
   - HealthKit  
   - Push Notifications  
   - App Groups → `group.com.borisdev.rpg-tracker`  
4. [ ] Target **FitRPGWidget**: тот же Team, App Group тот же, Deployment **18.6**  
5. [ ] Scheme **rpg-tracker** → **Any iOS Device (arm64)** (не симулятор) для Archive  
6. [ ] Configuration **Release** для Archive  
7. [ ] Entitlements для Release: `rpg-tracker.Release.entitlements` (`aps-environment` = **production**)  
8. [ ] `GoogleService-Info.plist` лежит в target (файл в `.gitignore` — должен быть **локально** у тебя; в git не коммитится)

### Versioning (перед каждой заливкой)
9. [ ] **Marketing Version** (CFBundleShortVersionString) — сейчас `1.0`; подними при апдейте (`1.0.1`…)  
10. [ ] **Build** (CFBundleVersion) — **обязательно +1** к тому, что уже в TF/ASC  
11. [ ] Widget Marketing/Build совпадают с app (или Xcode синхронизирует через project settings)

### Build Settings sanity
12. [ ] iOS Deployment Target **18.6** на app + widget (уже в pbxproj)  
13. [ ] Нет старых `16.2` в Project → Info → Deployment  

### Archive → Upload
14. [ ] Product → Archive  
15. [ ] Organizer → Distribute App → App Store Connect → Upload  
16. [ ] Дождаться обработки билда в ASC → добавить в TestFlight group  

---

## App Store Connect (не Xcode, но обязательно)

1. [ ] Availability / Minimum OS: **iOS 18.6** (ты сказал — настроено)  
2. [ ] Privacy Policy URL: `https://borisserz.github.io/fitrpg-legal/privacy.html`  
3. [ ] Support URL: `https://borisserz.github.io/fitrpg-legal/support.html`  
4. [ ] Terms: `https://borisserz.github.io/fitrpg-legal/terms.html`  
5. [ ] Age rating / Export compliance  
6. [ ] App Privacy (Nutrition Labels) ↔ HealthKit read + no tracking  
7. [ ] Screenshots под iPhone (после UI polish)  
8. [ ] Review notes: SIWA + Google + guest; Delete Account FitRPG-scoped; HK read-only; camera on-device; no IAP; UGC report+block  

---

## Firebase (параллельно Archive)

См. [KI-firebase-operator-checklist-2026-07-29.md](./KI-firebase-operator-checklist-2026-07-29.md)

Критично до TF:
- [ ] App Check → **App Attest** для FitRPG iOS  
- [ ] Auth: Anonymous + Apple + Google  
- [ ] RC `fitrpg_*` с **app** versions, не iOS:
  - Day-1: `fitrpg_min_version` пусто или `1.0`, `fitrpg_update_required` = false  
  - `fitrpg_update_url` = `https://apps.apple.com/app/id6785639478`  

---

## Что НЕ нужно делать в Xcode

- Менять Remote Config (это Firebase Console)  
- Деплоить Cloud Functions из Xcode  
- Коммитить `GoogleService-Info.plist`  
- Ставить Deployment Target ниже 18.6 «для совместимости» — floor зафиксирован  
