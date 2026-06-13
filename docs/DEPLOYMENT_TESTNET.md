# Testnet deployment runbook

Testnet is the **stable home** for the published `@sigil-aptos/sdk`, the tutorial,
and the example games (devnet wipes weekly; testnet is persistent and free).

## Current deployment

The live module is at **`0x694fd0c04ecf4ec750450d3c1a4d318d5869f2cf762562a8a586a44e1c29d1c1`**
(profile `testnet-v2`), with games 0 (Arcade), 1 (Dungeon), 2 (Idle) + leaderboards
registered. This is a **fresh deploy** that includes the rewards/quests bug fixes
(#9 `claim_reward` now requires an unlocked achievement — `claim_testing` is no
longer published; #8 `claim_quest_reward` exists). It replaces an earlier address
that had the pre-fix bytecode (a fresh address was needed because the fixes remove
a public function, which Aptos's compatible upgrade policy rejects in place).

## Accounts (generated, keys in gitignored `move/.aptos/config.yaml` / `.aptos/config.yaml`)

| Role | Profile | Address |
|------|---------|---------|
| Publisher (owns the modules) | `testnet-v2` | `0x694fd0c04ecf4ec750450d3c1a4d318d5869f2cf762562a8a586a44e1c29d1c1` |
| Sponsor (gas station fee payer) | `testnet-sponsor` | `0xe2a6706b01ecd5188a97e35f260ffec6bb8b1a4d87b005396b91d813705a407a` |

> These are throwaway testnet keys. To use your own, run
> `aptos init --profile <name> --network testnet`, fund it, then point the apps at
> your address.

## One-time: fund the publisher

Testnet's CLI faucet is disabled — either complete the web faucet captcha, or
transfer from an already-funded account:

- Web faucet: https://aptos.dev/network/faucet?address=0x694fd0c04ecf4ec750450d3c1a4d318d5869f2cf762562a8a586a44e1c29d1c1
- Or transfer: `aptos account transfer --profile <funded> --account <publisher> --amount 600000000`

The Sponsor likewise needs APT to pay gas:
https://aptos.dev/network/faucet?address=0xe2a6706b01ecd5188a97e35f260ffec6bb8b1a4d87b005396b91d813705a407a

## Deploy the modules

Once the **publisher** is funded (using its profile, e.g. `testnet-v2`):

```bash
APTOS_PROFILE=testnet-v2 ./scripts/redeploy_testnet.sh
```

This publishes the package under the publisher address and runs all module
`init_*` calls + registers a game (game_id 0) + leaderboard 0. Verify:

```bash
aptos move view --profile testnet-v2 \
  --function-id 0x694fd0c04ecf4ec750450d3c1a4d318d5869f2cf762562a8a586a44e1c29d1c1::game_platform::game_count \
  --args address:0x694fd0c04ecf4ec750450d3c1a4d318d5869f2cf762562a8a586a44e1c29d1c1
```

Explorer: https://explorer.aptoslabs.com/account/0x694fd0c04ecf4ec750450d3c1a4d318d5869f2cf762562a8a586a44e1c29d1c1?network=testnet

## Wire it into the apps

Set in each example app's `.env.local` (and in Vercel project env for deploys):

```
VITE_SIGIL_MODULE_ADDRESS=0x694fd0c04ecf4ec750450d3c1a4d318d5869f2cf762562a8a586a44e1c29d1c1
VITE_APTOS_NETWORK=testnet
VITE_SPONSOR_ENDPOINT=/api/sponsor        # gas station route (optional, for gasless)
```

## Gas station (sponsor) secret

The sponsor's **private key** powers `/api/sponsor`. Export it from the profile
and set it as a server-side secret (never commit, never expose to the browser):

```bash
# prints the private key for the sponsor profile — handle as a secret
aptos config show-private-key --profile testnet-sponsor   # if available on your CLI
# otherwise read it from move/.aptos/config.yaml (private_key under testnet-sponsor)
```

Set `SPONSOR_PRIVATE_KEY=<that key>` in the gas-station environment (Vercel
project env / local `.env.local` of the example with the API route). Keep the
sponsor account funded so it can pay gas.
