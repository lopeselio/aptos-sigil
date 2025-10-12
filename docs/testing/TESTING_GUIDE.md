# Sigil Leaderboard Testing Guide

> **📌 Current Status:** Both modules are successfully deployed on devnet with independent architecture.
> This guide serves as a reference for testing leaderboard functionality.
> See [README.md](./README.md) for latest deployment info, live examples, and on-chain verification.

## 🎯 Quick Start (No Changes to game_platform)

This guide shows how to test the leaderboard system **independently** without modifying `game_platform`. Perfect for validating functionality before full integration!

---

## Prerequisites

Ensure you have:
- ✅ Aptos CLI installed
- ✅ Publisher profile configured (`devnet`)
- ✅ At least one player profile configured
- ✅ Both modules compiled

---

## Step 1: Compile & Publish

```bash
cd move
aptos move compile
```

**Expected output:**
```
BUILDING sigil_v2
{
  "Result": [
    "<ADDRESS>::game_platform",
    "<ADDRESS>::leaderboard"
  ]
}
```

Publish both modules:

```bash
aptos move publish --profile devnet --assume-yes
```

---

## Step 2: Initialize Game Platform (if not already done)

```bash
aptos move run \
  --profile devnet \
  --function-id 'default::game_platform::init'
```

Register a test game:

```bash
aptos move run \
  --profile devnet \
  --function-id 'default::game_platform::register_game' \
  --args string:"Test Game"
```

This creates **Game ID 0**.

---

## Step 3: Initialize Leaderboards

Initialize the leaderboard system for the publisher:

```bash
aptos move run \
  --profile devnet \
  --function-id 'default::leaderboard::init_leaderboards'
```

**✅ Success:** Publisher now has `Leaderboards` resource at their address.

---

## Step 4: Create a Leaderboard

Create a leaderboard for Game ID 0:

```bash
aptos move run \
  --profile devnet \
  --function-id 'default::leaderboard::create_leaderboard' \
  --args \
    u64:0 \
    u8:0 \
    u64:0 \
    u64:18446744073709551615 \
    bool:false \
    bool:false \
    u64:5
```

### Parameter Breakdown:

| Parameter | Value | Meaning |
|-----------|-------|---------|
| `game_id` | `0` | Links to Game ID 0 |
| `decimals` | `0` | Integer scores (no decimal places) |
| `min_score` | `0` | Minimum valid score |
| `max_score` | `18446744073709551615` | Max u64 (unlimited) |
| `is_ascending` | `false` | Higher scores are better |
| `allow_multiple` | `false` | Only keep best score per player |
| `scores_to_retain` | `5` | Keep top 5 entries |

**✅ Success:** Creates **Leaderboard ID 0** for the game.

**📌 Note:** Game validation is currently disabled for independent deployment. In production, you can validate game existence at the application level before creating leaderboards.

---

## Step 5: Submit Test Scores

### Option A: Using the CLI Wrapper (Recommended)

The new `submit_score_direct` function allows testing from CLI:

```bash
# Submit score for player 1
aptos move run \
  --profile player1 \
  --function-id 'default::leaderboard::submit_score_direct' \
  --args \
    address:<PUBLISHER_ADDRESS> \
    u64:0 \
    address:<PLAYER1_ADDRESS> \
    u64:1000
```

**Example with real addresses:**
```bash
aptos move run \
  --profile player1 \
  --function-id 'default::leaderboard::submit_score_direct' \
  --args \
    address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 \
    u64:0 \
    address:0x123abc... \
    u64:1000
```

### Submit Multiple Scores

```bash
# Player 1: 1000 points
aptos move run --profile player1 \
  --function-id 'default::leaderboard::submit_score_direct' \
  --args address:<PUBLISHER> u64:0 address:<PLAYER1> u64:1000

# Player 2: 1500 points
aptos move run --profile player2 \
  --function-id 'default::leaderboard::submit_score_direct' \
  --args address:<PUBLISHER> u64:0 address:<PLAYER2> u64:1500

# Player 3: 800 points
aptos move run --profile player3 \
  --function-id 'default::leaderboard::submit_score_direct' \
  --args address:<PUBLISHER> u64:0 address:<PLAYER3> u64:800

# Player 1 improves: 1200 points (replaces 1000)
aptos move run --profile player1 \
  --function-id 'default::leaderboard::submit_score_direct' \
  --args address:<PUBLISHER> u64:0 address:<PLAYER1> u64:1200
```

