# Merged Ship Audit — 2026-07-29 (honesty bar)

After implementing ship-readiness plan (PvP forge lock, energy CF, clan trophies, client honesty).

## Verdict

**YES — App Store submission ready** for the chosen bar (*ship + honesty*): Guideline-critical paths, forgeable economy holes from deep audit, and misleading UI closed. Not a “100% every feature built” product (story co-op intentionally absent).

| Gate | Status |
|------|--------|
| Battles participant-scoped + server-derived PvP winner | PASS |
| Energy increases CF-only (`adjustEnergy`) | PASS |
| Clan trophies CF-only; memberIds membership gate | PASS |
| Free-train daily cap honored on finish | PASS |
| WB energy pre-check; no WB MM energy leak | PASS |
| Background surrender 30s delay | PASS |
| Story co-op removed from ship UI / onboarding | PASS |
| `rpgfitness://` URL scheme registered | PASS |
| CF error toasts / quest double-count / leaderboard load | PASS |
| Health sync no auto WB attack | PASS |
| Public search/leaderboard strip overshare | PASS |
| Legal URLs live (GitHub Pages) | PASS (verified HTTPS) |
| Delete = `cleanupFitRPGAccount` only | PASS |
| App Check on FitRPG callables | PASS |

## Residual (non-blocking / operator)

- **Firebase Console:** enroll App Attest for Release bundle `com.borisdev.rpg-tracker` if not already.
- ASC metadata: Privacy/Support/Terms = LegalURLs.public*; no IAP claims.
- Node 20 CF runtime deprecation warning (upgrade later).
- Story co-op not built (removed from UI — honest).
- Combat HP still client-synced among *participants only*; rewards derived server-side.
- Shared recursive `deleteAccount` still deployed for Food/Workout — FitRPG must never call it.

## Deploy

- `scripts/deploy-fitrpg-safe.sh` → `serzhanovich-ecosystem-ce700` (rules + FitRPG CF including new `adjustEnergy`)

## Related

- [KI-audit-backend-SHIP-2026-07-29](./KI-audit-backend-SHIP-2026-07-29.md)
- [KI-audit-ios-SHIP-2026-07-29](./KI-audit-ios-SHIP-2026-07-29.md)
