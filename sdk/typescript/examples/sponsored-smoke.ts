/**
 * End-to-end smoke for sponsored (gasless) submit_score on a live network.
 *
 * Proves the fee-payer flow: a brand-new account with ZERO balance submits a
 * score and pays no gas — a funded fee payer (gas station) covers it. Mirrors
 * the browser path (build fee-payer tx → sender signs → gas station signs as fee
 * payer over the serialized tx → submit with both authenticators).
 *
 * Usage (testnet):
 *   SPONSOR_PRIVATE_KEY=ed25519-priv-0x... \
 *   SIGIL_MODULE_ADDRESS=0x568721... \
 *   npx tsx examples/sponsored-smoke.ts
 */
import {
  Account,
  AccountAddress,
  Ed25519PrivateKey,
  Network,
  PrivateKey,
  PrivateKeyVariants,
} from "@aptos-labs/ts-sdk";
import {
  SigilClient,
  createAptosClient,
  buildSponsoredTransaction,
  serializeTransaction,
  sponsorTransaction,
  sponsoredFunctionId,
  deserializeAuthenticator,
  submitSponsored,
} from "../src/index.js";

const MODULE = process.env.SIGIL_MODULE_ADDRESS ?? "0x694fd0c04ecf4ec750450d3c1a4d318d5869f2cf762562a8a586a44e1c29d1c1";
const GAME_ID = BigInt(process.env.SIGIL_GAME_ID ?? "0");
const pk = process.env.SPONSOR_PRIVATE_KEY;
if (!pk) throw new Error("set SPONSOR_PRIVATE_KEY (a funded testnet account's key)");

const network = (process.env.APTOS_NETWORK as Network) ?? Network.TESTNET;
const aptos = createAptosClient({ network });
const sigil = new SigilClient({ aptos, moduleAddress: AccountAddress.from(MODULE) });

const feePayer = Account.fromPrivateKey({
  privateKey: new Ed25519PrivateKey(PrivateKey.formatPrivateKey(pk, PrivateKeyVariants.Ed25519)),
});

// Fresh player with ZERO balance — the gasless flow must still work for them.
const player = Account.generate();
const score = BigInt(1000 + Math.floor(Math.random() * 9000));

async function main() {
  console.log(`network=${network} module=${MODULE} game=${GAME_ID}`);
  console.log(`fee payer (sponsor): ${feePayer.accountAddress.toString()}`);
  console.log(`player (fresh, 0 APT): ${player.accountAddress.toString()} submitting score=${score}`);

  // 1. Build the fee-payer transaction from the same walletPayload* the dapp uses.
  const payload = sigil.gamePlatform.walletPayloadSubmitScore({
    gameId: GAME_ID,
    score,
    username: "gasless-smoke",
  });
  const transaction = await buildSponsoredTransaction({
    aptos,
    sender: player.accountAddress,
    data: payload.data as never,
  });

  // 2. Player signs as sender (the wallet does this in the browser).
  const senderAuthenticator = aptos.transaction.sign({ signer: player, transaction });

  // 3. Gas station receives the serialized tx and signs as fee payer (with allowlist).
  const wire = serializeTransaction(transaction);
  const body = sponsorTransaction({
    aptos,
    feePayer,
    serializedTransaction: wire,
    allow: (tx) => (sponsoredFunctionId(tx) ?? "").startsWith(`${MODULE}::`),
  });
  console.log(`gas station signed; fee payer = ${body.feePayerAddress}`);

  // 4. Submit with both authenticators.
  const committed = await submitSponsored({
    aptos,
    transaction,
    senderAuthenticator,
    feePayerAuthenticator: deserializeAuthenticator(body.feePayerAuthenticator),
    feePayerAddress: body.feePayerAddress,
  });
  const ok = "success" in committed ? committed.success : false;
  console.log(`submitted: success=${ok} hash=${committed.hash}`);
  if (!ok) throw new Error(`tx failed: ${JSON.stringify(committed).slice(0, 300)}`);

  // 5. Verify on chain: the score landed and the player still has 0 APT.
  const summary = await sigil.gamePlatform.viewScoreSummary({ player: player.accountAddress, gameId: GAME_ID });
  console.log(`score_summary(player) = ${JSON.stringify(summary)}`);
  console.log(`explorer: https://explorer.aptoslabs.com/txn/${committed.hash}?network=${network}`);
  console.log("✅ gasless submit_score worked from a zero-balance account.");
}

main().catch((e) => {
  console.error("❌", e);
  process.exit(1);
});
