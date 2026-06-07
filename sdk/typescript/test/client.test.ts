import { test } from "node:test";
import assert from "node:assert/strict";
import { AccountAddress } from "@aptos-labs/ts-sdk";
import { makeClient, MOD } from "./helpers.js";

test("client: exposes an accessor for every module", () => {
  const { client } = makeClient();
  for (const m of [
    "gamePlatform",
    "leaderboard",
    "rewards",
    "achievements",
    "quests",
    "seasons",
    "guilds",
    "merge",
    "treasury",
    "roles",
    "attest",
    "shadowSigners",
  ] as const) {
    assert.ok(client[m], `missing module accessor: ${m}`);
  }
});

test("client: fid renders moduleAddress::module::func", () => {
  const { client } = makeClient();
  assert.equal(client.fid("game_platform", "submit_score"), `${MOD}::game_platform::submit_score`);
});

test("client: rewardsPoolAddress is a deterministic resource address", () => {
  const { client } = makeClient();
  const a = client.rewardsPoolAddress();
  assert.ok(a instanceof AccountAddress);
  assert.equal(a.toString(), client.rewardsPoolAddress().toString());
});
