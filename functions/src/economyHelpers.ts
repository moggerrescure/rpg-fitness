/**
 * Pure helpers for FitRPG economy / battle settlement (unit-testable).
 */

export const PVP_REWARDS = {
  win: { xp: 250, gold: 60, trophies: 50 },
  loss: { xp: 50, gold: 15, trophies: -50 },
  draw: { xp: 100, gold: 30, trophies: 0 },
} as const;

export const WORLD_BOSS_ATTACK_ENERGY = 15;
export const WORLD_BOSS_MAX_DAMAGE_PER_CALL = 50000;
export const WORLD_BOSS_ATTACKS_PER_HOUR = 20;

export const PVE_XP_CAP = 500;
export const PVE_GOLD_CAP = 250;
export const ACTIVITY_XP_CAP = 400;
export const ACTIVITY_GOLD_CAP = 200;

export type PvpOutcome = "win" | "loss" | "draw";

export function pvpOutcomeForPlayer(winnerId: string | null | undefined, playerUid: string): PvpOutcome {
  if (!winnerId || winnerId === "draw") return "draw";
  if (winnerId === playerUid) return "win";
  return "loss";
}

export function rewardsForPvpOutcome(outcome: PvpOutcome) {
  return PVP_REWARDS[outcome];
}

export function clampInt(value: unknown, min: number, max: number, fallback = 0): number {
  const n = Number(value);
  if (!Number.isFinite(n)) return fallback;
  return Math.min(max, Math.max(min, Math.floor(n)));
}

export function clampPvERewards(xp: unknown, gold: unknown): { xp: number; gold: number } {
  return {
    xp: clampInt(xp, 0, PVE_XP_CAP),
    gold: clampInt(gold, 0, PVE_GOLD_CAP),
  };
}

export function clampActivityRewards(xp: unknown, gold: unknown): { xp: number; gold: number } {
  return {
    xp: clampInt(xp, 0, ACTIVITY_XP_CAP),
    gold: clampInt(gold, 0, ACTIVITY_GOLD_CAP),
  };
}

/** Clan war: server rolls outcome from power; client `won` is ignored. */
export function rollClanWarWin(basePower: number, rng: () => number = Math.random): boolean {
  const power = Math.max(50, Number(basePower) || 100);
  const winChance = Math.min(0.72, 0.38 + power / 1200);
  return rng() < winChance;
}

export function applyXpToProgression(
  progressions: Record<string, any>,
  selectedClass: string,
  xpGain: number,
  userData: { statPoints?: number; maxEnergy?: number; energy?: number; basePower?: number }
): { progressions: Record<string, any>; updates: Record<string, any> } {
  const updates: Record<string, any> = {};
  const next = { ...(progressions || {}) };
  let classProg = { ...(next[selectedClass] || { level: 1, xp: 0, totalReps: 0, storyStage: 1 }) };
  classProg.xp = (classProg.xp || 0) + xpGain;

  let earnedStatPoints = 0;
  let levelsGained = 0;
  while (classProg.xp >= classProg.level * 150) {
    classProg.xp -= classProg.level * 150;
    classProg.level += 1;
    earnedStatPoints += 3;
    levelsGained += 1;
  }

  next[selectedClass] = classProg;
  updates.progressions = next;

  if (levelsGained > 0) {
    updates.statPoints = (userData.statPoints || 0) + earnedStatPoints;
    const newMax = (userData.maxEnergy || 100) + levelsGained * 5;
    updates.maxEnergy = newMax;
    updates.energy = newMax;
    updates.basePower = (userData.basePower || 100) + levelsGained * 15;
  }

  return { progressions: next, updates };
}

export const FITRPG_USER_FIELD_KEYS = [
  "username",
  "usernameLower",
  "selectedClass",
  "energy",
  "maxEnergy",
  "basePower",
  "gold",
  "avatarName",
  "statPoints",
  "baseStrength",
  "baseDexterity",
  "baseIntelligence",
  "baseVitality",
  "stats",
  "equippedWeaponId",
  "equippedArmorId",
  "equippedRingId",
  "equippedAmuletId",
  "ownedEquipmentIds",
  "clanId",
  "pvpWins",
  "pvpTrophies",
  "friends",
  "friendRequests",
  "currentLevel",
  "classTrophies",
  "lastActive",
  "lastHealthSyncDate",
  "progressions",
  "fcmToken",
] as const;
