#!/usr/bin/env node
/**
 * One-shot admin top-up for App Store screenshots.
 * Usage:
 *   node scripts/fill-screenshot-wallet.mjs [username]
 * Defaults username to 1213231.
 *
 * Auth: Application Default Credentials, or Firebase CLI login tokens
 * (via firebase-tools defaultCredentials — tokens never printed).
 *
 * Also enables config/fitrpg.screenshotFillEnabled so the DEBUG Profile button can call CF.
 */
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const require = createRequire(join(__dirname, "../functions/package.json"));
const admin = require("firebase-admin");

const PROJECT = process.env.FIREBASE_PROJECT || "serzhanovich-ecosystem-ce700";
const USERNAME = (process.argv[2] || "1213231").trim();
const GOLD = 9999;
const MIN_MAX_ENERGY = 100;

async function resolveCredentialPath() {
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    return process.env.GOOGLE_APPLICATION_CREDENTIALS;
  }
  try {
    const ftRequire = createRequire("/usr/local/lib/node_modules/firebase-tools/package.json");
    const auth = ftRequire("./lib/auth.js");
    const defaultCredentials = ftRequire("./lib/defaultCredentials.js");
    const account =
      auth.getProjectDefaultAccount(join(__dirname, "..")) || auth.getGlobalDefaultAccount();
    if (!account) return null;
    return (await defaultCredentials.getCredentialPathAsync(account)) || null;
  } catch (e) {
    console.error("firebase-tools credential bridge unavailable:", e.message || e);
    return null;
  }
}

async function initAdmin() {
  if (admin.apps.length) return;
  const credPath = await resolveCredentialPath();
  if (credPath) {
    process.env.GOOGLE_APPLICATION_CREDENTIALS = credPath;
  }
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: PROJECT,
  });
}

async function findUserByUsername(db, username) {
  const lower = username.toLowerCase();
  let snap = await db.collection("users").where("usernameLower", "==", lower).limit(5).get();
  if (snap.empty) {
    snap = await db.collection("users").where("username", "==", username).limit(5).get();
  }
  if (snap.empty) {
    snap = await db
      .collection("users")
      .where("usernameLower", ">=", lower)
      .where("usernameLower", "<", lower + "\uf8ff")
      .limit(10)
      .get();
    const exact = snap.docs.filter((d) => {
      const data = d.data();
      return (
        String(data.usernameLower || "").toLowerCase() === lower ||
        String(data.username || "") === username
      );
    });
    if (exact.length) return exact;
    return snap.docs;
  }
  return snap.docs;
}

async function main() {
  console.error(`Project=${PROJECT} username=${USERNAME}`);
  await initAdmin();
  const db = admin.firestore();

  const docs = await findUserByUsername(db, USERNAME);
  if (!docs.length) {
    console.error(`No user found for username "${USERNAME}"`);
    process.exit(1);
  }
  if (docs.length > 1) {
    console.error(
      `Multiple matches:\n` +
        docs
          .map((d) => `  ${d.id} username=${d.data().username} gold=${d.data().gold} energy=${d.data().energy}`)
          .join("\n")
    );
  }

  const doc = docs[0];
  const data = doc.data() || {};
  const prevMax = Number(data.maxEnergy) || 0;
  const maxEnergy = Math.max(prevMax, MIN_MAX_ENERGY);
  const before = {
    gold: data.gold,
    energy: data.energy,
    maxEnergy: data.maxEnergy,
    level: data.level,
    username: data.username,
  };

  await doc.ref.update({
    gold: GOLD,
    energy: maxEnergy,
    maxEnergy,
    lastEnergyRegenAt: admin.firestore.Timestamp.now(),
  });

  await db.collection("config").doc("fitrpg").set(
    {
      screenshotFillEnabled: true,
      screenshotFillEnabledAt: admin.firestore.FieldValue.serverTimestamp(),
      screenshotFillNote:
        "Enable DEBUG/TestFlight Profile → Fill for Screenshots. Set false after ASC shots.",
    },
    { merge: true }
  );

  console.log(
    JSON.stringify(
      {
        uid: doc.id,
        username: before.username,
        before,
        after: { gold: GOLD, energy: maxEnergy, maxEnergy },
        screenshotFillEnabled: true,
      },
      null,
      2
    )
  );
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
