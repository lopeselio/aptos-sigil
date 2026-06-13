# Testnet deployment runbook

Testnet is the **stable home** for the published `@sigil-aptos/sdk`, the tutorial,
and the example games (devnet wipes weekly; testnet is persistent and free).

## Accounts (generated, keys in gitignored `move/.aptos/config.yaml`)

| Role | Profile | Address |
|------|---------|---------|
| Publisher (owns the modules) | `testnet` | `0x568721f98162f03aa564384f15d7ead24b9825a3f35e4c2dba8265bd126ce787` |
| Sponsor (gas station fee payer) | `testnet-sponsor` | `0xe2a6706b01ecd5188a97e35f260ffec6bb8b1a4d87b005396b91d813705a407a` |

> These are throwaway testnet keys. To use your own, re-run
> `cd move && aptos init --profile testnet --network testnet` (and likewise for
> `testnet-sponsor`), then update the addresses above.

## One-time: fund both accounts (manual — testnet faucet is web-only)

The CLI faucet does not work on testnet. Visit the faucet for each address and
complete the captcha:

- Publisher: https://aptos.dev/network/faucet?address=0x568721f98162f03aa564384f15d7ead24b9825a3f35e4c2dba8265bd126ce787
- Sponsor: https://aptos.dev/network/faucet?address=0xe2a6706b01ecd5188a97e35f260ffec6bb8b1a4d87b005396b91d813705a407a

## Deploy the modules

Once the **publisher** is funded:

```bash
./scripts/redeploy_testnet.sh
```

This publishes the package under the publisher address and runs all module
`init_*` calls + registers a game (game_id 0) + leaderboard 0. Verify:

```bash
aptos move view --profile testnet \
  --function-id 0x568721f98162f03aa564384f15d7ead24b9825a3f35e4c2dba8265bd126ce787::game_platform::game_count \
  --args address:0x568721f98162f03aa564384f15d7ead24b9825a3f35e4c2dba8265bd126ce787
```

Explorer: https://explorer.aptoslabs.com/account/0x568721f98162f03aa564384f15d7ead24b9825a3f35e4c2dba8265bd126ce787?network=testnet

## Wire it into the apps

Set in each example app's `.env.local` (and in Vercel project env for deploys):

```
VITE_SIGIL_MODULE_ADDRESS=0x568721f98162f03aa564384f15d7ead24b9825a3f35e4c2dba8265bd126ce787
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
