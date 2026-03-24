/// Seasons Module - Temporal Competition & Engagement System
///
/// Enables publishers to create time-bounded competitive seasons with:
/// - Start and end timestamps
/// - Season-specific leaderboards
/// - Seasonal achievements
/// - Prize pool distribution
/// - Isolated data per season
///
/// Use case: Monthly tournaments, battle passes, seasonal rankings
module sigil::seasons {
    use std::signer;
    use std::vector;
    use std::string::{Self, String};
    use aptos_std::table::{Self, Table};
    use aptos_framework::timestamp;
    use aptos_framework::account;
    use aptos_framework::event::{Self, EventHandle};
    use sigil::roles;
    use sigil::game_platform;
    use sigil::leaderboard;
    use sigil::achievements;

    /************
     * Constants
     ************/

    const MAX_SEASON_DURATION: u64 = 7776000; // 90 days in seconds

    /************
     * Errors
     ************/

    const E_NOT_INITIALIZED: u64 = 0;
    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_SEASON_NOT_FOUND: u64 = 2;
    const E_SEASON_ALREADY_STARTED: u64 = 3;
    const E_SEASON_NOT_STARTED: u64 = 4;
    const E_SEASON_ENDED: u64 = 5;
    const E_INVALID_DURATION: u64 = 6;
    const E_NO_PERMISSION: u64 = 7;

    /************
     * Structs
     ************/

    /// Status of a season
    struct SeasonStatus has store, drop {
        upcoming: bool,
        active: bool,
        ended: bool,
    }

    /// A competitive season with time bounds
    struct Season has store, drop {
        id: u64,
        name: String,
        start_time: u64,        // Unix timestamp (seconds)
        end_time: u64,          // Unix timestamp (seconds)
        leaderboard_id: u64,    // Associated leaderboard
        achievement_ids: vector<u64>, // Season-specific achievements
        prize_pool: u64,        // Total APT for prizes
        is_finalized: bool,     // Prize distribution done
    }

    /// Per-season player scores (isolated from other seasons)
    struct SeasonScores has store {
        // game_id -> player -> best_score
        scores: Table<u64, Table<address, u64>>,
    }

    /// Registry of all seasons for a publisher
    struct Seasons has key {
        publisher: address,
        current_season_id: u64, // active season id (may be 0 when season 0 is current)
        has_active_season: bool, // disambiguates "no current season" vs "current is id 0"
        next_id: u64,
        seasons: Table<u64, Season>,
        // Season data isolation
        season_scores: Table<u64, SeasonScores>,
        events: SeasonEvents,
    }

    /// Events
    struct SeasonCreatedEvent has drop, store {
        publisher: address,
        season_id: u64,
        name: String,
        start_time: u64,
        end_time: u64,
    }

    struct SeasonStartedEvent has drop, store {
        publisher: address,
        season_id: u64,
    }

    struct SeasonEndedEvent has drop, store {
        publisher: address,
        season_id: u64,
    }

    struct SeasonScoreEvent has drop, store {
        publisher: address,
        season_id: u64,
        player: address,
        game_id: u64,
        score: u64,
    }

    struct SeasonEvents has store {
        created: EventHandle<SeasonCreatedEvent>,
        started: EventHandle<SeasonStartedEvent>,
        ended: EventHandle<SeasonEndedEvent>,
        scores: EventHandle<SeasonScoreEvent>,
    }

    /************
     * Lifecycle
     ************/

    /// Initialize seasons system for a publisher
    public entry fun init_seasons(publisher: &signer) {
        let addr = signer::address_of(publisher);
        assert!(!exists<Seasons>(addr), E_ALREADY_INITIALIZED);

        move_to(publisher, Seasons {
            publisher: addr,
            current_season_id: 0,
            has_active_season: false,
            next_id: 0,
            seasons: table::new(),
            season_scores: table::new(),
            events: SeasonEvents {
                created: account::new_event_handle<SeasonCreatedEvent>(publisher),
                started: account::new_event_handle<SeasonStartedEvent>(publisher),
                ended: account::new_event_handle<SeasonEndedEvent>(publisher),
                scores: account::new_event_handle<SeasonScoreEvent>(publisher),
            },
        });
    }

    /************
     * Season Management
     ************/

