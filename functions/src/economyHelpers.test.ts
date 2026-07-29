import {
  applyXpToProgression,
  clampPvERewards,
  pvpOutcomeForPlayer,
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

console.log("economyHelpers.test.ts: OK");
