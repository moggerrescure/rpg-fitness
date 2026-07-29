# iOS Ship Audit — 2026-07-29

## Closed vs deep audit P0/P1

| Finding | Fix |
|---------|-----|
| Instant background surrender | 30s background timeout before surrender |
| WB MM energy leak / wb_local | Block worldBoss/bossRaid from PvP MM |
| Missing `rpgfitness` scheme | Added to Debug+Release URL types |
| Free train finish ignored cap | Cap remaining reps; honest “limit reached” copy |
| WB no energy gate | Pre-check 15 energy + disable button |
| Story co-op / onboarding ads | Skip co-op prompt; onboarding copy without Co-op Raids |
| Silent CF fails | `lastActionError` toasts for awards/PvP/WB/energy |
| Quest double-count | Single `recordExercise` path in free train |
| Leaderboard fake timer | Bind loading to `$leaderboards` |
| Friends deep link | `FitRPGOpenFriendsSegment` → Friends tab |
| Health → auto WB | Removed auto-attack; use Raids tab |
| Offline BattleEngine PvP mint | No `awardActivityRewards` for isPvP |

## ASC operator checklist

- [ ] App Attest enrolled in Firebase Console (Release)
- [ ] ASC Privacy/Support/Terms = GitHub Pages LegalURLs
- [ ] Privacy Nutrition Labels match HealthKit read + PrivacyInfo
- [ ] Smoke Delete Account (Apple / Google / anonymous)
- [ ] No StoreKit / IAP claims in metadata
