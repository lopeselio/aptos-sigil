import { test } from "node:test";
import assert from "node:assert/strict";
import { makeClient, normArgs, MOD } from "./helpers.js";

const APT = "0xa";

test("guilds: create_guild and leave_guild", () => {
  const { client, sender, last } = makeClient();
  client.guilds.buildCreateGuild({ sender, name: "Wolves" });
  assert.equal(last().fn, `${MOD}::guilds::create_guild`);
  assert.deepEqual(normArgs(last().args), [MOD, "Wolves"]);
  client.guilds.buildLeaveGuild({ sender });
  assert.deepEqual(normArgs(last().args), [MOD]);
});

test("merge: register_recipe and grant_items arg order", () => {
  const { client, sender, last } = makeClient();
  client.merge.buildRegisterRecipe({ sender, inputItemId: 1, inputQty: 2, outputItemId: 3, outputQty: 1 });
  assert.deepEqual(normArgs(last().args), [MOD, "1", "2", "3", "1"]);
  client.merge.buildGrantItems({ sender, player: "0x5", itemId: 1, qty: 10 });
  assert.deepEqual(normArgs(last().args), [MOD, "0x5", "1", "10"]);
});

test("treasury: deposit/withdraw default FA + arg order", () => {
  const { client, sender, last } = makeClient();
  client.treasury.buildDeposit({ sender, amount: 100 });
  assert.equal(last().fn, `${MOD}::treasury::deposit`);
  assert.deepEqual(normArgs(last().args), [MOD, APT, "100"]);
  client.treasury.buildWithdraw({ sender, recipient: "0x5", amount: 50 });
  assert.deepEqual(normArgs(last().args), [APT, "0x5", "50"]);
  client.treasury.viewBalance();
  assert.deepEqual(normArgs(last().args), [MOD, APT]);
});

test("roles: add_admin and role_summary view", () => {
  const { client, sender, last } = makeClient();
  client.roles.buildAddAdmin({ sender, admin: "0x5" });
  assert.equal(last().fn, `${MOD}::roles::add_admin`);
  assert.deepEqual(normArgs(last().args), [MOD, "0x5"]);
  client.roles.viewRoleSummary({ addr: "0x5" });
  assert.deepEqual(normArgs(last().args), [MOD, "0x5"]);
});

test("attest: init encodes pubkey bytes", () => {
  const { client, sender, last } = makeClient();
  client.attest.buildInit({ sender, serverPubkey: new Uint8Array([1, 2]), maxAgeSecs: 60 });
  assert.equal(last().fn, `${MOD}::attest::init_attest`);
  assert.deepEqual(normArgs(last().args), ["bytes:0102", "60"]);
});
