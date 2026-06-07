import { test } from "node:test";
import assert from "node:assert/strict";
import { makeClient, normArgs, MOD } from "./helpers.js";

test("quests: create_score_quest arg order (publisher is signer)", () => {
  const { client, sender, last } = makeClient();
  client.quests.buildCreateScoreQuest({ sender, title: "Q", description: "D", gameId: 0, targetScore: 100, rewardId: 1, isSeasonal: false });
  const c = last();
  assert.equal(c.fn, `${MOD}::quests::create_score_quest`);
  assert.deepEqual(normArgs(c.args), ["Q", "D", "0", "100", "1", false]);
});

test("quests: start_quest + wallet payload", () => {
  const { client, sender, last } = makeClient();
  client.quests.buildStartQuest({ sender, questId: 3 });
  assert.equal(last().fn, `${MOD}::quests::start_quest`);
  assert.deepEqual(normArgs(last().args), [MOD, "3"]);
  const p = client.quests.walletPayloadStartQuest({ questId: 3 });
  assert.deepEqual(normArgs(p.data.functionArguments), [MOD, "3"]);
});

test("quests: submit_score_with_quest passes publisher/game/score", () => {
  const { client, sender, last } = makeClient();
  client.quests.buildSubmitScoreWithQuest({ sender, gameId: 1, score: 9 });
  assert.deepEqual(normArgs(last().args), [MOD, "1", "9"]);
});

test("quests: progress view arg order", () => {
  const { client, last } = makeClient();
  client.quests.viewQuestProgress({ questId: 2, player: "0x5" });
  assert.equal(last().fn, `${MOD}::quests::get_quest_progress`);
  assert.deepEqual(normArgs(last().args), [MOD, "2", "0x5"]);
});
