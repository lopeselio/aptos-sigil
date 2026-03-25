#!/usr/bin/env bash
# Fast devnet smoke: touch each published module with minimal txs (no season wait).
#
# Run from repo root (uses .aptos/config.yaml):
#   export APTOS_PROFILE=sigil-main   # or devnet
#   ./scripts/devnet_quick_module_smoke.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PUB="${SIGIL_PUBLISHER:-0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6}"
PROFILE="${APTOS_PROFILE:?Set APTOS_PROFILE (e.g. sigil-main)}"
TS="$(date +%s)"
# 32-byte Ed25519 pubkey placeholder (smoke only)
PK32=0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20

run() { aptos move run --profile "$PROFILE" --assume-yes --max-gas 500000 "$@"; }
view() { aptos move view --profile "$PROFILE" "$@"; }

parse_u64() {
  python3 -c "import json,sys; r=json.load(sys.stdin)['Result'][0]; print(int(r,16) if isinstance(r,str) and r.startswith('0x') else int(r))"
}

echo "== Quick module smoke profile=$PROFILE publisher=$PUB =="

echo "== Inits (ignore if already done) =="
set +e
run --function-id "${PUB}::merge::init_merge" || true
run --function-id "${PUB}::guilds::init_guilds" || true
run --function-id "${PUB}::game_platform::init" || true
run --function-id "${PUB}::leaderboard::init_leaderboards" || true
run --function-id "${PUB}::seasons::init_seasons" || true
run --function-id "${PUB}::treasury::init_treasury" || true
run --function-id "${PUB}::achievements::init_achievements" || true
run --function-id "${PUB}::rewards::init_rewards" || true
run --function-id "${PUB}::roles::init_roles" || true
run --function-id "${PUB}::quests::init_quests" || true
run --function-id "${PUB}::shadow_signers::init_sessions" || true
run --function-id "${PUB}::attest::init_attest" --args "hex:${PK32}" u64:60 || true
set -e

echo "== game_platform: register_game =="
set +e
run --function-id "${PUB}::game_platform::register_game" --args string:"QuickSmoke_${TS}" || true
set -e

echo "== leaderboard: ensure id 0, submit_score_direct =="
LB_COUNT="$(view --function-id "${PUB}::leaderboard::get_leaderboard_count" --args "address:$PUB" | parse_u64)"
if [[ "${LB_COUNT:-0}" -eq 0 ]]; then
  run --function-id "${PUB}::leaderboard::create_leaderboard" \
    --args "address:$PUB" u64:0 u8:0 u64:0 u64:10000000000 bool:false bool:false u64:10
fi
PX="0x4444444444444444444444444444444444444444444444444444444444444444"
run --function-id "${PUB}::leaderboard::submit_score_direct" \
  --args "address:$PUB" u64:0 "address:${PX}" "u64:$((TS % 100000 + 1000))"

echo "== achievements: create + on_score hook via submit path =="
set +e
run --function-id "${PUB}::achievements::create" \
  --args "address:$PUB" hex:536d6f6b65 hex:536d6f6b6520616368 u64:10 hex: || true
set -e

echo "== guilds: create_guild (publisher as founder) =="
set +e
run --function-id "${PUB}::guilds::create_guild" \
  --args "address:$PUB" string:"QuickGuild_${TS}" || true
set -e

echo "== merge: register_recipe + grant_items =="
set +e
run --function-id "${PUB}::merge::register_recipe" \
  --args "address:$PUB" u64:1 u64:1 u64:2 u64:1 || true
run --function-id "${PUB}::merge::grant_items" \
  --args "address:$PUB" "address:${PX}" u64:1 u64:10 || true
set -e

echo "== quests: create_score_quest =="
set +e
run --function-id "${PUB}::quests::create_score_quest" \
  --args string:"Q_${TS}" string:"Score 50 smoke" u64:0 u64:50 u64:0 bool:false || true
set -e

echo "== treasury: tiny self-deposit (0.01 APT) =="
set +e
run --function-id "${PUB}::treasury::deposit" \
  --args "address:$PUB" address:0xa u64:1000000 || true
set -e

echo "== Views =="
view --function-id "${PUB}::leaderboard::get_top_entries" --args "address:$PUB" u64:0
view --function-id "${PUB}::quests::get_quest_count" --args "address:$PUB"
view --function-id "${PUB}::game_platform::game_count" --args "address:$PUB"
view --function-id "${PUB}::treasury::get_balance" --args "address:$PUB" address:0xa

echo "== Done. For full season + payout smoke use: ./scripts/devnet_season_payout_smoke.sh (SKIP_PUBLISH=1) =="
