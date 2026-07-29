import {
  derivePvpWinnerId,
  isAllowedActivityReason,
  isBattleParticipant,
  participantUidsFromTeams,
  stripUserForPublic,
} from "./battleHelpers";

function assert(cond: boolean, msg: string) {
  if (!cond) throw new Error(msg);
}

const local = [{ id: "u1", health: 50, reps: 10 }];
const opp = [{ id: "u2", health: 0, reps: 3 }];

assert(participantUidsFromTeams(local, opp).sort().join(",") === "u1,u2", "uids");
assert(isBattleParticipant({ localTeam: local, opponentTeam: opp }, "u1"), "participant");
assert(!isBattleParticipant({ localTeam: local, opponentTeam: opp }, "u3"), "non-participant");

assert(derivePvpWinnerId({ localTeam: local, opponentTeam: opp }) === "u1", "hp wipe win");
assert(
  derivePvpWinnerId({
    localTeam: [{ id: "u1", health: 10, reps: 5 }],
    opponentTeam: [{ id: "u2", health: 10, reps: 8 }],
  }) === "u2",
  "reps win"
);
assert(
  derivePvpWinnerId({
    localTeam: local,
    opponentTeam: [{ id: "u2", health: 20, reps: 0 }],
    surrenderedBy: "u1",
  }) === "u2",
  "surrender"
);

assert(isAllowedActivityReason("training"), "training ok");
assert(isAllowedActivityReason("quest_daily"), "quest_ ok");
assert(!isAllowedActivityReason("pvp_hack"), "pvp blocked by allowlist");

const pub = stripUserForPublic({
  id: "x",
  username: "A",
  fcmToken: "secret",
  gold: 999,
  pvpTrophies: 10,
});
assert(pub.username === "A" && pub.pvpTrophies === 10 && !("fcmToken" in pub) && !("gold" in pub), "strip");

console.log("battleHelpers.test.ts: OK");
