import { test } from "node:test";
import assert from "node:assert/strict";
import { makeClient, normArgs, utf8, MOD } from "./helpers.js";

test("achievements: create encodes text, defaults empty badge", () => {
  const { client, sender, last } = makeClient();
  client.achievements.buildCreate({ sender, title: "First", description: "desc", minScore: 50 });
  const c = last();
  assert.equal(c.fn, `${MOD}::achievements::create`);
  assert.deepEqual(normArgs(c.args), [MOD, utf8("First"), utf8("desc"), "50", utf8("")]);
});

test("achievements: create_with_game inserts gameId before minScore", () => {
  const { client, sender, last } = makeClient();
  client.achievements.buildCreateWithGame({ sender, title: "T", description: "D", gameId: 2, minScore: 5, badgeUri: "u" });
  assert.deepEqual(normArgs(last().args), [MOD, utf8("T"), utf8("D"), "2", "5", utf8("u")]);
});

test("achievements: create_advanced arg order", () => {
  const { client, sender, last } = makeClient();
  client.achievements.buildCreateAdvanced({ sender, title: "T", description: "D", minScore: 1, requiredCount: 3, minSubmissions: 2 });
  assert.deepEqual(normArgs(last().args), [MOD, utf8("T"), utf8("D"), "1", "3", "2", utf8("")]);
});

test("achievements: grant normalizes player", () => {
  const { client, sender, last } = makeClient();
  client.achievements.buildGrant({ sender, player: "0x5", achievementId: 7 });
  assert.equal(last().fn, `${MOD}::achievements::grant`);
  assert.deepEqual(normArgs(last().args), [MOD, "0x5", "7"]);
});

test("achievements: progress view arg order", () => {
  const { client, last } = makeClient();
  client.achievements.viewProgress({ player: "0x5", achievementId: 1 });
  assert.equal(last().fn, `${MOD}::achievements::get_progress`);
  assert.deepEqual(normArgs(last().args), [MOD, "0x5", "1"]);
});
