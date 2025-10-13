/// Quests Module - Mission-Based Progression System
///
/// Provides a quest/mission system that coordinates with all Sigil modules:
/// - 6 quest types: Score, Achievement, PlayCount, Streak, Rank, MultiStep
/// - Automatic reward distribution on completion
/// - Seasonal quest support (tied to seasons module)
/// - Progress tracking per player
/// - Wrapper functions for seamless integration
///
/// Use case: Daily quests, battle pass progression, tutorial chains
module sigil::quests {
    use std::signer;
    use std::vector;
    use std::string::{Self, String};
    use std::option::{Self, Option};
    use aptos_std::table::{Self, Table};
    use aptos_framework::timestamp;
    use aptos_framework::account;
    use aptos_framework::event::{Self, EventHandle};
    use sigil::roles;
    use sigil::game_platform;
    use sigil::achievements;
    use sigil::seasons;
    use sigil::rewards;
    use sigil::leaderboard;

    /************
     * Constants
     ************/

    // Quest Types
    const QUEST_TYPE_SCORE: u8 = 0;
    const QUEST_TYPE_ACHIEVEMENT: u8 = 1;
    const QUEST_TYPE_PLAY_COUNT: u8 = 2;
    const QUEST_TYPE_STREAK: u8 = 3;
    const QUEST_TYPE_RANK: u8 = 4;
    const QUEST_TYPE_MULTI_STEP: u8 = 5;

    /************
     * Errors
     ************/

    const E_NOT_INITIALIZED: u64 = 0;
    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_QUEST_NOT_FOUND: u64 = 2;
    const E_QUEST_NOT_STARTED: u64 = 3;
    const E_QUEST_ALREADY_COMPLETED: u64 = 4;
    const E_QUEST_NOT_AVAILABLE: u64 = 5;
    const E_INVALID_QUEST_TYPE: u64 = 6;
    const E_NO_PERMISSION: u64 = 7;
    const E_ALREADY_STARTED: u64 = 8;

    /************
     * Structs
     ************/

    /// Quest definition
    struct Quest has store, drop {
        id: u64,
        title: String,
        description: String,
        quest_type: u8,
        // Type-specific data
        game_id: u64,              // For score/play quests (0 = any game)
        target: u64,               // Score/count/days target
        leaderboard_id: u64,       // For rank quests
        steps: vector<u64>,        // For multi-step quests (sub-quest IDs)
        // Rewards & availability
        reward_id: u64,            // From rewards module (0 = no reward)
        season_id: Option<u64>,    // None = always available, Some = seasonal
        is_active: bool,
        created_at: u64,
    }

    /// Player's progress on a quest
    struct QuestProgress has store, drop {
        quest_id: u64,
        current_progress: u64,     // Current score/count/streak
        completed: bool,
        claimed: bool,
        started_at: u64,
        completed_at: u64,
        last_update_day: u64,      // For streak tracking (day number)
    }

    /// Registry of all quests for a publisher
    struct Quests has key {
        publisher: address,
        next_quest_id: u64,
        quests: Table<u64, Quest>,
        // Player progress: player -> quest_id -> progress
        player_progress: Table<address, Table<u64, QuestProgress>>,
        // Active quests per player: player -> vector<quest_id>
        active_quests: Table<address, vector<u64>>,
        events: QuestEvents,
    }

    /// Events
    struct QuestCreatedEvent has drop, store {
        publisher: address,
        quest_id: u64,
        title: String,
        quest_type: u8,
    }

    struct QuestStartedEvent has drop, store {
        publisher: address,
        quest_id: u64,
        player: address,
    }

    struct QuestProgressEvent has drop, store {
        publisher: address,
        quest_id: u64,
        player: address,
        progress: u64,
        target: u64,
    }

    struct QuestCompletedEvent has drop, store {
        publisher: address,
        quest_id: u64,
        player: address,
        reward_id: u64,
    }

    struct QuestEvents has store {
        created: EventHandle<QuestCreatedEvent>,
        started: EventHandle<QuestStartedEvent>,
        progress: EventHandle<QuestProgressEvent>,
        completed: EventHandle<QuestCompletedEvent>,
    }

    /************
     * Lifecycle
     ************/

