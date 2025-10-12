# Verifying Rewards on Aptos Explorer

Quick guide for checking rewards state on-chain via the Aptos Explorer.

---

## 🔍 What You Can See Now (Current Implementation)

### ✅ Claim Transactions

**Example NFT Claim:**
https://explorer.aptoslabs.com/txn/0x7be610e9b2b32947290ae038c9b4f85707e493d87068d20b636aa9cd98c9b362?network=devnet

**What to look for:**
1. **Status:** Success ✅
2. **Events Tab:** Look for `RewardClaimedEvent`
3. **Changes Tab:** See resource updates to `Rewards` struct
4. **Gas Used:** 424 units (for this NFT claim)

---

### ✅ View Functions (Read State)

All view functions are **free** to call (no gas):

#### 1. Check if Player Claimed a Reward

```bash
aptos move view --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::rewards::is_claimed' \
  --args \
    address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 \
    address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 \
    u64:1
```

**Returns:**
```json
{
  "Result": [true]
}
```
- `true` = Claimed
- `false` = Not claimed yet

---

#### 2. Get Reward Details

```bash
aptos move view --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::rewards::get_reward' \
  --args \
    address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 \
    u64:0
```

**Returns (for FA reward #0):**
```json
{
  "Result": [
    true,           // exists
    true,           // is_ft (true = FA, false = NFT)
    "100000000",    // amount (1 APT in octas)
    "1",            // claimed_count
    "10"            // total_supply
  ]
}
```

**Returns (for NFT reward #1):**
```json
{
  "Result": [
    true,    // exists
    false,   // is_ft (false = NFT)
    "0",     // not used for NFT
    "1",     // claimed_count
    "100"    // total_supply
  ]
}
```

---

#### 3. Get NFT Metadata

```bash
aptos move view --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::rewards::get_reward_details' \
  --args \
    address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 \
    u64:1
```

**Returns:**
```json
{
  "Result": [
    true,     // exists
    false,    // is_ft (false = NFT)
    "0",      // amount (not used)
    "0x436f6e73697374656e7420506572666f726d6572204261646765",  // nft_name (hex)
    "100",    // total_supply
    "1"       // claimed_count
  ]
}
```

**Decode the hex name:**
```bash
echo "436f6e73697374656e7420506572666f726d6572204261646765" | xxd -r -p
# Output: "Consistent Performer Badge"
```

---

#### 4. Check Available Supply

```bash
aptos move view --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::rewards::get_available' \
  --args \
    address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 \
    u64:0
```

**Returns:**
```json
{
  "Result": [
    true,   // has_supply
    "9"     // available (was 10, now 9 after 1 claim)
  ]
}
```

**Verification:** Supply correctly decreased! ✅

---

#### 5. Get All Player's Claims

```bash
aptos move view --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::rewards::get_claimed_rewards' \
  --args \
    address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 \
    address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6
```

**Returns:**
```json
{
  "Result": [
    ["0", "1"]
  ]
}
```
- Player claimed achievement #0 reward (1 APT)
- Player claimed achievement #1 reward (NFT badge)

---

#### 6. List All Rewarded Achievements

```bash
aptos move view --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::rewards::list_rewarded_achievements' \
  --args \
    address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6
```

**Returns:**
```json
{
  "Result": [
    ["0", "1"]
  ]
}
```
- Achievement #0 has a reward attached (FA)
- Achievement #1 has a reward attached (NFT)

---

## ❌ What You CANNOT See Yet

### No Actual Asset Transfer/Minting

**Looking for NFT in player's wallet?**
❌ Won't find it - not minted yet (bookkeeping only)

**Looking for FA balance increase?**
❌ Won't see it - not transferred yet (requires treasury)

**Looking for NFT asset ID on explorer?**
❌ Doesn't exist - NFT not created on-chain

**Why?**
- Current implementation is **bookkeeping only**
- Actual transfers/minting require Phase Final integration
- See [REWARDS_GUIDE.md](./REWARDS_GUIDE.md#%EF%B8%8F-bookkeeping-only-requires-phase-final) for details

---

## 🎯 Explorer Deep Dive: Claim Transaction

### Example: NFT Claim Transaction

**Link:** https://explorer.aptoslabs.com/txn/0x7be610e9b2b32947290ae038c9b4f85707e493d87068d20b636aa9cd98c9b362?network=devnet

### What Each Tab Shows:

#### 1. **Overview Tab**
- **Status:** Success ✅
- **Gas Used:** 424 units
- **Function:** `0xe68ef...::rewards::claim_testing`
- **Sender:** Publisher address

#### 2. **Events Tab**
Look for `RewardClaimedEvent`:
```json
{
  "publisher": "0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6",
  "player": "0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6",
  "achievement_id": "1",
  "is_ft": false
}
```
- `is_ft: false` = NFT reward
- `achievement_id: 1` = Consistent Performer achievement

#### 3. **Changes Tab**
Shows resource mutations:
```
0xe68ef...::rewards::Rewards
  ├─ claimed: Table (new entry added)
  └─ by_achievement[1].claimed_count: 0 → 1
```

**This proves:**
- ✅ Claim was recorded
- ✅ State updated correctly
- ✅ Supply decremented

---

## 🔐 Verify Security Features

### 1. Double-Claim Prevention

**Try claiming again:**
```bash
aptos move run --profile sigil-main \
  --function-id '0xe68ef...::rewards::claim_testing' \
  --args address:0xe68ef... u64:0 --assume-yes
```

**Result:** ❌ **E_ALREADY_CLAIMED(0x4)**

**Proof:** https://explorer.aptoslabs.com/txn/0xdf78bc2600f9a9237c83a7eb6f9e76ee35af0ccbdf29ccee1a3eb7bceec5eecd?network=devnet

On explorer:
- **Status:** Failed (as expected)
- **Error:** `Move abort in 0xe68ef...::rewards: E_ALREADY_CLAIMED(0x4)`
- **Gas Used:** Still charged (validation ran before abort)

---

### 2. Supply Tracking

**Before claim:**
```bash
get_available(... u64:0)
# Result: [true, "10"]
```

**After claim:**
```bash
get_available(... u64:0)
# Result: [true, "9"]
```

**Verified:** Supply decrements atomically ✅

---

## 📊 Complete Verification Checklist

Use this to verify your own rewards:

### Setup Phase
- [ ] Rewards module deployed
- [ ] Rewards initialized (`init_rewards`)
- [ ] FA reward attached (check `get_reward`)
- [ ] NFT reward attached (check `get_reward_details`)

### Claim Phase
- [ ] Player claims FA reward (transaction success)
- [ ] `is_claimed` returns `true`
- [ ] FA supply decreased (`10 → 9`)
- [ ] `RewardClaimedEvent` emitted with `is_ft: true`

- [ ] Player claims NFT reward (transaction success)
- [ ] `is_claimed` returns `true`
- [ ] NFT supply decreased (`100 → 99`)
- [ ] `RewardClaimedEvent` emitted with `is_ft: false`

### Security Phase
- [ ] Double-claim blocked (E_ALREADY_CLAIMED)
- [ ] `get_claimed_rewards` shows both claims
- [ ] Supply accurately tracked for both

---

## 🛠️ Quick Reference: All View Functions

```bash
# Publisher address (replace with yours)
PUB="0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6"

# 1. Get reward (achievement_id: 0)
aptos move view --profile sigil-main \
  --function-id "$PUB::rewards::get_reward" \
  --args address:$PUB u64:0

# 2. Get reward details with NFT metadata (achievement_id: 1)
aptos move view --profile sigil-main \
  --function-id "$PUB::rewards::get_reward_details" \
  --args address:$PUB u64:1

# 3. Check if player claimed (publisher, player, achievement_id)
aptos move view --profile sigil-main \
  --function-id "$PUB::rewards::is_claimed" \
  --args address:$PUB address:$PUB u64:0

# 4. Get available supply (achievement_id: 0)
aptos move view --profile sigil-main \
  --function-id "$PUB::rewards::get_available" \
  --args address:$PUB u64:0

# 5. List all claimed by player
aptos move view --profile sigil-main \
  --function-id "$PUB::rewards::get_claimed_rewards" \
  --args address:$PUB address:$PUB

# 6. List all rewarded achievements
aptos move view --profile sigil-main \
  --function-id "$PUB::rewards::list_rewarded_achievements" \
  --args address:$PUB

# 7. Count total rewarded achievements
aptos move view --profile sigil-main \
  --function-id "$PUB::rewards::count_rewarded_achievements" \
  --args address:$PUB
```

---

## 💡 Pro Tips

### 1. Decode Hex Strings
NFT names/descriptions are returned as hex:
```bash
# Method 1: xxd
echo "HEX_STRING" | xxd -r -p

# Method 2: Python
python3 -c "print(bytes.fromhex('HEX_STRING').decode())"

# Method 3: Online tool
https://www.rapidtables.com/convert/number/hex-to-ascii.html
```

### 2. Monitor Events
Listen to `RewardClaimedEvent` for real-time claims:
```typescript
const events = await client.getEventsByEventHandle(
  publisherAddress,
  `${publisherAddress}::rewards::Rewards`,
  "claimed"
);

events.forEach(event => {
  console.log(`Player ${event.data.player} claimed achievement ${event.data.achievement_id}`);
  console.log(`Type: ${event.data.is_ft ? "FA" : "NFT"}`);
});
```

### 3. Track Supply in Real-Time
```typescript
async function getRemainingSupply(achievementId: number) {
  const result = await client.view({
    function: `${publisher}::rewards::get_available`,
    type_arguments: [],
    arguments: [publisher, achievementId.toString()]
  });
  
  return {
    hasSupply: result[0],
    available: parseInt(result[1])
  };
}

// Poll every 5 seconds
setInterval(async () => {
  const supply = await getRemainingSupply(0);
  console.log(`Reward #0: ${supply.available} remaining`);
}, 5000);
```

---

## 🔗 Live Examples (Devnet)

### Deployment Transactions
- **Rewards Module:** [0x4bc161...](https://explorer.aptoslabs.com/txn/0x4bc16150bb80e5c28fe9a773ffe4c4963395b40475074212877a564c529b5ff1?network=devnet)
- **Initialize:** [0x7440d5...](https://explorer.aptoslabs.com/txn/0x7440d558e4a1117465491444f9818f00fbb9bae5d94ee564fb1bb960c66a5719?network=devnet)

### Reward Configuration
- **Attach FA (1 APT):** [0x3d7002...](https://explorer.aptoslabs.com/txn/0x3d700292cca8b276a46fa4980c8d066cc85669e7f7d0e9504f3641b5aad4f5eb?network=devnet)
- **Attach NFT (Badge):** [0x5adf02...](https://explorer.aptoslabs.com/txn/0x5adf027c42ba5d3d13082450500d6f0e3f38ee88d9e598428fea378874a5dd67?network=devnet)

### Claims
- **Claim FA:** [0xa2f60e...](https://explorer.aptoslabs.com/txn/0xa2f60e1b90709a791d3fa2708a9849243a08fc5912c8e0062dc6491a4ce1f89e?network=devnet)
- **Claim NFT:** [0x7be610...](https://explorer.aptoslabs.com/txn/0x7be610e9b2b32947290ae038c9b4f85707e493d87068d20b636aa9cd98c9b362?network=devnet)

### Security Checks
- **Double-Claim Blocked:** [0xdf78bc...](https://explorer.aptoslabs.com/txn/0xdf78bc2600f9a9237c83a7eb6f9e76ee35af0ccbdf29ccee1a3eb7bceec5eecd?network=devnet)

---

## 📚 Related Documentation

- [REWARDS_GUIDE.md](./REWARDS_GUIDE.md) - Complete rewards API and usage
- [PROJECT_STATUS.md](./PROJECT_STATUS.md) - Implementation status
- [README.md](./README.md) - Main project documentation

---

**Last Updated:** October 2025  
**Network:** Aptos Devnet  
**Publisher:** `0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6`

