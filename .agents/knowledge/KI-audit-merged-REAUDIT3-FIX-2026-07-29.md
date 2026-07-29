# REAUDIT3-FIX — FitRPG — 2026-07-29

Post-REAUDIT3 honesty + Apple code blockers closed. Uncommitted local iOS/rules/CF changes; **rules + functions deployed** via `scripts/deploy-fitrpg-safe.sh`.

## Overall: **YES (code honesty)** / **CONDITIONAL (ASC operator)**

| Lens | Verdict |
|------|---------|
| Backend integrity | **YES** — energy/gold omit-then-reintroduce closed; story stage via `awardActivityRewards` |
| iOS core mechanics | **YES** |
| UI/UX honesty | **YES** — celebrations use CF/capped amounts; PvE fail → toast, no fake win |
| Apple Guidelines (code) | **YES** — `NSHealthUpdateUsageDescription` Debug+Release; UGC Block |
| Apple Guidelines (ASC) | **CONDITIONAL** — operator residuals |

## P0 closed

| Item | Status |
|------|--------|
| DuelResultOverlay hardcoded +250/+60 | **YES** — `lastPvPSettlement` from `resolvePvPBattle` |
| Boss Raid / Dungeon uncapped XP | **YES** — UI + settle use `FitRPGEconomyCaps` (500/250) |
| Story win client mint | **YES** — CF `awardActivityRewards` reason `story` + `completedStoryStage` |
| PvE CF fail celebrates | **YES** — `lastActionError`; BossRaid no victory on fail; Dungeon no `.victory` |
| Energy/gold delete→reintroduce | **YES** — `fitrpgEnergyNotIncreased` + `fitrpgGoldNotIncreased` require field present |
| NSHealthUpdateUsageDescription | **YES** — pbxproj Debug+Release |

## P1 closed

| Item | Status |
|------|--------|
| Block user (UGC 1.2) | **YES** — UserDefaults + Friends menus; hide search/list; refuse duel |
| Friend request → toast | **YES** — `lastActionError` |
| Arena 10 ENERGY + disable | **YES** |
| Health Sync «& energy» | **YES** removed |
| Onboarding clan-raid overclaim | **YES** |
| StoryModePromptInlineView Coming soon | **YES** gutted |
| Boss Raid WORLD BOSS mislabel | **YES** → LOCAL RAID |

## Residuals (operator / ASC — not code blockers)

1. Privacy/Support URLs in App Store Connect = `LegalURLs.public*`
2. Review notes: delete path, HK read-only, camera on-device, free/no IAP, SIWA+Google
3. App Attest enrollment for Release
4. Nutrition Labels (if ASC requires)
5. Optional: HP forge / App Attest hardening beyond current App Check Release

## Deploy

- `scripts/deploy-fitrpg-safe.sh` — **success** (rules + FitRPG-scoped functions)
- No recursive `deleteAccount` for FitRPG cleanup path
