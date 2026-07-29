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
    localTeam: [{ id: "u1", health: 10, reps: 5 }],
    opponentTeam: [{ id: "bot_1", health: 10, reps: 8 }],
    surrenderedBy: "u1",
  }) === "bot_1",
  "surrender vs bot"
);

assert(
  derivePvpWinnerId({
    localTeam: [
      { id: "u1", health: 50, reps: 2 },
      { id: "bot_ally", health: 50, reps: 0 },
    ],
    opponentTeam: [
      { id: "bot_1", health: 40, reps: 1 },
      { id: "bot_2", health: 40, reps: 1 },
      { id: "bot_3", health: 40, reps: 1 },
    ],
    surrenderedBy: "u1",
  }) === "bot_1",
  "3v3 surrender vs bots"
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
