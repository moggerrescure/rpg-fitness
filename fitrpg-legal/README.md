# FitRPG Legal Pages (GitHub Pages)

Static legal pages for App Store compliance. Host under GitHub Pages so the app can link to stable URLs.

## URLs (after hosting)

| Page | URL |
|------|-----|
| Privacy Policy | https://borisserz.github.io/fitrpg-legal/privacy.html |
| Terms of Use | https://borisserz.github.io/fitrpg-legal/terms.html |
| Support | https://borisserz.github.io/fitrpg-legal/support.html |

## Hosting steps

1. Push this `fitrpg-legal/` folder to a repo (e.g. `borisserz/fitrpg-legal` or as `/fitrpg-legal` in an existing user/org site repo).
2. Enable **GitHub Pages** for the branch/folder (Settings → Pages → source: branch + `/fitrpg-legal` or repo root).
3. Confirm the three URLs load in a browser.
4. Add the Privacy Policy URL in **App Store Connect** → App Information → Privacy Policy URL.

## App references

The iOS app reads these URLs from `LegalURLs.swift` in `rpg-tracker/rpg-tracker/`.
