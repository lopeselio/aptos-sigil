# Tutorial: Build an on-chain game on Aptos with `@sigil-aptos/sdk`

This walks a first-time Aptos game dev from zero to a playable game whose scores
live on chain — including **gasless** score submission so players never need APT.
It mirrors the [Sigil Arcade](../../sdk/typescript/examples/games/arcade) example.

**What you'll build:** connect a wallet → submit a score → show a live leaderboard
→ make submission gasless with a fee-payer gas station.

**Prereqs:** Node ≥ 20, a browser wallet (Nightly) set to **Aptos Testnet**, and
basic React. You do *not* need to write or deploy Move — Sigil's modules are
already live on testnet. (Deploying your own is the last, optional section.)

The platform exposes these Move modules; you reach each via `sigil.<module>`:
`gamePlatform`, `leaderboard`, `achievements`, `rewards`, `quests`, `seasons`,
`guilds`, `merge`, `treasury`, `roles`, `attest`, `shadowSigners`.

---

## 0. The fastest way to see it working

```bash
git clone https://github.com/lopeselio/aptos-sigil && cd aptos-sigil
cd sdk/typescript && npm install && npm run build      # build the SDK
cd examples/games/arcade && cp .env.example .env.local # set SPONSOR_PRIVATE_KEY for gasless
npm install && npm run dev                             # http://localhost:3000
```

Now read on to understand each piece.

---

## 1. Install the SDK

```bash
npm install @sigil-aptos/sdk @aptos-labs/ts-sdk
```

`@aptos-labs/ts-sdk` is a peer dependency — install it alongside so your app and
the SDK share one copy.

## 2. Create a client (point it at testnet)

The SDK is network-agnostic: give it an Aptos client and the published module
address. Testnet is the stable home (devnet wipes weekly).

```ts
import { AccountAddress, Network } from "@aptos-labs/ts-sdk";
import { SigilClient, createAptosClient } from "@sigil-aptos/sdk";

const MODULE = "0x694fd0c04ecf4ec750450d3c1a4d318d5869f2cf762562a8a586a44e1c29d1c1";

export const sigil = new SigilClient({
  aptos: createAptosClient({ network: Network.TESTNET }),
  moduleAddress: AccountAddress.from(MODULE),
});
```

## 3. Read data — views are free, no signature

```ts
// Two aligned vectors: [players[], scores[]]
const [players, scores] = (await sigil.leaderboard.viewTopEntriesForGame(0n)) as [string[], string[]];

// A player's (exists, last, best):
const summary = await sigil.gamePlatform.viewScoreSummary({ player, gameId: 0n });
```

Use these to render your leaderboard and a player's standing — they return the
same data the chain stores.

## 4. Submit a score (player signs & pays gas)

Every write has a `walletPayload*` form that returns a plain object for a browser
wallet adapter. The **first** `submit_score` auto-registers the player and sets
their username — no separate signup transaction.

```ts
import { useWallet } from "@aptos-labs/wallet-adapter-react";

const { signAndSubmitTransaction } = useWallet();

const payload = sigil.gamePlatform.walletPayloadSubmitScore({
  gameId: 0n,
  score: BigInt(finalScore),
  username: "player1",
});
const res = await signAndSubmitTransaction(payload);
await sigil.aptos.waitForTransaction({ transactionHash: res.hash }); // a hash ≠ success
```

> Tip: a returned hash only means *submitted*. Always `waitForTransaction` and
> check `.success` — an aborted transaction also has a hash.

## 5. Make it gasless (sponsored transactions)

So players never need APT, a **fee payer** (a "gas station") covers gas. The
player still signs; they just don't pay. Three steps on the client:

