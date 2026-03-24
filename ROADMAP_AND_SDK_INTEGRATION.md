# SIGIL Platform - Roadmap & SDK Integration Plan

**Solving the blockchain gaming integration problem on Aptos**

---

## 🎯 The Problem

### Current State of Blockchain Gaming on Aptos

Despite Aptos being a high-performance blockchain ideal for gaming, developers face significant barriers:

**❌ High Development Complexity**
- Building leaderboards, achievements, and rewards requires writing complex Move smart contracts from scratch
- No standardized gaming infrastructure - every team reinvents the wheel
- Steep learning curve for Move language (months to become proficient)
- Gas optimization and security concerns require deep blockchain expertise

**❌ Poor Developer Experience**
- Raw Aptos SDK is low-level (manual transaction building, BCS encoding, error handling)
- No game-specific abstractions or utilities
- Limited documentation and examples for gaming use cases
- Integration requires blockchain expertise on the development team

**❌ Fragmented Gaming Features**
- No standard for achievements, leaderboards, or reward systems
- Each game implements features differently (incompatible ecosystems)
- No composability between games (assets locked in silos)
- Difficult to build cross-game features or shared infrastructure

**❌ Time & Cost Barriers**
- 3-6 months to build basic gaming infrastructure
- Requires hiring Move developers ($150k-$300k/year)
- High maintenance costs for smart contract upgrades
- Significant testing overhead (security audits, gas optimization)

### The Opportunity Cost

**Every game developer building on Aptos must:**
1. Learn Move programming (3-6 months)
2. Build gaming infrastructure (3-6 months)
3. Test and audit contracts (1-2 months)
4. Maintain and upgrade modules (ongoing)

**Total:** 7-14 months of infrastructure work before focusing on actual game development! 🕒

---

## ✨ The SIGIL Solution

### "Plug-and-Play Gaming Infrastructure for Aptos"

SIGIL provides **production-ready, battle-tested gaming modules** that eliminate months of development time:

**✅ Pre-Built Gaming Infrastructure**
- 12 Move modules (~5,300 lines): leaderboards, achievements, rewards, seasons, quests, merge MVP, guilds MVP, …
- Automatic reward distribution (FA/NFT)
- Multi-admin management and anti-cheat

**✅ Developer-Friendly SDKs**
- TypeScript SDK: `await sigil.games.submitScore(gameId, score, player)`
- Unity SDK: `sigil.Games.SubmitScore(gameId, score, playerAccount)`
- No Move knowledge required - just use familiar languages

**✅ Zero Infrastructure Costs**
- All modules open source (MIT license)
- No deployment fees (already on devnet/mainnet)
- Pay only for transaction gas (pennies per action)
- No backend servers needed (fully on-chain)

**✅ Time to Market**
- **From 7-14 months → 1-2 weeks** to integrate full gaming features
- Focus on game design, not blockchain infrastructure
- Launch faster, iterate quicker, validate ideas sooner

### How SIGIL Works

```
Traditional Approach:                    SIGIL Approach:
┌──────────────────────┐                ┌──────────────────────┐
│ Learn Move (3-6 mo)  │                │ Install SDK (5 min)  │
│ Build modules (3-6mo)│                │ Import SIGIL (1 line)│
│ Test & audit (1-2 mo)│                │ Start building game! │
│ Deploy & maintain    │                │                      │
└──────────────────────┘                └──────────────────────┘
     7-14 months                              1-2 weeks
```

### Key Benefits

| Benefit | Traditional | SIGIL |
|---------|------------|-------|
| **Time to Production** | 7-14 months | 1-2 weeks |
| **Move Expertise Needed** | Expert level | None |
| **Infrastructure Cost** | $150k-$300k | $0 (open source) |
| **Maintenance Burden** | Ongoing | None (we maintain) |
| **Cross-Game Compatible** | No | Yes (shared standards) |

---

## 📋 Table of Contents