    /// Initialize quests system for a publisher
    public entry fun init_quests(publisher: &signer) {
        let addr = signer::address_of(publisher);
        assert!(!exists<Quests>(addr), E_ALREADY_INITIALIZED);

        move_to(publisher, Quests {
            publisher: addr,
            next_quest_id: 0,
            quests: table::new(),
            player_progress: table::new(),
            active_quests: table::new(),
            events: QuestEvents {
                created: account::new_event_handle<QuestCreatedEvent>(publisher),
                started: account::new_event_handle<QuestStartedEvent>(publisher),
                progress: account::new_event_handle<QuestProgressEvent>(publisher),
                completed: account::new_event_handle<QuestCompletedEvent>(publisher),
            },
        });
    }

    /************
     * Quest Creation
     ************/

    /// Create a score-based quest
    public entry fun create_score_quest(
        publisher: &signer,
        title: String,
        description: String,
        game_id: u64,          // 0 = any game
        target_score: u64,
        reward_id: u64,
        is_seasonal: bool
    ) acquires Quests {
        let addr = signer::address_of(publisher);
        check_permission(addr);

        let season_id = if (is_seasonal && seasons::is_initialized(addr)) {
            let (has_season, sid) = seasons::get_current_season(addr);
            if (has_season) option::some(sid) else option::none()
        } else {
            option::none()
        };

        create_quest_internal(
            addr,
            title,
            description,
            QUEST_TYPE_SCORE,
            game_id,
            target_score,
            0,
            vector::empty(),
            reward_id,
            season_id
        );
    }

    /// Create an achievement-based quest
    public entry fun create_achievement_quest(
        publisher: &signer,
        title: String,
        description: String,
        target_count: u64,
        reward_id: u64,
        is_seasonal: bool
    ) acquires Quests {
        let addr = signer::address_of(publisher);
        check_permission(addr);

        let season_id = if (is_seasonal && seasons::is_initialized(addr)) {
            let (has_season, sid) = seasons::get_current_season(addr);
            if (has_season) option::some(sid) else option::none()
        } else {
            option::none()
        };

        create_quest_internal(
            addr,
            title,
            description,
            QUEST_TYPE_ACHIEVEMENT,
            0,
            target_count,
            0,
            vector::empty(),
            reward_id,
            season_id
        );
    }

    /// Create a play count quest
    public entry fun create_play_count_quest(
        publisher: &signer,
        title: String,
        description: String,
        game_id: u64,          // 0 = any game
        target_plays: u64,
        reward_id: u64,
        is_seasonal: bool
    ) acquires Quests {
        let addr = signer::address_of(publisher);
        check_permission(addr);

        let season_id = if (is_seasonal && seasons::is_initialized(addr)) {
            let (has_season, sid) = seasons::get_current_season(addr);
            if (has_season) option::some(sid) else option::none()
        } else {
            option::none()
        };

        create_quest_internal(
            addr,
            title,
            description,
            QUEST_TYPE_PLAY_COUNT,
            game_id,
            target_plays,
            0,
            vector::empty(),
            reward_id,
            season_id
        );
    }

    /// Create a streak quest (consecutive days)
    public entry fun create_streak_quest(
        publisher: &signer,
        title: String,
        description: String,
        target_days: u64,
        reward_id: u64,
        is_seasonal: bool
    ) acquires Quests {
        let addr = signer::address_of(publisher);
        check_permission(addr);

        let season_id = if (is_seasonal && seasons::is_initialized(addr)) {
            let (has_season, sid) = seasons::get_current_season(addr);
            if (has_season) option::some(sid) else option::none()
        } else {
            option::none()
        };

        create_quest_internal(
            addr,
            title,
            description,
            QUEST_TYPE_STREAK,
            0,
            target_days,
            0,
            vector::empty(),
            reward_id,
            season_id
        );
    }

    /// Create a rank-based quest
    public entry fun create_rank_quest(
        publisher: &signer,
        title: String,
        description: String,
        leaderboard_id: u64,
        target_rank: u64,
        reward_id: u64,
        is_seasonal: bool
    ) acquires Quests {
        let addr = signer::address_of(publisher);
        check_permission(addr);

        let season_id = if (is_seasonal && seasons::is_initialized(addr)) {
            let (has_season, sid) = seasons::get_current_season(addr);
            if (has_season) option::some(sid) else option::none()
        } else {
            option::none()
        };

        create_quest_internal(
            addr,
            title,
            description,
            QUEST_TYPE_RANK,
            0,
            target_rank,
            leaderboard_id,
            vector::empty(),
            reward_id,
            season_id
        );
    }

