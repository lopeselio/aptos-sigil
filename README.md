# Sigil Game Platform - Aptos Smart Contract

A decentralized gaming open source public good on Aptos that allows publishers to register games, players to create profiles, submit scores on-chain, and compete on dynamic leaderboards.

## 🎮 Features

- **Game Management** - Publishers can register games with unique IDs
- **Player Profiles** - Players create on-chain profiles with usernames
- **Score Submission** - Submit and track scores for any registered game
- **Leaderboards** - Dynamic, gas-optimized leaderboards with configurable ranking
- **Events** - All actions emit events for easy indexing

## 📋 Prerequisites

- [Aptos CLI](https://aptos.dev/tools/install-cli/) installed (v7.8.1+)
- Aptos account with devnet tokens
- API Key from [Aptos Labs](https://geomi.dev/docs/start)

## Directory structure


```
sigil-aptos/
├── move/
│   ├── sources/
│   │   ├── sigil_core.move         ✅ Untouched (as requested)
│   │   └── leaderboard.move        ✅ Enhanced & Production Ready
│   └── tests/
│       └── leaderboard_tests.move  ✅ 15 passing tests
│
├── LEADERBOARD_INTEGRATION.md      📚 500+ lines of integration docs
├── TESTING_GUIDE.md                📚 Complete CLI testing guide
├── SUMMARY.md                      📚 Technical implementation summary
```

## 🚀 Deployment Steps

### 1. Configure Your Environment

Create or update `.aptos/config.yaml` in your project root:

```yaml
---
profiles:
  sigil-main:
    network: Devnet
    private_key: "YOUR_PRIVATE_KEY_HERE"
    public_key: "YOUR_PUBLIC_KEY_HERE"
    account: YOUR_ACCOUNT_ADDRESS
    rest_url: "https://api.devnet.aptoslabs.com"
    faucet_url: "https://faucet.devnet.aptoslabs.com"
    api_key: "YOUR_API_KEY_HERE"
```

### 2. Update Move.toml

Update `move/Move.toml` with your account address:

```toml
[addresses]
sigil = "YOUR_ACCOUNT_ADDRESS"

[dev-addresses]
```

### 3. Fund Your Account

```bash
aptos account fund-with-faucet \
  --account YOUR_ACCOUNT_ADDRESS \
  --profile sigil-main
```

### 4. Compile the Modules

```bash
cd move
aptos move compile --save-metadata
```

### 5. Deploy to Devnet

```bash
aptos move publish \
  --package-dir move \
  --profile sigil-main \
  --assume-yes
```

### 6. Initialize the Modules

**Important:** Initialize both modules after deployment.

```bash
# Initialize Game Platform
aptos move run \
  --function-id 'YOUR_ACCOUNT_ADDRESS::game_platform::init' \
  --profile sigil-main \
  --assume-yes

# Initialize Leaderboards
aptos move run \
  --function-id 'YOUR_ACCOUNT_ADDRESS::leaderboard::init_leaderboards' \
  --profile sigil-main \
  --assume-yes
```

---

## 📝 Game Platform Functions

### Publisher Functions

#### Register a Game

```bash
aptos move run \
  --function-id 'YOUR_ACCOUNT_ADDRESS::game_platform::register_game' \
  --args string:"Game Title Here" \
  --profile sigil-main \
  --assume-yes
```

**Parameters:**
- `string` - The title of your game

**Example:**
```bash
aptos move run \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::game_platform::register_game' \
  --args string:"Space Shooter 2024" \
  --profile sigil-main \
  --assume-yes
```

### Player Functions

#### Register as a Player

Players must register before submitting scores.

```bash
aptos move run \
  --function-id 'YOUR_ACCOUNT_ADDRESS::game_platform::register_player' \
  --args string:"your_username" \
  --profile sigil-main \
  --assume-yes
```

**Example:**
```bash
aptos move run \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::game_platform::register_player' \
  --args string:"player123" \
  --profile sigil-main \
  --assume-yes
```

#### Submit a Score

```bash
aptos move run \
  --function-id 'YOUR_ACCOUNT_ADDRESS::game_platform::submit_score' \
  --args address:PUBLISHER_ADDRESS u64:GAME_ID u64:SCORE \
  --profile sigil-main \
  --assume-yes
```

**Parameters:**
- `address` - The publisher's address who owns the game
- `u64` - The game ID (starts from 0)
- `u64` - The score value

**Example:**
```bash
aptos move run \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::game_platform::submit_score' \
  --args address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 u64:0 u64:5000 \
  --profile sigil-main \
  --assume-yes
```

### View Functions (Read State)

View functions don't require gas and are free to call.

#### Get Game Count

```bash
aptos move view \
  --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::game_platform::game_count' \
  --args address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6
```

**Returns:** `["1"]` - Number of games

#### Get Game Details

```bash
aptos move view \
  --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::game_platform::get_game' \
  --args address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 u64:0
```

**Returns:** 
```json
[
  "0",           // Game ID
  "Test Game",   // Game Title
  "0xe68ef..."   // Creator Address
]
```

#### Get Player Scores

```bash
aptos move view \
  --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::game_platform::get_scores' \
  --args address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 address:PLAYER_ADDRESS u64:0
```

---

## 🏆 Leaderboard Functions

### Create a Leaderboard

Publishers can create customizable leaderboards for their games.

```bash
aptos move run \
  --profile sigil-main \
  --function-id 'YOUR_ACCOUNT_ADDRESS::leaderboard::create_leaderboard' \
  --args u64:GAME_ID u8:DECIMALS u64:MIN_SCORE u64:MAX_SCORE bool:IS_ASCENDING bool:ALLOW_MULTIPLE u64:TOP_N \
  --assume-yes
```

**Parameters:**
- `game_id` (u64) - The game ID to create leaderboard for
- `decimals` (u8) - Number of decimal places for display (0 for integers)
- `min_score` (u64) - Minimum valid score (scores below are rejected)
- `max_score` (u64) - Maximum valid score (scores above are rejected)
- `is_ascending` (bool) - `false` = higher is better, `true` = lower is better (speedruns)
- `allow_multiple` (bool) - `false` = only best score per player, `true` = allow multiple submissions
- `scores_to_retain` (u64) - How many top entries to keep (e.g., top 10, top 100)

**Example - High Score Leaderboard (Top 10):**
```bash
aptos move run \
  --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::leaderboard::create_leaderboard' \
  --args u64:0 u8:0 u64:0 u64:999999999 bool:false bool:false u64:10 \
  --assume-yes
```

**Example - Speedrun Leaderboard (Lower Time is Better):**
```bash
aptos move run \
  --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::leaderboard::create_leaderboard' \
  --args u64:0 u8:2 u64:0 u64:999999 bool:true bool:false u64:50 \
  --assume-yes
```

### Submit Score to Leaderboard

For testing purposes, you can directly submit scores to the leaderboard:

```bash
aptos move run \
  --profile sigil-main \
  --function-id 'YOUR_ACCOUNT_ADDRESS::leaderboard::submit_score_direct' \
  --args address:PUBLISHER_ADDRESS u64:LEADERBOARD_ID address:PLAYER_ADDRESS u64:SCORE \
  --assume-yes
```

**Example:**
```bash
aptos move run \
  --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::leaderboard::submit_score_direct' \
  --args address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 u64:0 address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 u64:2500 \
  --assume-yes
```

### Leaderboard View Functions

#### Get Leaderboard Count

```bash
aptos move view \
  --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::leaderboard::get_leaderboard_count' \
  --args address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6
```

**Returns:** Number of leaderboards created

#### Get Leaderboard Configuration

```bash
aptos move view \
  --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::leaderboard::get_leaderboard_config' \
  --args address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 u64:0
```

**Returns:**
```json
[
  "0",         // game_id
  0,           // decimals
  "0",         // min_score
  "999999999", // max_score
  false,       // is_ascending
  false,       // allow_multiple
  "10"         // scores_to_retain
]
```

#### Get Top Entries (Leaderboard Rankings)

```bash
aptos move view \
  --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::leaderboard::get_top_entries' \
  --args address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 u64:0
```

**Returns:** Two aligned arrays - player addresses and their scores
```json
{
  "Result": [
    [
      "0x30be4b352a2e02eae96e771a210d32ecab488f82c5b059bb1fa875117b81f239",
      "0x14cbc9d57823000f77aa8d29454ba90c52f0443fdb670b5a1357bcc07971c048",
      "0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6"
    ],
    [
      "2500",
      "2000",
      "1500"
    ]
  ]
}
```

---

## 🎮 Complete Example Workflow

Here's a complete example of deploying and using the platform:

```bash
# 1. Compile
cd move && aptos move compile --save-metadata && cd ..

# 2. Deploy both modules
aptos move publish --package-dir move --profile sigil-main --assume-yes

# 3. Initialize game platform
aptos move run \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::game_platform::init' \
  --profile sigil-main --assume-yes

# 4. Initialize leaderboards
aptos move run \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::leaderboard::init_leaderboards' \
  --profile sigil-main --assume-yes

# 5. Register a game
aptos move run \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::game_platform::register_game' \
  --args string:"Space Shooter" \
  --profile sigil-main --assume-yes

# 6. Create a leaderboard for the game (top 10)
aptos move run \
  --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::leaderboard::create_leaderboard' \
  --args u64:0 u8:0 u64:0 u64:999999999 bool:false bool:false u64:10 \
  --assume-yes

# 7. Register as a player
aptos move run \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::game_platform::register_player' \
  --args string:"gamer123" \
  --profile sigil-main --assume-yes

# 8. Submit scores to leaderboard
aptos move run \
  --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::leaderboard::submit_score_direct' \
  --args address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 u64:0 address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 u64:1500 \
  --assume-yes

# 9. Check the leaderboard rankings
aptos move view \
  --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::leaderboard::get_top_entries' \
  --args address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 u64:0
```

---

## 🔗 Deployed Contract Info

**Network:** Aptos Devnet  
**Module Address:** `0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6`  
**Modules:** `game_platform`, `leaderboard`  

**Explorer Links:**
- [Account View](https://explorer.aptoslabs.com/account/0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6?network=devnet)
- [Latest Module Publication](https://explorer.aptoslabs.com/txn/0x3ca4da35dcd2d2f57cd35b8e695ba24d3c6d27767d1873c4d77fc6adb6cc780c?network=devnet)

---

## ✅ Latest Deployments & Tests on Devnet

### Latest Deployment (January 2025)

| Action | Transaction Hash | Explorer Link | Status |
|--------|-----------------|---------------|---------|
| **Modules Published** (game_platform + leaderboard) | `0x3ca4da35dcd2d2f57cd35b8e695ba24d3c6d27767d1873c4d77fc6adb6cc780c` | [View](https://explorer.aptoslabs.com/txn/0x3ca4da35dcd2d2f57cd35b8e695ba24d3c6d27767d1873c4d77fc6adb6cc780c?network=devnet) | ✅ Success |
| **Leaderboards Initialized** | `0x273fa651eb3b0e73c2ff54c26ea0ef0a4e3cd8c82a503bb72d14c4b394052a8f` | [View](https://explorer.aptoslabs.com/txn/0x273fa651eb3b0e73c2ff54c26ea0ef0a4e3cd8c82a503bb72d14c4b394052a8f?network=devnet) | ✅ Success |
| **Leaderboard Created** (Game 0, Top 10) | `0xdd82e156a7a68f3088c3c80a85d89b15376d12885c149db4945896700fa988ea` | [View](https://explorer.aptoslabs.com/txn/0xdd82e156a7a68f3088c3c80a85d89b15376d12885c149db4945896700fa988ea?network=devnet) | ✅ Success |

### Test Transactions - Leaderboard System

| Action | Details | Transaction Hash | Explorer Link | Status |
|--------|---------|-----------------|---------------|---------|
| **Submit Score #1** | Player: 0xe68e..., Score: 1500 | `0x2f5e9f6a8d9bd6528e1130be967194b83f1d83648e02234c875e616878f4dce4` | [View](https://explorer.aptoslabs.com/txn/0x2f5e9f6a8d9bd6528e1130be967194b83f1d83648e02234c875e616878f4dce4?network=devnet) | ✅ Success |
| **Submit Score #2** | Player: 0x14cb..., Score: 2000 | `0x47135fe138630f9e047aaf5119a8dfcf8024844126452b1700e9159b2f9e87cf` | [View](https://explorer.aptoslabs.com/txn/0x47135fe138630f9e047aaf5119a8dfcf8024844126452b1700e9159b2f9e87cf?network=devnet) | ✅ Success |
| **Submit Score #3** | Player: 0x30be..., Score: 1000 | `0x6ae5339f9c5ab4654fbb75dd1caf749473a8ef758afb36457fbed5cc3bba5128` | [View](https://explorer.aptoslabs.com/txn/0x6ae5339f9c5ab4654fbb75dd1caf749473a8ef758afb36457fbed5cc3bba5128?network=devnet) | ✅ Success |
| **Update Score** | Player: 0x30be... → 2500 (moved to 1st place!) | `0x168b100df4cb36a1e72a1d907e87d8ab5d427c7ef8fb4afefe0bf5f509a3ba95` | [View](https://explorer.aptoslabs.com/txn/0x168b100df4cb36a1e72a1d907e87d8ab5d427c7ef8fb4afefe0bf5f509a3ba95?network=devnet) | ✅ Success |

### Verified Live Leaderboard State

After testing, the leaderboard rankings on-chain:

| Rank | Player Address | Score | Status |
|------|---------------|-------|---------|
| 🥇 1st | `0x30be4b...` | **2500** | Updated from 1000 → 2500 |
| 🥈 2nd | `0x14cbc9...` | **2000** | Maintained |
| 🥉 3rd | `0xe68ef2...` | **1500** | Maintained |

**Verified using:**
```bash
aptos move view --profile sigil-main \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::leaderboard::get_top_entries' \
  --args address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 u64:0
```

---

## 📊 Data Structures

### Game Platform

**Game**
```move
struct Game {
    id: u64,
    title: String,
    creator: address,
}
```

**Player**
```move
struct Player {
    user: address,
    username: String,
}
```

### Leaderboard

**Leaderboard Config**
```move
struct Config {
    game_id: u64,
    decimals: u8,
    min_score: u64,
    max_score: u64,
    is_ascending: bool,      // true => lower is better
    allow_multiple: bool,    // if false: only keep best per player
    scores_to_retain: u64,   // how many entries to keep in top list
}
```

**Leaderboard**
```move
struct Leaderboard {
    id: u64,
    config: Config,
    best_by_player: Table<address, u64>,           // Track best score per player
    top_entries_players: vector<address>,          // Sorted player addresses
    top_entries_scores: vector<u64>,               // Corresponding scores
}
```

### Events

**GameRegisteredEvent**
```move
struct GameRegisteredEvent {
    id: u64,
    creator: address,
    title: String,
}
```

**ScoreSubmittedEvent**
```move
struct ScoreSubmittedEvent {
    publisher: address,
    player: address,
    game_id: u64,
    score: u64,
}
```

---

## ⚠️ Error Codes

### Game Platform
- `E_ALREADY_INIT (0)` - Module already initialized
- `E_GAME_NOT_FOUND (1)` - Game ID doesn't exist
- `E_PLAYER_EXISTS (2)` - Player already registered
- `E_PLAYER_REQUIRED (3)` - Must register as player first

### Leaderboard
- `E_ALREADY_INIT (0)` - Leaderboards already initialized
- `E_NOT_FOUND (1)` - Leaderboard ID doesn't exist
- `E_ID_EXISTS (2)` - Leaderboard ID already exists

---

## 🎯 Leaderboard Features

### Gas Optimization
- **Best Score Tracking**: Prevents unnecessary updates
- **Bounded Operations**: Only maintains top N entries (no unbounded growth)
- **Smart Sorting**: Efficient insertion-sort algorithm that only bubbles the changed entry
- **Early Exits**: Score gates reject invalid entries before processing

### Flexible Configurations

**High Score Games** (Points-based)
```bash
# Higher is better, keep top 100
--args u64:0 u8:0 u64:0 u64:999999999 bool:false bool:false u64:100
```

**Speedrun Games** (Time-based)
```bash
# Lower is better (faster time), keep top 50
--args u64:0 u8:2 u64:0 u64:999999 bool:true bool:false u64:50
```

**Competitive Games** (Skill-gated)
```bash
# Must score at least 10000 to appear, keep top 20
--args u64:0 u8:0 u64:10000 u64:999999 bool:false bool:false u64:20
```

---

## 🛠️ Troubleshooting

### Rate Limit Exceeded
If you see rate limit errors, make sure you're using your API key in the config:
```yaml
api_key: "aptoslabs_YOUR_API_KEY_HERE"
```

### Transaction Timeout
Add explicit profile to avoid simulation timeouts:
```bash
--profile sigil-main --assume-yes
```

### Profile Not Found
Make sure you're running commands from the project root directory where `.aptos/config.yaml` exists.

### Module Already Exists
If republishing, the modules will be upgraded automatically. Make sure you're using the same address in `Move.toml`.

---

## 📚 Additional Documentation

For more detailed information, check out:

- **[LEADERBOARD_INTEGRATION.md](./LEADERBOARD_INTEGRATION.md)** - Complete integration guide (500+ lines)
- **[TESTING_GUIDE.md](./TESTING_GUIDE.md)** - Step-by-step testing instructions
- **[SUMMARY.md](./SUMMARY.md)** - Technical implementation details
- **[QUICK_START.md](./QUICK_START.md)** - 3-minute quick start guide

---

## 🧪 Running Tests

The project includes comprehensive unit tests:

```bash
cd move
aptos move test
```

**Test Coverage:**
- 15 unit tests for leaderboard functionality
- All tests passing ✅
- Tests cover: initialization, score submission, ranking, updates, edge cases

---

## 📜 License

MIT

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development Setup

1. Clone the repository
2. Install Aptos CLI
3. Set up your `.aptos/config.yaml`
4. Run `aptos move test` to verify setup
5. Make your changes
6. Submit a PR

---

## 📧 Contact

For questions or support, please open an issue on GitHub.

---

**Built with ❤️ for the Aptos gaming ecosystem**

*Last Updated: January 2025*
