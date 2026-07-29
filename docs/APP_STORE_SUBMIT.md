# FitRPG — App Store submit checklist (remaining manual steps)

Code foundation is largely in place on `main`. Complete these before upload:

## You must do in Apple / hosting

1. **Publish legal pages** to a stable HTTPS host  
   - Files live in `fitrpg-legal/`  
   - App currently uses jsDelivr CDN URLs (works now)  
   - Preferred: create GitHub Pages site `fitrpg-legal` or add under `borisserz.github.io` and update `LegalURLs.swift`

2. **App Store Connect**  
   - Create app listing, get real numeric App ID  
   - Set `AppStoreConfig.bundledAppStoreID` or Remote Config `rpg_ios_app_store_id`  
   - Fill Privacy Policy / Support URLs, age rating (Fitness + mild fantasy violence), screenshots

3. **Apple Developer capabilities**  
   - Enable App Group `group.com.borisdev.rpg-tracker` for app + widget  
   - Production push for Release archives (`aps-environment`)

4. **Firebase (shared project — follow `docs/DEPLOY_ECOSYSTEM.md`)**  
   - Deploy **new callables only** (e.g. `declineFriendRequest`) after confirming shared AI exports remain in `functions/src/index.ts`  
   - Deploy `firestore.rules` only after reviewing yoga merge (already in repo)  
   - Publish Remote Config `rpg_*` keys; keep min version empty until store URL is real

5. **TestFlight** on a physical device: camera, HealthKit grant from Health tab, Live Activity, push, Sign in with Apple, Delete Account, clan war, shop, daily quest claim

## Already landed in code (high level)

- Build fix, English onboarding, legal links, Apple Sign-In UI, scoped delete account  
- PrivacyInfo expanded + in Xcode target  
- Clan war / equip / decline / Boss Raid → Cloud Functions  
- Daily quests + claim, widget App Group writes, friend Report  
- Shared CF restored (Food/Workout safe if deploy includes them)  
- Training reward daily cap, HealthKit not auto-prompted on launch
