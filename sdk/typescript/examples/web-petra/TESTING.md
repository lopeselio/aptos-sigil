# Web-Petra Testing Console — Test Plan & Status

Manual test checklist for the Sigil module testing console (`npm run dev`, http://localhost:5173).
Module under test: `0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6` (Aptos devnet, chain 240).
Override with `VITE_SIGIL_MODULE_ADDRESS` in `.env.local`.

## ⚠️ Devnet reset (2026-06-11)

Devnet wiped overnight (chain 239 → 240, ledger restarted). All of 2026-06-10's
on-chain state — module, games 0–3, player registration, the score of 1000 —
is gone. Redeployed via `./scripts/redeploy_devnet.sh`, which republished the
package, re-ran all inits, registered game 0, and (via the smoke script)
already created a leaderboard for game 0, a quest, and a treasury deposit.

State after redeploy:

```
game_count: ["1"]            (game_id 0 only)
has_game(0): [true]
has_leaderboard_for_game(0): [true]   ← smoke script made it; create_leaderboard for game 0 will abort
leaderboard_count: ["1"]
attest initialized: done (inits re-run by redeploy script — still skip init buttons)
```

Consequences for manual testing:
- The Nightly player wallet (`0x0cb7b087...665e636e47`) has **zero balance**
  and is **no longer registered** — airdrop devnet APT to it (Nightly's faucet
  button) and re-run player registration before any submit_score.
- If the wallet had Devnet pinned as a custom network with chain 239, re-add
  it; the standard Devnet entry picks up chain 240 automatically.
- Flow 1's `create_leaderboard` must target a **new game**: run
  `register_game` first (becomes game_id 1), then create the board for game 1.

## Status from 2026-06-10 (pre-reset, for reference)

Completed before the reset: wallet connect (Nightly), `has_game`/`game_count`
views, player registration, `submit_score` (1000, confirmed via
`score_summary`/`get_scores`), role + init attestation views. All of this
state no longer exists on chain; the player-side steps need a re-run.

### Roles
`role_summary` is `[false,false,false]` on the player wallet — Publisher-tab
calls only pass when connected as the publisher account `0xe68e...dfac6`
(the CLI `devnet` profile that deployed the module — see
`scripts/setup_petra_player_cli_profile.sh`), or after granting the player
wallet an admin/operator role from it.

---

## Step-by-step UI walkthrough (full coverage, post-reset)

On-chain starting point (created by the redeploy smoke script, all owned by
the publisher `0xe68e...dfac6`): game 0 + leaderboard 0 (dummy entry
`0x4444...` = 1844), achievement 0, quest 0 (game 0), recipe 0
(1× item 1 → 1× item 2 — note input qty 1, unlike the UI's 2× default), guild 0
(publisher is its member), small treasury deposit. No seasons, no rewards attached yet.

Plan: do everything on a **fresh game 1** so `create_leaderboard` (the fixed
wallet path) can be exercised. One wallet switch total: Publisher phase →
Player phase → back to Publisher to finalize the season.

### Phase 0 — setup
1. Dev server running at http://localhost:5173 (it is).
2. Nightly: make sure the **publisher** account (`0xe68e...dfac6`, key from
   `.aptos/config.yaml` profile `devnet`) and a **player** account are both
   imported. Devnet is now **chain 240** — if a custom network pinned 239,
   re-add it.
3. Fund the player wallet (it was wiped):
   `aptos account fund-with-faucet --profile devnet --account <PLAYER_ADDR>`
   (publisher already has ~3 APT from the redeploy).
4. Open the app, **Connect Nightly**, select the publisher account.
   Views tab → `my role` should log `[true,...]`; `attest init?` → `[true]`.

### Phase 1 — Publisher: platform + leaderboard (bug-fix path)
5. Publisher tab → game_platform: set game title, click `register_game`
   → tx hash in log. This is **game_id 1**.
6. Set the shared `gameId` field to `1` (it's used by every card from now on).
   Views → `has_game` → `[true]`; `game_count` → `["2"]`.
7. Publisher tab → leaderboard: defaults (decimals 0, min 0, max 1e10,
   retain 10, both checkboxes off) → `create_leaderboard (game_id above)`.
   This is the BigInt→Number fix under test — it must reach Nightly's
   approve popup (previously it threw client-side). Expect success;
   Views → `count` → `["2"]` (this board is **lb 1**).
   Note `top (lb 0)` / `config (lb 0)` view buttons are hardcoded to board 0;
   use `top (game_id)` for game 1's board.

### Phase 2 — Publisher: achievement → reward, quest, season, treasury, merge
8. achievements: defaults ("First Win", min 1000) → `create`. This is
   **achievement_id 1** (0 exists from the smoke script).
9. rewards: set `rewardAchId` = `1`, amount 100000 (0.001 APT), supply 100 →
   `attach_fa_reward`. Views → `rewarded list` should include 1;
   `get_reward` (ach id 1) shows amount/supply.
10. quests: defaults (target 1000, reward_id 0 = none, gameId field = 1) →
    `create_score_quest`. This is **quest_id 1**.
11. seasons: in a terminal run `date +%s`; set `seasonStart` = now + 60,
    `seasonEnd` = now + 240 (Move asserts start ≥ now and finalize needs
    now ≥ end), `seasonLb` = `1`, name/prize as you like → `create_season`
    (**season_id 0**... season_count was 0). Wait ~1 min, set `seasonId` = `0`,
    click `start` (aborts E_SEASON_NOT_STARTED=4 if clicked before start time).
    Views → `current` shows it active.
12. treasury: amount 100000 → `deposit`; Views → `treasury balance` /
    `treasury stats` before & after. Then set `withdrawTo` = player address,
    amount 100000 → `withdraw`; re-check views (balance back down, player +0.001).
13. merge (publisher doubles as the player here, since `grant_items → me`
    grants to the *connected* wallet): `grant_items → me` (item 1, qty 5) →
    Views `my item_qty` → 5 (or 10 if the smoke grant also hit this account) →
    Player tab → merge: `recipeId` = `0` → `execute_merge` →
    Views: item 1 down by 2, item 2 (set `grantItem` = `2`) up by 1.
14. Optional roles test: set `adminAddr` = player address → `add_admin`;
    later, on the player wallet, `my role` should read `[false,true,...]`.

### Phase 3 — Player: scores, quest, reward, guilds (switch wallet in Nightly)
15. Switch Nightly to the player account (reconnect if the app doesn't pick
    it up). Views → `my role` → `[false,false,false]` (unless step 14).
16. Player tab → game_platform (gameId still 1): `Check game exists` → ok.
    `Preflight simulate` → simulation success logged. **quests first**: set
    `questId` = `1` → `start_quest`. Then `submit_score` (score 1000,
    username player1) — first score auto-registers, updates leaderboard 1,
    and advances the started score quest. One tx.
17. Views: `score_summary` → `[true,"1000","1000"]`; `get_scores` →
    `[["1000","1000"]]`; `top (game_id)` → player ranked on board 1;
    quests `my progress` (quest 1) → complete; `active (me)`.
18. rewards: `rewardAchId` = `1` → `claim_reward` → success; player gains
    0.001 APT. Click `claim_reward` again → **expect abort E_ALREADY_CLAIMED**.
19. guilds: `create_guild` ("My Clan") → **guild 1**; Views `my guild` → 1,
    `guild_count` → 2. `leave_guild`, then `guildId` = `0` → `join_guild`,
    `my guild` → 0.
20. Negative pass (still player): rewards `rewardAchId` = `0` →
    `claim_reward` → abort E_NOT_FOUND (nothing attached to ach 0) — Nightly
    simulation should surface it before signing. Publisher tab →
    `register_game` → abort E_NO_PERMISSION (skip if you did step 14 —
    an admin player will succeed instead).

### Phase 4 — Publisher: close the season
21. Switch back to the publisher. During the season window the player's
    submit_score landed on board 1 (season's board). seasons: `seasonId` 0 →
    `end`. Once past `seasonEnd` (~4 min after creation) → `finalize`
    (early click aborts E_CANNOT_FINALIZE_YET=9). Views → `get_season` →
    finalized; `current` → none active.

Done = every card on all three tabs exercised, plus 3 negative cases.

---

## Notes
- The console connects via the **Nightly** wallet (AIP-62), despite the
  `web-petra` folder name.
- Staging vs public devnet are different chains — the wallet's Devnet custom
  RPC must match the app fullnode (`https://api.devnet.aptoslabs.com/v1`) or
  simulation and Approve will fail.
