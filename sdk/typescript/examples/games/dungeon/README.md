# Sigil Dungeon

A run-based Aptos game (game id **1**): descend, mash **⚔️ Strike** to earn score
and find loot, then record your run on chain — normally or **⚡ gasless**. Adds a
**guild** (party) panel on top of the on-chain leaderboard.

Same stack and gas station as the [Arcade](../arcade) (Next.js App Router,
`@sigil-aptos/sdk`, `/api/sponsor`). See the Arcade README for the SDK call map.

```bash
cd sdk/typescript && npm install && npm run build   # SDK must be built
cd examples/games/dungeon
cp .env.example .env.local   # set SPONSOR_PRIVATE_KEY for ⚡ gasless
npm install && npm run dev   # http://localhost:3001
```

What's on chain:
- `submit_score` to game 1 (run score) — normal or gasless.
- `guilds::create_guild` / `join_guild` / `leave_guild` — player-signed.
- Loot is local flavor; minting real items on chain (`merge`) needs the publisher
  to `grant_items` first — try that in the [web-petra console](../../web-petra)
  Publisher tab.
