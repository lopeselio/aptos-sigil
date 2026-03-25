/**
 * Deeper on-chain smoke using @aptos-labs/ts-sdk (shadow_signers scopes + rewards FA attach optional path).
 *
 * Required env:
 *   SIGIL_PUBLISHER_PRIVATE_KEY  — hex private key for the on-chain publisher (same as sigil address).
 * Optional:
 *   SIGIL_MODULE_ADDRESS         — defaults to devnet publisher in repo.
 *   FA_ACHIEVEMENT_ID            — u64 slot for attach_fa_reward (default 424242; change if E_ALREADY_ATTACHED).
 *   SIGIL_PLAYER_PRIVATE_KEY     — if set, runs claim_testing after attach.
 *   SKIP_FA_REWARD=1             — only run create_session + views.
 *
 * Run from sdk/typescript:
 *   npm install
 *   SIGIL_PUBLISHER_PRIVATE_KEY=0x... npm run example:deeper-smoke
 */
import {
  Account,
  AccountAddress,
  Aptos,
  AptosConfig,
  Ed25519PrivateKey,
  Network,
} from "@aptos-labs/ts-sdk";
import {
  APTOS_COIN_METADATA_ADDRESS,
  SigilClient,
} from "../src/index.js";

const MODULE =
  process.env.SIGIL_MODULE_ADDRESS ??
  "0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6";

function requireEnv(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`Missing env ${name}`);
  return v;
}

async function main() {
  const publisherKey = requireEnv("SIGIL_PUBLISHER_PRIVATE_KEY");
  const publisher = Account.fromPrivateKey({
    privateKey: new Ed25519PrivateKey(publisherKey),
  });

  const config = new AptosConfig({ network: Network.DEVNET });
  const aptos = new Aptos(config);
  const moduleAddress = AccountAddress.from(MODULE);

  const pubAddr = publisher.accountAddress.toString();
  if (pubAddr.toLowerCase() !== MODULE.toLowerCase()) {
    console.warn(
      `Warning: publisher account ${pubAddr} !== SIGIL_MODULE_ADDRESS ${MODULE} — on-chain calls may abort with permission errors.`,
    );
  }

  const sigil = new SigilClient({ aptos, moduleAddress });

  const shadow = Account.generate();
  const shadowPk = shadow.publicKey.toUint8Array();

  console.log("== shadow_signers::create_session ==");
  const sessionTx = await sigil.buildCreateSession({
    sender: publisher,
    shadowPublicKey: shadowPk,
    scopes: ["submit_score", "claim_reward"],
    ttlSecs: 3600,
  });
  const pending = await aptos.signAndSubmitTransaction({ signer: publisher, transaction: sessionTx });
  await aptos.waitForTransaction({ transactionHash: pending.hash });
  console.log("create_session:", pending.hash);

  const valid = await sigil.viewSessionValid(publisher.accountAddress, shadowPk);
  console.log("is_session_valid:", valid);

  const scopes = await sigil.viewSessionScopes(publisher.accountAddress, shadowPk);
  console.log("get_session_scopes:", scopes);

  if (process.env.SKIP_FA_REWARD === "1") {
    console.log("SKIP_FA_REWARD=1 — done.");
    return;
  }

  const pool = sigil.rewardsPoolAddress();
  console.log("== Fund rewards pool", pool.toString(), "==");
  const fundTx = await aptos.transferFungibleAsset({
    sender: publisher,
    fungibleAssetMetadataAddress: APTOS_COIN_METADATA_ADDRESS,
    recipient: pool,
    amount: 5_000_000,
  });
  const fundPending = await aptos.signAndSubmitTransaction({ signer: publisher, transaction: fundTx });
  await aptos.waitForTransaction({ transactionHash: fundPending.hash });
  console.log("transferFungibleAsset (pool):", fundPending.hash);

  const achId = BigInt(process.env.FA_ACHIEVEMENT_ID ?? "424242");
  console.log("== rewards::attach_fa_reward achievement", achId.toString(), "==");
  const attachTx = await sigil.buildAttachFaReward({
    sender: publisher,
    achievementId: achId,
    amount: 100_000,
    supply: 3,
  });
  const attachPending = await aptos.signAndSubmitTransaction({ signer: publisher, transaction: attachTx });
  await aptos.waitForTransaction({ transactionHash: attachPending.hash });
  console.log("attach_fa_reward:", attachPending.hash);

  console.log("get_reward view:", await sigil.viewReward(achId));

  const playerHex = process.env.SIGIL_PLAYER_PRIVATE_KEY;
  if (playerHex) {
    const player = Account.fromPrivateKey({
      privateKey: new Ed25519PrivateKey(playerHex),
    });
    console.log("== rewards::claim_testing (player)", player.accountAddress.toString(), "==");
    const claimTx = await sigil.buildClaimTesting({ sender: player, achievementId: achId });
    const claimPending = await aptos.signAndSubmitTransaction({ signer: player, transaction: claimTx });
    await aptos.waitForTransaction({ transactionHash: claimPending.hash });
    console.log("claim_testing:", claimPending.hash);
    console.log("get_reward after:", await sigil.viewReward(achId));
  } else {
    console.log("Set SIGIL_PLAYER_PRIVATE_KEY to run claim_testing.");
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
