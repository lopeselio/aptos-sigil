# Deploying Sigil Move packages

Use this when moving from an **older on-chain deployment** to the current repo (new entry signatures, `seasons` resource layout, etc.).

## Prerequisites

- **Aptos CLI 9.x+** (matches Move 2.2 / framework `mainnet` rev used in `move/Move.toml`).
- An Aptos profile with enough APT for gas (`aptos init`, fund via faucet on devnet).

## Publish

The package is **larger than the default 60 KB publish limit** when built with full artifacts. Use one of these patterns.

**Recommended (single transaction, smaller bytecode bundle):** publish with minimal artifacts (still fine for production use; you only lose on-chain source reconstruction extras):

```bash
cd move
aptos move publish \
  --profile YOUR_PROFILE \
  --included-artifacts none \
  --skip-fetch-latest-git-deps \
  --assume-yes \
  --max-gas 2000000
```

**Alternative (chunked publish):** if you need default/sparse artifacts or hit on-chain size limits:

```bash
cd move
aptos move publish \
  --profile YOUR_PROFILE \
  --chunked-publish \
  --large-packages-module-address 0x7 \
  --skip-fetch-latest-git-deps \
  --assume-yes \
  --max-gas 2000000
```

On **devnet**, chunked mode uses the framework `large_packages` address **`0x7`** (see `aptos move publish --help`). Use `--override-size-check` only if you understand the risk; the chain may still reject oversized payloads.

**Profile:** `YOUR_PROFILE` must control the **`sigil` address** in `move/Move.toml` (`[addresses]`). Publishing from a different account fails with a constraint / permission error.

Use `--max-gas` if the default cap is too low for your network.

For local verification without refetching framework git deps:

```bash
cd move
aptos move test --skip-fetch-latest-git-deps
```

## Breaking upgrades (read before mainnet)

- **Full package republish:** Deploy the **entire** package at your publisher address. Do not assume partial upgrades across incompatible resource layouts.
- **`seasons`:** `Seasons` on-chain state changed (e.g. `has_active_season`). Existing `Seasons` resources from an old deployment are **not** layout-compatible; plan migration or a **new publisher account** for production cutovers.
- **Entry functions:** Many admin entrypoints now take **`actor` + `publisher: address`**. CLI examples in the README and `docs/modules/*` use **publisher as the first `--args` address** where applicable. Player-only calls (`game_platform::submit_score`, `quests::start_quest`, etc.) pass **publisher as the first arg** while the **transaction sender is the player**.

## Smoke test after deploy

Run one end-to-end path with **your** module address (replace `PUB`):

1. **Init** (once per publisher): `game_platform::init`, `leaderboard::init_leaderboards`, `achievements::init_achievements`, `rewards::init_rewards`, and any other modules you use (`seasons::init_seasons`, `quests::init_quests`, `merge::init_merge`, `guilds::init_guilds`, …).
2. **Publisher setup:** register a game, `leaderboard::create_leaderboard` with `--args address:PUB …`, create at least one achievement (publisher-first args), attach a reward if testing claims.
3. **Player path:** register player, submit score (player profile; args `address:PUB u64:game_id u64:score`), or use `submit_score_direct` / `quests::submit_score_with_quest` as documented.
4. **Claim:** `rewards::claim_testing` or `claim_reward` with the player profile.
5. **(Optional) Season payouts:** If you use `seasons::finalize_season_and_distribute_prizes`, initialize `treasury`, `treasury::deposit` enough of the prize FA for the publisher, ensure the FA metadata supports **primary stores**, and run the finalize entry **with the publisher profile** (not an operator). See [Seasons Guide](./modules/SEASONS_GUIDE.md#step-5-end-season--distribute-prizes).

**Automated smoke (devnet):** from the repo root, with a profile that matches `[addresses].sigil` and devnet APT:

```bash
export APTOS_PROFILE=your_publisher_profile
./scripts/devnet_season_payout_smoke.sh
```

Set `SKIP_PUBLISH=1` to only run the on-chain calls after you have already published. The script uses **native APT** metadata **`0xa`** (primary-store compatible). See `scripts/devnet_season_payout_smoke.sh` for tunables (`SLEEP_AFTER_CREATE`, `PUBLISH_CHUNKED`, etc.).

Detailed command snippets also live in the [README](../README.md) (CLI sections per module).
