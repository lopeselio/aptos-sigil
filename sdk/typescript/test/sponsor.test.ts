import { test } from "node:test";
import assert from "node:assert/strict";
import { Account } from "@aptos-labs/ts-sdk";
import {
  buildSponsoredTransaction,
  serializeAuthenticator,
  deserializeAuthenticator,
} from "../src/index.js";

/**
 * Sponsored (fee-payer) helpers. `buildSponsoredTransaction` is exercised against
 * a mock Aptos that records the `build.simple` args (no network). The wire
 * (de)serialization is checked with a real Ed25519 authenticator (pure crypto,
 * offline). Full on-chain round trips are covered by the testnet smoke scripts.
 */

/** Mock Aptos that captures the last `transaction.build.simple` call. */
function mockAptos() {
  const calls: Array<Record<string, unknown>> = [];
  const aptos = {
    transaction: {
      build: {
        simple: (args: Record<string, unknown>) => {
          calls.push(args);
          return Promise.resolve({ __mockTx: true, ...args });
        },
      },
    },
  };
  return { aptos, calls, last: () => calls[calls.length - 1] };
}

test("buildSponsoredTransaction sets withFeePayer and default gas", async () => {
  const { aptos, last } = mockAptos();
  const data = { function: "0x1::game_platform::submit_score", functionArguments: ["0x1", 0, 100] };
  await buildSponsoredTransaction({ aptos: aptos as never, sender: "0x9", data: data as never });

  const call = last();
  assert.equal(call.withFeePayer, true);
  assert.equal(String(call.sender), "0x9");
  assert.deepEqual(call.data, data);
  // Defaults from DEFAULT_SIGIL_TX_GAS unless overridden.
  assert.deepEqual(call.options, { maxGasAmount: 200_000, gasUnitPrice: 100 });
});

test("buildSponsoredTransaction merges caller options over defaults", async () => {
  const { aptos, last } = mockAptos();
  await buildSponsoredTransaction({
    aptos: aptos as never,
    sender: "0x9",
    data: { function: "0x1::a::b", functionArguments: [] } as never,
    options: { maxGasAmount: 5_000 },
  });
  assert.deepEqual(last().options, { maxGasAmount: 5_000, gasUnitPrice: 100 });
});

test("authenticator serialize/deserialize round-trips", () => {
  const acct = Account.generate();
  const auth = acct.signWithAuthenticator("0x1234abcd");
  const hex = serializeAuthenticator(auth);
  assert.match(hex, /^0x[0-9a-f]+$/);

  const back = deserializeAuthenticator(hex);
  assert.deepEqual(Array.from(back.bcsToBytes()), Array.from(auth.bcsToBytes()));
});