    /// Create a new season (upcoming)
    /// Times are in Unix seconds (use Date.now() / 1000 in JS)
    public entry fun create_season(
        actor: &signer,
        publisher: address,
        name: String,
        start_time: u64,
        end_time: u64,
        leaderboard_id: u64,
        prize_pool: u64
    ) acquires Seasons {
        let caller = signer::address_of(actor);
        assert!(exists<Seasons>(publisher), E_NOT_INITIALIZED);

        if (roles::is_initialized(publisher)) {
            assert!(roles::can_manage_leaderboards(publisher, caller), E_NO_PERMISSION);
        } else {
            assert!(caller == publisher, E_NO_PERMISSION);
        };

        let seasons = borrow_global_mut<Seasons>(publisher);
        let now = timestamp::now_seconds();

        // Validate times
        assert!(start_time >= now, E_INVALID_DURATION);
        assert!(end_time > start_time, E_INVALID_DURATION);
        assert!(end_time - start_time <= MAX_SEASON_DURATION, E_INVALID_DURATION);

        let id = seasons.next_id;
        seasons.next_id = id + 1;

        let season = Season {
            id,
            name,
            start_time,
            end_time,
            leaderboard_id,
            achievement_ids: vector::empty(),
            prize_pool,
            is_finalized: false,
        };

        table::add(&mut seasons.seasons, id, season);

        // Initialize empty score tracking
        table::add(&mut seasons.season_scores, id, SeasonScores {
            scores: table::new(),
        });

        event::emit_event(
            &mut seasons.events.created,
            SeasonCreatedEvent { publisher, season_id: id, name, start_time, end_time }
        );
    }

    /// Start a season manually (or it auto-starts at start_time)
    /// Sets it as the current active season
    public entry fun start_season(
        actor: &signer,
        publisher: address,
        season_id: u64
    ) acquires Seasons {
        let caller = signer::address_of(actor);
        assert!(exists<Seasons>(publisher), E_NOT_INITIALIZED);

        if (roles::is_initialized(publisher)) {
            assert!(roles::can_manage_leaderboards(publisher, caller), E_NO_PERMISSION);
        } else {
            assert!(caller == publisher, E_NO_PERMISSION);
        };

        let seasons = borrow_global_mut<Seasons>(publisher);
        assert!(table::contains(&seasons.seasons, season_id), E_SEASON_NOT_FOUND);

        let season = table::borrow(&seasons.seasons, season_id);
        let now = timestamp::now_seconds();
        assert!(now >= season.start_time, E_SEASON_NOT_STARTED);
        assert!(now < season.end_time, E_SEASON_ENDED);

        seasons.has_active_season = true;
        seasons.current_season_id = season_id;

        event::emit_event(
            &mut seasons.events.started,
            SeasonStartedEvent { publisher, season_id }
        );
    }

    /// End a season manually (or it auto-ends at end_time)
    public entry fun end_season(
        actor: &signer,
        publisher: address,
        season_id: u64
    ) acquires Seasons {
        let caller = signer::address_of(actor);
        assert!(exists<Seasons>(publisher), E_NOT_INITIALIZED);

        if (roles::is_initialized(publisher)) {
            assert!(roles::can_manage_leaderboards(publisher, caller), E_NO_PERMISSION);
        } else {
            assert!(caller == publisher, E_NO_PERMISSION);
        };

        let seasons = borrow_global_mut<Seasons>(publisher);
        assert!(table::contains(&seasons.seasons, season_id), E_SEASON_NOT_FOUND);

        if (seasons.current_season_id == season_id) {
            seasons.has_active_season = false;
            seasons.current_season_id = 0;
        };

        event::emit_event(
            &mut seasons.events.ended,
            SeasonEndedEvent { publisher, season_id }
        );
    }

    /************
     * Score Recording
     ************/

    /// Record a score for the current season
    /// Typically called by game_platform or directly
    public fun record_season_score(
        publisher: address,
        player: address,
        game_id: u64,
        score: u64
    ) acquires Seasons {
        if (!exists<Seasons>(publisher)) {
            return
        };

        let seasons = borrow_global_mut<Seasons>(publisher);

        if (!seasons.has_active_season) {
            return
        };

        let season_id = seasons.current_season_id;

        if (!table::contains(&seasons.seasons, season_id)) {
            return // Season doesn't exist
        };

        let season = table::borrow(&seasons.seasons, season_id);
        let now = timestamp::now_seconds();

        // Only record if season is active
        if (now < season.start_time || now >= season.end_time) {
            return
        };

        // Record score
        let season_scores = table::borrow_mut(&mut seasons.season_scores, season_id);

        if (!table::contains(&season_scores.scores, game_id)) {
            table::add(&mut season_scores.scores, game_id, table::new());
        };

        let game_scores = table::borrow_mut(&mut season_scores.scores, game_id);

        if (table::contains(game_scores, player)) {
            let current_best = table::borrow_mut(game_scores, player);
            if (score > *current_best) {
                *current_best = score;
            };
        } else {
            table::add(game_scores, player, score);
        };

        event::emit_event(
            &mut seasons.events.scores,
            SeasonScoreEvent { publisher, season_id, player, game_id, score }
        );
    }

    /************
     * Wrapper Functions (Seasonal Context)
     ************/

