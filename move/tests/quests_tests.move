#[test_only]
module sigil::quests_tests {
    use std::signer;
    use std::string;
    use std::vector;
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use sigil::quests;
    use sigil::game_platform;
    use sigil::achievements;
    use sigil::seasons;

    // Test accounts helper
    fun setup_accounts(): (signer, signer, signer) {
        let publisher = account::create_account_for_test(@0x123);
        let player1 = account::create_account_for_test(@0x456);
        let player2 = account::create_account_for_test(@0x789);
        (publisher, player1, player2)
    }

    /// Aptos `timestamp` global must exist for quest creation (uses `now_seconds`).
    fun init_test_chain_clock() {
        let framework = account::create_signer_for_test(@0x1);
        timestamp::set_time_has_started_for_testing(&framework);
        timestamp::update_global_time_for_test(1700000000000000);
    }

    // Setup full game environment
    fun setup_game_environment(publisher: &signer, player: &signer) {
        init_test_chain_clock();

        // Initialize core modules
        game_platform::init(publisher);
        game_platform::register_player(player, string::utf8(b"Player1"));
        game_platform::register_game(publisher, string::utf8(b"Game1"));
        
        achievements::init_achievements(publisher);
        quests::init_quests(publisher);
    }

    /************
     * Init Tests
     ************/

    #[test]
    fun test_init_quests() {
        let (publisher, _, _) = setup_accounts();
        let pub_addr = signer::address_of(&publisher);
        
        quests::init_quests(&publisher);
        
        assert!(quests::is_initialized(pub_addr), 0);
        assert!(quests::get_quest_count(pub_addr) == 0, 1);
    }

    #[test]
    #[expected_failure(abort_code = 1, location = sigil::quests)] // E_ALREADY_INITIALIZED
    fun test_init_quests_twice_fails() {
        let (publisher, _, _) = setup_accounts();
        
        quests::init_quests(&publisher);
        quests::init_quests(&publisher);
    }

    /************
     * Score Quest Tests
     ************/

    #[test]
    fun test_create_score_quest() {
        let (publisher, _, _) = setup_accounts();
        let pub_addr = signer::address_of(&publisher);

        init_test_chain_clock();
        quests::init_quests(&publisher);
        
        quests::create_score_quest(
            &publisher,
            string::utf8(b"First Victory"),
            string::utf8(b"Score 500 points"),
            0,      // game_id (0 = any game)
            500,    // target_score
            0,      // reward_id (0 = no reward)
            false   // not seasonal
        );
        
        assert!(quests::get_quest_count(pub_addr) == 1, 0);
        
        let (exists, title, description, quest_type, target, reward_id, is_seasonal) = 
            quests::get_quest(pub_addr, 0);
        
        assert!(exists, 1);
        assert!(title == string::utf8(b"First Victory"), 2);
        assert!(description == string::utf8(b"Score 500 points"), 3);
        assert!(quest_type == 0, 4); // QUEST_TYPE_SCORE
        assert!(target == 500, 5);
        assert!(reward_id == 0, 6);
        assert!(!is_seasonal, 7);
    }

    #[test]
    fun test_start_score_quest() {
        let (publisher, player1, _) = setup_accounts();
        let pub_addr = signer::address_of(&publisher);
        let player1_addr = signer::address_of(&player1);
        
        setup_game_environment(&publisher, &player1);
        
        quests::create_score_quest(
            &publisher,
            string::utf8(b"Score Quest"),
            string::utf8(b"Score 100"),
            0, 100, 0, false
        );
        
        quests::start_quest(&player1, pub_addr, 0);
        
        // Check player has started the quest
        let active_quests = quests::get_active_quests(pub_addr, player1_addr);
        assert!(vector::length(&active_quests) == 1, 0);
        assert!(*vector::borrow(&active_quests, 0) == 0, 1);
        
        // Check initial progress
        let (has_progress, current, target, completed, claimed) = 
            quests::get_quest_progress(pub_addr, 0, player1_addr);
        assert!(has_progress, 2);
        assert!(current == 0, 3);
        assert!(target == 100, 4);
        assert!(!completed, 5);
        assert!(!claimed, 6);
    }

