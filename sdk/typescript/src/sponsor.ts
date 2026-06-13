import {
  AccountAddress,
  AccountAuthenticator,
  Deserializer,
  Hex,
  SimpleTransaction,
  type Account,
  type Aptos as AptosInstance,
  type CommittedTransactionResponse,
  type InputGenerateTransactionOptions,
  type InputGenerateTransactionPayloadData,
  type PendingTransactionResponse,
} from "@aptos-labs/ts-sdk";
import { DEFAULT_SIGIL_TX_GAS } from "./constants.js";
import { normalizeAddress, type AddressInput } from "./modules/base.js";

/**
 * Sponsored (fee-payer) transactions — gasless gameplay.
 *
 * On Aptos a transaction can name a **fee payer** that covers gas instead of the
 * sender. The sender (player's wallet) still authorizes the call, but pays 0 APT;
 * a separate fee-payer account (a "gas station") signs and pays. This is an L1
 * feature — no Move changes are required. It is distinct from `shadow_signers`
 * (session keys): there the player delegates signing; here the player still signs,
 * they just don't pay.
 *
 * The canonical browser flow (sender does not know the fee payer up front):
 * ```ts
 * const tx = await buildSponsoredTransaction({ aptos, sender, data: payload.data });
 * // player signs as sender via the wallet adapter:
 * const { authenticator: senderAuthenticator } = await signTransaction({ transactionOrPayload: tx });
 * // ask a gas station to sign as fee payer (HTTP), then submit with both:
 * const { feePayerAuthenticator } = await requestSponsorship({ endpoint, transaction: tx });
 * await submitSponsored({ aptos, transaction: tx, senderAuthenticator, feePayerAuthenticator });
 * ```
 *
 * The fee-payer (gas-station) side, e.g. a serverless `/api/sponsor` route, uses
 * {@link sponsorTransaction} with a funded {@link Account} built from a private key
 * env var — so any dev can run their own sponsor by swapping in their own key.
 */

/**
 * Build a fee-payer (sponsored) transaction. `data` is the same entry-function
 * payload a `walletPayload*` wrapper returns (`{ function, functionArguments, ... }`).
 * Defaults to {@link DEFAULT_SIGIL_TX_GAS}; merge/override via `options`.
 */
export function buildSponsoredTransaction(args: {
  aptos: AptosInstance;
  sender: AddressInput;
  data: InputGenerateTransactionPayloadData;
  options?: InputGenerateTransactionOptions;
}): Promise<SimpleTransaction> {
  return args.aptos.transaction.build.simple({
    sender: normalizeAddress(args.sender),
    data: args.data,
    options: { ...DEFAULT_SIGIL_TX_GAS, ...args.options } as InputGenerateTransactionOptions,
    withFeePayer: true,
  });
}

/** Fee-payer side: sign a built sponsored transaction as the fee payer (gas station). */
export function signSponsoredAsFeePayer(args: {
  aptos: AptosInstance;
  feePayer: Account;
  transaction: SimpleTransaction;
}): AccountAuthenticator {
  return args.aptos.transaction.signAsFeePayer({ signer: args.feePayer, transaction: args.transaction });
}

/**
 * Submit a sponsored transaction with both authenticators. Waits for the
 * transaction to commit by default; pass `waitForResult: false` to return the
 * pending response immediately.
 *
 * The sender signs with the fee-payer address unset (`0x0`) — they don't know
 * the fee payer up front — so the transaction's `feePayerAddress` must be set to
 * the real fee payer before submit, or the node rejects it as INVALID_SIGNATURE.
 * Pass `feePayerAddress` (returned by {@link requestSponsorship}) and it's set
 * for you; the sender's `0x0` signature still verifies under the fee-payer scheme.
 */
export async function submitSponsored(args: {
  aptos: AptosInstance;
  transaction: SimpleTransaction;
  senderAuthenticator: AccountAuthenticator;
  feePayerAuthenticator: AccountAuthenticator;
  feePayerAddress?: AddressInput;
  waitForResult?: boolean;
}): Promise<PendingTransactionResponse | CommittedTransactionResponse> {
  if (args.feePayerAddress) {
    args.transaction.feePayerAddress = normalizeAddress(args.feePayerAddress);
  }
  const pending = await args.aptos.transaction.submit.simple({
    transaction: args.transaction,
    senderAuthenticator: args.senderAuthenticator,
    feePayerAuthenticator: args.feePayerAuthenticator,
  });
  if (args.waitForResult === false) return pending;
  return args.aptos.waitForTransaction({ transactionHash: pending.hash });
}

// ---- BCS wire (de)serialization for a gas-station HTTP round trip ----