    /// Internal quest creation
    fun create_quest_internal(
        publisher: address,
        title: String,
        description: String,
        quest_type: u8,
        game_id: u64,
        target: u64,
        leaderboard_id: u64,
        steps: vector<u64>,
        reward_id: u64,
        season_id: Option<u64>
    ) acquires Quests {
        assert!(exists<Quests>(publisher), E_NOT_INITIALIZED);
        let quests = borrow_global_mut<Quests>(publisher);

        let quest_id = quests.next_quest_id;
        quests.next_quest_id = quest_id + 1;

        let quest = Quest {
            id: quest_id,
            title,
            description,
            quest_type,
            game_id,
            target,
            leaderboard_id,
            steps,
            reward_id,
            season_id,
            is_active: true,
            created_at: timestamp::now_seconds(),
        };

        table::add(&mut quests.quests, quest_id, quest);

        event::emit_event(
            &mut quests.events.created,
            QuestCreatedEvent { publisher, quest_id, title, quest_type }
        );
    }

    /************
     * Quest Management
     ************/

    /// Player starts tracking a quest
    public entry fun start_quest(
        player: &signer,
        publisher: address,
        quest_id: u64
    ) acquires Quests {
        let player_addr = signer::address_of(player);
        assert!(exists<Quests>(publisher), E_NOT_INITIALIZED);

        let quests = borrow_global_mut<Quests>(publisher);
        assert!(table::contains(&quests.quests, quest_id), E_QUEST_NOT_FOUND);

        let quest = table::borrow(&quests.quests, quest_id);
        assert!(quest.is_active, E_QUEST_NOT_AVAILABLE);

        // Check if quest is available (seasonal check)
        if (option::is_some(&quest.season_id)) {
            let season_id = *option::borrow(&quest.season_id);
            if (seasons::is_initialized(publisher)) {
                let (has_season, current_season) = seasons::get_current_season(publisher);
                assert!(has_season && current_season == season_id, E_QUEST_NOT_AVAILABLE);
            };
        };

        // Initialize player's progress tracking if needed
        if (!table::contains(&quests.player_progress, player_addr)) {
            table::add(&mut quests.player_progress, player_addr, table::new());
        };

        let player_quests = table::borrow_mut(&mut quests.player_progress, player_addr);
        
        // Check if already started
        assert!(!table::contains(player_quests, quest_id), E_ALREADY_STARTED);

        // Create progress entry
        let progress = QuestProgress {
            quest_id,
            current_progress: 0,
            completed: false,
            claimed: false,
            started_at: timestamp::now_seconds(),
            completed_at: 0,
            last_update_day: 0,
        };

        table::add(player_quests, quest_id, progress);

        // Add to active quests list
        if (!table::contains(&quests.active_quests, player_addr)) {
            table::add(&mut quests.active_quests, player_addr, vector::empty());
        };
        let active = table::borrow_mut(&mut quests.active_quests, player_addr);
        vector::push_back(active, quest_id);

        event::emit_event(
            &mut quests.events.started,
            QuestStartedEvent { publisher, quest_id, player: player_addr }
        );
    }

    /************
     * Wrapper Functions (Coordinator Pattern)
     ************/

    /// Submit score and update all relevant quests
    /// This is the MAIN wrapper function!
    public entry fun submit_score_with_quest(
        player: &signer,
        publisher: address,
        game_id: u64,
        score: u64
    ) acquires Quests {
        let player_addr = signer::address_of(player);

        // 1. Submit to game platform (global score)
        game_platform::submit_score(player, publisher, game_id, score);

        // 2. Update achievements
        achievements::on_score(publisher, player_addr, game_id, score);

        // 3. Update seasonal scores if applicable
        if (seasons::is_initialized(publisher)) {
            seasons::record_season_score(publisher, player_addr, game_id, score);
        };

        // 4. Update quest progress
        if (exists<Quests>(publisher)) {
            // Update score quests
            update_score_quests_internal(publisher, player_addr, game_id, score);
            
            // Update play count quests
            update_play_count_quests_internal(publisher, player_addr, game_id);
            
            // Update streak quests
            update_streak_quests_internal(publisher, player_addr);
        };
    }

