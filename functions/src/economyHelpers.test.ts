import {
  applyXpToProgression,
  clampPvERewards,
  consumeEnergyChargeForRefund,
  pvpOutcomeForPlayer,
  registerEnergySpend,
  rewardsForPvpOutcome,
  rollClanWarWin,
} from "./economyHelpers";

function assert(cond: boolean, msg: string) {
  if (!cond) throw new Error(msg);
}

assert(pvpOutcomeForPlayer("u1", "u1") === "win", "win");
assert(pvpOutcomeForPlayer("u2", "u1") === "loss", "loss");
assert(pvpOutcomeForPlayer("draw", "u1") === "draw", "draw");
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

console.log("economyHelpers.test.ts: OK");
