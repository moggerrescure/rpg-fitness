# FitRPG Legal Pages (GitHub Pages)

Static legal pages for App Store compliance. Host under GitHub Pages so the app can link to stable URLs.

## URLs (after hosting)

| Page | URL |
|------|-----|
| Privacy Policy | https://borisserz.github.io/fitrpg-legal/privacy.html |
| Terms of Use | https://borisserz.github.io/fitrpg-legal/terms.html |
| Support | https://borisserz.github.io/fitrpg-legal/support.html |

Contact: borisserzh5@gmail.com

## Hosting steps

1. Push this folder to `Borisserz/fitrpg-legal` (or enable Pages from this monorepo `/fitrpg-legal`).
2. Enable **GitHub Pages** (Settings → Pages → Deploy from branch `main` / root).
3. Confirm the three URLs load in a browser.
4. Add the Privacy Policy URL in **App Store Connect** → App Information → Privacy Policy URL.
5. Optionally set Support URL on the App Store product page.

## App references

The iOS app reads these URLs from `LegalURLs.swift` and ships bundled copies under `rpg-tracker/rpg-tracker/Legal/`.
