import { test } from "node:test";
import assert from "node:assert/strict";
import { makeClient, normArgs, utf8, MOD } from "./helpers.js";

/**
 * Wallet-adapter payload wrappers (`walletPayload*`) used by the browser example.
 * Unlike `build*`, these return a plain `{ data: { function, typeArguments, functionArguments } }`
 * object (no signer / network), so we inspect the return value directly. The default
 * publisher is the module address (MOD) and the default FA metadata is native APT (`0xa`).
 */
const APT = "0xa";

test("gamePlatform: walletPayloadInit / walletPayloadRegisterGame", () => {
  const { client } = makeClient();
  const init = client.gamePlatform.walletPayloadInit();
  assert.equal(init.data.function, `${MOD}::game_platform::init`);
  assert.deepEqual(normArgs(init.data.functionArguments), []);

  const reg = client.gamePlatform.walletPayloadRegisterGame("My Game");
  assert.equal(reg.data.function, `${MOD}::game_platform::register_game`);
  assert.deepEqual(normArgs(reg.data.functionArguments), ["My Game"]);
});

test("leaderboard: walletPayloadCreateLeaderboard arg order + bool flags", () => {
  const { client } = makeClient();
  const init = client.leaderboard.walletPayloadInit();
  assert.equal(init.data.function, `${MOD}::leaderboard::init_leaderboards`);

  const p = client.leaderboard.walletPayloadCreateLeaderboard({
    gameId: 0,
    decimals: 0,
    minScore: 0,
    maxScore: 10_000,
    isAscending: false,
    allowMultiple: true,
    scoresToRetain: 10,
  });
  assert.equal(p.data.function, `${MOD}::leaderboard::create_leaderboard`);
  assert.deepEqual(normArgs(p.data.functionArguments), [MOD, "0", "0", "0", "10000", false, true, "10"]);
});

test("achievements: walletPayloadCreate encodes text as bytes and defaults badge to empty", () => {
  const { client } = makeClient();
  const withBadge = client.achievements.walletPayloadCreate({ title: "A", description: "B", minScore: 5, badgeUri: "u" });
  assert.equal(withBadge.data.function, `${MOD}::achievements::create`);
  assert.deepEqual(normArgs(withBadge.data.functionArguments), [MOD, utf8("A"), utf8("B"), "5", utf8("u")]);

  const noBadge = client.achievements.walletPayloadCreate({ title: "A", description: "B", minScore: 5 });
  assert.deepEqual(normArgs(noBadge.data.functionArguments), [MOD, utf8("A"), utf8("B"), "5", utf8("")]);
});

test("rewards: walletPayloadAttachFaReward defaults FA metadata to APT", () => {
  const { client } = makeClient();
  assert.equal(client.rewards.walletPayloadInit().data.function, `${MOD}::rewards::init_rewards`);

  const p = client.rewards.walletPayloadAttachFaReward({ achievementId: 1, amount: 100, supply: 5 });
  assert.equal(p.data.function, `${MOD}::rewards::attach_fa_reward`);
  assert.deepEqual(normArgs(p.data.functionArguments), [MOD, "1", APT, "100", "5"]);
});

test("quests: walletPayloadCreateScoreQuest + walletPayloadUpdateQuestProgress", () => {
  const { client } = makeClient();
  const q = client.quests.walletPayloadCreateScoreQuest({
    title: "Q",
    description: "D",
    gameId: 0,
    targetScore: 1000,
    rewardId: 0,
    isSeasonal: false,
  });
  assert.equal(q.data.function, `${MOD}::quests::create_score_quest`);
  assert.deepEqual(normArgs(q.data.functionArguments), ["Q", "D", "0", "1000", "0", false]);

  const up = client.quests.walletPayloadUpdateQuestProgress({ questId: 3 });
  assert.equal(up.data.function, `${MOD}::quests::update_quest_progress`);
  assert.deepEqual(normArgs(up.data.functionArguments), [MOD, "3"]);
});

test("guilds: create / join / leave wallet payloads", () => {
  const { client } = makeClient();
  const create = client.guilds.walletPayloadCreateGuild({ name: "Clan" });
  assert.equal(create.data.function, `${MOD}::guilds::create_guild`);
  assert.deepEqual(normArgs(create.data.functionArguments), [MOD, "Clan"]);

  const join = client.guilds.walletPayloadJoinGuild({ guildId: 1 });
  assert.deepEqual(normArgs(join.data.functionArguments), [MOD, "1"]);

  const leave = client.guilds.walletPayloadLeaveGuild();
  assert.equal(leave.data.function, `${MOD}::guilds::leave_guild`);
  assert.deepEqual(normArgs(leave.data.functionArguments), [MOD]);
});

test("merge: registerRecipe + grantItems wallet payloads", () => {
  const { client } = makeClient();
  const recipe = client.merge.walletPayloadRegisterRecipe({ inputItemId: 1, inputQty: 2, outputItemId: 3, outputQty: 1 });
  assert.equal(recipe.data.function, `${MOD}::merge::register_recipe`);
  assert.deepEqual(normArgs(recipe.data.functionArguments), [MOD, "1", "2", "3", "1"]);

  const grant = client.merge.walletPayloadGrantItems({ player: "0x5", itemId: 1, qty: 10 });
  assert.equal(grant.data.function, `${MOD}::merge::grant_items`);
  assert.deepEqual(normArgs(grant.data.functionArguments), [MOD, "0x5", "1", "10"]);
});

test("seasons: create / start / end / finalize wallet payloads", () => {
  const { client } = makeClient();
  const create = client.seasons.walletPayloadCreateSeason({
    name: "S1",
    startTime: 100,
    endTime: 200,
    leaderboardId: 0,
    prizePool: 5000,
  });
  assert.equal(create.data.function, `${MOD}::seasons::create_season`);
  assert.deepEqual(normArgs(create.data.functionArguments), [MOD, "S1", "100", "200", "0", "5000"]);

  assert.deepEqual(normArgs(client.seasons.walletPayloadStartSeason({ seasonId: 1 }).data.functionArguments), [MOD, "1"]);
  assert.deepEqual(normArgs(client.seasons.walletPayloadEndSeason({ seasonId: 1 }).data.functionArguments), [MOD, "1"]);
  assert.equal(
    client.seasons.walletPayloadFinalizeSeason({ seasonId: 1 }).data.function,
    `${MOD}::seasons::finalize_season`,
  );
});

test("treasury: deposit defaults to APT; withdraw arg order is [meta, recipient, amount]", () => {
  const { client } = makeClient();
  const dep = client.treasury.walletPayloadDeposit({ amount: 1000 });
  assert.equal(dep.data.function, `${MOD}::treasury::deposit`);
  assert.deepEqual(normArgs(dep.data.functionArguments), [MOD, APT, "1000"]);

  const wd = client.treasury.walletPayloadWithdraw({ recipient: "0x5", amount: 250 });
  assert.equal(wd.data.function, `${MOD}::treasury::withdraw`);
  assert.deepEqual(normArgs(wd.data.functionArguments), [APT, "0x5", "250"]);
});

test("roles: walletPayloadAddAdmin normalizes the admin address", () => {
  const { client } = makeClient();
  assert.equal(client.roles.walletPayloadInit().data.function, `${MOD}::roles::init_roles`);

  const p = client.roles.walletPayloadAddAdmin({ admin: "0x5" });
  assert.equal(p.data.function, `${MOD}::roles::add_admin`);
  assert.deepEqual(normArgs(p.data.functionArguments), [MOD, "0x5"]);
});