    #[test]
    fun test_score_quest_completion_via_wrapper() {
        let (publisher, player1, _) = setup_accounts();
        let pub_addr = signer::address_of(&publisher);
        let player1_addr = signer::address_of(&player1);
        
        setup_game_environment(&publisher, &player1);
        
        quests::create_score_quest(
            &publisher,
            string::utf8(b"Score Quest"),
            string::utf8(b"Score 100"),
            0, 100, 0, false
        );
        
        quests::start_quest(&player1, pub_addr, 0);
        
        // Use wrapper function to submit score
        quests::submit_score_with_quest(&player1, pub_addr, 0, 150);
        
        // Check quest is completed
        let (has_progress, current, target, completed, claimed) = 
            quests::get_quest_progress(pub_addr, 0, player1_addr);
        assert!(has_progress, 0);
        assert!(current == 150, 1);
        assert!(target == 100, 2);
        assert!(completed, 3); // Should be completed!
    }

    #[test]
    fun test_score_quest_progress_tracking() {
        let (publisher, player1, _) = setup_accounts();
        let pub_addr = signer::address_of(&publisher);
        let player1_addr = signer::address_of(&player1);
        
        setup_game_environment(&publisher, &player1);
        
        quests::create_score_quest(
            &publisher,
            string::utf8(b"Score Quest"),
            string::utf8(b"Score 1000"),
            0, 1000, 0, false
        );
        
        quests::start_quest(&player1, pub_addr, 0);
        
        // Submit multiple scores
        quests::submit_score_with_quest(&player1, pub_addr, 0, 100);
        let (_, current1, _, _, _) = quests::get_quest_progress(pub_addr, 0, player1_addr);
        assert!(current1 == 100, 0);
        
        quests::submit_score_with_quest(&player1, pub_addr, 0, 500);
        let (_, current2, _, _, _) = quests::get_quest_progress(pub_addr, 0, player1_addr);
        assert!(current2 == 500, 1); // Should update to higher score
        
        // Lower score shouldn't update
        quests::submit_score_with_quest(&player1, pub_addr, 0, 300);
        let (_, current3, _, _, _) = quests::get_quest_progress(pub_addr, 0, player1_addr);
        assert!(current3 == 500, 2); // Should stay at 500
    }

    /************
     * Achievement Quest Tests
     ************/

    #[test]
    fun test_create_achievement_quest() {
        let (publisher, _, _) = setup_accounts();
        let pub_addr = signer::address_of(&publisher);

        init_test_chain_clock();
        quests::init_quests(&publisher);
        
        quests::create_achievement_quest(
            &publisher,
            string::utf8(b"Achievement Hunter"),
            string::utf8(b"Unlock 5 achievements"),
            5,      // target_count
            0,      // reward_id
            false   // not seasonal
        );
        
        let (exists, title, description, quest_type, target, _, _) = 
            quests::get_quest(pub_addr, 0);
        
        assert!(exists, 0);
        assert!(title == string::utf8(b"Achievement Hunter"), 1);
        assert!(quest_type == 1, 2); // QUEST_TYPE_ACHIEVEMENT
        assert!(target == 5, 3);
    }

    /************
     * Play Count Quest Tests
     ************/

    #[test]
    fun test_create_play_count_quest() {
        let (publisher, _, _) = setup_accounts();
        let pub_addr = signer::address_of(&publisher);

        init_test_chain_clock();
        quests::init_quests(&publisher);
        
        quests::create_play_count_quest(
            &publisher,
            string::utf8(b"Dedication"),
            string::utf8(b"Play 10 games"),
            0,      // game_id (any game)
            10,     // target_plays
            0,      // reward_id
            false   // not seasonal
        );
        
        let (exists, title, _, quest_type, target, _, _) = 
            quests::get_quest(pub_addr, 0);
        
        assert!(exists, 0);
        assert!(title == string::utf8(b"Dedication"), 1);
        assert!(quest_type == 2, 2); // QUEST_TYPE_PLAY_COUNT
        assert!(target == 10, 3);
    }

