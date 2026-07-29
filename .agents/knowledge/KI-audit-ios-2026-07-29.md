# iOS Audit — 2026-07-29

Agent: `acf146b1-bfe3-4955-96e8-ce1d78ea25d9`. Token-efficient summary only.

## Counts

**P0 × 6** · **P1 × 22** · **P2 × 18**

## Feature matrix (highlights)

| Status | Features |
|--------|----------|
| READY | Onboarding, class select, sign-out, hub/energy/XP, 1v1 queue, local boss raid, inventory, profile/legal/version gate, constellation, offline gate |
| PARTIAL | Auth link, anonymous, daily quests, free training/camera, dungeon, friend duel, 3v3, story, clans/friends/war, world boss, shop, HealthKit, notifications, widgets/LA, deep links, push |
| BROKEN | Delete account (linked: signOut only, no Auth `delete`) |

## P0 blockers

1. **Delete account Auth** — linked Apple/Google: wipe + `signOut`, not `user.delete()` (Guideline 5.1.1v)
2. **Auth hang** — anonymous fail → eternal «Connecting…»
3. **WB energy** — 15 energy spent on Attack; exit without damage = no refund
4. **Camera denied UI** — denied/restricted → blank workout, no Settings CTA
5. **Free training economy** — UI «UNLIMITED» vs silent cap 50 + double XP/gold awards
6. **Dead daily quests** — `.steps/.calories/.dungeonRun` / gold mix never progress

## Top fix order (client)

1. Delete Auth user after reauth  
2. Auth hang + camera permission UI  
3. World Boss energy refund  
4. Free training cap UI + single reward path  
5. Daily quest progress wiring  
6. Surface CF/matchmaking/clan errors (P1)  
7. Friend duel fail ≠ bot «success» (P1)  
8. Notification schedule race + deep links (P1)  
9. App Check Release + push entitlements (P1)

## Cross-cutting

Client-authoritative economy; silent `print` CF fails; shared `users/{uid}` field wipe risk; bot fallbacks blur real PvP.

## Related

- Full dump: agent transcript `acf146b1` (parent chat audit thread)
- Backend: [KI-audit-backend-2026-07-29](./KI-audit-backend-2026-07-29.md)
- Merged verdict: [KI-audit-merged-2026-07-29](./KI-audit-merged-2026-07-29.md)
