#!/usr/bin/env bash
# One-command devnet redeploy.
#
# Aptos devnet resets (wipes ALL state) roughly weekly. After a reset the
# published modules and account balance are gone, so the frontend fails with:
#   module_not_found: Module name(game_platform) ...
# This script restores a working deployment in three steps:
#   1. Fund the publisher account from the devnet faucet.
#   2. Republish the Move package (artifacts stripped to fit the 60 KB limit).
#   3. Re-run all module inits + register a game (devnet_quick_module_smoke.sh).
#
# Run from anywhere (it cd's to repo root, which holds .aptos/config.yaml):
#   ./scripts/redeploy_devnet.sh
#
# Optional env overrides:
#   APTOS_PROFILE     Publisher profile in .aptos/config.yaml   (default: devnet)
#   SIGIL_PUBLISHER   Publisher address; MUST match [addresses].sigil in
#                     move/Move.toml (default: that file's value)
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PROFILE="${APTOS_PROFILE:-devnet}"
PUB="${SIGIL_PUBLISHER:-0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6}"

echo "== Redeploy to devnet  profile=$PROFILE  publisher=$PUB =="

echo "== 1/3 Fund account from faucet =="
aptos account fund-with-faucet --profile "$PROFILE" --account "$PUB"

echo "== 2/3 Publish package (artifacts stripped to fit 60 KB limit) =="
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

echo "== Done. Verify: aptos move view --profile $PROFILE --function-id ${PUB}::game_platform::has_game --args address:$PUB u64:0 =="
