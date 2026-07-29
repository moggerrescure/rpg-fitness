import {
  canAcceptLobbyInvite,
  isLobbyInviteAccept,
  mergeTeamGuests,
  requireMyTicketId,
} from "./matchmakingHelpers";

function assert(cond: boolean, msg: string) {
  if (!cond) throw new Error(msg);
}

// mergeTeamGuests
{
  const r = mergeTeamGuests([{ id: "a" }], [{ id: "b" }, { id: "a" }]);
  assert(r.ok && r.team.length === 2 && r.team[1].id === "b", "merge dedupe");
  const full = mergeTeamGuests([{ id: "a" }, { id: "b" }, { id: "c" }], [{ id: "d" }]);
  assert(!full.ok && full.reason === "team_full", "team full");
}

// lobby invite
{
  assert(isLobbyInviteAccept(["u1", "u2"], "u1") === true, "invitee");
  assert(isLobbyInviteAccept(["u2"], "u1") === false, "not invitee");
  const ok = canAcceptLobbyInvite({
    ticketStatus: "searchingTeammates",
    pendingInvites: ["u1"],
    callerUid: "u1",
    guests: [{ id: "u1" }],
  });
  assert(ok.ok, "lobby accept ok");
  const bad = canAcceptLobbyInvite({
    ticketStatus: "searchingOpponent",
    callerUid: "u1",
    guests: [{ id: "u1" }],
  });
  assert(!bad.ok && bad.reason === "bad_status", "bad status");
}

// myTicketId required
{
  assert(requireMyTicketId(undefined, "opp").reason === "missing_my_ticket", "need my ticket");
  assert(requireMyTicketId("a", "a").reason === "same_ticket", "same ticket");
  assert(requireMyTicketId("mine", "opp").ok === true, "valid pair");
}

console.log("matchmakingHelpers.test.ts: OK");
