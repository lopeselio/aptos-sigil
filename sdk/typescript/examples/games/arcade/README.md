# Sigil Arcade

A small **playable** Aptos game (a 15-second reaction-grid) wired end-to-end to
`@sigil-aptos/sdk`: connect a wallet, play, and submit your score on chain —
either normally or **⚡ gasless** (a fee-payer gas station covers the gas so the
player pays 0 APT). Scores show up live on the on-chain leaderboard.

It's a Next.js App Router app, so one command serves both the game **and** the
`/api/sponsor` gas station, and it deploys to Vercel as-is.

## Run locally

```bash
# from the repo root, the SDK must be built (the arcade imports its dist):
cd sdk/typescript && npm install && npm run build

cd examples/games/arcade
cp .env.example .env.local
#   → set SPONSOR_PRIVATE_KEY to a FUNDED testnet account's key for ⚡ gasless.
#     The demo's testnet-sponsor key is in move/.aptos/config.yaml (private_key
#     under the `testnet-sponsor` profile). Keep .env.local out of git.
npm install
npm run dev          # http://localhost:3000
```

Connect Nightly (set it to **Testnet**), play, then **⚡ Submit gasless** or
**Submit (pay gas)**.

## What it demonstrates

| Step | SDK |
|------|-----|
| Read the leaderboard | `sigil.leaderboard.viewTopEntriesForGame(gameId)` |
| Submit a score (player pays) | `sigil.gamePlatform.walletPayloadSubmitScore(...)` → `signAndSubmitTransaction` |
| Submit a score (gasless) | `buildSponsoredTransaction` → wallet `signTransaction` → `requestSponsorship('/api/sponsor')` → `submitSponsored` |
| Gas station (server) | `sponsorTransaction({ aptos, feePayer, serializedTransaction, allow })` in `app/api/sponsor/route.ts` |

First `submit_score` auto-registers the player (sets username) — no separate
signup transaction.

## Deploy to Vercel

Set the project root to this folder. Environment variables:

| Var | Notes |
|-----|-------|
| `SPONSOR_PRIVATE_KEY` | **server-only secret** — funded fee-payer key. Never expose / commit. |
| `NEXT_PUBLIC_SIGIL_MODULE_ADDRESS` | published module address (default: testnet publisher) |
| `NEXT_PUBLIC_APTOS_NETWORK` | `testnet` (default) |
| `NEXT_PUBLIC_ARCADE_GAME_ID` | `0` (the deploy script registers game 0) |

The gas station **only** sponsors calls to your Sigil module (allowlist in the
route) — never remove that guard or it becomes an open gas relay. Keep the fee
payer funded.
