#!/usr/bin/env node
/**
 * Headless FitRPG iPhone export via Playwright.
 * Usage: node scripts/export-iphone.mjs [baseUrl]
 * Expects `npm run dev` already running (default http://localhost:3000).
 */
import { spawn } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const base = process.argv[2] || "http://localhost:3000";
const child = spawn(
  process.execPath,
  [path.join(__dirname, "export-device.mjs"), "iphone", base],
  { stdio: "inherit" },
);
child.on("exit", (code) => process.exit(code ?? 1));
