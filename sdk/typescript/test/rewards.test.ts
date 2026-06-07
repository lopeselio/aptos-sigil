import { test } from "node:test";
import assert from "node:assert/strict";
import { makeClient, normArgs, utf8, MOD } from "./helpers.js";

const APT = "0xa"; // native APT FA metadata (special address renders short)

test("rewards: attach_fa_reward defaults FA metadata to APT", () => {
  const { client, sender, last } = makeClient();
  client.rewards.buildAttachFaReward({ sender, achievementId: 1, amount: 100, supply: 5 });
  const c = last();
  assert.equal(c.fn, `${MOD}::rewards::attach_fa_reward`);
  assert.deepEqual(normArgs(c.args), [MOD, "1", APT, "100", "5"]);
});

test("rewards: attach_fa_reward honors custom FA metadata", () => {
  const { client, sender, last } = makeClient();
  client.rewards.buildAttachFaReward({ sender, achievementId: 1, amount: 1, supply: 1, faMetadataAddress: "0x5" });
  assert.deepEqual(normArgs(last().args), [MOD, "1", "0x5", "1", "1"]);
});

test("rewards: create_nft_collection encodes text as bytes", () => {
  const { client, sender, last } = makeClient();
  client.rewards.buildCreateNftCollection({ sender, name: "Badges", description: "d", uri: "ipfs://x" });
  const c = last();
  assert.equal(c.fn, `${MOD}::rewards::create_nft_collection`);
  assert.deepEqual(normArgs(c.args), [MOD, utf8("Badges"), utf8("d"), utf8("ipfs://x")]);
});

test("rewards: attach_nft_reward passes strings (not bytes) for name/desc/uri", () => {
  const { client, sender, last } = makeClient();
  client.rewards.buildAttachNftReward({ sender, achievementId: 2, collection: "0x6", name: "N", description: "D", uri: "U", supply: 3 });
  assert.deepEqual(normArgs(last().args), [MOD, "2", "0x6", "N", "D", "U", "3"]);
});

test("rewards: claim_reward + wallet payload", () => {
  const { client, sender, last } = makeClient();
  client.rewards.buildClaimReward({ sender, achievementId: 4 });
  assert.equal(last().fn, `${MOD}::rewards::claim_reward`);
  assert.deepEqual(normArgs(last().args), [MOD, "4"]);
  const p = client.rewards.walletPayloadClaimReward({ achievementId: 4 });
  assert.deepEqual(normArgs(p.data.functionArguments), [MOD, "4"]);
});

test("rewards: views default owner", () => {
  const { client, last } = makeClient();
  client.rewards.viewReward(1);
  assert.equal(last().fn, `${MOD}::rewards::get_reward`);
  assert.deepEqual(normArgs(last().args), [MOD, "1"]);
  client.rewards.viewIsClaimed({ player: "0x5", achievementId: 1 });
  assert.deepEqual(normArgs(last().args), [MOD, "0x5", "1"]);
});
