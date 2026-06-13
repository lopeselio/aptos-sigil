# Sigil Idle

An idle/accumulator Aptos game (game id **2**): essence ticks up over time,
**⛏️ Channel** for a burst, **⬆ Upgrade** your rate, then **checkpoint** your total
as your on-chain score — normally or **⚡ gasless**. Adds a **quests** panel and a
live **season** read.

Same stack and gas station as the [Arcade](../arcade) (Next.js App Router,
`@sigil-aptos/sdk`, `/api/sponsor`).

```bash
cd sdk/typescript && npm install && npm run build   # SDK must be built
cd examples/games/idle
cp .env.example .env.local   # set SPONSOR_PRIVATE_KEY for ⚡ gasless
npm install && npm run dev   # http://localhost:3002
```

What's on chain:
- `submit_score` to game 2 (your checkpoint) — normal or gasless.
- `quests::start_quest` + `quests::submit_score_with_quest` — player-signed.
- `seasons::get_current_season` — read-only.

Seasons are created/started by the publisher (web-petra console Publisher tab);
while one is active over game 2's leaderboard, your checkpoints count toward it.
