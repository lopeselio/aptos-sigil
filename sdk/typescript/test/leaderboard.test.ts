import { test } from "node:test";
import assert from "node:assert/strict";
import { makeClient, normArgs, MOD } from "./helpers.js";

test("leaderboard: create_leaderboard arg order", () => {
  const { client, sender, last } = makeClient();
  client.leaderboard.buildCreateLeaderboard({
    sender,
    gameId: 0,
    decimals: 2,
    minScore: 0,
    maxScore: 1000,
    isAscending: false,
    allowMultiple: true,
    scoresToRetain: 10,
  });
  const c = last();
  assert.equal(c.fn, `${MOD}::leaderboard::create_leaderboard`);
  assert.deepEqual(normArgs(c.args), [MOD, "0", "2", "0", "1000", false, true, "10"]);
});

test("leaderboard: submit_score_direct normalizes player", () => {
  const { client, sender, last } = makeClient();
  client.leaderboard.buildSubmitScoreDirect({ sender, leaderboardId: 1, player: "0x5", score: 42 });
  const c = last();
  assert.equal(c.fn, `${MOD}::leaderboard::submit_score_direct`);
  assert.deepEqual(normArgs(c.args), [MOD, "1", "0x5", "42"]);
});

test("leaderboard: views default owner and target functions", () => {
  const { client, last } = makeClient();
  client.leaderboard.viewTopEntriesForGame(3);
  assert.equal(last().fn, `${MOD}::leaderboard::get_top_entries_for_game`);
  assert.deepEqual(normArgs(last().args), [MOD, "3"]);
  client.leaderboard.viewLeaderboardConfig(0, "0x5");
  assert.deepEqual(normArgs(last().args), ["0x5", "0"]);
});