    #[test]
    fun test_play_count_quest_completion() {
        let (publisher, player1, _) = setup_accounts();
        let pub_addr = signer::address_of(&publisher);
        let player1_addr = signer::address_of(&player1);
        
        setup_game_environment(&publisher, &player1);
        
        quests::create_play_count_quest(
            &publisher,
            string::utf8(b"Play 3 Games"),
            string::utf8(b"Play 3 times"),
            0, 3, 0, false
        );
        
        quests::start_quest(&player1, pub_addr, 0);
        
        // Play 3 games
        quests::submit_score_with_quest(&player1, pub_addr, 0, 100);
        let (_, count1, _, completed1, _) = quests::get_quest_progress(pub_addr, 0, player1_addr);
        assert!(count1 == 1, 0);
        assert!(!completed1, 1);
        
        quests::submit_score_with_quest(&player1, pub_addr, 0, 200);
        let (_, count2, _, completed2, _) = quests::get_quest_progress(pub_addr, 0, player1_addr);
        assert!(count2 == 2, 2);
        assert!(!completed2, 3);
        
        quests::submit_score_with_quest(&player1, pub_addr, 0, 300);
        let (_, count3, _, completed3, _) = quests::get_quest_progress(pub_addr, 0, player1_addr);
        assert!(count3 == 3, 4);
        assert!(completed3, 5); // Should be completed!
    }

    /************
     * Streak Quest Tests
     ************/

    #[test]
    fun test_create_streak_quest() {
        let (publisher, _, _) = setup_accounts();
        let pub_addr = signer::address_of(&publisher);
        
        init_test_chain_clock();

        quests::init_quests(&publisher);
        
        quests::create_streak_quest(
            &publisher,
            string::utf8(b"Weekly Warrior"),
            string::utf8(b"Play 7 days in a row"),
            7,      // target_days
            0,      // reward_id
            false   // not seasonal
        );
        
        let (exists, title, _, quest_type, target, _, _) = 
            quests::get_quest(pub_addr, 0);
        
        assert!(exists, 0);
        assert!(title == string::utf8(b"Weekly Warrior"), 1);
        assert!(quest_type == 3, 2); // QUEST_TYPE_STREAK
        assert!(target == 7, 3);
    }

    /************
     * Rank Quest Tests
     ************/

    #[test]
    fun test_create_rank_quest() {
        let (publisher, _, _) = setup_accounts();
        let pub_addr = signer::address_of(&publisher);

        init_test_chain_clock();
        quests::init_quests(&publisher);
        
        quests::create_rank_quest(
            &publisher,
            string::utf8(b"Top 10"),
            string::utf8(b"Reach top 10 in leaderboard"),
            0,      // leaderboard_id
            10,     // target_rank
            0,      // reward_id
            false   // not seasonal
        );
        
        let (exists, title, _, quest_type, target, _, _) = 
            quests::get_quest(pub_addr, 0);
        
        assert!(exists, 0);
        assert!(title == string::utf8(b"Top 10"), 1);
        assert!(quest_type == 4, 2); // QUEST_TYPE_RANK
        assert!(target == 10, 3);
    }

    /************
     * Multiple Quests Tests
     ************/