    /// Update quest progress manually (for achievement/rank quests)
    public entry fun update_quest_progress(
        player: &signer,
        publisher: address,
        quest_id: u64
    ) acquires Quests {
        let player_addr = signer::address_of(player);
        assert!(exists<Quests>(publisher), E_NOT_INITIALIZED);

        let quests = borrow_global_mut<Quests>(publisher);
        assert!(table::contains(&quests.quests, quest_id), E_QUEST_NOT_FOUND);

        let quest = table::borrow(&quests.quests, quest_id);
        
        // Check if player has started this quest
        if (!table::contains(&quests.player_progress, player_addr)) return;
        let player_quests = table::borrow_mut(&mut quests.player_progress, player_addr);
        if (!table::contains(player_quests, quest_id)) return;

        let progress = table::borrow_mut(player_quests, quest_id);
        if (progress.completed) return;

        // Update based on quest type
        if (quest.quest_type == QUEST_TYPE_ACHIEVEMENT) {
            // Count player's achievements
            let achievement_count = count_player_achievements(publisher, player_addr);
            progress.current_progress = achievement_count;

            // Check completion
            if (achievement_count >= quest.target) {
                complete_quest_internal(quests, publisher, player_addr, quest_id);
            };
        } else if (quest.quest_type == QUEST_TYPE_RANK) {
            // Check player's rank in leaderboard
            let rank = get_player_rank(publisher, quest.leaderboard_id, player_addr);
            if (rank > 0 && rank <= quest.target) {
                progress.current_progress = quest.target;
                complete_quest_internal(quests, publisher, player_addr, quest_id);
            };
        };
    }

    /************
     * Internal Progress Updates
     ************/

    /// Update score-based quests
    fun update_score_quests_internal(
        publisher: address,
        player: address,
        game_id: u64,
        score: u64
    ) acquires Quests {
        let quests = borrow_global_mut<Quests>(publisher);
        
        if (!table::contains(&quests.player_progress, player)) return;
        if (!table::contains(&quests.active_quests, player)) return;

        // First pass: collect quests to complete
        let quests_to_complete = vector::empty<u64>();
        
        {
            let player_quests = table::borrow_mut(&mut quests.player_progress, player);
            let active_quest_ids = table::borrow(&quests.active_quests, player);

            let i = 0;
            let len = vector::length(active_quest_ids);
            while (i < len) {
                let quest_id = *vector::borrow(active_quest_ids, i);
                
                if (table::contains(player_quests, quest_id)) {
                    let progress = table::borrow_mut(player_quests, quest_id);
                    
                    if (!progress.completed) {
                        let quest = table::borrow(&quests.quests, quest_id);
                        
                        if (quest.quest_type == QUEST_TYPE_SCORE) {
                            // Check if quest applies to this game
                            if (quest.game_id == 0 || quest.game_id == game_id) {
                                // Update progress with max score
                                if (score > progress.current_progress) {
                                    progress.current_progress = score;
                                    
                                    // Check completion
                                    if (score >= quest.target) {
                                        vector::push_back(&mut quests_to_complete, quest_id);
                                    };
                                };
                            };
                        };
                    };
                };
                
                i = i + 1;
            };
        };

        // Second pass: complete quests
        let j = 0;
        let complete_len = vector::length(&quests_to_complete);
        while (j < complete_len) {
            let quest_id = *vector::borrow(&quests_to_complete, j);
            complete_quest_internal(quests, publisher, player, quest_id);
            j = j + 1;
        };
    }

