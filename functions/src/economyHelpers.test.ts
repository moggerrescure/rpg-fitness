import {
  applyXpToProgression,
  clampPvERewards,
  computeTrainEnergyGrant,
  consumeEnergyChargeForRefund,
  pvpOutcomeForPlayer,
  registerEnergySpend,
  rewardsForPvpOutcome,
  rollClanWarWin,
  TRAIN_ENERGY_DAILY_CAP,
  TRAIN_ENERGY_PER_SESSION,
  utcDayKey,
} from "./economyHelpers";

function assert(cond: boolean, msg: string) {
  if (!cond) throw new Error(msg);
}

assert(pvpOutcomeForPlayer("u1", "u1") === "win", "win");
assert(pvpOutcomeForPlayer("u2", "u1") === "loss", "loss");
assert(pvpOutcomeForPlayer("draw", "u1") === "draw", "draw");
assert(
  pvpOutcomeForPlayer("u1", "u1b", ["u1", "u1b"], ["u2", "u2b"]) === "win",
  "3v3 teammate win"
);
assert(
  pvpOutcomeForPlayer("u1", "u2b", ["u1", "u1b"], ["u2", "u2b"]) === "loss",
  "3v3 opposing team loss"
);
assert(rewardsForPvpOutcome("win").gold === 60, "win gold");

const capped = clampPvERewards(9999, -5);
assert(capped.xp === 500 && capped.gold === 0, "pve clamp");

assert(rollClanWarWin(100, () => 0) === true, "rng 0 wins");
assert(rollClanWarWin(100, () => 0.99) === false, "rng high loses");

const { updates } = applyXpToProgression(
  { Archer: { level: 1, xp: 140, totalReps: 0, storyStage: 1 } },
  "Archer",
  20,
  { statPoints: 0, maxEnergy: 100, basePower: 100 }
);
assert(updates.progressions.Archer.level === 2, "level up");
assert(updates.statPoints === 3, "stat points");

const t0 = 1_000_000;
let charges = registerEnergySpend({}, "c1", 10, t0);
assert(charges.c1.amount === 10, "spend registered");
const refundOk = consumeEnergyChargeForRefund(charges, "c1", 10, t0 + 1000);
assert(refundOk.ok === true && refundOk.ok && refundOk.refundAmount === 10, "refund ok");
assert(!refundOk.ok || Object.keys(refundOk.remaining).length === 0, "charge cleared");
const refundDup = consumeEnergyChargeForRefund({}, "c1", 10, t0 + 1000);
assert(refundDup.ok === false, "no double refund");
charges = registerEnergySpend({}, "c2", 10, t0);
const expired = consumeEnergyChargeForRefund(charges, "c2", 10, t0 + 16 * 60 * 1000);
assert(expired.ok === false, "expired charge");

assert(TRAIN_ENERGY_PER_SESSION === 5, "train session grant");
assert(TRAIN_ENERGY_DAILY_CAP === 40, "train daily cap");
assert(utcDayKey(Date.UTC(2026, 6, 29)).startsWith("2026-07-29"), "utc day key");

const trainFresh = computeTrainEnergyGrant({
  awardedToday: 0,
  dayKey: "",
  todayKey: "2026-07-29",
});
assert(trainFresh.awarded === 5 && trainFresh.nextAwardedToday === 5, "train fresh +5");

const trainNearCap = computeTrainEnergyGrant({
  awardedToday: 38,
  dayKey: "2026-07-29",
  todayKey: "2026-07-29",
});
assert(trainNearCap.awarded === 2 && trainNearCap.nextAwardedToday === 40, "train near daily cap");

const trainCapped = computeTrainEnergyGrant({
  awardedToday: 40,
  dayKey: "2026-07-29",
  todayKey: "2026-07-29",
});
assert(trainCapped.awarded === 0, "train daily exhausted");

const trainRollover = computeTrainEnergyGrant({
  awardedToday: 40,
  dayKey: "2026-07-28",
  todayKey: "2026-07-29",
});
assert(trainRollover.awarded === 5 && trainRollover.dayRollover === true, "train day rollover");

console.log("economyHelpers.test.ts: OK");
