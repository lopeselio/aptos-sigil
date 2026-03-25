#!/usr/bin/env bash
# End-to-end devnet smoke: leaderboard scores → treasury → finalize_season_and_distribute_prizes (APT / 0xa).
#
# Prerequisites:
#   - Aptos CLI 9.x+
#   - Profile whose **account address** matches `sigil` in move/Move.toml (named publisher).
#   - Account funded on devnet (faucet).
#
# Usage:
#   export APTOS_PROFILE=sigil-main       # or `devnet`; must match Move.toml [addresses].sigil
#   ./scripts/devnet_season_payout_smoke.sh
#
# Optional:
#   SKIP_PUBLISH=1              Skip `aptos move publish`
#   SKIP_INITS=1                Skip optional module init_* calls (avoids E_ALREADY_INIT noise and wasted gas on re-runs)
#   PUBLISH_CHUNKED=1           Use --chunked-publish (and default/sparse artifacts) instead of --included-artifacts none
#   SLEEP_AFTER_CREATE=100      Seconds to wait after create_season (must be > end_time - start_time)
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOVE_DIR="$ROOT/move"

# Must equal `sigil` under [addresses] in move/Move.toml
PUB="${SIGIL_PUBLISHER:-0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6}"
PROFILE="${APTOS_PROFILE:?Set APTOS_PROFILE to an Aptos CLI profile for $PUB}"
SLEEP_SEC="${SLEEP_AFTER_CREATE:-110}"

if [[ "$(echo "$PUB" | tr '[:upper:]' '[:lower:]')" != 0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 ]]; then
  echo "Warning: PUB/SIGIL_PUBLISHER differs from repo Move.toml default; ensure it matches [addresses].sigil."
fi

run() {
  aptos move run --profile "$PROFILE" --assume-yes --max-gas 500000 "$@"
}

view() {
  aptos move view --profile "$PROFILE" "$@"
}

echo "== Using profile=$PROFILE publisher=$PUB =="

if [[ "${SKIP_PUBLISH:-0}" != "1" ]]; then
  echo "== Publishing sigil_v2 =="
  cd "$MOVE_DIR"
  if [[ "${PUBLISH_CHUNKED:-0}" == "1" ]]; then
    aptos move publish \
      --profile "$PROFILE" \
      --chunked-publish \
      --large-packages-module-address 0x7 \
      --skip-fetch-latest-git-deps \
      --assume-yes \
      --max-gas 2000000
  else
    aptos move publish \
      --profile "$PROFILE" \
      --included-artifacts none \
      --skip-fetch-latest-git-deps \
      --assume-yes \
      --max-gas 2000000
  fi
  cd "$ROOT"
else
  echo "== SKIP_PUBLISH=1: not publishing =="
fi

if [[ "${SKIP_INITS:-0}" == "1" ]]; then
  echo "== SKIP_INITS=1: skipping module inits =="
else
  echo "== Optional module inits (ok if already initialized; set SKIP_INITS=1 to skip) =="
  set +e
  run --function-id "${PUB}::merge::init_merge" || true
  run --function-id "${PUB}::guilds::init_guilds" || true
  run --function-id "${PUB}::game_platform::init" || true
  run --function-id "${PUB}::leaderboard::init_leaderboards" || true
  run --function-id "${PUB}::seasons::init_seasons" || true
  run --function-id "${PUB}::treasury::init_treasury" || true
  run --function-id "${PUB}::achievements::init_achievements" || true
  run --function-id "${PUB}::rewards::init_rewards" || true
  set -e
fi

echo "== Register game (ignore failure if duplicate) =="
set +e
run --function-id "${PUB}::game_platform::register_game" --args string:"SmokeGame" || true
set -e

echo "== Create leaderboard id 0 if missing =="
parse_u64() {
  python3 -c "import json,sys; r=json.load(sys.stdin)['Result'][0]; print(int(r,16) if isinstance(r,str) and r.startswith('0x') else int(r))"
}
LB_COUNT="$(view --function-id "${PUB}::leaderboard::get_leaderboard_count" --args "address:$PUB" | parse_u64)"
if [[ "${LB_COUNT:-0}" -eq 0 ]]; then
  run --function-id "${PUB}::leaderboard::create_leaderboard" \
    --args "address:$PUB" u64:0 u8:0 u64:0 u64:10000000000 bool:false bool:false u64:10
fi

echo "== Seed two leaderboard players (submit_score_direct) =="
P1="0x1111111111111111111111111111111111111111111111111111111111111111"
P2="0x2222222222222222222222222222222222222222222222222222222222222222"
run --function-id "${PUB}::leaderboard::submit_score_direct" \
  --args "address:$PUB" u64:0 "address:$P1" u64:900
run --function-id "${PUB}::leaderboard::submit_score_direct" \
  --args "address:$PUB" u64:0 "address:$P2" u64:800

echo "== Create season (start soon, end in ~90s); prize_pool 2 APT for 2-way split =="
NOW="$(date +%s)"
START=$((NOW + 15))
END=$((NOW + 85))
PRIZE=200000000

run --function-id "${PUB}::seasons::create_season" \
  --args \
    "address:$PUB" \
    string:"SmokeSeason" \
    "u64:$START" \
    "u64:$END" \
    u64:0 \
    "u64:$PRIZE"

NEXT_SID="$(view --function-id "${PUB}::seasons::get_season_count" --args "address:$PUB" | parse_u64)"
SID=$((NEXT_SID - 1))
echo "Using season_id=$SID (last created)"

echo "== Waiting ${SLEEP_SEC}s until chain time is past end_time ($END) =="
sleep "$SLEEP_SEC"

# Native APT FA metadata; use `address:` (older CLI has no `object:` arg type).
FA_META="address:0xa"

echo "== Treasury: deposit 2 APT (native FA metadata 0xa) =="
run --function-id "${PUB}::treasury::deposit" \
  --args "address:$PUB" "$FA_META" "u64:$PRIZE"

echo "== Finalize season and distribute prizes (top 2, equal split) =="
run --function-id "${PUB}::seasons::finalize_season_and_distribute_prizes" \
  --args "address:$PUB" "u64:$SID" "$FA_META" u64:2

echo "== View season after payout =="
view --function-id "${PUB}::seasons::get_season" --args "address:$PUB" "u64:$SID"

echo "== Done. Expect is_finalized true and prize_pool reduced by paid amount (remainder dust). =="