    /// Submit a score that counts for BOTH global and current season
    /// This is the main entry point for seasonal gameplay
    public entry fun submit_score_seasonal(
        player: &signer,
        publisher: address,
        game_id: u64,
        score: u64
    ) acquires Seasons {
        let player_addr = signer::address_of(player);
        
        // 1. Submit to global system (always happens)
        game_platform::submit_score(player, publisher, game_id, score);
        
        // 2. Record for current season
        record_season_score(publisher, player_addr, game_id, score);
        
        // 3. Update global achievements
        achievements::on_score(publisher, player_addr, game_id, score);
        
        // 4. Update season leaderboard (if season exists)
        if (exists<Seasons>(publisher)) {
            let seasons = borrow_global<Seasons>(publisher);
            if (seasons.has_active_season && table::contains(&seasons.seasons, seasons.current_season_id)) {
                let season_id = seasons.current_season_id;
                let season = table::borrow(&seasons.seasons, season_id);
                leaderboard::on_score(publisher, season.leaderboard_id, player_addr, score);
            };
        };
    }

    /// Attach an achievement to a season
    /// Makes the achievement "seasonal" (shows in season context)
    public entry fun add_season_achievement(
        actor: &signer,
        publisher: address,
        season_id: u64,
        achievement_id: u64
    ) acquires Seasons {
        let caller = signer::address_of(actor);
        assert!(exists<Seasons>(publisher), E_NOT_INITIALIZED);

        if (roles::is_initialized(publisher)) {
            assert!(roles::can_manage_achievements(publisher, caller), E_NO_PERMISSION);
        } else {
            assert!(caller == publisher, E_NO_PERMISSION);
        };

        let seasons = borrow_global_mut<Seasons>(publisher);
        assert!(table::contains(&seasons.seasons, season_id), E_SEASON_NOT_FOUND);

        let season = table::borrow_mut(&mut seasons.seasons, season_id);
        vector::push_back(&mut season.achievement_ids, achievement_id);
    }

    /************
     * View Functions
     ************/

    #[view]
    public fun is_initialized(publisher: address): bool {
        exists<Seasons>(publisher)
    }

    #[view]
    public fun get_current_season(publisher: address): (bool, u64) acquires Seasons {
        if (!exists<Seasons>(publisher)) return (false, 0);
        let seasons = borrow_global<Seasons>(publisher);
        (seasons.has_active_season, seasons.current_season_id)
    }

    #[view]
    public fun get_season_count(publisher: address): u64 acquires Seasons {
        if (!exists<Seasons>(publisher)) return 0;
        borrow_global<Seasons>(publisher).next_id
    }

    #[view]
    public fun get_season(publisher: address, season_id: u64): (
        bool, String, u64, u64, u64, u64, bool
    ) acquires Seasons {
        if (!exists<Seasons>(publisher)) {
            return (false, string::utf8(b""), 0, 0, 0, 0, false)
        };

        let seasons = borrow_global<Seasons>(publisher);
        if (!table::contains(&seasons.seasons, season_id)) {
            return (false, string::utf8(b""), 0, 0, 0, 0, false)
        };

        let season = table::borrow(&seasons.seasons, season_id);
        (
            true,
            season.name,
            season.start_time,
            season.end_time,
            season.leaderboard_id,
            season.prize_pool,
            season.is_finalized
        )
    }

    #[view]
    public fun get_season_status(publisher: address, season_id: u64): (
        bool, bool, bool
    ) acquires Seasons {
        if (!exists<Seasons>(publisher)) return (false, false, false);

        let seasons = borrow_global<Seasons>(publisher);
        if (!table::contains(&seasons.seasons, season_id)) {
            return (false, false, false)
        };

        let season = table::borrow(&seasons.seasons, season_id);
        let now = timestamp::now_seconds();

        let upcoming = now < season.start_time;
        let active = now >= season.start_time && now < season.end_time;
        let ended = now >= season.end_time;

        (upcoming, active, ended)
    }

    #[view]
    public fun get_season_score(
        publisher: address,
        season_id: u64,
        game_id: u64,
        player: address
    ): (bool, u64) acquires Seasons {
        if (!exists<Seasons>(publisher)) return (false, 0);

        let seasons = borrow_global<Seasons>(publisher);
        if (!table::contains(&seasons.season_scores, season_id)) {
            return (false, 0)
        };

        let season_scores = table::borrow(&seasons.season_scores, season_id);
        if (!table::contains(&season_scores.scores, game_id)) {
            return (false, 0)
        };

        let game_scores = table::borrow(&season_scores.scores, game_id);
        if (!table::contains(game_scores, player)) {
            return (false, 0)
        };

        (true, *table::borrow(game_scores, player))
    }

    #[view]
    /// Check if a specific season is active right now
    public fun is_season_active(publisher: address, season_id: u64): bool acquires Seasons {
        let (_, active, _) = get_season_status(publisher, season_id);
        active
    }
}

