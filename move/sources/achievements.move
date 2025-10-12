module sigil::achievements {
    use std::option::{Self, Option};
    use std::vector;
    use aptos_std::table::{Self, Table};
    use aptos_framework::signer;
    use aptos_framework::account;
    use aptos_framework::event;
    use sigil::roles;

    /*************
     *  Types
     *************/

    /// Achievement condition with flexible trigger types
    /// (keeps this module independent; no cross-module validation)
    struct Condition has store, drop {
        // None  => applies to any game
        // Some  => only applies to that game_id
        game_id: Option<u64>,
        
        // Basic score threshold
        min_score: u64,
        
        // Advanced conditions (all must be satisfied if > 0)
        // Set to 0 to ignore that condition
        
        // Number of times player must achieve min_score (for "consistency" achievements)
        // Example: "Score 1000+ three times" = min_score: 1000, required_count: 3
        required_count: u64,
        
        // Minimum number of total submissions (for "dedication" achievements)
        // Example: "Play 100 times" = min_submissions: 100
        min_submissions: u64,
    }

    /// Achievement definition (publisher-owned)
    struct Achievement has store, drop {
        id: u64,
        title: vector<u8>,        // utf8 title (String clone-free for events)
        description: vector<u8>,  // utf8 description
        condition: Condition,
        // optional cosmetics (kept as utf8 bytes, could be URIs)
        badge_uri: Option<vector<u8>>,
    }

    /// Event when a player unlocks an achievement
    struct AchievementUnlockedEvent has drop, store {
        publisher: address,
        player: address,
        achievement_id: u64,
    }

    /// Event handle container
    struct Events has key, store {
        unlocked: event::EventHandle<AchievementUnlockedEvent>,
    }

    /// Progress tracking for advanced achievement conditions
    struct Progress has store, drop {
        // Count of times player achieved the min_score threshold
        threshold_count: u64,
        // Total number of score submissions (regardless of threshold)
        total_submissions: u64,
    }

    /// Per-publisher registry & state
    /// - `catalog`: id -> achievement config
    /// - `unlocked`: player -> (id -> bool)
    /// - `progress`: player -> (achievement_id -> Progress) for tracking advanced conditions
    /// - `next_id`: next achievement id to mint
    struct Achievements has key {
        next_id: u64,
        catalog: Table<u64, Achievement>,
        unlocked: Table<address, Table<u64, bool>>,
        progress: Table<address, Table<u64, Progress>>,
        events: Events,
    }

    /*************
     *  Constants
     *************/
    // Maximum achievement ID to scan when querying unlocked achievements
    // This prevents unbounded iteration. Increase if you need more achievements per player.
    // Typical use: 10-100 achievements per publisher, so 1024 is generous.
    const MAX_ACHIEVEMENT_SCAN: u64 = 1024;

    /*************
     *  Errors
     *************/
    const E_ALREADY_INIT: u64 = 0;
    const E_NOT_FOUND: u64 = 1;
    const E_EXISTS: u64 = 2;
    const E_NO_PERMISSION: u64 = 3;

    /*************
     *  Lifecycle (publisher)
     *************/

    /// One-time initializer under the publisher.
    public entry fun init_achievements(publisher: &signer) {
        let addr = signer::address_of(publisher);
        assert!(!exists<Achievements>(addr), E_ALREADY_INIT);

        move_to<Achievements>(publisher, Achievements {
            next_id: 0,
            catalog: table::new<u64, Achievement>(),
            unlocked: table::new<address, Table<u64, bool>>(),
            progress: table::new<address, Table<u64, Progress>>(),
            events: Events { unlocked: account::new_event_handle<AchievementUnlockedEvent>(publisher) },
        });
    }

    /// Create a basic achievement (simple score threshold, applies to any game)
    /// For advanced conditions, use create_advanced() or create_with_game_advanced()
    public entry fun create(
        publisher: &signer,
        title: vector<u8>,
        description: vector<u8>,
        min_score: u64,
        // pass badge_uri as empty vector for None; non-empty for Some
        badge_uri: vector<u8>
    ) acquires Achievements {
        let owner = signer::address_of(publisher);
        
        // Optional role check: if roles is initialized, verify permission
        if (roles::is_initialized(owner)) {
            assert!(
                roles::can_manage_achievements(owner, owner),
                E_NO_PERMISSION
            );
        };
        
        let a = borrow_global_mut<Achievements>(owner);

        let id = a.next_id;
        a.next_id = id + 1;

        let ach = Achievement {
            id,
            title,
            description,
            condition: Condition { 
                game_id: option::none<u64>(), 
                min_score,
                required_count: 0,  // 0 = ignore this condition
                min_submissions: 0, // 0 = ignore this condition
            },
            badge_uri: if (vector::length(&badge_uri) == 0) option::none<vector<u8>>() else option::some<vector<u8>>(badge_uri),
        };

        table::add<u64, Achievement>(&mut a.catalog, id, ach);
    }

    /// Create a basic achievement for a specific game (simple score threshold)
    public entry fun create_with_game(
        publisher: &signer,
        title: vector<u8>,
        description: vector<u8>,
        game_id: u64,
        min_score: u64,
        badge_uri: vector<u8>
    ) acquires Achievements {
        let owner = signer::address_of(publisher);
        
        // Optional role check: if roles is initialized, verify permission
        if (roles::is_initialized(owner)) {
            assert!(
                roles::can_manage_achievements(owner, owner),
                E_NO_PERMISSION
            );
        };
        
        let a = borrow_global_mut<Achievements>(owner);

        let id = a.next_id;
        a.next_id = id + 1;

        let ach = Achievement {
            id,
            title,
            description,
            condition: Condition { 
                game_id: option::some<u64>(game_id), 
                min_score,
                required_count: 0,
                min_submissions: 0,
            },
            badge_uri: if (vector::length(&badge_uri) == 0) option::none<vector<u8>>() else option::some<vector<u8>>(badge_uri),
        };

        table::add<u64, Achievement>(&mut a.catalog, id, ach);
    }

    /// Create an advanced achievement with all condition types (any game)
    /// Examples:
    /// - "Score 1000+ three times": min_score=1000, required_count=3, min_submissions=0
    /// - "Play 100 times": min_score=0, required_count=0, min_submissions=100
    /// - "Score 500+ in 50 games": min_score=500, required_count=50, min_submissions=50
    public entry fun create_advanced(
        publisher: &signer,
        title: vector<u8>,
        description: vector<u8>,
        min_score: u64,
        required_count: u64,
        min_submissions: u64,
        badge_uri: vector<u8>
    ) acquires Achievements {
        let owner = signer::address_of(publisher);
        
        // Optional role check: if roles is initialized, verify permission
        if (roles::is_initialized(owner)) {
            assert!(
                roles::can_manage_achievements(owner, owner),
                E_NO_PERMISSION
            );
        };
        
        let a = borrow_global_mut<Achievements>(owner);

        let id = a.next_id;
        a.next_id = id + 1;

        let ach = Achievement {
            id,
            title,
            description,
            condition: Condition {
                game_id: option::none<u64>(),
                min_score,
                required_count,
                min_submissions,
            },
            badge_uri: if (vector::length(&badge_uri) == 0) option::none<vector<u8>>() else option::some<vector<u8>>(badge_uri),
        };

        table::add<u64, Achievement>(&mut a.catalog, id, ach);
    }

    /// Create an advanced achievement for a specific game
    public entry fun create_with_game_advanced(
        publisher: &signer,
        title: vector<u8>,
        description: vector<u8>,
        game_id: u64,
        min_score: u64,
        required_count: u64,
        min_submissions: u64,
        badge_uri: vector<u8>
    ) acquires Achievements {
        let owner = signer::address_of(publisher);
        
        // Optional role check: if roles is initialized, verify permission
        if (roles::is_initialized(owner)) {
            assert!(
                roles::can_manage_achievements(owner, owner),
                E_NO_PERMISSION
            );
        };
        
        let a = borrow_global_mut<Achievements>(owner);

        let id = a.next_id;
        a.next_id = id + 1;

        let ach = Achievement {
            id,
            title,
            description,
            condition: Condition {
                game_id: option::some<u64>(game_id),
                min_score,
                required_count,
                min_submissions,
            },
            badge_uri: if (vector::length(&badge_uri) == 0) option::none<vector<u8>>() else option::some<vector<u8>>(badge_uri),
        };

        table::add<u64, Achievement>(&mut a.catalog, id, ach);
    }

    /*************
     *  Unlock paths
     *************/

    /// Admin/publisher can grant an achievement directly.
    public entry fun grant(
        publisher: &signer,
        player: address,
        achievement_id: u64
    ) acquires Achievements {
        let owner = signer::address_of(publisher);
        
        // Optional role check: if roles is initialized, verify permission
        if (roles::is_initialized(owner)) {
            assert!(
                roles::can_manage_achievements(owner, owner),
                E_NO_PERMISSION
            );
        };
        
        do_unlock(owner, player, achievement_id)
    }

    /// Entry wrapper for CLI testing - allows direct score submission to trigger achievements
    /// In production, call on_score() from game_platform::submit_score() instead
    public entry fun submit_score_direct(
        _caller: &signer,
        publisher: address,
        player: address,
        game_id: u64,
        score: u64
    ) acquires Achievements {
        on_score(publisher, player, game_id, score);
    }

    /// Hook you'll call later from score flow. For now, you can also call it
    /// from CLI (it's `public`, not `entry`). Independent: no imports required.
    /// Logic: if achievement has no game filter OR matches `game_id`, and
    /// `score >= min_score` → unlock.
    /// 
    /// Gas Considerations:
    /// - Iterates through ALL achievements in catalog to check unlock conditions
    /// - Cost scales linearly with number of achievements (O(n))
    /// - Acceptable for typical use: 10-100 achievements per publisher
    /// - For large catalogs (>500), consider event-driven or indexed approaches
    /// - Each unlock triggers an event for off-chain indexing
    public fun on_score(
        publisher: address,
        player: address,
        game_id: u64,
        score: u64
    ) acquires Achievements {
        let a = borrow_global_mut<Achievements>(publisher);
        // Iterate catalog to check which achievements this score affects
        let ids = get_achievement_ids(a);
        let n = vector::length<u64>(&ids);
        let i = 0;
        
        while (i < n) {
            let id = *vector::borrow<u64>(&ids, i);
            
            // Skip if already unlocked
            if (is_achievement_unlocked(&a.unlocked, player, id)) {
                i = i + 1;
                continue
            };
            
            let ach = table::borrow<u64, Achievement>(&a.catalog, id);
            let cond = &ach.condition;

            // Check game filter
            let game_matches = if (option::is_none<u64>(&cond.game_id)) {
                true
            } else {
                let gid = *option::borrow<u64>(&cond.game_id);
                gid == game_id
            };

            if (!game_matches) {
                i = i + 1;
                continue
            };

            // Update progress tracking
            ensure_player_progress(&mut a.progress, player);
            let prog_table = table::borrow_mut<address, Table<u64, Progress>>(&mut a.progress, player);
            
            if (!table::contains<u64, Progress>(prog_table, id)) {
                table::add<u64, Progress>(prog_table, id, Progress { threshold_count: 0, total_submissions: 0 });
            };
            
            let prog = table::borrow_mut<u64, Progress>(prog_table, id);
            prog.total_submissions = prog.total_submissions + 1;
            
            if (score >= cond.min_score) {
                prog.threshold_count = prog.threshold_count + 1;
            };

            // Check if all conditions are met for unlock
            let should_unlock = (cond.min_score == 0 || score >= cond.min_score) &&
                               (cond.required_count == 0 || prog.threshold_count >= cond.required_count) &&
                               (cond.min_submissions == 0 || prog.total_submissions >= cond.min_submissions);

            if (should_unlock) {
                ensure_player_map(&mut a.unlocked, player);
                let m = table::borrow_mut<address, Table<u64, bool>>(&mut a.unlocked, player);
                table::add<u64, bool>(m, id, true);
                event::emit_event<AchievementUnlockedEvent>(
                    &mut a.events.unlocked,
                    AchievementUnlockedEvent { publisher, player, achievement_id: id }
                );
            };

            i = i + 1;
        };
    }

    fun do_unlock(owner: address, player: address, id: u64) acquires Achievements {
        let a = borrow_global_mut<Achievements>(owner);
        assert!(table::contains<u64, Achievement>(&a.catalog, id), E_NOT_FOUND);
        ensure_player_map(&mut a.unlocked, player);

        let m = table::borrow_mut<address, Table<u64, bool>>(&mut a.unlocked, player);
        if (!table::contains<u64, bool>(m, id)) {
            table::add<u64, bool>(m, id, true);
            event::emit_event<AchievementUnlockedEvent>(
                &mut a.events.unlocked,
                AchievementUnlockedEvent { publisher: owner, player, achievement_id: id }
            );
        };
    }

    fun ensure_player_map(
        unlocked: &mut Table<address, Table<u64, bool>>,
        player: address
    ) {
        if (!table::contains<address, Table<u64, bool>>(unlocked, player)) {
            let inner = table::new<u64, bool>();
            table::add<address, Table<u64, bool>>(unlocked, player, inner);
        };
    }

    fun ensure_player_progress(
        progress: &mut Table<address, Table<u64, Progress>>,
        player: address
    ) {
        if (!table::contains<address, Table<u64, Progress>>(progress, player)) {
            let inner = table::new<u64, Progress>();
            table::add<address, Table<u64, Progress>>(progress, player, inner);
        };
    }

    fun is_achievement_unlocked(
        unlocked: &Table<address, Table<u64, bool>>,
        player: address,
        achievement_id: u64
    ): bool {
        if (!table::contains<address, Table<u64, bool>>(unlocked, player)) {
            return false
        };
        let inner = table::borrow<address, Table<u64, bool>>(unlocked, player);
        table::contains<u64, bool>(inner, achievement_id)
    }

    /*************
     *  Views
     *************/

    #[view]
    public fun achievement_count(owner: address): u64 acquires Achievements {
        if (!exists<Achievements>(owner)) { return 0 };
        borrow_global<Achievements>(owner).next_id
    }

    #[view]
    /// Returns simplified catalog for basic use cases
    /// Returns: (id[], title_bytes[][], desc_bytes[][], min_score[], game_id_opt[])
    /// For full details including advanced conditions, use get_achievement(id)
    public fun list_catalog(owner: address): (
        vector<u64>, vector<vector<u8>>, vector<vector<u8>>, vector<u64>, vector<Option<u64>>
    ) acquires Achievements {
        let a = borrow_global<Achievements>(owner);
        let ids = get_achievement_ids(a);

        let n = vector::length<u64>(&ids);
        let ids_out = vector::empty<u64>();
        let titles = vector::empty<vector<u8>>();
        let descs = vector::empty<vector<u8>>();
        let mins  = vector::empty<u64>();
        let gids  = vector::empty<Option<u64>>();

        let i = 0;
        while (i < n) {
            let id = *vector::borrow<u64>(&ids, i);
            let ach = table::borrow<u64, Achievement>(&a.catalog, id);

            vector::push_back<u64>(&mut ids_out, ach.id);
            vector::push_back<vector<u8>>(&mut titles, ach.title);
            vector::push_back<vector<u8>>(&mut descs, ach.description);
            vector::push_back<u64>(&mut mins, ach.condition.min_score);
            vector::push_back<Option<u64>>(&mut gids, ach.condition.game_id);

            i = i + 1;
        };

        (ids_out, titles, descs, mins, gids)
    }

    #[view]
    /// Return sorted (ascending) list of unlocked ids for a player.
    public fun unlocked_for(owner: address, player: address): vector<u64> acquires Achievements {
        let a = borrow_global<Achievements>(owner);

        if (!table::contains<address, Table<u64, bool>>(&a.unlocked, player)) {
            return vector::empty<u64>()
        };
        let inner = table::borrow<address, Table<u64, bool>>(&a.unlocked, player);
        keys_sorted_u64(inner)
    }

    #[view]
    /// Get achievement details including badge URI
    /// Returns: (id, title, description, min_score, game_id_opt, badge_uri_opt)
    public fun get_achievement(owner: address, achievement_id: u64): (
        u64,
        vector<u8>,
        vector<u8>,
        u64,
        Option<u64>,
        Option<vector<u8>>
    ) acquires Achievements {
        let a = borrow_global<Achievements>(owner);
        assert!(table::contains<u64, Achievement>(&a.catalog, achievement_id), E_NOT_FOUND);
        
        let ach = table::borrow<u64, Achievement>(&a.catalog, achievement_id);
        (
            ach.id,
            ach.title,
            ach.description,
            ach.condition.min_score,
            ach.condition.game_id,
            ach.badge_uri
        )
    }

    #[view]
    /// Check if a player has unlocked a specific achievement
    public fun is_unlocked(owner: address, player: address, achievement_id: u64): bool acquires Achievements {
        let a = borrow_global<Achievements>(owner);
        
        if (!table::contains<address, Table<u64, bool>>(&a.unlocked, player)) {
            return false
        };
        
        let inner = table::borrow<address, Table<u64, bool>>(&a.unlocked, player);
        table::contains<u64, bool>(inner, achievement_id)
    }

    #[view]
    /// Get player's progress toward a specific achievement
    /// Returns: (threshold_count, total_submissions, unlocked)
    /// Use this to show progress bars like "Score 1000+ three times: 2/3"
    public fun get_progress(owner: address, player: address, achievement_id: u64): (u64, u64, bool) acquires Achievements {
        let a = borrow_global<Achievements>(owner);
        
        let unlocked = is_achievement_unlocked(&a.unlocked, player, achievement_id);
        
        if (!table::contains<address, Table<u64, Progress>>(&a.progress, player)) {
            return (0, 0, unlocked)
        };
        
        let prog_table = table::borrow<address, Table<u64, Progress>>(&a.progress, player);
        
        if (!table::contains<u64, Progress>(prog_table, achievement_id)) {
            return (0, 0, unlocked)
        };
        
        let prog = table::borrow<u64, Progress>(prog_table, achievement_id);
        (prog.threshold_count, prog.total_submissions, unlocked)
    }

    /*************
     *  Small helpers
     *************/

    /// Get all active achievement IDs from the catalog
    /// 
    /// Implementation:
    /// - Scans sequential IDs from 0 to next_id
    /// - Returns only IDs that exist in the catalog
    /// - Automatically bounded by next_id (total achievements created)
    /// 
    /// Performance: O(n) where n = next_id (number of achievements ever created)
    /// Gas cost: Acceptable for typical use (10-100 achievements)
    /// 
    /// Alternative for scale: If you need 1000+ achievements, consider:
    /// - Maintaining an explicit vector of active IDs
    /// - Using pagination for catalog queries
    /// - Filtering by game_id before scanning
    fun get_achievement_ids(a: &Achievements): vector<u64> {
        let out = vector::empty<u64>();
        let n = a.next_id;
        let i = 0;
        while (i < n) {
            if (table::contains<u64, Achievement>(&a.catalog, i)) {
                vector::push_back<u64>(&mut out, i);
            };
            i = i + 1;
        };
        out
    }

    /// Collect and sort unlocked achievement IDs for a player
    /// 
    /// Implementation note:
    /// - Scans IDs from 0 to MAX_ACHIEVEMENT_SCAN (currently 1024)
    /// - This bounded scan prevents unbounded gas costs
    /// - If you need more than 1024 achievements, increase MAX_ACHIEVEMENT_SCAN
    /// - For very large scales (1000+), consider maintaining an explicit key vector
    /// 
    /// Performance: O(n log n) where n = number of unlocked achievements (typically < 100)
    fun keys_sorted_u64(m: &Table<u64, bool>): vector<u64> {
        // Collect all unlocked achievement IDs within the scan window
        let out = vector::empty<u64>();
        let i = 0;
        while (i < MAX_ACHIEVEMENT_SCAN) {
            if (table::contains<u64, bool>(m, i)) {
                vector::push_back<u64>(&mut out, i);
            };
            i = i + 1;
        };

        // insertion sort
        let n = vector::length<u64>(&out);
        let k = 1;
        while (k < n) {
            let j = k;
            while (j > 0 && *vector::borrow<u64>(&out, j) < *vector::borrow<u64>(&out, j-1)) {
                let tmp = *vector::borrow<u64>(&out, j);
                *vector::borrow_mut<u64>(&mut out, j) = *vector::borrow<u64>(&out, j-1);
                *vector::borrow_mut<u64>(&mut out, j-1) = tmp;
                j = j - 1;
            };
            k = k + 1;
        };
        out
    }
}
