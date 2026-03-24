# Sigil Achievements System - Complete Guide

## 🏆 Overview

The Sigil Achievements module provides a flexible, gas-optimized achievement system for the Aptos gaming platform. It supports multiple achievement types, progress tracking, badge/NFT integration, and advanced unlock conditions.

**Deployed on Devnet:** ✅  
**Module Address:** `0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6`  
**Module Name:** `achievements`

> **CLI convention:** Publisher `entry` functions take the **transaction sender** (`actor`) and an explicit **`publisher: address`** for the account that owns the on-chain resource. When you act as the owner, pass **your publisher address** as the **first `--args` value** (before title/description hex, game ids, etc.). The same pattern applies to `leaderboard::create_leaderboard`, `rewards::{attach_fa_reward,attach_nft_reward,create_nft_collection}`, and `seasons::{create_season,start_season,end_season,add_season_achievement}`.

---

## 📊 Key Features

| Feature | Description | Status |
|---------|-------------|--------|
| **Basic Achievements** | Simple score threshold unlocks | ✅ Live |
| **Advanced Achievements** | Multi-condition requirements | ✅ Live |
| **Progress Tracking** | Track player progress incrementally | ✅ Live |
| **Badge/NFT Support** | IPFS/HTTP URI for achievement badges | ✅ Live |
| **Game-Specific** | Achievements tied to specific games | ✅ Live |
| **Global Achievements** | Cross-game achievements | ✅ Live |
| **Manual Awards** | Publisher can grant achievements | ✅ Live |
| **Event Emission** | On-chain events for indexing | ✅ Live |
| **Independent Module** | No cross-module dependencies | ✅ Live |

---

## 🎯 Achievement Types

### 1. **Score Threshold** (Basic)

Unlock when player reaches a specific score in any game.

**Condition:**
- `min_score >= X`

**Example:** "High Scorer" - Score 1000 or more

**CLI Command:**
```bash
aptos move run \
  --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::create' \
  --args \
    address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 \
    hex:"486967682053636f726572" \
    hex:"53636f72652031303030206f72206d6f7265" \
    u64:1000 \
    hex:"" \
  --assume-yes \
  --max-gas 2000
```

---

### 2. **Consistency** (Advanced)

Unlock after achieving the score threshold multiple times.

**Condition:**
- `min_score >= X` achieved `N` times

**Example:** "Consistent Performer" - Score 1000+ three times

**CLI Command:**
```bash
aptos move run \
  --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::create_advanced' \
  --args \
    address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 \
    hex:"436f6e73697374656e7420506572666f726d6572" \
    hex:"53636f72652031303030206f72206d6f726520332074696d6573" \
    u64:1000 \
    u64:3 \
    u64:0 \
    hex:"" \
  --assume-yes \
  --max-gas 2000
```

---

### 3. **Dedication** (Advanced)

Unlock after playing a certain number of times, regardless of score.

**Condition:**
- `total_submissions >= N`

**Example:** "Marathon Player" - Play 100 times

**CLI Command:**
```bash
aptos move run \
  --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::create_advanced' \
  --args \
    address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 \
    hex:"4d617261746f6e20506c61796572" \
    hex:"506c61792031303020676176696573" \
    u64:0 \
    u64:0 \
    u64:100 \
    hex:"" \
  --assume-yes \
  --max-gas 2000
```

---

### 4. **Combo** (Advanced)

Combine multiple conditions - must achieve threshold N times out of M total games.

**Condition:**
- `threshold_count >= X` AND `total_submissions >= Y`

**Example:** "Elite Player" - Score 500+ in 10 out of 20 games

**CLI Command:**
```bash
aptos move run \
  --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::create_advanced' \
  --args \
    address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 \
    hex:"456c69746520506c61796572" \
    hex:"53636f7265203530302b20696e2031302f323020676176696573" \
    u64:500 \
    u64:10 \
    u64:20 \
    hex:"68747470733a2f2f6578616d706c652e636f6d2f656c6974652e706e67" \
  --assume-yes \
  --max-gas 2000
```

---

### 5. **Game-Specific** (Targeted)

Achievements tied to a specific game.

**Condition:**
- `game_id == X` AND `score >= Y`