/** Serialize a built transaction to `0x…` hex for transport to a gas station. */
export function serializeTransaction(tx: SimpleTransaction): string {
  return tx.bcsToHex().toString();
}

/** Inverse of {@link serializeTransaction} (gas-station side). */
export function deserializeTransaction(hex: string): SimpleTransaction {
  return SimpleTransaction.deserialize(Deserializer.fromHex(hex));
}

/** Serialize an account authenticator to `0x…` hex (e.g. the fee-payer signature). */
export function serializeAuthenticator(auth: AccountAuthenticator): string {
  return Hex.fromHexInput(auth.bcsToBytes()).toString();
}

/** Inverse of {@link serializeAuthenticator}. */
export function deserializeAuthenticator(hex: string): AccountAuthenticator {
  return AccountAuthenticator.deserialize(Deserializer.fromHex(hex));
}

/**
 * Best-effort `address::module::function` of a built transaction's entry function,
 * or `null` if it is not a simple entry-function call. Useful for a gas-station
 * allowlist so the sponsor only pays for its own app's functions (fail closed on
 * `null`). Reads the deserialized payload structurally to avoid coupling to SDK
 * internals across versions.
 */
export function sponsoredFunctionId(tx: SimpleTransaction): string | null {
  const payload = tx.rawTransaction.payload as unknown as {
    entryFunction?: {
      module_name?: { address?: { toString(): string }; name?: { identifier?: string } };
      function_name?: { identifier?: string };
    };
  };
  const ef = payload?.entryFunction;
  const addr = ef?.module_name?.address?.toString();
  const mod = ef?.module_name?.name?.identifier;
  const fn = ef?.function_name?.identifier;
  if (!addr || !mod || !fn) return null;
  return `${addr}::${mod}::${fn}`;
}

/** Response body a gas station returns to the browser. */
export type SponsorResponse = {
  /** Fee-payer `AccountAuthenticator` as `0x…` hex (feed to {@link deserializeAuthenticator}). */
  feePayerAuthenticator: string;
  /** Fee-payer account address (hex). */
  feePayerAddress: string;
};

/**
 * Gas-station side: given a serialized sponsored transaction, sign it as the fee
 * payer and produce the {@link SponsorResponse}. Pass `allow` to gate which
 * functions this sponsor will pay for (it should fail closed). Example for a
 * serverless route:
 * ```ts
 * const feePayer = Account.fromPrivateKey({ privateKey: new Ed25519PrivateKey(process.env.SPONSOR_PRIVATE_KEY!) });
 * const body = sponsorTransaction({ aptos, feePayer, serializedTransaction, allow: (tx) =>
 *   (sponsoredFunctionId(tx) ?? "").startsWith(`${MODULE_ADDRESS}::`) });
 * ```
 */
export function sponsorTransaction(args: {
  aptos: AptosInstance;
  feePayer: Account;
  serializedTransaction: string;
  allow?: (tx: SimpleTransaction) => boolean;
}): SponsorResponse {
  const transaction = deserializeTransaction(args.serializedTransaction);
  if (args.allow && !args.allow(transaction)) {
    throw new Error("sponsor: transaction not allowed by gas-station policy");
  }
  const authenticator = signSponsoredAsFeePayer({ aptos: args.aptos, feePayer: args.feePayer, transaction });
  return {
    feePayerAuthenticator: serializeAuthenticator(authenticator),
    feePayerAddress: args.feePayer.accountAddress.toString(),
  };
}

/**
 * Browser side: POST a built sponsored transaction to a gas-station endpoint and
 * get back the deserialized fee-payer authenticator + address, ready for
 * {@link submitSponsored}. `fetchImpl` defaults to the global `fetch`.
 */
export async function requestSponsorship(args: {
  endpoint: string;
  transaction: SimpleTransaction;
  headers?: Record<string, string>;
  fetchImpl?: typeof fetch;
}): Promise<{ feePayerAuthenticator: AccountAuthenticator; feePayerAddress: AccountAddress }> {
  const doFetch = args.fetchImpl ?? fetch;
  const res = await doFetch(args.endpoint, {
    method: "POST",
    headers: { "content-type": "application/json", ...args.headers },
    body: JSON.stringify({ transaction: serializeTransaction(args.transaction) }),
  });
  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new Error(`gas station ${res.status}: ${text || res.statusText}`);
  }
  const json = (await res.json()) as SponsorResponse;
  return {
    feePayerAuthenticator: deserializeAuthenticator(json.feePayerAuthenticator),
    feePayerAddress: AccountAddress.from(json.feePayerAddress),
  };
}
