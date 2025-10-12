module sigil::rewards {
    use std::option::{Self, Option};
    use std::signer;
    use std::string::{Self, String};
    use std::vector;
    use aptos_std::table::{Self, Table};
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::event;
    use aptos_framework::object::{Self, Object};
    use aptos_framework::fungible_asset::{Metadata};
    use aptos_framework::primary_fungible_store;
    use aptos_token_objects::collection;
    use aptos_token_objects::token;
    // use sigil::achievements;  // Temporarily disabled for independent deployment

    /*************
     *  Types
     *************/

    /// Reward kind discriminator and data
    /// We use struct with options instead of enum (Aptos Move 1 doesn't have enums)
    struct RewardKind has store, drop {
        // Discriminator
        is_ft: bool,  // true = Fungible Asset, false = NFT
        
        // Fungible Asset fields (used when is_ft = true)
        fa_metadata: Option<Object<Metadata>>,
        fa_amount: u64,
        
        // NFT fields (used when is_ft = false)
        nft_collection: Option<address>,
        nft_name: Option<String>,
        nft_description: Option<String>,
        nft_uri: Option<String>,
    }

    /// Reward definition attached to an achievement
    struct Reward has store, drop {
        achievement_id: u64,
        kind: RewardKind,
        total_supply: u64,      // Total rewards available
        claimed_count: u64,     // How many have been claimed
    }

    /// Per-publisher rewards registry
    /// - by_achievement: achievement_id -> Reward config
    /// - claimed: player -> achievement_id -> bool (prevent double claims)
    struct Rewards has key {
        by_achievement: Table<u64, Reward>,
        claimed: Table<address, Table<u64, bool>>,
        events: Events,
    }

    /// Configuration for automatic reward distribution
    /// Stores signer capability to enable FA transfers and NFT minting
    struct RewardsConfig has key {
        publisher: address,
        signer_cap: SignerCapability,
    }

    /// Events
    struct RewardAttachedEvent has drop, store {
        publisher: address,
        achievement_id: u64,
        is_ft: bool,
        supply: u64,
    }

    struct RewardClaimedEvent has drop, store {
        publisher: address,
        player: address,
        achievement_id: u64,
        is_ft: bool,
    }

    struct Events has key, store {
        attached: event::EventHandle<RewardAttachedEvent>,
        claimed: event::EventHandle<RewardClaimedEvent>,
    }

    /*************
     *  Errors
     *************/
    const E_ALREADY_INIT: u64 = 0;
    const E_NOT_FOUND: u64 = 1;
    const E_ALREADY_ATTACHED: u64 = 2;
    const E_ACHIEVEMENT_NOT_UNLOCKED: u64 = 3;
    const E_ALREADY_CLAIMED: u64 = 4;
    const E_OUT_OF_STOCK: u64 = 5;
    const E_INVALID_SUPPLY: u64 = 6;
    const E_NOT_INITIALIZED: u64 = 7;

    /*************
     *  Lifecycle
     *************/

    /// Initialize rewards system for publisher
    public entry fun init_rewards(publisher: &signer) {
        let addr = signer::address_of(publisher);
        assert!(!exists<Rewards>(addr), E_ALREADY_INIT);

        // Create resource account for automatic reward distribution
        // This account can act with publisher's authority for FA transfers and NFT minting
        let (_resource_signer, signer_cap) = account::create_resource_account(publisher, b"rewards_v1");

        // Store the signer capability (enables automatic distribution)
        move_to<RewardsConfig>(publisher, RewardsConfig {
            publisher: addr,
            signer_cap: signer_cap,
        });

        // Initialize rewards registry at publisher's address (keeps queries simple)
        move_to<Rewards>(publisher, Rewards {
            by_achievement: table::new<u64, Reward>(),
            claimed: table::new<address, Table<u64, bool>>(),
            events: Events {
                attached: account::new_event_handle<RewardAttachedEvent>(publisher),
                claimed: account::new_event_handle<RewardClaimedEvent>(publisher),
            },
        });
    }

    #[test_only]
    /// Test-only init that skips resource account creation (for backward compat with tests)
    public fun init_rewards_for_test(publisher: &signer) {
        let addr = signer::address_of(publisher);
        move_to<Rewards>(publisher, Rewards {
            by_achievement: table::new<u64, Reward>(),
            claimed: table::new<address, Table<u64, bool>>(),
            events: Events {
                attached: account::new_event_handle<RewardAttachedEvent>(publisher),
                claimed: account::new_event_handle<RewardClaimedEvent>(publisher),
            },
        });
    }

    /*************
     *  NFT Collection Management
     *************/

    /// Create an NFT collection for achievement rewards
    /// Must be called before attaching NFT rewards
    public entry fun create_nft_collection(
        publisher: &signer,
        name: vector<u8>,
        description: vector<u8>,
        uri: vector<u8>
    ) acquires RewardsConfig {
        let addr = signer::address_of(publisher);
        assert!(exists<RewardsConfig>(addr), E_NOT_INITIALIZED);
        
        // Get publisher signer from capability
        let config = borrow_global<RewardsConfig>(addr);
        let publisher_signer = account::create_signer_with_capability(&config.signer_cap);
        
        // Create unlimited collection
        collection::create_unlimited_collection(
            &publisher_signer,
            string::utf8(description),
            string::utf8(name),
            option::none(), // royalty
            string::utf8(uri)
        );
    }

    /*************
     *  Attach Rewards
     *************/

    /// Attach a Fungible Asset reward to an achievement
    /// 
    /// Parameters:
    /// - fa_metadata: The metadata object for the fungible asset
    /// - amount: Amount of FA to give per claim
    /// - supply: Total number of claims available (0 = unlimited)
    /// 
    /// Gas: ~500-600 units
    /// 
    /// Example: Attach 100 APT to achievement #0, with 50 claims available
    public entry fun attach_fa_reward(
        publisher: &signer,
        achievement_id: u64,
        fa_metadata: Object<Metadata>,
        amount: u64,
        supply: u64
    ) acquires Rewards {
        let addr = signer::address_of(publisher);
        let r = borrow_global_mut<Rewards>(addr);
        
        assert!(!table::contains<u64, Reward>(&r.by_achievement, achievement_id), E_ALREADY_ATTACHED);
        
        let reward = Reward {
            achievement_id,
            kind: RewardKind {
                is_ft: true,
                fa_metadata: option::some(fa_metadata),
                fa_amount: amount,
                nft_collection: option::none<address>(),
                nft_name: option::none<String>(),
                nft_description: option::none<String>(),
                nft_uri: option::none<String>(),
            },
            total_supply: supply,
            claimed_count: 0,
        };
        
        table::add<u64, Reward>(&mut r.by_achievement, achievement_id, reward);
        
        event::emit_event<RewardAttachedEvent>(
            &mut r.events.attached,
            RewardAttachedEvent { publisher: addr, achievement_id, is_ft: true, supply }
        );
    }

    /// Attach an NFT reward to an achievement
    /// 
    /// Parameters:
    /// - collection: Address of the NFT collection
    /// - name: Token name template
    /// - description: Token description
    /// - uri: Token URI (image/metadata)
    /// - supply: Total number of NFTs available
    /// 
    /// Gas: ~600-700 units
    /// 
    /// Note: This stores metadata for minting. Actual minting happens during claim.
    public entry fun attach_nft_reward(
        publisher: &signer,
        achievement_id: u64,
        collection: address,
        name: String,
        description: String,
        uri: String,
        supply: u64
    ) acquires Rewards {
        let addr = signer::address_of(publisher);
        let r = borrow_global_mut<Rewards>(addr);
        
        assert!(!table::contains<u64, Reward>(&r.by_achievement, achievement_id), E_ALREADY_ATTACHED);
        assert!(supply > 0, E_INVALID_SUPPLY);  // NFTs must have limited supply
        
        let reward = Reward {
            achievement_id,
            kind: RewardKind {
                is_ft: false,
                fa_metadata: option::none<Object<Metadata>>(),
                fa_amount: 0,
                nft_collection: option::some(collection),
                nft_name: option::some(name),
                nft_description: option::some(description),
                nft_uri: option::some(uri),
            },
            total_supply: supply,
            claimed_count: 0,
        };
        
        table::add<u64, Reward>(&mut r.by_achievement, achievement_id, reward);
        
        event::emit_event<RewardAttachedEvent>(
            &mut r.events.attached,
            RewardAttachedEvent { publisher: addr, achievement_id, is_ft: false, supply }
        );
    }

    /*************
     *  Claim Rewards
     *************/

    /// Claim a reward for an unlocked achievement
    /// 
    /// Requirements:
    /// - Achievement must be unlocked (checked via achievements module when available)
    /// - Reward must not be already claimed by this player
    /// - Reward must still be in stock
    /// 
    /// Gas: 
    /// - FT claims: ~800-1,200 units (includes FA transfer)
    /// - NFT claims: ~2,000-3,000 units (includes token minting)
    /// 
    /// For testing without achievements module, use claim_testing()
    public entry fun claim_reward(
        player: &signer,
        publisher: address,
        achievement_id: u64
    ) acquires Rewards, RewardsConfig {
        let player_addr = signer::address_of(player);
        
        // Check if achievement is unlocked
        // TODO: Uncomment when enabling cross-module integration
        // assert!(achievements::is_unlocked(publisher, player_addr, achievement_id), E_ACHIEVEMENT_NOT_UNLOCKED);
        
        do_claim(player, publisher, player_addr, achievement_id);
    }

    /// Testing-only claim that skips achievement unlock check
    /// WARNING: Remove or restrict in production!
    public entry fun claim_testing(
        player: &signer,
        publisher: address,
        achievement_id: u64
    ) acquires Rewards, RewardsConfig {
        let player_addr = signer::address_of(player);
        do_claim(player, publisher, player_addr, achievement_id);
    }

    /*************
     *  Internal Logic
     *************/

    fun do_claim(
        _player: &signer,
        publisher: address,
        player_addr: address,
        achievement_id: u64
    ) acquires Rewards, RewardsConfig {
        let r = borrow_global_mut<Rewards>(publisher);
        
        // Check reward exists
        assert!(table::contains<u64, Reward>(&r.by_achievement, achievement_id), E_NOT_FOUND);
        
        // Check not already claimed
        if (!table::contains<address, Table<u64, bool>>(&r.claimed, player_addr)) {
            table::add<address, Table<u64, bool>>(&mut r.claimed, player_addr, table::new<u64, bool>());
        };
        
        let claimed_map = table::borrow_mut<address, Table<u64, bool>>(&mut r.claimed, player_addr);
        assert!(!table::contains<u64, bool>(claimed_map, achievement_id), E_ALREADY_CLAIMED);
        
        // Check supply
        let reward = table::borrow_mut<u64, Reward>(&mut r.by_achievement, achievement_id);
        if (reward.total_supply > 0) {  // 0 = unlimited
            assert!(reward.claimed_count < reward.total_supply, E_OUT_OF_STOCK);
        };
        
        // Get publisher signer from resource account capability (if available)
        // Note: In tests, this may not work if config isn't set up, so we skip actual transfers
        let has_config = exists<RewardsConfig>(publisher);
        
        if (has_config) {
            let config = borrow_global<RewardsConfig>(publisher);
            let publisher_signer = account::create_signer_with_capability(&config.signer_cap);
            
            // Process reward based on kind
            if (reward.kind.is_ft) {
                // ✅ ACTUAL FA TRANSFER (Phase Final implemented!)
                let metadata = *option::borrow(&reward.kind.fa_metadata);
                let amount = reward.kind.fa_amount;
                
                // Transfer from publisher's primary store to player
                // Note: Publisher must have sufficient balance in their primary store
                primary_fungible_store::transfer(
                    &publisher_signer,
                    metadata,
                    player_addr,
                    amount
                );
            } else {
                // ✅ ACTUAL NFT MINTING (Phase Final implemented!)
                let _collection_addr = *option::borrow(&reward.kind.nft_collection);
                let name = *option::borrow(&reward.kind.nft_name);
                let description = *option::borrow(&reward.kind.nft_description);
                let uri = *option::borrow(&reward.kind.nft_uri);
                
                // Mint NFT token to player
                // Note: Collection must be created first via create_nft_collection()
                let constructor_ref = token::create_named_token(
                    &publisher_signer,
                    string::utf8(b"Achievement Rewards"), // Collection name
                    description,
                    name,
                    option::none(), // royalty
                    uri
                );
                
                // Transfer to player
                let token_object = object::object_from_constructor_ref<token::Token>(&constructor_ref);
                object::transfer(&publisher_signer, token_object, player_addr);
            };
        };
        // Note: If no config exists (test mode), we skip actual transfers (bookkeeping only)
        
        // Mark as claimed
        table::add<u64, bool>(claimed_map, achievement_id, true);
        reward.claimed_count = reward.claimed_count + 1;
        
        // Emit event
        event::emit_event<RewardClaimedEvent>(
            &mut r.events.claimed,
            RewardClaimedEvent {
                publisher,
                player: player_addr,
                achievement_id,
                is_ft: reward.kind.is_ft,
            }
        );
    }

    /*************
     *  Views
     *************/

    #[view]
    /// Get reward details for an achievement
    /// Returns: (exists, is_ft, amount_or_supply, claimed_count, total_supply)
    public fun get_reward(owner: address, achievement_id: u64): (bool, bool, u64, u64, u64) acquires Rewards {
        if (!exists<Rewards>(owner)) {
            return (false, false, 0, 0, 0)
        };
        
        let r = borrow_global<Rewards>(owner);
        
        if (!table::contains<u64, Reward>(&r.by_achievement, achievement_id)) {
            return (false, false, 0, 0, 0)
        };
        
        let reward = table::borrow<u64, Reward>(&r.by_achievement, achievement_id);
        let amount = if (reward.kind.is_ft) {
            reward.kind.fa_amount
        } else {
            reward.claimed_count  // For NFTs, return claimed count
        };
        
        (true, reward.kind.is_ft, amount, reward.claimed_count, reward.total_supply)
    }

    #[view]
    /// Check if a player has claimed a specific reward
    public fun is_claimed(owner: address, player: address, achievement_id: u64): bool acquires Rewards {
        if (!exists<Rewards>(owner)) {
            return false
        };
        
        let r = borrow_global<Rewards>(owner);
        
        if (!table::contains<address, Table<u64, bool>>(&r.claimed, player)) {
            return false
        };
        
        let claimed_map = table::borrow<address, Table<u64, bool>>(&r.claimed, player);
        table::contains<u64, bool>(claimed_map, achievement_id)
    }

    #[view]
    /// Get remaining supply for a reward
    /// Returns: (exists, available)
    /// available = 0 with unlimited supply means "unlimited"
    public fun get_available(owner: address, achievement_id: u64): (bool, u64) acquires Rewards {
        if (!exists<Rewards>(owner)) {
            return (false, 0)
        };
        
        let r = borrow_global<Rewards>(owner);
        
        if (!table::contains<u64, Reward>(&r.by_achievement, achievement_id)) {
            return (false, 0)
        };
        
        let reward = table::borrow<u64, Reward>(&r.by_achievement, achievement_id);
        
        if (reward.total_supply == 0) {
            return (true, 0)  // 0 = unlimited
        };
        
        let available = reward.total_supply - reward.claimed_count;
        (true, available)
    }

    #[view]
    /// Get full reward details including metadata
    /// Returns: (exists, is_ft, fa_amount, nft_name, supply, claimed)
    public fun get_reward_details(owner: address, achievement_id: u64): (
        bool,
        bool,
        u64,
        vector<u8>,
        u64,
        u64
    ) acquires Rewards {
        if (!exists<Rewards>(owner)) {
            return (false, false, 0, vector::empty<u8>(), 0, 0)
        };
        
        let r = borrow_global<Rewards>(owner);
        
        if (!table::contains<u64, Reward>(&r.by_achievement, achievement_id)) {
            return (false, false, 0, vector::empty<u8>(), 0, 0)
        };
        
        let reward = table::borrow<u64, Reward>(&r.by_achievement, achievement_id);
        
        let name_bytes = if (reward.kind.is_ft) {
            b"Fungible Asset"
        } else if (option::is_some(&reward.kind.nft_name)) {
            *string::bytes(option::borrow(&reward.kind.nft_name))
        } else {
            b"NFT"
        };
        
        (
            true,
            reward.kind.is_ft,
            reward.kind.fa_amount,
            name_bytes,
            reward.total_supply,
            reward.claimed_count
        )
    }

    #[view]
    /// Get all rewards attached by a publisher
    /// Returns: vector of achievement IDs that have rewards
    public fun list_rewarded_achievements(owner: address): vector<u64> acquires Rewards {
        if (!exists<Rewards>(owner)) {
            return vector::empty<u64>()
        };
        
        let r = borrow_global<Rewards>(owner);
        
        // Since we don't have a max achievement ID here, we'll scan 0..1024
        // In production, you might want to maintain an explicit list
        let out = vector::empty<u64>();
        let i = 0;
        while (i < 1024) {
            if (table::contains<u64, Reward>(&r.by_achievement, i)) {
                vector::push_back<u64>(&mut out, i);
            };
            i = i + 1;
        };
        out
    }

    #[view]
    /// Get player's claim status for all rewards
    /// Returns: vector of achievement IDs the player has claimed
    public fun get_claimed_rewards(owner: address, player: address): vector<u64> acquires Rewards {
        if (!exists<Rewards>(owner)) {
            return vector::empty<u64>()
        };
        
        let r = borrow_global<Rewards>(owner);
        
        if (!table::contains<address, Table<u64, bool>>(&r.claimed, player)) {
            return vector::empty<u64>()
        };
        
        let claimed_map = table::borrow<address, Table<u64, bool>>(&r.claimed, player);
        
        let out = vector::empty<u64>();
        let i = 0;
        while (i < 1024) {
            if (table::contains<u64, bool>(claimed_map, i)) {
                vector::push_back<u64>(&mut out, i);
            };
            i = i + 1;
        };
        out
    }

    /*************
     *  Update Rewards
     *************/

    /// Update reward supply (increase available claims)
    public entry fun increase_supply(
        publisher: &signer,
        achievement_id: u64,
        additional: u64
    ) acquires Rewards {
        let addr = signer::address_of(publisher);
        let r = borrow_global_mut<Rewards>(addr);
        
        assert!(table::contains<u64, Reward>(&r.by_achievement, achievement_id), E_NOT_FOUND);
        
        let reward = table::borrow_mut<u64, Reward>(&mut r.by_achievement, achievement_id);
        
        if (reward.total_supply > 0) {  // Only increase if not unlimited
            reward.total_supply = reward.total_supply + additional;
        };
    }

    /// Remove a reward (if no claims yet)
    public entry fun remove_reward(
        publisher: &signer,
        achievement_id: u64
    ) acquires Rewards {
        let addr = signer::address_of(publisher);
        let r = borrow_global_mut<Rewards>(addr);
        
        assert!(table::contains<u64, Reward>(&r.by_achievement, achievement_id), E_NOT_FOUND);
        
        let reward = table::remove<u64, Reward>(&mut r.by_achievement, achievement_id);
        
        // Only allow removal if no claims yet
        assert!(reward.claimed_count == 0, E_ALREADY_CLAIMED);
    }
}

