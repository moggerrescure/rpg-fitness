#!/usr/bin/env node
/**
 * Headless FitRPG export via Playwright for a given device.
 * Usage: node scripts/export-device.mjs <device> [baseUrl]
 * Expects `npm run dev` already running (default http://localhost:3000).
 * Device must match app-store-screenshots.json `device` (or switch in editor).
 */
import { chromium } from "playwright";

const device = process.argv[2] || "iphone";
const BASE = process.argv[3] || "http://localhost:3000";
const URL = `${BASE}/?saveExports=1`;

async function main() {
  console.error(`Opening ${URL} (expect device=${device} in project JSON)`);
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({
    viewport: { width: 1440, height: 900 },
  });
  page.setDefaultTimeout(120_000);

  await page.goto(URL, { waitUntil: "networkidle" });
  await page.evaluate(() => localStorage.clear());
  await page.goto(URL, { waitUntil: "networkidle" });

  // Ensure active device matches requested one (toolbar select).
  const current = await page.evaluate(() => {
    try {
      const raw = localStorage.getItem("app-store-screenshots:project:v1");
      if (!raw) return null;
      return JSON.parse(raw)?.device ?? null;
    } catch {
      return null;
    }
  });

  // Prefer file-backed state; if device differs, switch via UI select.
  const deviceSelect = page.getByRole("combobox").filter({ hasText: /iPhone|iPad|Android/i }).first();
  const selectVisible = await deviceSelect.isVisible().catch(() => false);
  if (selectVisible) {
    const label =
      device === "iphone"
        ? "iPhone"
        : device === "ipad"
          ? "iPad"
          : device === "android"
            ? "Android Phone"
            : device;
    await deviceSelect.click().catch(() => {});
    const option = page.getByRole("option", { name: new RegExp(`^${label}$`, "i") });
    if (await option.isVisible().catch(() => false)) {
      await option.click();
      await page.waitForTimeout(800);
    }
  }

  await page.getByRole("button", { name: /Export bundle/i }).waitFor({ state: "visible" });
  const appName = await page.getByLabel("App name").inputValue().catch(() => "");
  console.error(`Editor ready (app: ${appName || "n/a"}, target device: ${device}, ls device: ${current || "n/a"})`);

  await page.evaluate(() => {
    window.__EXPORT_DISK_DONE__ = false;
    window.__EXPORT_DISK_COUNT__ = 0;
  });

  console.error("Starting export…");
  await page.getByRole("button", { name: /Export bundle/i }).click();

  await page.waitForFunction(() => window.__EXPORT_DISK_DONE__ === true, null, {
    timeout: 600_000,
  });
  const count = await page.evaluate(() => window.__EXPORT_DISK_COUNT__ || 0);
  console.error(`Export finished: ${count} files written under exports/`);
  console.log(JSON.stringify({ ok: true, device, count }));
  await browser.close();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
