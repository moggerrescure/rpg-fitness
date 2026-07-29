import {
  CLAN_WAR_ACTIVE_SECONDS,
  CLAN_WAR_BOT_CLAN_ID,
  CLAN_WAR_BOT_CLAN_NAME,
  CLAN_WAR_SEARCH_SECONDS,
  buildActiveWarVsBot,
  buildActiveWarVsOpponent,
  buildSearchingWar,
  isBotClanId,
  shouldAssignBotAfterSearch,
  shouldSkipBotScoreUpdate,
} from "./clanWarHelpers";

function assert(cond: boolean, msg: string) {
  if (!cond) throw new Error(msg);
}

assert(CLAN_WAR_SEARCH_SECONDS === 45, "search window 45s");
assert(CLAN_WAR_ACTIVE_SECONDS === 24 * 3600, "active lasts 24h");
assert(isBotClanId("bot_shadowfiend") === true, "bot_ prefix");
assert(isBotClanId("bot_abc") === true, "bot_abc");
assert(isBotClanId("clan_real") === false, "human clan");
assert(isBotClanId(null) === false, "null not bot");

const nowSec = 1_700_000_000;
const searching = buildSearchingWar(nowSec);
assert(searching.phase === "searching", "searching phase");
assert(searching.opponentClanId === null, "no opponent while searching");
assert(searching.phaseEndsAtSeconds === nowSec + CLAN_WAR_SEARCH_SECONDS, "search ends");

const vsHuman = buildActiveWarVsOpponent(nowSec, "clan_abc", "Rivals");
assert(vsHuman.phase === "active", "human match starts active");
assert(vsHuman.opponentClanId === "clan_abc", "opp id");
assert(vsHuman.opponentClanName === "Rivals", "opp name");
assert(vsHuman.phaseEndsAtSeconds === nowSec + CLAN_WAR_ACTIVE_SECONDS, "active end");
assert(vsHuman.myClanScore === 0 && vsHuman.opponentClanScore === 0, "scores zero");

const vsBot = buildActiveWarVsBot(nowSec);
assert(vsBot.phase === "active", "bot war starts active");
assert(vsBot.opponentClanId === CLAN_WAR_BOT_CLAN_ID, "bot id");
assert(vsBot.opponentClanName === CLAN_WAR_BOT_CLAN_NAME, "bot name");
assert(isBotClanId(vsBot.opponentClanId) === true, "bot id detector");

assert(
  shouldAssignBotAfterSearch({ phase: "searching", phaseEndsAtMs: nowSec * 1000 }, nowSec * 1000 + 1) === true,
  "timed out searching → bot"
);
assert(
  shouldAssignBotAfterSearch({ phase: "searching", phaseEndsAtMs: nowSec * 1000 + 5000 }, nowSec * 1000) === false,
  "still waiting"
);
assert(
  shouldAssignBotAfterSearch({ phase: "active", phaseEndsAtMs: 0 }, 999) === false,
  "not searching"
);

// Ending wars must not also receive bot score increments in the same batch.
assert(shouldSkipBotScoreUpdate("clan_1", new Set(["clan_1", "clan_2"])) === true, "ending skipped");
assert(shouldSkipBotScoreUpdate("clan_3", new Set(["clan_1"])) === false, "ongoing kept");

console.log("clanWarHelpers.test.ts OK");
