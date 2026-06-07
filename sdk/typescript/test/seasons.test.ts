import { test } from "node:test";
import assert from "node:assert/strict";
import { makeClient, normArgs, MOD } from "./helpers.js";

const APT = "0xa";

test("seasons: create_season arg order", () => {
  const { client, sender, last } = makeClient();
  client.seasons.buildCreateSeason({ sender, name: "S1", startTime: 100, endTime: 200, leaderboardId: 0, prizePool: 5000 });
  const c = last();
  assert.equal(c.fn, `${MOD}::seasons::create_season`);
  assert.deepEqual(normArgs(c.args), [MOD, "S1", "100", "200", "0", "5000"]);
});

test("seasons: finalize_and_distribute defaults FA metadata to APT", () => {
  const { client, sender, last } = makeClient();
  client.seasons.buildFinalizeSeasonAndDistribute({ sender, seasonId: 1, maxPlacements: 10 });
  const c = last();
  assert.equal(c.fn, `${MOD}::seasons::finalize_season_and_distribute_prizes`);
  assert.deepEqual(normArgs(c.args), [MOD, "1", APT, "10"]);
});

test("seasons: season_score view arg order", () => {
  const { client, last } = makeClient();
  client.seasons.viewSeasonScore({ seasonId: 1, gameId: 2, player: "0x5" });
  assert.equal(last().fn, `${MOD}::seasons::get_season_score`);
  assert.deepEqual(normArgs(last().args), [MOD, "1", "2", "0x5"]);
});
