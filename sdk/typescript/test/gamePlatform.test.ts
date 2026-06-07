import { test } from "node:test";
import assert from "node:assert/strict";
import { makeClient, normArgs, utf8, MOD } from "./helpers.js";

test("gamePlatform: submit_score uses submit_score_named with [publisher, gameId, score, username]", () => {
  const { client, sender, last } = makeClient();
  client.gamePlatform.buildSubmitScore({ sender, gameId: 0, score: 100, username: "p1" });
  const c = last();
  assert.equal(c.fn, `${MOD}::game_platform::submit_score_named`);
  assert.deepEqual(normArgs(c.args), [MOD, "0", "100", "p1"]);
});

test("gamePlatform: walletPayloadSubmitScore coerces ids to bigint", () => {
  const { client } = makeClient();
  const p = client.gamePlatform.walletPayloadSubmitScore({ gameId: 2, score: 50, username: "n" });
  assert.equal(p.data.function, `${MOD}::game_platform::submit_score_named`);
  assert.deepEqual(normArgs(p.data.functionArguments), [MOD, "2", "50", "n"]);
});

test("gamePlatform: register_game passes only the title (publisher is the signer)", () => {
  const { client, sender, last } = makeClient();
  client.gamePlatform.buildRegisterGame({ sender, title: "My Game" });
  assert.equal(last().fn, `${MOD}::game_platform::register_game`);
  assert.deepEqual(normArgs(last().args), ["My Game"]);
});

test("gamePlatform: submit_score_attested forwards signature bytes", () => {
  const { client, sender, last } = makeClient();
  const sig = new Uint8Array([1, 2, 3]);
  client.gamePlatform.buildSubmitScoreAttested({ sender, gameId: 1, score: 9, timestampSigned: 100, nonce: 7, signature: sig });
  const c = last();
  assert.equal(c.fn, `${MOD}::game_platform::submit_score_attested`);
  assert.deepEqual(normArgs(c.args), [MOD, "1", "9", "100", "7", "bytes:010203"]);
});

test("gamePlatform: views default owner to the module address and accept overrides", () => {
  const { client, last } = makeClient();
  client.gamePlatform.viewGameCount();
  assert.deepEqual(normArgs(last().args), [MOD]);
  client.gamePlatform.viewHasGame(3, "0x5");
  const c = last();
  assert.equal(c.fn, `${MOD}::game_platform::has_game`);
  assert.deepEqual(normArgs(c.args), ["0x5", "3"]);
});

test("gamePlatform: publisher override is normalized into submit args", () => {
  const { client, sender, last } = makeClient();
  client.gamePlatform.buildSubmitScore({ sender, gameId: 0, score: 1, username: "p", publisher: "0x7" });
  assert.deepEqual(normArgs(last().args), ["0x7", "0", "1", "p"]);
});
