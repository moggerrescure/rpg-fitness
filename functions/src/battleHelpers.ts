/**
 * Pure helpers for PvP battle participation / outcome (unit-testable).
 */

export type BattleTeamPlayer = { id?: string; health?: number; reps?: number };

export function teamPlayerIds(team: BattleTeamPlayer[] | undefined | null): string[] {
  return (team || []).map((p) => p?.id).filter((id): id is string => typeof id === "string" && id.length > 0);
}

export function participantUidsFromTeams(
  localTeam: BattleTeamPlayer[] | undefined | null,
  opponentTeam: BattleTeamPlayer[] | undefined | null
): string[] {
  return Array.from(new Set([...teamPlayerIds(localTeam), ...teamPlayerIds(opponentTeam)]));
}

export function isBattleParticipant(
  battle: { localTeam?: BattleTeamPlayer[]; opponentTeam?: BattleTeamPlayer[]; participantUids?: string[] },
  uid: string
): boolean {
  if (Array.isArray(battle.participantUids) && battle.participantUids.includes(uid)) return true;
  return teamPlayerIds(battle.localTeam).includes(uid) || teamPlayerIds(battle.opponentTeam).includes(uid);
}

function teamAlive(team: BattleTeamPlayer[]): boolean {
  return team.some((p) => (p.health ?? 0) > 0);
}

function teamReps(team: BattleTeamPlayer[]): number {
  return team.reduce((sum, p) => sum + (Number(p.reps) || 0), 0);
}

function teamHp(team: BattleTeamPlayer[]): number {
  return team.reduce((sum, p) => sum + (Number(p.health) || 0), 0);
}

/**
 * Server-authoritative PvP winner. Ignores client winnerId.
 * Honors surrenderedBy when the surrendering uid is a participant.
 */
export function derivePvpWinnerId(battle: {
  localTeam?: BattleTeamPlayer[];
  opponentTeam?: BattleTeamPlayer[];
  surrenderedBy?: string | null;
}): string {
  const local = battle.localTeam || [];
  const opp = battle.opponentTeam || [];
  const localIds = teamPlayerIds(local);
  const oppIds = teamPlayerIds(opp);

  const surrenderedBy = battle.surrenderedBy;
  if (typeof surrenderedBy === "string" && surrenderedBy.length > 0) {
    if (localIds.includes(surrenderedBy)) return oppIds[0] || "draw";
    if (oppIds.includes(surrenderedBy)) return localIds[0] || "draw";
  }

  const myAlive = teamAlive(local);
  const oppAlive = teamAlive(opp);

  if (!oppAlive && myAlive) return localIds[0] || "draw";
  if (!myAlive && oppAlive) return oppIds[0] || "draw";
  if (!myAlive && !oppAlive) return "draw";

  const myReps = teamReps(local);
  const oppReps = teamReps(opp);
  if (myReps > oppReps) return localIds[0] || "draw";
  if (oppReps > myReps) return oppIds[0] || "draw";

  const myHP = teamHp(local);
  const oppHP = teamHp(opp);
  if (myHP > oppHP) return localIds[0] || "draw";
  if (oppHP > myHP) return oppIds[0] || "draw";
  return "draw";
}

/** Public player fields safe to return from search / leaderboards. */
export const PUBLIC_PLAYER_FIELDS = [
  "username",
  "selectedClass",
  "avatarName",
  "currentLevel",
  "pvpTrophies",
  "classTrophies",
  "pvpWins",
] as const;

export function stripUserForPublic(data: Record<string, any> | undefined | null): Record<string, any> {
  if (!data) return {};
  const out: Record<string, any> = {};
  for (const key of PUBLIC_PLAYER_FIELDS) {
    if (key in data) out[key] = data[key];
  }
  if (data.id) out.id = data.id;
  return out;
}

export const ACTIVITY_REASON_ALLOWLIST = new Set([
  "training",
  "workout",
  "free_training",
  "quest",
  "daily_quest",
  "health",
  "health_sync",
  "dungeon",
  "story",
  "practice",
  "activity",
]);

export function isAllowedActivityReason(reason: unknown): boolean {
  const r = String(reason || "activity").toLowerCase().slice(0, 40);
  return ACTIVITY_REASON_ALLOWLIST.has(r) || r.startsWith("quest_");
}
