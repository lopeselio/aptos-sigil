#!/usr/bin/env bash
# Deeper devnet checks: fund Sigil rewards resource account, attach native APT FA reward, optional player claim,
# plus shadow_signers::create_session (nested scope vectors are awkward in bare CLI — use sdk/typescript example).
#
# Prerequisites:
#   - Aptos CLI 9.x+, devnet-funded publisher profile (matches [addresses].sigil).
#   - rewards::init_rewards already run once for this publisher (creates resource account + RewardsConfig).
#   - Optional: APTOS_PLAYER_PROFILE — separate account with gas; used for rewards::claim_testing.
#
# Env:
#   APTOS_PROFILE          Publisher profile (required).
#   APTOS_PLAYER_PROFILE   Player profile for claim (optional).
#   SIGIL_PUBLISHER        Module address (default: Move.toml devnet publisher).
#   FA_ACHIEVEMENT_ID      u64 reward slot (default: random 900000–999999 to avoid E_ALREADY_ATTACHED).
#   FUND_POOL_OCTAS        Transfer to rewards pool before attach (default: 5000000 = 0.05 APT).
#   REWARD_AMOUNT_OCTAS    Per-claim amount (default: 100000 = 0.001 APT).
#   REWARD_SUPPLY          Max claims, 0 = unlimited (default: 3).
#
# Usage:
#   export APTOS_PROFILE=sigil-main
#   export APTOS_PLAYER_PROFILE=sigil-player   # optional
#   ./scripts/devnet_deeper_onchain_smoke.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PUB="${SIGIL_PUBLISHER:-0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6}"
PROFILE="${APTOS_PROFILE:?Set APTOS_PROFILE (publisher)}"
ACH_ID="${FA_ACHIEVEMENT_ID:-$((900000 + RANDOM % 99999))}"
FUND_POOL="${FUND_POOL_OCTAS:-5000000}"
AMT="${REWARD_AMOUNT_OCTAS:-100000}"
SUPPLY="${REWARD_SUPPLY:-3}"

run() { aptos move run --profile "$PROFILE" --assume-yes --max-gas 500000 "$@"; }
view() { aptos move view --profile "$PROFILE" "$@"; }

derive_pool_hex() {
  aptos account derive-resource-account-address \
    --address "$PUB" \
    --seed rewards_v1 \
    --seed-encoding utf8
}

POOL_ADDR="$(
  derive_pool_hex | python3 -c "import json,sys; h=json.load(sys.stdin)['Result']; print(h if h.startswith('0x') else '0x'+h)"
)"

echo "== Deeper smoke: publisher=$PUB profile=$PROFILE achievement_id=$ACH_ID pool=$POOL_ADDR =="

echo "== Fund rewards resource account (native APT primary store) =="
aptos account transfer --profile "$PROFILE" --account "$POOL_ADDR" --amount "$FUND_POOL" --assume-yes

echo "== rewards::attach_fa_reward (metadata 0xa) =="
set +e
run --function-id "${PUB}::rewards::attach_fa_reward" \
  --args "address:$PUB" "u64:$ACH_ID" address:0xa "u64:$AMT" "u64:$SUPPLY"
ATTACH_EC=$?
set -e
if [[ "$ATTACH_EC" -ne 0 ]]; then
  echo "attach_fa_reward failed (exit $ATTACH_EC). If E_ALREADY_ATTACHED, set FA_ACHIEVEMENT_ID to a fresh u64."
  exit "$ATTACH_EC"
fi

echo "== View get_reward =="
view --function-id "${PUB}::rewards::get_reward" --args "address:$PUB" "u64:$ACH_ID"

if [[ -n "${APTOS_PLAYER_PROFILE:-}" ]]; then
  echo "== Player claim_testing via profile $APTOS_PLAYER_PROFILE =="
  aptos move run --profile "$APTOS_PLAYER_PROFILE" --assume-yes --max-gas 500000 \
    --function-id "${PUB}::rewards::claim_testing" \
    --args "address:$PUB" "u64:$ACH_ID"
  echo "== View get_reward after claim =="
  view --function-id "${PUB}::rewards::get_reward" --args "address:$PUB" "u64:$ACH_ID"
else
  echo "== Skip claim_testing (set APTOS_PLAYER_PROFILE to run player-signed claim) =="
fi

echo "== Shadow session: use TypeScript example (nested vector<u8> scopes) =="
echo "    cd sdk/typescript && npm install && SIGIL_PUBLISHER_PRIVATE_KEY=0x... npm run example:deeper-smoke"
echo "== Done. Full season path: SKIP_PUBLISH=1 ./scripts/devnet_season_payout_smoke.sh =="
