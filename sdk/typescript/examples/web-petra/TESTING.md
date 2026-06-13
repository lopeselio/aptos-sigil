# Web-Petra hybrid console — test plan

Manual checklist for the Sigil hybrid console (`npm run dev`, http://localhost:5173).

- **Network:** Aptos **testnet** (persistent; devnet wipes weekly).
- **Module:** `0x568721f98162f03aa564384f15d7ead24b9825a3f35e4c2dba8265bd126ce787`
  (override via `VITE_SIGIL_MODULE_ADDRESS` / `VITE_APTOS_NETWORK` in `.env.local`).
- **Wallet:** Nightly, set to **Testnet** (its RPC must match the app's fullnode).

## Setup
1. `cp .env.example .env.local` (already points at testnet + the module above).
2. `npm install && npm run dev`, open http://localhost:5173, **Connect Nightly**.
3. Fund your player wallet at https://aptos.dev/network/faucet (testnet faucet is web-only).

## Guided (Sigil Arcade) tab — the happy path
Walk steps 1–7. Each step: try **Inspect** (Move fn id, typed args, SDK call,
wallet payload), **Simulate** (free dry-run → `success` / gas / `vm_status`), then
**Run** (sign & submit). Expected:

1. **Open** — `Check game exists` / `game_count` → game 0 exists.
2. **First score** — `submit_score` (1000) → OK; first score auto-registers you.
3. **Leaderboard** — `top entries` shows you; `score_summary` → `[true,"1000","1000"]`.
4. **Quest** — `start_quest` (id 1) then `submit_score_with_quest` → OK.
5. **Reward** — `claim_reward` (achievement id 1) → OK; second claim aborts `E_ALREADY_CLAIMED`.
6. **Guild** — `create_guild` → OK; `my guild` (Views) reflects it.
7. **Season** — `current season` / `top entries` read cleanly.

## ⚡ Gasless
Run the [Arcade](../games/arcade) (`npm run dev`, serves `/api/sponsor`) or
deploy a gas station, then set `VITE_SPONSOR_ENDPOINT` to it. On a `submit_score`
step click **⚡ Gasless** → you approve but pay 0 APT; the log shows the fee payer.
Without a station, it logs a clear "gas station must be running" message.

## Technical tabs
- **Player** — same actions as Guided with Inspect/Simulate, plus merge.
- **Publisher (admin)** — raw owner calls; abort unless connected as the publisher.
- **Views (read-only)** — every `view*` for spot checks.

## Negative checks
- `claim_reward` twice → `E_ALREADY_CLAIMED`.
- `claim_reward` on an achievement with no reward → `E_NOT_FOUND`.
- A Publisher-tab write from a non-publisher wallet → `E_NO_PERMISSION`.

Done = Guided steps 1–7 run on testnet + the three negative checks behave.
Because testnet persists, state carries across runs (no weekly redeploy).