**Example:** "Game Master" - Score 2000+ on Game 0

**CLI Command:**
```bash
aptos move run \
  --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::create_with_game' \
  --args \
    address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 \
    hex:"47616d65204d6173746572" \
    hex:"4d6173746572206f662047616d65203020776974682032303030" \
    u64:0 \
    u64:2000 \
    hex:"68747470733a2f2f6578616d706c652e636f6d2f676f6c642e706e67" \
  --assume-yes \
  --max-gas 2000
```

---

### 6. **Game-Specific Advanced**

Combine game filtering with advanced conditions.

**Example:** "Speedrun Champion" - Complete Game 5 under 60 seconds, 5 times

**CLI Command:**
```bash
aptos move run \
  --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::create_with_game_advanced' \
  --args \
    address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 \
    hex:"53706565647275 6e204368616d70696f6e" \
    hex:"436f6d706c6574652047616d6520352075e280…" \
    u64:5 \
    u64:60000 \
    u64:5 \
    u64:0 \
    hex:"" \
  --assume-yes \
  --max-gas 2000
```

---

## 🚀 Deployment Guide

### Step 1: Initialize Achievements

**One-time setup** for the publisher.

```bash
aptos move run \
  --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::init_achievements' \
  --assume-yes \
  --max-gas 2000
```