    #[test]
    fun test_multiple_quests_simultaneously() {
        let (publisher, player1, _) = setup_accounts();
        let pub_addr = signer::address_of(&publisher);
        let player1_addr = signer::address_of(&player1);
        
        setup_game_environment(&publisher, &player1);
        
        // Create 3 quests
        quests::create_score_quest(
            &publisher, string::utf8(b"Q1"), string::utf8(b"Score 100"),
            0, 100, 0, false
        );
        quests::create_score_quest(
            &publisher, string::utf8(b"Q2"), string::utf8(b"Score 500"),
            0, 500, 0, false
        );
        quests::create_play_count_quest(
            &publisher, string::utf8(b"Q3"), string::utf8(b"Play 5"),
            0, 5, 0, false
        );
        
        // Start all 3 quests
        quests::start_quest(&player1, pub_addr, 0);
        quests::start_quest(&player1, pub_addr, 1);
        quests::start_quest(&player1, pub_addr, 2);
        
        let active_quests = quests::get_active_quests(pub_addr, player1_addr);
        assert!(vector::length(&active_quests) == 3, 0);
        
        // Submit score - should update all 3 quests
        quests::submit_score_with_quest(&player1, pub_addr, 0, 150);
        
        // Check quest 0 (score 100) - completed
        let (_, current0, _, completed0, _) = quests::get_quest_progress(pub_addr, 0, player1_addr);
        assert!(current0 == 150, 1);
        assert!(completed0, 2);
        
        // Check quest 1 (score 500) - not completed yet
        let (_, current1, _, completed1, _) = quests::get_quest_progress(pub_addr, 1, player1_addr);
        assert!(current1 == 150, 3);
        assert!(!completed1, 4);
        
        // Check quest 2 (play 5) - 1 play counted
        let (_, current2, _, completed2, _) = quests::get_quest_progress(pub_addr, 2, player1_addr);
        assert!(current2 == 1, 5);
        assert!(!completed2, 6);
    }

    /************
     * Seasonal Quest Tests
     ************/

    #[test]
    fun test_create_seasonal_quest() {
        let (publisher, _, _) = setup_accounts();
        let pub_addr = signer::address_of(&publisher);
        
        let framework_signer = account::create_signer_for_test(@0x1);
        timestamp::set_time_has_started_for_testing(&framework_signer);
        let base_micros = 1700000000000000;
        timestamp::update_global_time_for_test(base_micros);
        
        // Initialize seasons
        seasons::init_seasons(&publisher);
        let now = timestamp::now_seconds();
        seasons::create_season(&publisher, @0x123, string::utf8(b"Season 1"), now + 10, now + 86500, 0, 0);
        // Advance past season start so start_season succeeds
        timestamp::update_global_time_for_test(base_micros + 20000000);
        seasons::start_season(&publisher, @0x123, 0);
        
        // Initialize quests
        quests::init_quests(&publisher);
        
        // Create seasonal quest
        quests::create_score_quest(
            &publisher,
            string::utf8(b"Seasonal Quest"),
            string::utf8(b"Score 1000 this season"),
            0, 1000, 0,
            true  // is_seasonal = true
        );
        
        let (exists, _, _, _, _, _, is_seasonal) = quests::get_quest(pub_addr, 0);
        assert!(exists, 0);
        assert!(is_seasonal, 1);
        
        // Quest should be available (season is active)
        assert!(quests::is_quest_available(pub_addr, 0), 2);
    }

    /************
     * Wrapper Function Integration Tests
     ************/

    #[test]
    fun test_wrapper_updates_game_platform() {
        let (publisher, player1, _) = setup_accounts();
        let pub_addr = signer::address_of(&publisher);
        let player1_addr = signer::address_of(&player1);
        
        setup_game_environment(&publisher, &player1);
        
        // Submit via wrapper
        quests::submit_score_with_quest(&player1, pub_addr, 0, 500);
        
        // Verify game_platform recorded the score
        let (has_score, best_score, _) = game_platform::score_summary(pub_addr, player1_addr, 0);
        assert!(has_score, 0);
        assert!(best_score == 500, 1);
    }

