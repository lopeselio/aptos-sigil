#!/usr/bin/env bash
# One-command TESTNET deploy.
#
# Unlike devnet (which wipes ALL state ~weekly), testnet is persistent and free,
# so it's the stable home for the published @sigil-aptos/sdk, the tutorial, and
# the example games. This script:
#   1. Resolves the publisher address from an Aptos CLI profile (default: testnet).
#   2. Funds it from the testnet faucet.
#   3. Publishes the Move package under that address (artifacts stripped to fit).
#   4. Re-runs all module inits + registers a game (devnet_quick_module_smoke.sh,
#      which is network-agnostic — it just uses $APTOS_PROFILE / $SIGIL_PUBLISHER).
#
# First-time setup (creates the publisher profile + key in move/.aptos/config.yaml):
#   cd move && aptos init --profile testnet --network testnet && cd ..
#
# Then run from anywhere:
#   ./scripts/redeploy_testnet.sh
#
# Optional env overrides:
#   APTOS_PROFILE     Publisher profile in move/.aptos/config.yaml (default: testnet)
#   SIGIL_PUBLISHER   Publisher address; overrides the profile's account.
#                     MUST be the account the profile signs with (it becomes
#                     [addresses].sigil for this publish via --named-addresses).
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/move"

PROFILE="${APTOS_PROFILE:-testnet}"

# Resolve the publisher address from the profile unless explicitly overridden.
if [[ -z "${SIGIL_PUBLISHER:-}" ]]; then
  ACCT="$(aptos config show-profiles --profile "$PROFILE" 2>/dev/null \
    | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['Result']['$PROFILE']['account'])" 2>/dev/null || true)"
  if [[ -z "$ACCT" ]]; then
    echo "ERROR: could not read account for profile '$PROFILE'." >&2
    echo "       Create it first:  cd move && aptos init --profile $PROFILE --network testnet" >&2
    exit 1
  fi
  PUB="0x${ACCT#0x}"
else
  PUB="0x${SIGIL_PUBLISHER#0x}"
fi

cd "$ROOT"
echo "== Deploy to TESTNET  profile=$PROFILE  publisher=$PUB =="

echo "== 1/3 Fund account from testnet faucet =="
# Testnet faucet can rate-limit / require the web faucet. If this fails, fund via
# https://aptos.dev/network/faucet then re-run with the account already funded.
aptos account fund-with-faucet --profile "$PROFILE" --account "$PUB" || \
  echo "WARN: faucet call failed — fund $PUB at https://aptos.dev/network/faucet and re-run."

echo "== 2/3 Publish package (artifacts stripped to fit size limit) =="
aptos move publish \
  --profile "$PROFILE" \
  --package-dir move \
  --named-addresses "sigil=$PUB" \
  --included-artifacts none \
  --skip-fetch-latest-git-deps \
  --assume-yes \
  --max-gas 2000000

echo "== 3/3 Initialize modules + register a game =="
APTOS_PROFILE="$PROFILE" SIGIL_PUBLISHER="$PUB" ./scripts/devnet_quick_module_smoke.sh

echo ""
echo "== Done. Sigil is live on testnet at: $PUB =="
echo "   Explorer: https://explorer.aptoslabs.com/account/$PUB?network=testnet"
echo "   Wire it into the apps:"
echo "     VITE_SIGIL_MODULE_ADDRESS=$PUB"
echo "     VITE_APTOS_NETWORK=testnet"
echo "   Verify: aptos move view --profile $PROFILE --function-id ${PUB}::game_platform::game_count --args address:$PUB"
