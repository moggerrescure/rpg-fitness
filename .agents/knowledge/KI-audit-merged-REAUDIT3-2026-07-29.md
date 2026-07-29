# REAUDIT3 — FitRPG — 2026-07-29 (post-7bf3cdf)

Four-way re-audit after honesty push `7bf3cdf`.

> **Superseded by** [KI-audit-merged-REAUDIT3-FIX-2026-07-29.md](./KI-audit-merged-REAUDIT3-FIX-2026-07-29.md) — code P0/P1 closed; ASC operator residual.

## Overall: **CONDITIONAL** (historical)

| Lens | Verdict |
|------|---------|
| Backend integrity | CONDITIONAL — energy/gold delete→reintroduce |
| iOS core mechanics (12 gates) | YES (honesty) / CONDITIONAL (ops) |
| UI/UX honesty | **NO** — celebration overlays still lie |
| Apple Guidelines | CONDITIONAL — HK Update key + ASC + UGC block |

Prior KI “YES (honesty bar)” is **overstated for UX rewards** and **energy field-delete**.

## Must-fix before clean YES

### Code P0
1. **Reward celebrations** — PvP overlay hardcodes +250/+60; Boss Raid/Dungeon show uncapped XP vs CF cap 500/250; Story shows rewards without CF mint; PvE CF fail still celebrates (`BattleArenaView`, `BossRaidView`, `DungeonRunView`)
2. **Rules energy/gold delete→reintroduce** — `fitrpgEnergyNotIncreased` true when energy omitted from update (`firestore.rules`)
3. **`NSHealthUpdateUsageDescription`** in pbxproj (even if read-only HealthKit)

### Operator / ASC
4. Privacy/Support URLs in App Store Connect = `LegalURLs.public*`
5. Review notes: delete path, HK read-only, camera on-device, free/no IAP, SIWA+Google
6. App Attest enrollment for Release

### P1
- UGC Block user (Guideline 1.2)
- Friend request → `lastActionError`
- PvP 10 energy on cards; Health “& energy” copy; onboarding clan-raid flavor
- Remove dead `StoryModePromptInlineView`
- Boss Raid card “WORLD BOSS” mislabel

## What holds (post-7bf3cdf)
- Stamp battles + no client winnerId; refund ledger; clanId/trophies; activity allowlist; PII strip CF
- Free-train FINISH-once; quest single path; Health Sync no fake WB DMG; Story SOLO ship path
- Delete `cleanupFitRPGAccount`; SIWA+Google; no IAP; Legal Pages live; App Check Release

## Agents
- Backend: 9dbfef32 — CONDITIONAL
- iOS core: ac25a01f — YES/CONDITIONAL
- UI/UX: 8c9ee8eb — NO (celebrations)
- Apple: b216a11d — CONDITIONAL