- [Project Completion Status](#project-completion-status)
- [Open Source MVP Scope](#open-source-mvp-scope)
- [TypeScript SDK Plans](#typescript-sdk-plans)
- [Unity SDK Integration](#unity-sdk-integration)
- [Timeline & Milestones](#timeline--milestones)
- [Remaining Work for MVP](#remaining-work-for-mvp)
- [MVP Completion Estimate](#mvp-completion-estimate)
- [Community & Contributions](#community--contributions)
- [Resources](#resources)
- [Long-Term Vision](#long-term-vision)
- [Get Involved](#get-involved)
- [Conclusion](#conclusion)

---

## ✅ Project Completion Status

### Current State: **12/12 Core Modules Complete** (Move package)

| Layer | Module | Status | Lines | Tests | Devnet | Notes |
|-------|--------|--------|-------|-------|--------|-------|
| **Layer 1: Foundation** | | | | | | |
| 1 | `game_platform` | ✅ Complete | 340 | 100% | ✅ Live | Score tracking, player profiles |
| 1 | `treasury` | ✅ Complete | 247 | 100% | ✅ Live | FA management |
| 1 | `shadow_signers` | ✅ Complete | 526 | 100% | ✅ Live | Gasless gameplay |
| **Layer 2: Core Features** | | | | | | |
| 2 | `leaderboard` | ✅ Complete | 336 | 100% | ✅ Live | Dynamic rankings |
| 2 | `achievements` | ✅ Complete | 543 | 100% | ✅ Live | 6 achievement types |
| 2 | `rewards` | ✅ Complete | 487 | 100% | ✅ Live | Automatic FA/NFT distribution |
| **Layer 3: Access Control** | | | | | | |
| 3 | `roles` | ✅ Complete | 426 | 100% | ✅ Live | Multi-admin management |
| 3 | `attest` | ✅ Complete | 315 | 100% | ✅ Live | Anti-cheat verification |
| **Layer 4: Coordination** | | | | | | |
| 4 | `seasons` | ✅ Complete | ~500 | 100% | ✅ Live | Temporal competitions + `finalize_season` + treasury prize split |
| 4 | `quests` | ✅ Complete | 825 | 100% | ✅ Live | Mission-based progression |
| 4 | `merge` | ✅ MVP | ~220 | 100% | ⏳ Publish | Abstract item recipes + inventory |
| 4 | `guilds` | ✅ MVP | ~270 | 100% | ⏳ Publish | Teams / clans (max 100 members) |

**Total:** ~5,295 lines of Move code | 194 unit tests (package `sigil_v2`) | 12 modules (republish for merge/guilds)

### Deployment Summary

**Address:** `0x1cc029fcb6f1c5770147584f3bdedc9e0fe4a59353de514342b57cb4f4286c19`  
**Network:** Aptos Devnet  
**Deployment Method:** Chunked publish (large package support)  
**Package Size:** 68,533 bytes  
**Gas Cost:** ~20,000 units total (~$0.0004)

**Latest Deployments:**
- Seasons: [0x8802d582...](https://explorer.aptoslabs.com/txn/0x8802d5828092f9d11c8178b35482b7d368f88b83be2a049550717824d8ac91ba?network=devnet)
- Quests (Tx1): [0x99889d38...](https://explorer.aptoslabs.com/txn/0x99889d38de548abf5f0d39bb3cd130b04aed01a6d9f2fd32c5c9b0a56193c907?network=devnet)
- Quests (Tx2): [0xeeea89c1...](https://explorer.aptoslabs.com/txn/0xeeea89c1a25acb21541932a65ee7a2c89541e4485d2dd334857c39b1dd68c18a?network=devnet)

---

## 🎯 Open Source MVP Scope

### What's Included in MVP (v1.0)

#### ✅ **Core Gaming Infrastructure** (Complete)
- Game registration and management
- Player profile system
- Score submission and tracking
- Dynamic leaderboards
- Achievement system (6 types)
- Automatic reward distribution (FA/NFT)

#### ✅ **Advanced Features** (Complete)
- Multi-admin role management
- Server-side attestation (anti-cheat)
- Gasless gameplay (session keys)
- Treasury management
- Temporal competitions (seasons)
- Mission system (quests)

#### ⏳ **Remaining for MVP**
1. **Merge / guilds v2** (Token Object burn-mint, advanced guild roles)
2. **Enhanced APIs** (Helper functions for quests/achievements)
3. **Documentation Polish** (Video tutorials, interactive examples)
4. **Example Game** (Simple demo showcasing all features)

### MVP Definition

**SIGIL v1.0 MVP = Production-Ready Gaming Platform**

**Requirements:**
- ✅ All core modules deployed and tested
- ✅ Comprehensive documentation (guides for each module)
- ✅ Live devnet deployment with verified transactions
- ✅ Non-breaking design (modules work independently)
- ⏳ At least 1 example game using the platform
- ⏳ TypeScript SDK with all module wrappers
- ⏳ Unity SDK integration examples

**Target:** Q2 2026 (revised from the original 2025 target)

---

## 🚀 TypeScript SDK Plans

### Overview

Create a comprehensive TypeScript SDK that provides high-level abstractions over the SIGIL Move modules, making it easy for game developers to integrate blockchain features without understanding Move internals.

### SDK Architecture

```
┌─────────────────────────────────────────────────────┐
│         SIGIL TypeScript SDK (sigil-sdk)            │
│                                                     │
│  High-level game developer API                     │
│  ├─ SigilClient (main entry point)                 │
│  ├─ GamePlatform module                            │
│  ├─ Leaderboard module                             │
│  ├─ Achievements module                            │
│  ├─ Rewards module                                 │
│  ├─ Seasons module                                 │
│  ├─ Quests module                                  │
│  ├─ Roles module                                   │
│  └─ Utils (formatters, validators)                 │
└─────────────────────────────────────────────────────┘
                      ↓ uses
┌─────────────────────────────────────────────────────┐
│        @aptos-labs/ts-sdk (Official SDK)            │
│                                                     │
│  Low-level Aptos blockchain interaction            │
│  ├─ Transaction building                           │
│  ├─ Signing & submission                           │
│  ├─ View function calls                            │
│  └─ Account management                             │
└─────────────────────────────────────────────────────┘
                      ↓ calls
┌─────────────────────────────────────────────────────┐
│         SIGIL Move Modules (On-Chain)               │
│         Address: 0x1cc029...c19                     │
└─────────────────────────────────────────────────────┘
```



### TypeScript SDK Roadmap

| Feature | Priority | Status | ETA |
|---------|----------|--------|-----|
| Core client & modules | 🔥 High | ⏳ Todo | Q2 2025 |
| Type definitions | 🔥 High | ⏳ Todo | Q2 2025 |
| Error handling | 🔥 High | ⏳ Todo | Q2 2025 |
| Unit tests | 🔥 High | ⏳ Todo | Q2 2025 |
| React hooks | 🟡 Medium | 📝 Planned | Q3 2025 |
| WebSocket support | 🟡 Medium | 📝 Planned | Q3 2025 |
| Indexer queries | 🟡 Medium | 📝 Planned | Q3 2025 |
| Vue composables | 🔵 Low | 📝 Planned | Q4 2025 |
| Svelte stores | 🔵 Low | 📝 Planned | Q4 2025 |

---

## 🎮 Unity SDK Integration

### Overview

Integrate SIGIL modules with the existing [Aptos Unity SDK](https://github.com/aptos-labs/unity-sdk) by creating C# wrapper classes that provide Unity-friendly APIs.

**Aptos Unity SDK Features:**
- ✅ BCS encoding/decoding
- ✅ Ed25519, MultiKey, Keyless signers
- ✅ Transaction building & submission
- ✅ Fullnode & Indexer API abstractions

**SIGIL Unity Integration:**
- Add high-level game module wrappers
- Provide Unity-specific utilities (coroutines, ScriptableObjects)
- Example scenes & prefabs
- Inspector integration

### Unity Integration Architecture

```
┌─────────────────────────────────────────────────────┐
│         Unity Game (C# Scripts)                     │
│                                                     │
│  Game Logic:                                        │
│  ├─ PlayerController.cs                            │
│  ├─ GameManager.cs                                 │
│  ├─ UIManager.cs                                   │
│  └─ LeaderboardUI.cs                               │
└─────────────────────────────────────────────────────┘
                      ↓ uses
┌─────────────────────────────────────────────────────┐
│         SIGIL Unity Integration (New!)              │
│         Namespace: Aptos.Sigil                      │
│                                                     │
│  High-level C# wrappers:                            │
│  ├─ SigilClient.cs                                 │
│  ├─ GamePlatformManager.cs                         │
│  ├─ LeaderboardManager.cs                          │
│  ├─ AchievementsManager.cs                         │
│  ├─ QuestsManager.cs                               │
│  └─ SeasonsManager.cs                              │
└─────────────────────────────────────────────────────┘
                      ↓ uses
┌─────────────────────────────────────────────────────┐
│         Aptos Unity SDK (Existing)                  │
│         Namespace: Aptos                            │
│                                                     │
│  Low-level blockchain:                              │
│  ├─ AptosClient                                    │
│  ├─ Account                                        │
│  ├─ TransactionBuilder                             │
│  └─ Contract view/entry functions                  │
└─────────────────────────────────────────────────────┘
```

### Unity Integration Roadmap

| Feature | Priority | Status | ETA |
|---------|----------|--------|-----|
| Core C# wrappers | 🔥 High | ⏳ Todo | Q4 2025 |
| Unity coroutines | 🔥 High | ⏳ Todo | Q4 2025 |
| ScriptableObject configs | 🔥 High | ⏳ Todo | Q4 2025 |
| Example scenes | 🔥 High | ⏳ Todo | Q4 2025 |
| Pre-built UI prefabs | 🟡 Medium | 📝 Planned | Q4 2025 |
| Inspector integration | 🟡 Medium | 📝 Planned | Q4 2025 |
| WebGL support | 🟡 Medium | 📝 Planned | Q4 2025 |
| Mobile optimization | 🔵 Low | 📝 Planned | Q1 2026 |

### Unity Example Game (Demo)

**Concept:** "Aptos Arcade Shooter"

**Features:**
- Single-player space shooter
- Score submission to SIGIL
- Real-time leaderboard display
- Achievement unlocks with NFT badges
- Daily quests system
- Seasonal tournaments
- Automatic APT rewards

**Tech Stack:**
- Unity 2022.3 LTS
- Aptos Unity SDK (existing)
- SIGIL Unity Integration (new)
- Universal Render Pipeline (URP)

**Use Cases Demonstrated:**
1. Player registration and profiles
2. Score submission and leaderboards
3. Achievement progression and unlocking
4. Quest tracking and completion
5. Seasonal tournaments with prizes
6. Automatic reward claiming

**Timeline:** Q1 2026 (after TS SDK completion)

---

## 🗓️ Timeline & Milestones

### Phase 1 - Core Platform Delivery (2025) ✅ **COMPLETE**

**✅ Completed:**
- [x] Core Move modules (game_platform, leaderboard, achievements, rewards)
- [x] Access control modules (roles, attest)
- [x] Infrastructure modules (treasury, shadow_signers)
- [x] Coordination modules (seasons, quests, merge MVP, guilds MVP)
- [x] Comprehensive documentation (module guides; merge + guilds added)
- [x] Devnet deployment and testing (republish required for new modules)
- [x] 190 unit tests written

**Deliverables:**
- 12 Move modules in package (10 previously on devnet + merge + guilds)
- 10+ comprehensive guides
- Live devnet testing complete

### Phase 2 - SDK & MVP Packaging (2026) ⏳ **IN PROGRESS**

**Goals:**
- [x] Merge module MVP (abstract crafting; Token Object burn/mint = future)
- [ ] TypeScript SDK implementation
  - [ ] Core client and module wrappers
  - [ ] Type definitions and error handling
  - [ ] Unit tests and integration tests
  - [ ] NPM package publication
- [ ] Unity SDK integration
  - [ ] C# wrapper classes
  - [ ] Unity example scenes
  - [ ] Documentation and samples
- [ ] Example game development
  - [ ] Simple arcade game showcasing SIGIL
  - [ ] Full integration of all modules
  - [ ] WebGL build for browser play

**Deliverables:**
- `@sigil/aptos-sdk` npm package (v1.0.0)
- `com.sigil.aptos-unity-sdk` Unity package (v1.0.0)
- Demo game (open source)
- Video tutorials (3-5 videos)

### Phase 3 - Post-MVP Expansion (Late 2026) 📝 **PLANNED**

**Goals:**
- [ ] Mainnet deployment (production-ready)
- [ ] React SDK (`@sigil/react-sdk`)
- [ ] Real-time features (WebSocket support)
- [ ] Indexer integration (historical queries)
- [ ] Enhanced UI components
- [ ] Mobile optimization (iOS/Android)
- [ ] Community examples and templates
---

## 🛠️ Remaining Work for MVP

### 1. **Merge Module** (MVP shipped in repo)

**Done:** `sigil::merge` — recipes over `item_id` quantities, `grant_items`, `execute_merge`, tests + [MERGE_GUIDE.md](./docs/modules/MERGE_GUIDE.md).

**Future:** On-chain NFT/FA burn + mint hooks, multi-input recipes, gacha tables.

### 2. **API Enhancements** (Medium Priority)

**Required for Full Quest Support:**

**achievements module:**
```move
#[view]
public fun get_player_achievement_count(
    publisher: address, 
    player: address
): u64
```

**leaderboard module:**
```move
#[view]
public fun get_player_rank(
    publisher: address,
    leaderboard_id: u64,
    player: address
): (bool, u64)  // (has_rank, rank)
```


---

## 📊 MVP Completion Estimate

### Current Progress: **~88% Complete** (all Move modules in repo; SDKs pending)

| Category | Status | Completion |
|----------|--------|------------|
| Move Modules | ✅ 12/12 | 100% |
| Documentation | ✅ 8/8 | 100% |
| Devnet Testing | ✅ Complete | 100% |
| TypeScript SDK | ⏳ Not Started | 0% |
| Unity SDK | ⏳ Not Started | 0% |
| Example Game | ⏳ Not Started | 0% |
| Video Tutorials | ⏳ Not Started | 0% |

### Remaining Work: **8-12 weeks** (optimistic)

**Critical Path:**
1. Merge/guilds **v2** (NFT hooks, guild roles): optional, 1–2 weeks
2. TypeScript SDK: 4-5 weeks
3. Unity SDK: 4-5 weeks (parallel with TS SDK)
4. Example game: 4-5 weeks (after SDK)
5. Documentation/tutorials: 3 weeks (parallel)

**MVP Launch Target:** **Q2 2026**

---

## 🤝 Community & Contributions

### How to Contribute 
(To be updated once MVP is out)

## 🔗 Resources

### Official Links

- **Move Modules:** [GitHub Repository](https://github.com/lopeselio/aptos-sigil)
- **Documentation:** [docs/modules/](./docs/modules/)
- **Devnet Deployment:** [Explorer](https://explorer.aptoslabs.com/account/0x1cc029fcb6f1c5770147584f3bdedc9e0fe4a59353de514342b57cb4f4286c19?network=devnet)

### External SDKs

- **Aptos TypeScript SDK:** [GitHub](https://github.com/aptos-labs/aptos-ts-sdk) | [Docs](https://aptos.dev/en/build/sdks/ts-sdk)
- **Aptos Unity SDK:** [GitHub](https://github.com/aptos-labs/unity-sdk) | [Docs](https://aptos.dev/en/build/sdks/unity-sdk)

### Related Projects

- **Aptos Token Objects:** Used for NFT minting
- **Aptos Framework:** Core blockchain functionality
- **Aptos Indexer:** Historical data queries

---


---

## 🎯 Long-Term Vision

### SIGIL v2.0 (2026)

**Planned Features:**
- **Guilds/Clans:** Team-based competition
- **PvP Matchmaking:** On-chain ranked matchmaking
- **Cross-Game Assets:** NFTs usable across games
- **Governance:** DAO for platform decisions
- **Analytics Dashboard:** Real-time metrics for developers
- **Mobile SDK:** Native iOS/Android support
- **Game Launcher:** Unified hub for SIGIL games

### Ecosystem Growth

**Developer Tools:**
- CLI tool for scaffolding new games
- Testing framework for SIGIL games
- Analytics SDK for tracking metrics
- Admin dashboard for publishers

**Community:**
- Developer Discord (support & collaboration)
- Monthly hackathons for indie teams
- Developer grants program
- Case studies & success stories

---

## 📞 Get Involved

### For Developers

**Start Building:**
1. Clone the repository
2. Deploy modules to your devnet account
3. Experiment with the APIs
4. Join the Discord for support
5. Share your progress!

**Contribute:**
1. Check open issues on GitHub
2. Pick a task from the roadmap
3. Submit PRs with improvements
4. Help with documentation
5. Build example games


---

## 🏆 Conclusion

SIGIL’s **Move package** includes **12 modules** (merge + guilds MVP, seasons `finalize_season`, etc.). **Republish** to devnet to load new modules. The remaining open-source MVP work is **SDKs**, an **example game**, and polish.

**Next Steps:**
1. ✅ Complete quests module (Done!)
2. ✅ Merge + guilds MVP in repo (publish + integrate)
3. 🚀 Build TypeScript SDK (in progress window: 2026)
4. 🎮 Build Unity SDK integration (in progress window: 2026)
5. 🎨 Create example game (after SDK baseline)
6. 📢 Launch open source MVP (target: Q2 2026)

---

**Last Updated:** March 24, 2026  
**Project Status:** Active Development  
**License:** MIT  
**Maintainer:** lopeselio

**Built with ❤️ for the Aptos gaming community**