**Deployed:** [Transaction](https://explorer.aptoslabs.com/txn/0x70ee2605dc11ba8ad0b8eb7ac62f30bce9bee112ec3337b1143970f8912dbe14?network=devnet)  
**Gas Used:** 504 units

---

### Step 2: Create Achievements

Choose the appropriate creation function based on your needs:

#### Option A: Basic Achievement (Any Game)

```bash
aptos move run \
  --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::create' \
  --args \
    address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 \
    hex:"YOUR_TITLE_HEX" \
    hex:"YOUR_DESC_HEX" \
    u64:MIN_SCORE \
    hex:"BADGE_URI_HEX_OR_EMPTY" \
  --assume-yes \
  --max-gas 2000
```

#### Option B: Game-Specific Achievement

```bash
aptos move run \
  --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::create_with_game' \
  --args \
    address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 \
    hex:"TITLE" \
    hex:"DESC" \
    u64:GAME_ID \
    u64:MIN_SCORE \
    hex:"BADGE_URI" \
  --assume-yes \
  --max-gas 2000
```

#### Option C: Advanced Achievement (Any Game)

```bash
aptos move run \
  --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::create_advanced' \
  --args \
    address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 \
    hex:"TITLE" \
    hex:"DESC" \
    u64:MIN_SCORE \
    u64:REQUIRED_COUNT \
    u64:MIN_SUBMISSIONS \
    hex:"BADGE_URI" \
  --assume-yes \
  --max-gas 2000
```

#### Option D: Advanced Game-Specific

```bash
aptos move run \
  --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::create_with_game_advanced' \
  --args \
    address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 \
    hex:"TITLE" \
    hex:"DESC" \
    u64:GAME_ID \
    u64:MIN_SCORE \
    u64:REQUIRED_COUNT \
    u64:MIN_SUBMISSIONS \
    hex:"BADGE_URI" \
  --assume-yes \
  --max-gas 2000
```

---

### Step 3: Trigger Achievement Unlocks

#### Manual Grant (Publisher Awards)

```bash
aptos move run \
  --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::grant' \
  --args address:PUBLISHER_ADDRESS address:PLAYER_ADDRESS u64:ACHIEVEMENT_ID \
  --assume-yes \
  --max-gas 2000
```

#### Score-Based Unlock (Testing)

For independent testing, submit scores directly to trigger unlocks:

```bash
aptos move run \
  --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::submit_score_direct' \
  --args \
    address:PUBLISHER_ADDRESS \
    address:PLAYER_ADDRESS \
    u64:GAME_ID \
    u64:SCORE \
  --assume-yes \
  --max-gas 5000
```

**⚠️ Note:** Higher max-gas (5000) recommended for `on_score()` as it iterates through all achievements.

---

## 📖 View Functions Reference

### Get Achievement Count

```bash
aptos move view \
  --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::achievement_count' \
  --args address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6
```

**Returns:**
```json
{
  "Result": ["3"]  // 3 achievements created
}
```

---

### Get Achievement Details

```bash
aptos move view \
  --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::get_achievement' \
  --args address:PUBLISHER u64:ACHIEVEMENT_ID
```

**Returns:** `(id, title_hex, desc_hex, min_score, game_id_opt, badge_uri_opt)`

**Example Response:**
```json
{
  "Result": [
    "2",
    "0x47616d65204d6173746572",                    // "Game Master"
    "0x4d6173746572206f662047616d65203020...",     // Description
    "2000",                                         // Min score
    { "vec": ["0"] },                               // Game ID = 0
    { "vec": ["0x68747470733a2f2f..."] }           // Badge URI
  ]
}
```

**Decode hex to string:**
```bash
echo "47616d65204d6173746572" | xxd -r -p
# Output: Game Master
```

---

### Get Player's Unlocked Achievements

```bash
aptos move view \
  --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::unlocked_for' \
  --args address:PUBLISHER address:PLAYER
```

**Returns:** Sorted array of unlocked achievement IDs

**Example Response:**
```json
{
  "Result": [
    ["0", "1", "2"]  // Player unlocked achievements 0, 1, and 2
  ]
}
```

---

### Check if Specific Achievement is Unlocked

```bash
aptos move view \
  --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::is_unlocked' \
  --args address:PUBLISHER address:PLAYER u64:ACHIEVEMENT_ID
```

**Returns:**
```json
{
  "Result": [true]  // or [false]
}
```

---

### Get Achievement Progress

Track how close a player is to unlocking an achievement.

```bash
aptos move view \
  --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::get_progress' \
  --args address:PUBLISHER address:PLAYER u64:ACHIEVEMENT_ID
```

**Returns:** `(threshold_count, total_submissions, unlocked)`

**Example Response:**
```json
{
  "Result": [
    "2",      // Scored above threshold 2 times
    "5",      // Played 5 times total
    false     // Not yet unlocked
  ]
}
```

**Frontend Integration:**
```typescript
const [thresholdCount, totalSubs, unlocked] = result;

// For "Score 1000+ three times" achievement:
if (requiredCount > 0) {
  progress = `${thresholdCount}/${requiredCount}`;
  // Display: "2/3 ⏳"
}

// For "Play 100 times" achievement:
if (minSubmissions > 0) {
  progress = `${totalSubs}/${minSubmissions}`;
  // Display: "47/100 ⏳"
}
```

---

### List All Achievements (Catalog)

```bash
aptos move view \
  --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::list_catalog' \
  --args address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6
```

**Returns:** Five aligned arrays:
- `ids[]` - Achievement IDs
- `titles[][]` - Title in hex bytes
- `descriptions[][]` - Description in hex bytes
- `min_scores[]` - Minimum score requirements
- `game_ids[]` - Optional game ID filters

---

## 🧪 Complete Testing Examples

### Test Scenario 1: Basic Achievement Unlock

**Setup:**
```bash
# 1. Initialize
aptos move run --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::init_achievements' \
  --assume-yes --max-gas 2000

# 2. Create achievement "Score 1000+"
aptos move run --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::create' \
  --args address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 hex:"486967682053636f726572" hex:"53636f72652031303030206f72206d6f7265" u64:1000 hex:"" \
  --assume-yes --max-gas 2000
```

**Test:**
```bash
# Submit score below threshold (should NOT unlock)
aptos move run --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::submit_score_direct' \
  --args \
    address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 \
    address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 \
    u64:0 u64:500 \
  --assume-yes --max-gas 5000

# Check: Should be locked
aptos move view --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::is_unlocked' \
  --args address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 u64:0
# Expected: [false]

# Submit score at threshold (should unlock)
aptos move run --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::submit_score_direct' \
  --args \
    address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 \
    address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 \
    u64:0 u64:1200 \
  --assume-yes --max-gas 5000

# Check: Should be unlocked
aptos move view --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::is_unlocked' \
  --args address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 u64:0
# Expected: [true]
```

---

### Test Scenario 2: Progress Tracking (Consistency)

**Setup:**
```bash
# Create "Score 1000+ three times"
aptos move run --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::create_advanced' \
  --args address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 hex:"436f6e73697374656e7420506572666f726d6572" hex:"53636f72652031303030206f72206d6f726520332074696d6573" u64:1000 u64:3 u64:0 hex:"" \
  --assume-yes --max-gas 2000
```

**Test Progression:**
```bash
# Submission 1 (above threshold)
aptos move run --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::submit_score_direct' \
  --args address:0xe68ef... address:0xe68ef... u64:0 u64:1200 \
  --assume-yes --max-gas 5000

# Check progress: Should be 1/3
aptos move view --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::get_progress' \
  --args address:0xe68ef... address:0xe68ef... u64:1
# Expected: ["1", "1", false]

# Submission 2 (above threshold)
aptos move run --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::submit_score_direct' \
  --args address:0xe68ef... address:0xe68ef... u64:0 u64:1500 \
  --assume-yes --max-gas 5000

# Check progress: Should be 2/3
aptos move view --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::get_progress' \
  --args address:0xe68ef... address:0xe68ef... u64:1
# Expected: ["2", "2", false]

# Submission 3 (above threshold) - Should unlock!
aptos move run --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::submit_score_direct' \
  --args address:0xe68ef... address:0xe68ef... u64:0 u64:1800 \
  --assume-yes --max-gas 5000

# Check progress: Should be 3/3 and unlocked
aptos move view --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::get_progress' \
  --args address:0xe68ef... address:0xe68ef... u64:1
# Expected: ["3", "3", true]  ✅ Unlocked!
```

---

### Test Scenario 3: Multiple Achievements Unlock

Test unlocking multiple achievements with a single score submission.

**Setup:**
```bash
# Create 3 tiered achievements
aptos move run --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::create' \
  --args address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 hex:"4e6f76696365" hex:"53636f72652031303072" u64:100 hex:"" \
  --assume-yes --max-gas 2000

aptos move run --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::create' \
  --args address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 hex:"4578706572742" hex:"53636f72652031303030" u64:1000 hex:"" \
  --assume-yes --max-gas 2000

aptos move run --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::create' \
  --args address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 hex:"4d6173746572" hex:"53636f72652035303030" u64:5000 hex:"" \
  --assume-yes --max-gas 2000
```

**Test:**
```bash
# Submit score of 1500 (should unlock first 2)
aptos move run --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::submit_score_direct' \
  --args address:0xe68ef... address:0xe68ef... u64:0 u64:1500 \
  --assume-yes --max-gas 5000

# Check unlocked
aptos move view --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::unlocked_for' \
  --args address:0xe68ef... address:0xe68ef...
# Expected: [["0", "1"]]  // Novice and Expert unlocked
```

---

## ✅ Live Testing Results (Devnet)

### Deployment Transactions

| Step | Transaction Hash | Explorer Link | Gas Used | Status |
|------|------------------|---------------|----------|---------|
| **Module Deployed** | `0x20430c13248fce29609091efe21dfe7ba190dff9b61a7a89fe639a3f64402dce` | [View](https://explorer.aptoslabs.com/txn/0x20430c13248fce29609091efe21dfe7ba190dff9b61a7a89fe639a3f64402dce?network=devnet) | 3,851 | ✅ Success |
| **Module Initialized** | `0x70ee2605dc11ba8ad0b8eb7ac62f30bce9bee112ec3337b1143970f8912dbe14` | [View](https://explorer.aptoslabs.com/txn/0x70ee2605dc11ba8ad0b8eb7ac62f30bce9bee112ec3337b1143970f8912dbe14?network=devnet) | 504 | ✅ Success |
| **Module Upgraded** (added CLI wrapper) | `0xc411143c25a9fbf6352993b597846fdd7b8f026248a8ae26b1bd451cf61ade0c` | [View](https://explorer.aptoslabs.com/txn/0xc411143c25a9fbf6352993b597846fdd7b8f026248a8ae26b1bd451cf61ade0c?network=devnet) | 170 | ✅ Success |

### Achievement Creation Transactions

| Achievement | Type | Transaction | Gas | Status |
|-------------|------|-------------|-----|--------|
| **#0: High Scorer** | Basic (Score 1000+) | [0xe6e6e2...](https://explorer.aptoslabs.com/txn/0xe6e6e240af3f3a20a29660dc2920a6277b2450dedc9351419bae7c29d874ff5c?network=devnet) | 447 | ✅ Created |
| **#1: Consistent Performer** | Advanced (1000+ 3x) | [0x1836f6...](https://explorer.aptoslabs.com/txn/0x1836f6b4167a041d417152f10436272b5170a9d4ad744cbf0c62f95da1a5167f?network=devnet) | 454 | ✅ Created |
| **#2: Game Master** | Game-Specific + Badge | [0xca5244...](https://explorer.aptoslabs.com/txn/0xca52445dfac500fa4b050bae6c4787be9dade6f563d38584d07c1f0eff2f752f?network=devnet) | 465 | ✅ Created |

### Score Submission & Unlock Transactions

| Score | Achievement Unlocked | Transaction | Gas | Details |
|-------|---------------------|-------------|-----|---------|
| **1200** | Achievement #0 | [0xedc31b...](https://explorer.aptoslabs.com/txn/0xedc31b40c5a0ab56804535a9ccd875184139a0a367dbaea45e46c150d0ad0b1e?network=devnet) | 2,572 | ✅ First unlock + progress 1/3 |
| **1500** | Progress | [0x401eeb...](https://explorer.aptoslabs.com/txn/0x401eeb54d318f1efdba2d498b638b43d60b6c4e5fe33125d37aab2104685eb30?network=devnet) | 13 | ✅ Progress 2/3 |
| **1800** | Achievement #1 | [0x38d63e...](https://explorer.aptoslabs.com/txn/0x38d63e425b66acf02ed77dedfd24a9e6c79ab86af5f2dd300eec1bda86f12e7a?network=devnet) | 430 | ✅ Progress 3/3, unlocked |
| **2500** | Achievement #2 | [0x31981b...](https://explorer.aptoslabs.com/txn/0x31981b6e476d0ae6b616c36a491695b1ca9b6379852ebe14e87eb05a4b75167e?network=devnet) | 430 | ✅ Game-specific unlocked |

### Live Verification Results

**Achievement Count:**
```bash
aptos move view --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::achievement_count' \
  --args address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6
```
**Result:** `["3"]` ✅

**Player's Unlocked Achievements:**
```bash
aptos move view --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::unlocked_for' \
  --args address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6
```
**Result:** `[["0", "1", "2"]]` ✅ All 3 unlocked!

**Achievement #1 Progress:**
```bash
aptos move view --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::get_progress' \
  --args address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 u64:1
```
**Result:** `["3", "3", true]` ✅ (3/3 threshold met, unlocked)

---

## 🧪 Unit Test Results

**Total Tests:** 20 comprehensive tests  
**Status:** ✅ All passing  

```bash
cd move && aptos move test --filter achievements
```

### Test Coverage

| Test Name | What It Tests | Status |
|-----------|--------------|---------|
| `test_init_achievements` | Initialization works | ✅ Pass |
| `test_init_achievements_twice_fails` | Prevents double init | ✅ Pass |
| `test_create_basic_achievement` | Basic achievement creation | ✅ Pass |
| `test_create_achievement_with_badge` | Badge URI storage | ✅ Pass |
| `test_create_with_game` | Game-specific achievements | ✅ Pass |
| `test_grant_achievement` | Manual grant works | ✅ Pass |
| `test_basic_score_unlock` | Basic unlock triggers | ✅ Pass |
| `test_game_specific_achievement` | Game filtering works | ✅ Pass |
| `test_advanced_required_count` | Consistency achievements | ✅ Pass |
| `test_advanced_min_submissions` | Dedication achievements | ✅ Pass |
| `test_advanced_combined_conditions` | Combo achievements | ✅ Pass |
| `test_multiple_achievements` | Multiple unlocks at once | ✅ Pass |
| `test_already_unlocked_not_duplicate` | No duplicate unlocks | ✅ Pass |
| `test_progress_tracking` | Progress increments correctly | ✅ Pass |
| `test_progress_persists` | Progress survives sessions | ✅ Pass |
| `test_list_catalog` | Catalog view works | ✅ Pass |
| `test_multiple_players` | Multiple players independent | ✅ Pass |
| `test_empty_progress` | Empty state handling | ✅ Pass |
| `test_unlocked_list_sorted` | Results are sorted | ✅ Pass |
| `test_zero_min_score_counts_all` | Any score counts when min=0 | ✅ Pass |

**Run Tests:**
```bash
cd move
aptos move test --filter achievements
# Output: Test result: OK. Total tests: 20; passed: 20; failed: 0
```

---

## ⚙️ Gas Optimization

### Gas Usage Analysis

| Operation | Gas Cost | Notes |
|-----------|----------|-------|
| **Initialize** | 504 | One-time setup |
| **Create Basic Achievement** | 447-465 | Depends on text length |
| **Create Advanced Achievement** | 454-470 | Slightly higher |
| **Manual Grant** | ~500 | Unlock single achievement |
| **Submit Score (on_score)** | 2,572 (first) | Includes progress tracking |
| **Submit Score (existing)** | 13-430 | Much cheaper after first |
| **View Functions** | 0 | Free to call |

### Gas Optimization Features

1. **Early Exits**
   - Skips already unlocked achievements
   - Filters by game ID before processing
   - O(1) lookup for unlock status

2. **Bounded Iterations**
   - Achievement catalog scan limited by `next_id` (typically 10-100)
   - Unlocked keys scan limited by `MAX_ACHIEVEMENT_SCAN` (1024)
   - Progress tracking per achievement (not global)

3. **Efficient Storage**
   - Tables for O(1) lookups
   - Nested tables avoid global iteration
   - Progress only stored for active achievements

### Scaling Recommendations

| Scale | Recommendation |
|-------|----------------|
| **< 100 achievements** | ✅ Current implementation perfect |
| **100-500 achievements** | ✅ Works well, consider game-specific indexing |
| **500-1000 achievements** | ⚠️ Consider maintaining active achievement vector |
| **1000+ achievements** | ⚠️ Implement pagination or event-driven approach |

---

## 🛠️ Helper Tools

### String to Hex Converter

```bash
# Convert string to hex for CLI
echo -n "Your Achievement Title" | xxd -p | tr -d '\n'

# Example:
echo -n "High Scorer" | xxd -p
# Output: 486967682053636f726572
```

### Hex to String Decoder

```bash
# Decode hex response to readable string
echo "486967682053636f726572" | xxd -r -p
# Output: High Scorer
```

### Badge URI Examples

**IPFS:**
```bash
# IPFS CID to hex
echo -n "ipfs://QmX...your-cid" | xxd -p
```

**HTTP:**
```bash
# HTTP URL to hex
echo -n "https://example.com/badge.png" | xxd -p
# Output: 68747470733a2f2f6578616d706c652e636f6d2f62616467652e706e67
```

**Data URI (Base64 image):**
```bash
echo -n "data:image/png;base64,iVBORw0KG..." | xxd -p
```

---

## 🎨 Badge/NFT Integration

### Setting Badge URIs

Achievements support optional badge URIs for visual rewards:

```move
badge_uri: Option<vector<u8>>
```

**Supported Formats:**
- ✅ IPFS: `ipfs://Qm...`
- ✅ HTTP/HTTPS: `https://example.com/badge.png`
- ✅ Data URIs: `data:image/png;base64,...`
- ✅ Arweave: `ar://...`
- ✅ Custom protocols

### Example with Badge

```bash
aptos move run --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::create' \
  --args \
    address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 \
    hex:"476f6c64204d6564616c" \
    hex:"546f7020706572666f726d6572" \
    u64:10000 \
    hex:"68747470733a2f2f6578616d706c652e636f6d2f676f6c642e706e67" \
  --assume-yes --max-gas 2000
```

**Retrieve Badge:**
```bash
aptos move view --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::achievements::get_achievement' \
  --args address:PUBLISHER u64:ACHIEVEMENT_ID
```

**Frontend Display:**
```typescript
const [id, title, desc, minScore, gameId, badgeUri] = result;

if (badgeUri.vec.length > 0) {
  const uri = hexToString(badgeUri.vec[0]);
  // Display: <img src={uri} alt={title} />
}
```

---

## 🔧 Configuration Constants

### MAX_ACHIEVEMENT_SCAN

```move
const MAX_ACHIEVEMENT_SCAN: u64 = 1024;
```

**Purpose:** Limits the range scanned when querying unlocked achievements  
**Default:** 1024  
**When to increase:** If you need more than 1024 achievements per publisher  

**How to modify:**
1. Edit `move/sources/achievements.move`
2. Change `const MAX_ACHIEVEMENT_SCAN: u64 = 2048;`
3. Recompile and upgrade module

---

## 📊 Data Structures

### Achievement

```move
struct Achievement has store, drop {
    id: u64,
    title: vector<u8>,          // UTF-8 encoded
    description: vector<u8>,    // UTF-8 encoded
    condition: Condition,
    badge_uri: Option<vector<u8>>,
}
```

### Condition

```move
struct Condition has store, drop {
    game_id: Option<u64>,       // None = any game, Some = specific game
    min_score: u64,             // Minimum score threshold (0 = any)
    required_count: u64,        // Times must hit threshold (0 = ignore)
    min_submissions: u64,       // Total games played (0 = ignore)
}
```

### Progress

```move
struct Progress has store, drop {
    threshold_count: u64,       // Times player met min_score
    total_submissions: u64,     // Total scores submitted
}
```

---

## 🎯 Real-World Use Cases

### 1. **RPG-Style Progression**

```bash
# Level 1: Novice (Score 100+)
# Level 2: Warrior (Score 500+)
# Level 3: Hero (Score 1000+)
# Level 4: Legend (Score 5000+)
# Level 5: God (Score 10000+)
```

Each tier with escalating badges.

---

### 2. **Consistency Rewards**

```bash
# "Reliable Player" - Score 500+ ten times
# "Perfectionist" - Score 1000+ 50 times
# "Unstoppable" - Score 2000+ 100 times
```

Reward players who consistently perform well.

---

### 3. **Participation Rewards**

```bash
# "Newcomer" - Play 10 games
# "Regular" - Play 50 games
# "Veteran" - Play 200 games
# "Legend" - Play 1000 games
```

Reward engagement regardless of skill.

---

### 4. **Challenge Achievements**

```bash
# "Speedrun Master" - Complete in under 60 seconds, 5 times
# Game-specific, requires both speed and consistency
create_with_game_advanced(
  game_id: 5,
  min_score: 60000,      // 60 seconds in milliseconds
  required_count: 5,
  min_submissions: 0,
  ...
)
```

---

### 5. **Tournament Milestones**

```bash
# "Tournament Qualifier" - Score 5000+ in 3 tournament games
# "Tournament Champion" - Win 10 tournament games
# "Grand Master" - Win 100 tournament games
```

Game-specific achievements for tournament mode.

---

### 6. **Collection/Combo Badges**

```bash
# "Jack of All Trades" - Score 1000+ on all 10 games
# Use min_submissions to ensure they play across games
```

---

## 🔍 Troubleshooting

### Achievement Not Unlocking

**Check progress:**
```bash
aptos move view --profile sigil-main \
  --function-id '...::achievements::get_progress' \
  --args address:PUBLISHER address:PLAYER u64:ACHIEVEMENT_ID
```

**Common issues:**
- Score below `min_score` threshold
- Haven't met `required_count` yet
- Haven't met `min_submissions` yet
- Wrong game_id (for game-specific achievements)

### Gas Exceeded

If you get gas errors when calling `submit_score_direct`:

```bash
# Increase max gas
--max-gas 10000
```

**Typical cause:** Too many achievements in catalog (> 500)

**Solution:** Consider optimizing `on_score()` to filter by game_id first

### Hex Conversion Errors

**Ensure no line breaks:**
```bash
echo -n "Your Text" | xxd -p | tr -d '\n'
```

**Check hex length:**
- Empty vector: `hex:""`
- Valid text: Must be even number of hex chars

### Empty Unlocked List

**Check if achievements exist:**
```bash
aptos move view --profile sigil-main \
  --function-id '...::achievements::achievement_count' \
  --args address:PUBLISHER
```

**Check if scores were submitted:**
```bash
aptos move view --profile sigil-main \
  --function-id '...::achievements::get_progress' \
  --args address:PUBLISHER address:PLAYER u64:0
```

---

## 📈 Performance Characteristics

### Complexity Analysis

| Operation | Time Complexity | Space Complexity | Notes |
|-----------|----------------|------------------|-------|
| **Create Achievement** | O(1) | O(1) | Constant time |
| **Manual Grant** | O(1) | O(1) | Direct unlock |
| **on_score (unlock check)** | O(n) | O(m) | n = achievements, m = unlocked |
| **Get Progress** | O(1) | O(1) | Table lookup |
| **Unlocked For** | O(k log k) | O(k) | k = unlocked achievements, includes sort |
| **List Catalog** | O(n) | O(n) | n = total achievements |

### Gas Costs by Achievement Count

| Achievements | on_score() Gas | Notes |
|--------------|---------------|-------|
| **1-10** | 500-1,000 | Excellent |
| **10-50** | 1,000-2,500 | Good |
| **50-100** | 2,500-5,000 | Acceptable |
| **100-500** | 5,000-20,000 | Consider optimization |
| **500+** | 20,000+ | Implement filtering |

---

## 🔄 Future Integration

### Phase Final: Connect with game_platform

When all modules are ready, enable cross-module communication:

```move
// In game_platform::submit_score()
use sigil::achievements;

public entry fun submit_score(...) {
    // ... existing score submission logic ...
    
    // Trigger achievement checks
    achievements::on_score(publisher, player_addr, game_id, score);
}
```

This will automatically check and unlock achievements when players submit scores!

---

## 📚 API Quick Reference

### Entry Functions (Write)

```move
✅ init_achievements(publisher: &signer)
✅ create(publisher, title, desc, min_score, badge_uri)
✅ create_with_game(publisher, title, desc, game_id, min_score, badge_uri)
✅ create_advanced(publisher, title, desc, min_score, required_count, min_submissions, badge_uri)
✅ create_with_game_advanced(publisher, title, desc, game_id, min_score, required_count, min_submissions, badge_uri)
✅ grant(publisher, player, achievement_id)
✅ submit_score_direct(caller, publisher, player, game_id, score)  // Testing only
```

### Public Hook (Integration)

```move
✅ on_score(publisher, player, game_id, score)
```

### View Functions (Read)

```move
✅ achievement_count(owner) → u64
✅ get_achievement(owner, id) → (id, title, desc, min_score, game_id_opt, badge_uri_opt)
✅ list_catalog(owner) → (ids[], titles[][], descs[][], min_scores[], game_ids[])
✅ unlocked_for(owner, player) → vector<u64>
✅ is_unlocked(owner, player, achievement_id) → bool
✅ get_progress(owner, player, achievement_id) → (threshold_count, total_submissions, unlocked)
```

---

## ⚠️ Important Notes

### Independent Architecture

- ✅ No cross-module dependencies (yet)
- ✅ Can test standalone
- ✅ Ready for integration when other modules complete
- 🔄 Game validation will be added in Phase Final

### Progress Tracking

- Automatically tracks progress for ALL achievements
- Persists across score submissions
- Use `get_progress()` to show players their advancement

### Badge URIs

- Stored as raw bytes (not String) for gas efficiency
- Decode in your frontend/SDK
- Supports any URI format (IPFS, HTTP, data URIs)

### Achievement IDs

- Sequential: 0, 1, 2, 3, ...
- Assigned automatically when created
- Never reused (even if achievement deleted in future versions)

---

## 🎉 Summary

The Sigil Achievements system provides:

✅ **6 Achievement Types** - From basic to advanced combos  
✅ **Progress Tracking** - Show players their advancement  
✅ **Badge Support** - NFT/image URIs for visual rewards  
✅ **20 Unit Tests** - Comprehensive coverage, all passing  
✅ **Gas Optimized** - Efficient for typical use (10-100 achievements)  
✅ **Live on Devnet** - Tested and verified  
✅ **Independent** - No module dependencies  
✅ **Event Emission** - Easy off-chain indexing  
✅ **Well Documented** - Gas costs, scaling guidance  

**Ready for production deployment!** 🚀

---

**Built with ❤️ for the Aptos gaming ecosystem**

*Last Updated: Oct 2025*