    #[test]
    fun test_wrapper_without_quests_initialized() {
        let (publisher, player1, _) = setup_accounts();
        let pub_addr = signer::address_of(&publisher);
        let player1_addr = signer::address_of(&player1);
        
        // Initialize only game platform (no quests)
        game_platform::init(&publisher);
        game_platform::register_player(&player1, string::utf8(b"Player1"));
        game_platform::register_game(&publisher, string::utf8(b"Game1"));
        
        // Wrapper should still work (gracefully handles missing quests)
        quests::submit_score_with_quest(&player1, pub_addr, 0, 300);
        
        // Verify game_platform still recorded the score
        let (has_score, best_score, _) = game_platform::score_summary(pub_addr, player1_addr, 0);
        assert!(has_score, 0);
        assert!(best_score == 300, 1);
    }

    /************
     * View Function Tests
     ************/

    #[test]
    fun test_is_initialized_false() {
        assert!(!quests::is_initialized(@0x999), 0);
    }

    #[test]
    fun test_get_quest_not_found() {
        let (publisher, _, _) = setup_accounts();
        let pub_addr = signer::address_of(&publisher);
        
        quests::init_quests(&publisher);
        
        let (exists, _, _, _, _, _, _) = quests::get_quest(pub_addr, 999);
        assert!(!exists, 0);
    }

    #[test]
    fun test_get_quest_progress_not_started() {
        let (publisher, player1, _) = setup_accounts();
        let pub_addr = signer::address_of(&publisher);
        let player1_addr = signer::address_of(&player1);
        
        setup_game_environment(&publisher, &player1);
        
        quests::create_score_quest(
            &publisher, string::utf8(b"Q1"), string::utf8(b"Test"),
            0, 100, 0, false
        );
        
        // Player hasn't started the quest
        let (has_progress, _, _, _, _) = quests::get_quest_progress(pub_addr, 0, player1_addr);
        assert!(!has_progress, 0);
    }

    #[test]
    fun test_get_active_quests_empty() {
        let (publisher, player1, _) = setup_accounts();
        let pub_addr = signer::address_of(&publisher);
        let player1_addr = signer::address_of(&player1);
        
        quests::init_quests(&publisher);
        
        let active_quests = quests::get_active_quests(pub_addr, player1_addr);
        assert!(vector::length(&active_quests) == 0, 0);
    }

    #[test]
    fun test_is_quest_available_without_seasons() {
        let (publisher, _, _) = setup_accounts();
        let pub_addr = signer::address_of(&publisher);

        init_test_chain_clock();
        quests::init_quests(&publisher);
        
        // Create non-seasonal quest
        quests::create_score_quest(
            &publisher, string::utf8(b"Q1"), string::utf8(b"Test"),
            0, 100, 0, false
        );
        
        // Should always be available
        assert!(quests::is_quest_available(pub_addr, 0), 0);
    }

    /************
     * Error Case Tests
     ************/

    #[test]
    #[expected_failure(abort_code = 2, location = sigil::quests)] // E_QUEST_NOT_FOUND
    fun test_start_nonexistent_quest_fails() {
        let (publisher, player1, _) = setup_accounts();
        let pub_addr = signer::address_of(&publisher);
        
        setup_game_environment(&publisher, &player1);
        
        // Try to start quest that doesn't exist
        quests::start_quest(&player1, pub_addr, 999);
    }

    #[test]
    #[expected_failure(abort_code = 8, location = sigil::quests)] // E_ALREADY_STARTED
    fun test_start_quest_twice_fails() {
        let (publisher, player1, _) = setup_accounts();
        let pub_addr = signer::address_of(&publisher);
        
        setup_game_environment(&publisher, &player1);
        
        quests::create_score_quest(
            &publisher, string::utf8(b"Q1"), string::utf8(b"Test"),
            0, 100, 0, false
        );
        
        quests::start_quest(&player1, pub_addr, 0);
        quests::start_quest(&player1, pub_addr, 0); // Should fail
    }
}

