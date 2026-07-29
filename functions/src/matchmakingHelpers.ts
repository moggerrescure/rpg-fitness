/**
 * Pure helpers for FitRPG matchmaking / team invite acceptance (unit-testable).
 */

export type TeamPlayer = { id: string; [key: string]: unknown };

export function mergeTeamGuests(
  currentTeam: TeamPlayer[],
  guests: TeamPlayer[],
  maxSize = 3
): { ok: boolean; team: TeamPlayer[]; reason?: string } {
  const team = Array.isArray(currentTeam) ? [...currentTeam] : [];
  const existingIds = new Set(team.map((p) => p?.id).filter(Boolean));
  const newGuests = (guests || []).filter((g) => g && g.id && !existingIds.has(g.id as string));
  if (team.length + newGuests.length > maxSize) {
    return { ok: false, team, reason: "team_full" };
  }
  team.push(...newGuests);
  return { ok: true, team };
}

/** Lobby invite accept: caller must be pending invitee (or already in guests payload). */
export function canAcceptLobbyInvite(params: {
  ticketStatus?: string;
  pendingInvites?: string[];
  callerUid: string;
  guests: TeamPlayer[];
}): { ok: boolean; reason?: string } {
  const { ticketStatus, pendingInvites = [], callerUid, guests } = params;
  if (ticketStatus !== "searchingTeammates") {
    return { ok: false, reason: "bad_status" };
  }
  const callerInGuests = guests.some((g) => g && g.id === callerUid);
  if (!callerInGuests) {
    return { ok: false, reason: "caller_not_guest" };
  }
  if (!pendingInvites.includes(callerUid)) {
    // Queue join (open searchingTeammates) still allowed without pending invite.
    return { ok: true };
  }
  return { ok: true };
}

/** True when acceptor should be treated as lobby invitee (must be in pendingInvites). */
export function isLobbyInviteAccept(pendingInvites: string[] | undefined, callerUid: string): boolean {
  return Array.isArray(pendingInvites) && pendingInvites.includes(callerUid);
}

export function requireMyTicketId(myTicketId: unknown, opponentTicketId: unknown): {
  ok: boolean;
  myTicketId?: string;
  opponentTicketId?: string;
  reason?: string;
} {
  if (typeof opponentTicketId !== "string" || !opponentTicketId) {
    return { ok: false, reason: "missing_opponent" };
  }
  if (typeof myTicketId !== "string" || !myTicketId) {
    return { ok: false, reason: "missing_my_ticket" };
  }
  if (opponentTicketId === myTicketId) {
    return { ok: false, reason: "same_ticket" };
  }
  return { ok: true, myTicketId, opponentTicketId };
}