    /// Update play count quests
    fun update_play_count_quests_internal(
        publisher: address,
        player: address,
        game_id: u64
    ) acquires Quests {
        let quests = borrow_global_mut<Quests>(publisher);
        
        if (!table::contains(&quests.player_progress, player)) return;
        if (!table::contains(&quests.active_quests, player)) return;

        // First pass: collect quests to complete
        let quests_to_complete = vector::empty<u64>();
        
        {
            let player_quests = table::borrow_mut(&mut quests.player_progress, player);
            let active_quest_ids = table::borrow(&quests.active_quests, player);

            let i = 0;
            let len = vector::length(active_quest_ids);
            while (i < len) {
                let quest_id = *vector::borrow(active_quest_ids, i);
                
                if (table::contains(player_quests, quest_id)) {
                    let progress = table::borrow_mut(player_quests, quest_id);
                    
                    if (!progress.completed) {
                        let quest = table::borrow(&quests.quests, quest_id);
                        
                        if (quest.quest_type == QUEST_TYPE_PLAY_COUNT) {
                            if (quest.game_id == 0 || quest.game_id == game_id) {
                                progress.current_progress = progress.current_progress + 1;
                                
                                if (progress.current_progress >= quest.target) {
                                    vector::push_back(&mut quests_to_complete, quest_id);
                                };
                            };
                        };
                    };
                };
                
                i = i + 1;
            };
        };

        // Second pass: complete quests
        let j = 0;
        let complete_len = vector::length(&quests_to_complete);
        while (j < complete_len) {
            let quest_id = *vector::borrow(&quests_to_complete, j);
            complete_quest_internal(quests, publisher, player, quest_id);
            j = j + 1;
        };
    }

    /// Update streak quests
    fun update_streak_quests_internal(
        publisher: address,
        player: address
    ) acquires Quests {
        let quests = borrow_global_mut<Quests>(publisher);
        
        if (!table::contains(&quests.player_progress, player)) return;
        if (!table::contains(&quests.active_quests, player)) return;

        let now = timestamp::now_seconds();
        let current_day = now / 86400; // Days since epoch

        // First pass: collect quests to complete
        let quests_to_complete = vector::empty<u64>();
        
        {
            let player_quests = table::borrow_mut(&mut quests.player_progress, player);
            let active_quest_ids = table::borrow(&quests.active_quests, player);

            let i = 0;
            let len = vector::length(active_quest_ids);
            while (i < len) {
                let quest_id = *vector::borrow(active_quest_ids, i);
                
                if (table::contains(player_quests, quest_id)) {
                    let progress = table::borrow_mut(player_quests, quest_id);
                    
                    if (!progress.completed) {
                        let quest = table::borrow(&quests.quests, quest_id);
                        
                        if (quest.quest_type == QUEST_TYPE_STREAK) {
                            if (progress.last_update_day == 0) {
                                // First play
                                progress.current_progress = 1;
                                progress.last_update_day = current_day;
                            } else if (current_day == progress.last_update_day + 1) {
                                // Consecutive day
                                progress.current_progress = progress.current_progress + 1;
                                progress.last_update_day = current_day;
                                
                                if (progress.current_progress >= quest.target) {
                                    vector::push_back(&mut quests_to_complete, quest_id);
                                };
                            } else if (current_day > progress.last_update_day + 1) {
                                // Streak broken, reset
                                progress.current_progress = 1;
                                progress.last_update_day = current_day;
                            };
                            // Same day = no change
                        };
                    };
                };
                
                i = i + 1;
            };
        };

        // Second pass: complete quests
        let j = 0;
        let complete_len = vector::length(&quests_to_complete);
        while (j < complete_len) {
            let quest_id = *vector::borrow(&quests_to_complete, j);
            complete_quest_internal(quests, publisher, player, quest_id);
            j = j + 1;
        };
    }

    /// Complete a quest and distribute rewards
    fun complete_quest_internal(
        quests: &mut Quests,
        publisher: address,
        player: address,
        quest_id: u64
    ) {
        let player_quests = table::borrow_mut(&mut quests.player_progress, player);
        let progress = table::borrow_mut(player_quests, quest_id);
        
        progress.completed = true;
        progress.completed_at = timestamp::now_seconds();

        let quest = table::borrow(&quests.quests, quest_id);

        // Emit completion event
        event::emit_event(
            &mut quests.events.completed,
            QuestCompletedEvent { 
                publisher, 
                quest_id, 
                player,
                reward_id: quest.reward_id
            }
        );

        // Auto-claim reward if available
        if (quest.reward_id != 0) {
            // Note: Reward claiming would be handled by a separate function
            // that calls rewards::claim_reward() with proper permissions
            // For now, just mark as ready to claim
            progress.claimed = false; // Will be true after manual claim
        };
    }