```ts
import { buildSponsoredTransaction, requestSponsorship, submitSponsored } from "@sigil-aptos/sdk";
const { signTransaction } = useWallet();

// 1. build a fee-payer transaction from the same payload
const tx = await buildSponsoredTransaction({ aptos: sigil.aptos, sender: account.address, data: payload.data });

// 2. player signs as sender (wallet) — pays 0 gas
const { authenticator: senderAuthenticator } = await signTransaction({ transactionOrPayload: tx });

// 3. ask your gas station to sign as fee payer, then submit with both
const { feePayerAuthenticator, feePayerAddress } = await requestSponsorship({ endpoint: "/api/sponsor", transaction: tx });
await submitSponsored({ aptos: sigil.aptos, transaction: tx, senderAuthenticator, feePayerAuthenticator, feePayerAddress });
```

> Why `feePayerAddress` at submit: the sender signs with the fee payer unset
> (`0x0`) because they don't know it up front. `submitSponsored` sets the real
> fee payer on the transaction before sending, or the node rejects it.

### The gas station (server side)

A tiny serverless route signs as the fee payer. In the Arcade it's
`app/api/sponsor/route.ts`:

```ts
import { Account, Aptos, AptosConfig, Ed25519PrivateKey, Network, PrivateKey, PrivateKeyVariants } from "@aptos-labs/ts-sdk";
import { sponsorTransaction, sponsoredFunctionId } from "@sigil-aptos/sdk";

export async function POST(req: Request) {
  const { transaction } = await req.json();
  const aptos = new Aptos(new AptosConfig({ network: Network.TESTNET }));
  const feePayer = Account.fromPrivateKey({
    privateKey: new Ed25519PrivateKey(PrivateKey.formatPrivateKey(process.env.SPONSOR_PRIVATE_KEY!, PrivateKeyVariants.Ed25519)),
  });
  const body = sponsorTransaction({
    aptos, feePayer, serializedTransaction: transaction,
    allow: (tx) => (sponsoredFunctionId(tx) ?? "").startsWith(`${MODULE}::`), // never remove this
  });
  return Response.json(body);
}
```

Set `SPONSOR_PRIVATE_KEY` to **your own funded account's** key to sponsor your
own app. Keep the `allow` guard or anyone could drain your fee payer (open relay).
Keep the fee payer funded.

## 6. The UI

See [`examples/games/arcade/app/page.tsx`](../../sdk/typescript/examples/games/arcade/app/page.tsx)
for a complete React component: a reaction-grid mini-game, wallet connect, both
submit paths, and a live leaderboard. Copy its structure and swap in your own
gameplay — only the `finalScore` you pass to `submit_score` changes.

Want to *explore every module* interactively (quests, achievements, rewards,
seasons, guilds) with the Move call, typed args, SDK code, and a Simulate/Inspect
panel per action? Run the hybrid console:
[`examples/web-petra`](../../sdk/typescript/examples/web-petra) — its **Guided
(Sigil Arcade)** tab is a narrated version of this tutorial.

## 7. Go further — quests, achievements, rewards

```ts
// Opt into a quest, then advance it with a score (one tx):
sigil.quests.walletPayloadStartQuest({ questId: 1n });
sigil.quests.walletPayloadSubmitScoreWithQuest({ gameId: 0n, score: 1000n });

// Claim an FA/NFT reward attached to an unlocked achievement:
sigil.rewards.walletPayloadClaimReward({ achievementId: 1n });
```

All of these have `walletPayload*` (browser) and `build*` (server `Account`)
forms, plus `view*` reads.

## 8. (Optional) Deploy your own modules

You don't need this to build — but to run your own publisher/game catalog:

```bash
cd move && aptos init --profile testnet --network testnet     # create + (web-faucet) fund
cd .. && ./scripts/redeploy_testnet.sh                         # publish + init + register game 0
```

Then point your app's `MODULE` at your publisher address. See
[`docs/DEPLOYMENT_TESTNET.md`](../DEPLOYMENT_TESTNET.md).

---

## Recap

You connected a wallet, read on-chain data, submitted a score, and made it
gasless — the full loop of an on-chain game. From here, layer on quests,
achievements, rewards, and seasons using the same `walletPayload*` / `view*`
pattern, and verify each call with the console's **Inspect** + **Simulate**
before you ship.
