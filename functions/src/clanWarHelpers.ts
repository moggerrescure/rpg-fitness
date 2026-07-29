/** Pure helpers for FitRPG clan war matchmaking / cron (testable). */

export const CLAN_WAR_SEARCH_SECONDS = 45;
export const CLAN_WAR_ACTIVE_SECONDS = 24 * 3600;
export const CLAN_WAR_BOT_CLAN_ID = "bot_shadowfiend";
export const CLAN_WAR_BOT_CLAN_NAME = "ShadowFiend (Bot)";

export type ClanWarPhase = "searching" | "preparation" | "active" | "finished";

export interface ClanWarState {
  phase: ClanWarPhase;
  /** Unix seconds (Firestore Timestamp.seconds). */
  phaseEndsAtSeconds: number;
  opponentClanId: string | null;
  opponentClanName: string | null;
  myClanScore: number;
  opponentClanScore: number;
}

export function isBotClanId(id: string | null | undefined): boolean {
  return typeof id === "string" && id.startsWith("bot_");
}

export function buildSearchingWar(nowSeconds: number): ClanWarState {
  return {
    phase: "searching",
    phaseEndsAtSeconds: nowSeconds + CLAN_WAR_SEARCH_SECONDS,
    opponentClanId: null,
    opponentClanName: null,
    myClanScore: 0,
    opponentClanScore: 0,
  };
}

export function buildActiveWarVsOpponent(
  nowSeconds: number,
  opponentClanId: string,
  opponentClanName: string
): ClanWarState {
  return {
    phase: "active",
    phaseEndsAtSeconds: nowSeconds + CLAN_WAR_ACTIVE_SECONDS,
    opponentClanId,
    opponentClanName,
    myClanScore: 0,
    opponentClanScore: 0,
  };
}

export function buildActiveWarVsBot(nowSeconds: number): ClanWarState {
  return buildActiveWarVsOpponent(nowSeconds, CLAN_WAR_BOT_CLAN_ID, CLAN_WAR_BOT_CLAN_NAME);
}

export function shouldAssignBotAfterSearch(
  war: { phase?: string; phaseEndsAtMs?: number | null } | null | undefined,
  nowMs: number
): boolean {
  if (!war || war.phase !== "searching") return false;
  const ends = war.phaseEndsAtMs;
  if (ends == null || !Number.isFinite(ends)) return false;
  return ends <= nowMs;
}

/** Ending wars are written in the same cron batch — skip bot score increments for those docs. */
export function shouldSkipBotScoreUpdate(clanId: string, endingClanIds: Set<string>): boolean {
  return endingClanIds.has(clanId);
}

/** Convert helper state → Firestore map (caller supplies Timestamp). */
export function clanWarToFirestoreFields(
  war: ClanWarState,
  toTimestamp: (seconds: number) => unknown
): Record<string, unknown> {
  return {
    phase: war.phase,
    phaseEndsAt: toTimestamp(war.phaseEndsAtSeconds),
    opponentClanId: war.opponentClanId,
    opponentClanName: war.opponentClanName,
    myClanScore: war.myClanScore,
    opponentClanScore: war.opponentClanScore,
  };
}
