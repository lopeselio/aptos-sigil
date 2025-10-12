module sigil::leaderboard {
    use std::vector;
    use aptos_std::table::{Self, Table};
    use aptos_framework::signer;
    // use sigil::game_platform;  // Temporarily disabled for independent deployment
    use sigil::roles;

    /*************
     *  Types
     *************/

    /// Configuration for a leaderboard (mirrors the SOAR ideas in a compact form)
    struct Config has store, drop {
        game_id: u64,
        decimals: u8,
        min_score: u64,
        max_score: u64,
        is_ascending: bool,          // true => lower is better
        allow_multiple: bool,        // if false: only keep best per player
        scores_to_retain: u64,       // how many entries to keep in top list
    }

    /// A single leaderboard under a publisher
    struct Leaderboard has store {
        id: u64,
        config: Config,
        /// best score per player (used to ensure O(logN)-ish updates to top list)
        best_by_player: Table<address, u64>,
        /// sorted top N (address, score), order controlled by `is_ascending`
        top_entries_players: vector<address>,
        top_entries_scores: vector<u64>,
    }

    /// Per-publisher registry of leaderboards
    struct Leaderboards has key {
        next_id: u64,
        by_id: Table<u64, Leaderboard>,
    }

    /*************
     *  Errors
     *************/
    const E_ALREADY_INIT: u64 = 0;
    const E_NOT_FOUND: u64 = 1;
    const E_ID_EXISTS: u64 = 2;
    // const E_GAME_NOT_FOUND: u64 = 3;  // Reserved for future use
    const E_NO_PERMISSION: u64 = 4;

    /*************
     *  Publisher lifecycle
     *************/

    /// Initialize the Leaderboards resource for the publisher (one-time).
    public entry fun init_leaderboards(publisher: &signer) {
        let addr = signer::address_of(publisher);
        assert!(!exists<Leaderboards>(addr), E_ALREADY_INIT);

        move_to<Leaderboards>(publisher, Leaderboards {
            next_id: 0,
            by_id: table::new<u64, Leaderboard>(),
        });
    }

    /// Create a new leaderboard. Assigns sequential id and stores config.
    /// Keep it simple: no return (query via `get_leaderboard_count` or `get_leaderboard_config`).
    public entry fun create_leaderboard(
        publisher: &signer,
        game_id: u64,
        decimals: u8,
        min_score: u64,
        max_score: u64,
        is_ascending: bool,
        allow_multiple: bool,
        scores_to_retain: u64
    ) acquires Leaderboards {
        let owner = signer::address_of(publisher);
        
        // Optional role check: if roles is initialized, verify permission
        if (roles::is_initialized(owner)) {
            assert!(
                roles::can_manage_leaderboards(owner, owner),
                E_NO_PERMISSION
            );
        };
        
        // Validate that the game exists in game_platform
        // assert!(game_platform::has_game(owner, game_id), E_GAME_NOT_FOUND);  // Temporarily disabled
        
        let regs = borrow_global_mut<Leaderboards>(owner);

        let id = regs.next_id;
        regs.next_id = id + 1;

        let lb = Leaderboard {
            id,
            config: Config {
                game_id,
                decimals,
                min_score,
                max_score,
                is_ascending,
                allow_multiple,
                scores_to_retain,
            },
            best_by_player: table::new<address, u64>(),
            top_entries_players: vector::empty<address>(),
            top_entries_scores: vector::empty<u64>(),
        };

        table::add<u64, Leaderboard>(&mut regs.by_id, id, lb);
    }

    /*************
     *  Score ingestion (callable from other modules)
     *************/

    /// Update leaderboard state when a score is submitted.
    /// - `publisher` is the owner of this leaderboard.
    /// - `leaderboard_id` is the target.
    /// - `player` & `score` are from the original submission.
    public fun on_score(
        publisher: address,
        leaderboard_id: u64,
        player: address,
        score: u64
    ) acquires Leaderboards {
        let regs = borrow_global_mut<Leaderboards>(publisher);
        assert!(table::contains<u64, Leaderboard>(&regs.by_id, leaderboard_id), E_NOT_FOUND);
        let lb = table::borrow_mut<u64, Leaderboard>(&mut regs.by_id, leaderboard_id);

        // Respect score gates.
        let cfg = &lb.config;
        if (score < cfg.min_score || score > cfg.max_score) {
            return
        };

        // If multiple scores per player are *not* allowed, hold only the best.
        if (!cfg.allow_multiple) {
            if (table::contains<address, u64>(&lb.best_by_player, player)) {
                let best_ref = table::borrow_mut<address, u64>(&mut lb.best_by_player, player);
                let current = *best_ref;
                if (!is_better(score, current, cfg.is_ascending)) {
                    // Not better -> nothing to do.
                    return
                };
                // Update best and reflect in top list.
                *best_ref = score;
                // Update (player, score) in the top_entries vector and re-order.
                upsert_and_resort_top(&mut lb.top_entries_players, &mut lb.top_entries_scores, player, score, cfg.is_ascending, cfg.scores_to_retain);
                return
            } else {
                table::add<address, u64>(&mut lb.best_by_player, player, score);
                upsert_and_resort_top(&mut lb.top_entries_players, &mut lb.top_entries_scores, player, score, cfg.is_ascending, cfg.scores_to_retain);
                return
            }
        };

        // allow_multiple == true: we still want the top list to keep only the best occurrence per player.
        // Compare against their tracked best (if any), and update if the new one is better.
        if (table::contains<address, u64>(&lb.best_by_player, player)) {
            let best_ref2 = table::borrow_mut<address, u64>(&mut lb.best_by_player, player);
            let cur2 = *best_ref2;
            if (is_better(score, cur2, cfg.is_ascending)) {
                *best_ref2 = score;
                upsert_and_resort_top(&mut lb.top_entries_players, &mut lb.top_entries_scores, player, score, cfg.is_ascending, cfg.scores_to_retain);
            }
        } else {
            table::add<address, u64>(&mut lb.best_by_player, player, score);
            upsert_and_resort_top(&mut lb.top_entries_players, &mut lb.top_entries_scores, player, score, cfg.is_ascending, cfg.scores_to_retain);
        };
    }

    /*************
     *  Testing & Integration Helpers
     *************/

    /// Entry wrapper for testing - allows CLI to submit scores directly to leaderboard
    /// In production, call on_score() from game_platform::submit_score() instead
    public entry fun submit_score_direct(
        _caller: &signer,
        publisher: address,
        leaderboard_id: u64,
        player: address,
        score: u64
    ) acquires Leaderboards {
        // In production, you might want access control here
        // For now, anyone can submit scores for testing
        on_score(publisher, leaderboard_id, player, score);
    }

    /*************
     *  Views
     *************/

    #[view]
    public fun get_leaderboard_count(owner: address): u64 acquires Leaderboards {
        if (!exists<Leaderboards>(owner)) { return 0 };
        borrow_global<Leaderboards>(owner).next_id
    }

    #[view]
    public fun get_leaderboard_config(
        owner: address,
        leaderboard_id: u64
    ): (u64, u8, u64, u64, bool, bool, u64) acquires Leaderboards {
        let regs = borrow_global<Leaderboards>(owner);
        let lb = table::borrow<u64, Leaderboard>(&regs.by_id, leaderboard_id);
        let c = &lb.config;
        (c.game_id, c.decimals, c.min_score, c.max_score, c.is_ascending, c.allow_multiple, c.scores_to_retain)
    }

    #[view]
    /// Returns two aligned vectors: players[i], scores[i]
    public fun get_top_entries(
        owner: address,
        leaderboard_id: u64
    ): (vector<address>, vector<u64>) acquires Leaderboards {
        let regs = borrow_global<Leaderboards>(owner);
        let lb = table::borrow<u64, Leaderboard>(&regs.by_id, leaderboard_id);
        // clone vectors for return
        (clone_addresses(&lb.top_entries_players), clone_u64s(&lb.top_entries_scores))
    }

    /*************
     *  Helpers
     *************/

    fun is_better(a: u64, b: u64, is_ascending: bool): bool {
        if (is_ascending) { a < b } else { a > b }
    }

    /// Insert or update player's score in the sorted arrays, then trim to N.
    fun upsert_and_resort_top(
        players: &mut vector<address>,
        scores: &mut vector<u64>,
        player: address,
        score: u64,
        is_ascending: bool,
        retain: u64
    ) {
        let len = vector::length<address>(players);
        let idx = 0;
        let found = false;

        // If player exists, update their score.
        while (idx < len) {
            if (*vector::borrow<address>(players, idx) == player) {
                *vector::borrow_mut<u64>(scores, idx) = score;
                found = true;
                break
            };
            idx = idx + 1;
        };

        if (!found) {
            vector::push_back<address>(players, player);
            vector::push_back<u64>(scores, score);
        };

        // Re-position the (possibly updated) entry via insertion-sort style bubbling.
        let n = vector::length<address>(players);
        if (n == 0) { return };

        // Find the index where the player currently sits.
        let i = 0;
        while (i < n) {
            if (*vector::borrow<address>(players, i) == player) { break };
            i = i + 1;
        };

        // Bubble up while the order is “more optimal”.
        while (i > 0) {
            let s_prev = *vector::borrow<u64>(scores, i - 1);
            let s_here = *vector::borrow<u64>(scores, i);
            if (is_better(s_here, s_prev, is_ascending)) {
                swap(players, i, i - 1);
                swap_u64(scores, i, i - 1);
                i = i - 1;
            } else { break };
        };

        // Bubble down if needed.
        while (i + 1 < n) {
            let s_here2 = *vector::borrow<u64>(scores, i);
            let s_next = *vector::borrow<u64>(scores, i + 1);
            if (is_better(s_next, s_here2, is_ascending)) {
                swap(players, i, i + 1);
                swap_u64(scores, i, i + 1);
                i = i + 1;
            } else { break };
        };

        // Trim to retain
        let m = vector::length<address>(players);
        while (m > retain) {
            vector::pop_back<address>(players);
            vector::pop_back<u64>(scores);
            m = m - 1;
        };
    }

    fun swap<T: copy + drop>(v: &mut vector<T>, i: u64, j: u64) {
        let tmp = *vector::borrow<T>(v, i);
        *vector::borrow_mut<T>(v, i) = *vector::borrow<T>(v, j);
        *vector::borrow_mut<T>(v, j) = tmp;
    }

    fun swap_u64(v: &mut vector<u64>, i: u64, j: u64) {
        let tmp = *vector::borrow<u64>(v, i);
        *vector::borrow_mut<u64>(v, i) = *vector::borrow<u64>(v, j);
        *vector::borrow_mut<u64>(v, j) = tmp;
    }

    fun clone_u64s(src: &vector<u64>) : vector<u64> {
        let out = vector::empty<u64>();
        let n = vector::length<u64>(src);
        let i = 0;
        while (i < n) {
            vector::push_back<u64>(&mut out, *vector::borrow<u64>(src, i));
            i = i + 1;
        };
        out
    }

    fun clone_addresses(src: &vector<address>) : vector<address> {
        let out = vector::empty<address>();
        let n = vector::length<address>(src);
        let i = 0;
        while (i < n) {
            vector::push_back<address>(&mut out, *vector::borrow<address>(src, i));
            i = i + 1;
        };
        out
    }
}