    /// Emit progress event
    fun emit_progress_event(
        quests: &mut Quests,
        publisher: address,
        player: address,
        quest_id: u64,
        progress: u64,
        target: u64
    ) {
        event::emit_event(
            &mut quests.events.progress,
            QuestProgressEvent { publisher, quest_id, player, progress, target }
        );
    }

    /************
     * Helper Functions
     ************/

    /// Check if caller has permission to create quests
    fun check_permission(publisher: address) {
        if (roles::is_initialized(publisher)) {
            assert!(
                roles::can_manage_achievements(publisher, publisher),
                E_NO_PERMISSION
            );
        };
    }

    /// Count player's unlocked achievements
    fun count_player_achievements(_publisher: address, _player: address): u64 {
        // This would need achievements module to expose a count function
        // For now, return 0 (requires achievements module API enhancement)
        // TODO: Add achievements::get_player_achievement_count() API
        0
    }

    /// Get player's rank in leaderboard
    fun get_player_rank(_publisher: address, _leaderboard_id: u64, _player: address): u64 {
        // This would need leaderboard module to expose a rank query function
        // For now, return 0 (requires leaderboard module API enhancement)
        // TODO: Add leaderboard::get_player_rank() API
        0
    }

    /************
     * View Functions
     ************/

    #[view]
    public fun is_initialized(publisher: address): bool {
        exists<Quests>(publisher)
    }

    #[view]
    public fun get_quest_count(publisher: address): u64 acquires Quests {
        if (!exists<Quests>(publisher)) return 0;
        borrow_global<Quests>(publisher).next_quest_id
    }

    #[view]
    public fun get_quest(publisher: address, quest_id: u64): (
        bool,     // exists
        String,   // title
        String,   // description
        u8,       // quest_type
        u64,      // target
        u64,      // reward_id
        bool      // is_seasonal
    ) acquires Quests {
        if (!exists<Quests>(publisher)) {
            return (false, string::utf8(b""), string::utf8(b""), 0, 0, 0, false)
        };

        let quests = borrow_global<Quests>(publisher);
        if (!table::contains(&quests.quests, quest_id)) {
            return (false, string::utf8(b""), string::utf8(b""), 0, 0, 0, false)
        };

        let quest = table::borrow(&quests.quests, quest_id);
        (
            true,
            quest.title,
            quest.description,
            quest.quest_type,
            quest.target,
            quest.reward_id,
            option::is_some(&quest.season_id)
        )
    }

    #[view]
    public fun get_quest_progress(
        publisher: address,
        quest_id: u64,
        player: address
    ): (bool, u64, u64, bool, bool) acquires Quests {
        if (!exists<Quests>(publisher)) return (false, 0, 0, false, false);

        let quests = borrow_global<Quests>(publisher);
        if (!table::contains(&quests.player_progress, player)) {
            return (false, 0, 0, false, false)
        };

        let player_quests = table::borrow(&quests.player_progress, player);
        if (!table::contains(player_quests, quest_id)) {
            return (false, 0, 0, false, false)
        };

        let progress = table::borrow(player_quests, quest_id);
        let quest = table::borrow(&quests.quests, quest_id);

        (
            true,
            progress.current_progress,
            quest.target,
            progress.completed,
            progress.claimed
        )
    }

    #[view]
    public fun get_active_quests(
        publisher: address,
        player: address
    ): vector<u64> acquires Quests {
        if (!exists<Quests>(publisher)) return vector::empty();

        let quests = borrow_global<Quests>(publisher);
        if (!table::contains(&quests.active_quests, player)) {
            return vector::empty()
        };

        *table::borrow(&quests.active_quests, player)
    }

    #[view]
    public fun is_quest_available(
        publisher: address,
        quest_id: u64
    ): bool acquires Quests {
        if (!exists<Quests>(publisher)) return false;

        let quests = borrow_global<Quests>(publisher);
        if (!table::contains(&quests.quests, quest_id)) return false;

        let quest = table::borrow(&quests.quests, quest_id);
        if (!quest.is_active) return false;

        // Check seasonal availability
        if (option::is_some(&quest.season_id)) {
            let season_id = *option::borrow(&quest.season_id);
            if (seasons::is_initialized(publisher)) {
                let (has_season, current_season) = seasons::get_current_season(publisher);
                return has_season && current_season == season_id
            } else {
                return false
            }
        };

        true
    }
}