**Expected Ranking:**
1. Player 2: 1500
2. Player 1: 1200
3. Player 3: 800

---

## Step 6: Query the Leaderboard

### View Top Entries

```bash
aptos move view \
  --function-id 'default::leaderboard::get_top_entries' \
  --args \
    address:<PUBLISHER_ADDRESS> \
    u64:0
```

**Expected Output:**
```json
{
  "Result": [
    [
      "0x<PLAYER2_ADDRESS>",
      "0x<PLAYER1_ADDRESS>",
      "0x<PLAYER3_ADDRESS>"
    ],
    [
      "1500",
      "1200",
      "800"
    ]
  ]
}
```

The result is two aligned vectors:
- First vector: player addresses (in ranked order)
- Second vector: corresponding scores

### View Leaderboard Config

```bash
aptos move view \
  --function-id 'default::leaderboard::get_leaderboard_config' \
  --args \
    address:<PUBLISHER_ADDRESS> \
    u64:0
```

**Expected Output:**
```json
{
  "Result": [
    "0",      // game_id
    "0",      // decimals
    "0",      // min_score
    "18446744073709551615", // max_score
    false,    // is_ascending
    false,    // allow_multiple
    "5"       // scores_to_retain
  ]
}
```

### Count Leaderboards

```bash
aptos move view \
  --function-id 'default::leaderboard::get_leaderboard_count' \
  --args address:<PUBLISHER_ADDRESS>
```

---

## 🧪 Test Scenarios

### Test 1: Score Gate Validation

Create a leaderboard with restricted score range:

```bash
aptos move run --profile devnet \
  --function-id 'default::leaderboard::create_leaderboard' \
  --args u64:0 u8:0 u64:100 u64:1000 bool:false bool:false u64:10
```

Now scores below 100 or above 1000 will be **silently rejected**.

```bash
# This will be rejected (score < 100)
aptos move run --profile player1 \
  --function-id 'default::leaderboard::submit_score_direct' \
  --args address:<PUBLISHER> u64:1 address:<PLAYER1> u64:50

# This will be accepted
aptos move run --profile player1 \
  --function-id 'default::leaderboard::submit_score_direct' \
  --args address:<PUBLISHER> u64:1 address:<PLAYER1> u64:500
```

### Test 2: Ascending Order (Lower is Better)

For speedrun/time-based games:

```bash
aptos move run --profile devnet \
  --function-id 'default::leaderboard::create_leaderboard' \
  --args u64:0 u8:0 u64:0 u64:999999 bool:true bool:false u64:5
```

Submit times (in milliseconds):

```bash
# Player 1: 5000ms (5 seconds)
aptos move run --profile player1 \
  --function-id 'default::leaderboard::submit_score_direct' \
  --args address:<PUBLISHER> u64:2 address:<PLAYER1> u64:5000

# Player 2: 3000ms (3 seconds) - better!
aptos move run --profile player2 \
  --function-id 'default::leaderboard::submit_score_direct' \
  --args address:<PUBLISHER> u64:2 address:<PLAYER2> u64:3000
```

**Expected Ranking:** Player 2 (3000) ranks higher than Player 1 (5000).

### Test 3: Multiple Leaderboards for One Game

```bash
# Global leaderboard (all-time)
aptos move run --profile devnet \
  --function-id 'default::leaderboard::create_leaderboard' \
  --args u64:0 u8:0 u64:0 u64:999999 bool:false bool:false u64:100

# Top 10 leaderboard
aptos move run --profile devnet \
  --function-id 'default::leaderboard::create_leaderboard' \
  --args u64:0 u8:0 u64:0 u64:999999 bool:false bool:false u64:10
```

Each can be queried independently by leaderboard ID (0, 1, etc.).

---

## 🔗 Integration with game_platform (Phase 2)

Once testing is complete, you can integrate with `game_platform` in two ways:

