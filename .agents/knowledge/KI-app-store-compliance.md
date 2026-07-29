# App Store compliance (FitRPG)

Updated: 2026-07-29

## Public legal URLs (GitHub Pages)

Host `fitrpg-legal/` then set in App Store Connect:

- Privacy: `https://borisserz.github.io/fitrpg-legal/privacy.html`
- Support: `https://borisserz.github.io/fitrpg-legal/support.html`
- Terms: `https://borisserz.github.io/fitrpg-legal/terms.html`

In-app copies live under `rpg-tracker/rpg-tracker/Legal/` (bundled HTML via `LegalDocumentView`).

Contact email used in pages: `borisserzh5@gmail.com`

## Checklist

- [x] Privacy / Terms / Support HTML (EN)
- [x] In-app Profile links + version string
- [x] Delete Account (FitRPG-scoped)
- [x] App Store ID `6785639478`
- [ ] Enable GitHub Pages for `fitrpg-legal` (or push to `borisserz/fitrpg-legal`)
- [ ] Paste Privacy URL in ASC → App Information
- [ ] App Group `group.com.borisdev.rpg-tracker` in Developer portal
- [ ] TestFlight smoke: 1v1, 3v3, clan war, world boss empty state
