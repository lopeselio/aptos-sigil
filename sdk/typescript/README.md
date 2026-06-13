# @sigil-aptos/sdk

TypeScript SDK for the **Sigil** gaming platform on [Aptos](https://aptos.dev) —
scores, leaderboards, achievements, rewards, quests, seasons, guilds, item
merging, and **gasless (sponsored) transactions**.

The SDK is network-agnostic: you give it an `Aptos` client and the published
module address, and it builds wallet-signable payloads and read-only view calls
for every Sigil Move module. Transaction signing stays in your hands (browser
wallet, CLI keyfile, KMS, or a fee-payer/gas-station).

## Install

```bash
npm install @sigil-aptos/sdk @aptos-labs/ts-sdk
```

`@aptos-labs/ts-sdk` is a **peer dependency** — install it alongside so your app
and the SDK share a single copy (needed for `instanceof` checks on SDK types).

## Quickstart

```ts
import { AccountAddress, Network } from "@aptos-labs/ts-sdk";
import { SigilClient, createAptosClient } from "@sigil-aptos/sdk";

const aptos = createAptosClient({ network: Network.TESTNET });
const sigil = new SigilClient({
  aptos,
  moduleAddress: AccountAddress.from(process.env.SIGIL_MODULE_ADDRESS!),
});

// Read-only view (no signature):
const count = await sigil.gamePlatform.viewGameCount();

// Build a wallet-signable payload for the player's first score (auto-registers):
const payload = sigil.gamePlatform.walletPayloadSubmitScore({
  gameId: 0n,
  score: 1000n,
  username: "player1",
});
// Hand `payload` to your wallet adapter:
//   await signAndSubmitTransaction(payload);
```

Every write flow exposes both forms:

- `walletPayload*(…)` → a plain `InputTransactionData` object for browser wallet
  adapters (`signAndSubmitTransaction`).
- `build*({ sender, … })` → a built `SimpleTransaction` for any server-side
  `Account` signer.

…plus `view*` read-only calls. Reach them via namespaced accessors:
`sigil.gamePlatform`, `sigil.leaderboard`, `sigil.achievements`, `sigil.rewards`,
`sigil.quests`, `sigil.seasons`, `sigil.guilds`, `sigil.merge`, `sigil.treasury`,
`sigil.roles`, `sigil.attest`, `sigil.shadowSigners`.

## Gasless gameplay (sponsored / fee-payer transactions)

A **fee payer** (a "gas station") covers gas so the player pays 0 APT. The player
still authorizes the call from their wallet — they just don't pay. This is an
Aptos L1 feature; no Move changes required.

**Browser (player) side:**

```ts
import {
  buildSponsoredTransaction,
  requestSponsorship,
  submitSponsored,
} from "@sigil-aptos/sdk";

// 1. build a fee-payer transaction from any walletPayload* data
const tx = await buildSponsoredTransaction({
  aptos,
  sender: account.address,
  data: sigil.gamePlatform.walletPayloadSubmitScore({ gameId: 0n, score: 1000n, username: "p1" }).data,
});

// 2. player signs as sender via the wallet adapter
const { authenticator: senderAuthenticator } = await signTransaction({ transactionOrPayload: tx });

// 3. ask your gas station to sign as fee payer, then submit with both
const { feePayerAuthenticator } = await requestSponsorship({ endpoint: "/api/sponsor", transaction: tx });
await submitSponsored({ aptos, transaction: tx, senderAuthenticator, feePayerAuthenticator });
```

**Gas-station (server) side** — e.g. a serverless `/api/sponsor` route. Build a
funded `Account` from your own private key (set via env) so you sponsor for your
own app, and **allowlist** which functions you'll pay for:

```ts
import { Account, Ed25519PrivateKey } from "@aptos-labs/ts-sdk";
import { sponsorTransaction, sponsoredFunctionId } from "@sigil-aptos/sdk";

const feePayer = Account.fromPrivateKey({
  privateKey: new Ed25519PrivateKey(process.env.SPONSOR_PRIVATE_KEY!),
});

const body = sponsorTransaction({
  aptos,
  feePayer,
  serializedTransaction, // the hex string posted from the browser
  allow: (tx) => (sponsoredFunctionId(tx) ?? "").startsWith(`${MODULE_ADDRESS}::`),
});
// return `body` ({ feePayerAuthenticator, feePayerAddress }) as JSON
```

> ⚠️ Without an `allow` guard your endpoint is an open gas relay — anyone could
> drain the fee payer. Always allowlist your module (and ideally rate-limit), and
> keep the demo fee-payer key on testnet/devnet only.

## Networks

The SDK does not pin a network. Point `createAptosClient` and `moduleAddress` at
wherever the Sigil package is published (testnet is the recommended stable home;
devnet resets weekly). See the repo README for current addresses and the
[tutorial](https://github.com/lopeselio/aptos-sigil/tree/master/docs/tutorial)
for an end-to-end walkthrough.

## License

MIT — see [LICENSE](./LICENSE).
