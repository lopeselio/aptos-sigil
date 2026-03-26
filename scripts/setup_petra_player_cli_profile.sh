#!/usr/bin/env bash
# Creates CLI profile `petra-player-devnet` on devnet for an existing wallet.
# The private key must be the one that controls that account (export from Petra / your wallet).
#
# From repo root:
#   APTOS_PLAYER_PRIVATE_KEY='ed25519-priv-0x…' ./scripts/setup_petra_player_cli_profile.sh
#   # or pass as first argument
#
# Afterward, compare `account` from `aptos config show-profiles` to your wallet address.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

KEY="${1:-${APTOS_PLAYER_PRIVATE_KEY:-}}"
if [[ -z "$KEY" ]]; then
  echo "Missing private key. Set APTOS_PLAYER_PRIVATE_KEY or pass ed25519-priv-0x… as the first argument." >&2
  exit 1
fi

PROFILE_NAME="${APTOS_PLAYER_PROFILE_NAME:-petra-player-devnet}"

aptos init \
  --network devnet \
  --profile "$PROFILE_NAME" \
  --private-key "$KEY" \
  --skip-faucet \
  --assume-yes

echo ""
echo "Profile ${PROFILE_NAME} added. Confirm account matches 0x1a16eab671220a2bc4673acc7658b7466492fc478023677c88f666677c2345ab (or your intended wallet):"
aptos config show-profiles