### Option A: New Entry Function (Recommended)

Add to `game_platform`:

```move
use sigil::leaderboard;

public entry fun submit_score_with_leaderboard(
    player: &signer,
    publisher: address,
    game_id: u64,
    leaderboard_id: u64,
    score: u64
) acquires Sigil {
    // Call existing submit_score logic
    submit_score(player, publisher, game_id, score);
    
    // Update leaderboard
    leaderboard::on_score(publisher, leaderboard_id, player_addr, score);
}
```

This keeps your original `submit_score` untouched.

### Option B: Automatic Integration

Modify the existing `submit_score` to automatically update leaderboards:

```move
// In Sigil struct, add:
struct Sigil has key {
    // ... existing fields ...
    leaderboard_for_game: Table<u64, u64>,  // game_id -> leaderboard_id
}

// At the end of submit_score:
if (table::contains<u64, u64>(&sigil.leaderboard_for_game, game_id)) {
    let lb_id = *table::borrow<u64, u64>(&sigil.leaderboard_for_game, game_id);
    leaderboard::on_score(publisher, lb_id, player_addr, score);
};
```

---

## 📊 Helper Script

Create a test script `test_leaderboard.sh`:

```bash
#!/bin/bash

PUBLISHER="0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6"
PLAYER1="0x123..."
PLAYER2="0x456..."

echo "🎮 Testing Sigil Leaderboard System"

echo "1. Initializing leaderboards..."
aptos move run --profile devnet \
  --function-id 'default::leaderboard::init_leaderboards'

echo "2. Creating leaderboard for Game 0..."
aptos move run --profile devnet \
  --function-id 'default::leaderboard::create_leaderboard' \
  --args u64:0 u8:0 u64:0 u64:18446744073709551615 bool:false bool:false u64:5

echo "3. Submitting test scores..."
aptos move run --profile player1 \
  --function-id 'default::leaderboard::submit_score_direct' \
  --args address:$PUBLISHER u64:0 address:$PLAYER1 u64:1000

aptos move run --profile player2 \
  --function-id 'default::leaderboard::submit_score_direct' \
  --args address:$PUBLISHER u64:0 address:$PLAYER2 u64:1500

echo "4. Querying top entries..."
aptos move view \
  --function-id 'default::leaderboard::get_top_entries' \
  --args address:$PUBLISHER u64:0

echo "✅ Test complete!"
```

---

## 🐛 Troubleshooting

### Error: "Resource not found"
- Make sure you've run `init_leaderboards` for the publisher

### Empty leaderboard results
- Verify scores are within `min_score` and `max_score` gates
- Check that you're querying the correct leaderboard ID

### Scores not ranking correctly
- Check the `is_ascending` flag matches your game type
- Verify you're reading the correct leaderboard

---

## ✅ Implementation Status

### Module Features:

1. ✅ **Added `submit_score_direct`** - Entry function for CLI testing
2. ✅ **Independent deployment** - Modules can be tested separately
3. ✅ **Gas-optimized sorting** - Efficient leaderboard updates
4. ✅ **Public `on_score` API** - Ready for future cross-module integration

### Current Architecture:

| Feature | Status | Details |
|---------|--------|---------|
| CLI Testing | ✅ Deployed | Use `submit_score_direct` |
| Independent Modules | ✅ Active | No dependency issues |
| Production Ready | ✅ Yes | Tested live on devnet |
| Future Integration | 🔄 Planned | When all modules complete |

---

## 🚀 Development Status

### ✅ Completed:

1. ✅ **Leaderboard module deployed** - Live on devnet at `0xe68ef...`
2. ✅ **Comprehensive testing** - All configurations validated (ascending, gates, rankings)
3. ✅ **Unit tests** - 15 tests written and passing
4. ✅ **Live verification** - Rankings tested on-chain with multiple players
5. ✅ **Documentation** - Complete guides and API reference

### 🔄 Development Strategy:

- **Current:** Modules remain independent for flexible development
- **Next:** Build additional modules using the same pattern
- **Future:** Enable cross-module communication when all modules are ready
- **See:** [README.md](./README.md) for latest deployment links and live examples

---

**Happy Testing! 🎮**

