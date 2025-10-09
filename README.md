# Sigil Game Platform - Aptos Smart Contract

A decentralized gaming open source public good on Aptos that allows publishers to register games, players to create profiles, and submit scores on-chain.

## 📋 Prerequisites

- [Aptos CLI](https://aptos.dev/tools/install-cli/) installed (v7.8.1+)
- Aptos account with devnet tokens
- API Key from [Aptos Labs](https://geomi.dev/docs/start)

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
sigil = "YOUR_ACCOUNT_ADDRESS"
```

### 3. Fund Your Account

```bash
aptos account fund-with-faucet \
  --account YOUR_ACCOUNT_ADDRESS \
  --profile sigil-main
```

### 4. Compile the Module

```bash
aptos move compile \
  --package-dir move \
  --named-addresses sigil=YOUR_ACCOUNT_ADDRESS
```

### 5. Deploy to Devnet

```bash
aptos move publish \
  --package-dir move \
  --profile sigil-main \
  --named-addresses sigil=YOUR_ACCOUNT_ADDRESS \
  --url https://api.devnet.aptoslabs.com \
  --assume-yes
```

### 6. Initialize the Module

**Important:** This must be done once after deployment by the publisher.

```bash
aptos move run \
  --function-id 'YOUR_ACCOUNT_ADDRESS::game_platform::init' \
  --profile sigil-main \
  --url https://api.devnet.aptoslabs.com \
  --max-gas 2000 \
  --assume-yes
```

## 📝 Contract Functions

### Publisher Functions

#### Register a Game

```bash
aptos move run \
  --function-id 'YOUR_ACCOUNT_ADDRESS::game_platform::register_game' \
  --args string:"Game Title Here" \
  --profile sigil-main \
  --url https://api.devnet.aptoslabs.com \
  --max-gas 2000 \
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
  --url https://api.devnet.aptoslabs.com \
  --max-gas 2000 \
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
  --url https://api.devnet.aptoslabs.com \
  --max-gas 2000 \
  --assume-yes
```

**Parameters:**
- `string` - Your desired username

**Example:**
```bash
aptos move run \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::game_platform::register_player' \
  --args string:"player123" \
  --profile sigil-main \
  --url https://api.devnet.aptoslabs.com \
  --max-gas 2000 \
  --assume-yes
```

#### Submit a Score

```bash
aptos move run \
  --function-id 'YOUR_ACCOUNT_ADDRESS::game_platform::submit_score' \
  --args address:PUBLISHER_ADDRESS u64:GAME_ID u64:SCORE \
  --profile sigil-main \
  --url https://api.devnet.aptoslabs.com \
  --max-gas 2000 \
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
  --url https://api.devnet.aptoslabs.com \
  --max-gas 2000 \
  --assume-yes
```

## 🔍 View Functions (Read State)

View functions don't require gas and are free to call.

### Get Game Count

Returns the total number of games registered by a publisher.

```bash
aptos move view \
  --function-id 'YOUR_ACCOUNT_ADDRESS::game_platform::game_count' \
  --args address:PUBLISHER_ADDRESS \
  --url https://api.devnet.aptoslabs.com
```

**Example:**
```bash
aptos move view \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::game_platform::game_count' \
  --args address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 \
  --url https://api.devnet.aptoslabs.com
```

**Returns:** `["1"]` - Number of games

### Check if Game Exists

```bash
aptos move view \
  --function-id 'YOUR_ACCOUNT_ADDRESS::game_platform::has_game' \
  --args address:PUBLISHER_ADDRESS u64:GAME_ID \
  --url https://api.devnet.aptoslabs.com
```

**Example:**
```bash
aptos move view \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::game_platform::has_game' \
  --args address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 u64:0 \
  --url https://api.devnet.aptoslabs.com
```

**Returns:** `[true]` or `[false]`

### Get Game Details

```bash
aptos move view \
  --function-id 'YOUR_ACCOUNT_ADDRESS::game_platform::get_game' \
  --args address:PUBLISHER_ADDRESS u64:GAME_ID \
  --url https://api.devnet.aptoslabs.com
```

**Example:**
```bash
aptos move view \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::game_platform::get_game' \
  --args address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 u64:0 \
  --url https://api.devnet.aptoslabs.com
```

**Returns:** 
```json
[
  "0",                                                          // Game ID
  "Test Game",                                                  // Game Title
  "0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6"  // Creator Address
]
```

### Get Player Scores

Retrieve all scores a player has submitted for a specific game.

```bash
aptos move view \
  --function-id 'YOUR_ACCOUNT_ADDRESS::game_platform::get_scores' \
  --args address:PUBLISHER_ADDRESS address:PLAYER_ADDRESS u64:GAME_ID \
  --url https://api.devnet.aptoslabs.com
```

**Parameters:**
- `address` - Publisher's address
- `address` - Player's address
- `u64` - Game ID

**Example:**
```bash
aptos move view \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::game_platform::get_scores' \
  --args address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 u64:0 \
  --url https://api.devnet.aptoslabs.com
```

**Returns:**
```json
[
  [
    "1500",
    "2000",
    "1800"
  ]
]
```

### Get Score Summary

Returns a summary with existence flag, last score, and maximum score.

```bash
aptos move view \
  --function-id 'YOUR_ACCOUNT_ADDRESS::game_platform::score_summary' \
  --args address:PUBLISHER_ADDRESS address:PLAYER_ADDRESS u64:GAME_ID \
  --url https://api.devnet.aptoslabs.com
```

**Example:**
```bash
aptos move view \
  --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::game_platform::score_summary' \
  --args address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 u64:0 \
  --url https://api.devnet.aptoslabs.com
```

**Returns:**
```json
[
  true,      // Has scores
  "1500",    // Last score
  "1500"     // Max score
]
```

## 🎮 Complete Example Workflow

Here's a complete example of deploying and using the platform:

```bash
# 1. Deploy and initialize
aptos move publish --package-dir move --profile sigil-main --named-addresses sigil=0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 --url https://api.devnet.aptoslabs.com --assume-yes

aptos move run --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::game_platform::init' --profile sigil-main --url https://api.devnet.aptoslabs.com --max-gas 2000 --assume-yes

# 2. Register a game
aptos move run --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::game_platform::register_game' --args string:"Space Shooter" --profile sigil-main --url https://api.devnet.aptoslabs.com --max-gas 2000 --assume-yes

# 3. Register as a player
aptos move run --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::game_platform::register_player' --args string:"gamer123" --profile sigil-main --url https://api.devnet.aptoslabs.com --max-gas 2000 --assume-yes

# 4. Submit a score
aptos move run --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::game_platform::submit_score' --args address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 u64:0 u64:5000 --profile sigil-main --url https://api.devnet.aptoslabs.com --max-gas 2000 --assume-yes

# 5. Check the score
aptos move view --function-id '0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6::game_platform::get_scores' --args address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 address:0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6 u64:0 --url https://api.devnet.aptoslabs.com
```

## 🔗 Deployed Contract Info

**Network:** Aptos Devnet  
**Module Address:** `0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6`  
**Module Name:** `game_platform`  

**Explorer Links:**
- [Deployment Transaction](https://explorer.aptoslabs.com/txn/0xd112cd68bd0a7df81c469864da499d947ec3286f4732b9205e7eccf0c89381ce?network=devnet)
- [Initialization Transaction](https://explorer.aptoslabs.com/txn/0xe2b41233d2e320a1c9cdaabb2e08ee211f1213c326c540525fc0b9724b2befc7?network=devnet)
- [Account View](https://explorer.aptoslabs.com/account/0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6?network=devnet)

## 📊 Data Structures

### Game
```move
struct Game {
    id: u64,
    title: String,
    creator: address,
}
```

### Player
```move
struct Player {
    user: address,
    username: String,
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

## ⚠️ Error Codes

- `E_ALREADY_INIT (0)` - Module already initialized
- `E_GAME_NOT_FOUND (1)` - Game ID doesn't exist
- `E_PLAYER_EXISTS (2)` - Player already registered
- `E_PLAYER_REQUIRED (3)` - Must register as player first

## ✅ Tested Transactions on Devnet

All functions have been tested and verified on Aptos Devnet. Here are the transaction links:

### Deployment & Initialization

| Action | Transaction Hash | Explorer Link | Status |
|--------|-----------------|---------------|---------|
| **Module Published** | `0xd112cd68bd0a7df81c469864da499d947ec3286f4732b9205e7eccf0c89381ce` | [View on Explorer](https://explorer.aptoslabs.com/txn/0xd112cd68bd0a7df81c469864da499d947ec3286f4732b9205e7eccf0c89381ce?network=devnet) | ✅ Success |
| **Module Initialized** | `0xe2b41233d2e320a1c9cdaabb2e08ee211f1213c326c540525fc0b9724b2befc7` | [View on Explorer](https://explorer.aptoslabs.com/txn/0xe2b41233d2e320a1c9cdaabb2e08ee211f1213c326c540525fc0b9724b2befc7?network=devnet) | ✅ Success |

### Test Transactions

| Action | Details | Transaction Hash | Explorer Link | Status |
|--------|---------|-----------------|---------------|---------|
| **Register Game** | Game ID: 0, Title: "Test Game" | `0xd922de3cd47a38971a2c2838ffea17c0a468194dc24e9221cbf6f82777c10e99` | [View on Explorer](https://explorer.aptoslabs.com/txn/0xd922de3cd47a38971a2c2838ffea17c0a468194dc24e9221cbf6f82777c10e99?network=devnet) | ✅ Success |
| **Register Player** | Username: "TestPlayer" | `0x43410cf8ebcb9d6c45db25fff06c411839730a94a37c50e52812cde1fe6fb440` | [View on Explorer](https://explorer.aptoslabs.com/txn/0x43410cf8ebcb9d6c45db25fff06c411839730a94a37c50e52812cde1fe6fb440?network=devnet) | ✅ Success |
| **Submit Score** | Game ID: 0, Score: 1500 | `0x4731b14133d8af61dfaff0b2f22d8cb57022cc7a59d2b44d815baaf2f96d6c14` | [View on Explorer](https://explorer.aptoslabs.com/txn/0x4731b14133d8af61dfaff0b2f22d8cb57022cc7a59d2b44d815baaf2f96d6c14?network=devnet) | ✅ Success |

### Verified State

After the test transactions, the following state was verified using view functions:

- **Game Count**: 1 game registered
- **Game Details**: Game ID 0 - "Test Game" owned by `0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6`
- **Player Scores**: Player has submitted score of 1500 for Game ID 0
- **Score Summary**: Last score: 1500, Max score: 1500

All transactions executed successfully with gas costs ranging from 86 to 865 gas units.

## 🛠️ Troubleshooting

### Rate Limit Exceeded
If you see rate limit errors, make sure you're using your API key in the config:
```yaml
api_key: "aptoslabs_YOUR_API_KEY_HERE"
```

### Transaction Timeout
Add explicit flags to avoid simulation timeouts:
```bash
--url https://api.devnet.aptoslabs.com --max-gas 2000
```

### Profile Not Found
Make sure you're running commands from the project root directory where `.aptos/config.yaml` exists, or use `--config-path` to specify the location.

## 📜 License

MIT

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📧 Contact

For questions or support, please open an issue on GitHub.

