import { test } from "node:test";
import assert from "node:assert/strict";
import { makeClient, normArgs, utf8, MOD } from "./helpers.js";

const PK = new Uint8Array([0xaa, 0xbb]);

test("shadowSigners: create_session encodes pubkey + scopes as byte vectors", () => {
  const { client, sender, last } = makeClient();
  client.shadowSigners.buildCreateSession({ sender, shadowPublicKey: PK, scopes: ["submit_score", "claim_reward"], ttlSecs: 3600 });
  const c = last();
  assert.equal(c.fn, `${MOD}::shadow_signers::create_session`);
  assert.deepEqual(normArgs(c.args), ["bytes:aabb", [utf8("submit_score"), utf8("claim_reward")], "3600"]);
});

test("shadowSigners: create_session_with_payer is a multi-agent tx with the fee payer as secondary signer", () => {
  const { client, sender, last } = makeClient();
  client.shadowSigners.buildCreateSessionWithPayer({ sender, feePayer: "0x5", shadowPublicKey: PK, scopes: ["x"], ttlSecs: 10 });
  const c = last();
  assert.equal(c.kind, "multiAgent");
  assert.equal(c.fn, `${MOD}::shadow_signers::create_session_with_payer`);
  assert.deepEqual(c.secondary, ["0x5"]);
  assert.deepEqual(normArgs(c.args), ["bytes:aabb", [utf8("x")], "10"]);
});

test("shadowSigners: revoke + cleanup pass authority address then pubkey", () => {
  const { client, sender, last } = makeClient();
  client.shadowSigners.buildRevokeSession({ sender, authorityAddr: "0x5", shadowPublicKey: PK });
  assert.deepEqual(normArgs(last().args), ["0x5", "bytes:aabb"]);
  client.shadowSigners.buildCleanupExpiredSession({ sender, authorityAddr: "0x5", shadowPublicKey: PK });
  assert.equal(last().fn, `${MOD}::shadow_signers::cleanup_expired_session`);
  assert.deepEqual(normArgs(last().args), ["0x5", "bytes:aabb"]);
});

test("shadowSigners: session view arg order", () => {
  const { client, last } = makeClient();
  client.shadowSigners.viewSessionValid("0x5", PK);
  assert.equal(last().fn, `${MOD}::shadow_signers::is_session_valid`);
  assert.deepEqual(normArgs(last().args), ["0x5", "bytes:aabb"]);
});
