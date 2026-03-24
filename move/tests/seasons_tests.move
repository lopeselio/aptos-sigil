#[test_only]
module sigil::seasons_tests {
    use std::signer;
    use std::string;
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use sigil::seasons;
    use sigil::game_platform;

    // Test accounts helper
    fun setup_accounts(): (signer, signer, signer) {
        let publisher = account::create_account_for_test(@0x123);
        let player1 = account::create_account_for_test(@0x456);
        let player2 = account::create_account_for_test(@0x789);
        (publisher, player1, player2)
    }

    /************
     * Init Tests
     ************/

    #[test]
    fun test_init_seasons() {
        let (publisher, _, _) = setup_accounts();
        let pub_addr = signer::address_of(&publisher);
        
        seasons::init_seasons(&publisher);
        
        assert!(seasons::is_initialized(pub_addr), 0);
        assert!(seasons::get_season_count(pub_addr) == 0, 1);
        
        let (has_current, _) = seasons::get_current_season(pub_addr);
        assert!(!has_current, 2); // No active season yet
    }

    #[test]
    #[expected_failure(abort_code = 1, location = sigil::seasons)] // E_ALREADY_INITIALIZED
    fun test_init_seasons_twice_fails() {
        let (publisher, _, _) = setup_accounts();
        
        seasons::init_seasons(&publisher);
        seasons::init_seasons(&publisher);
    }

    /************
     * Create Season Tests
     ************/

    #[test]
    fun test_create_season() {
        let (publisher, _, _) = setup_accounts();
        let pub_addr = signer::address_of(&publisher);
        
        seasons::init_seasons(&publisher);
        timestamp::set_time_has_started_for_testing(&account::create_signer_for_test(@0x1));
        
        let now = timestamp::now_seconds();
        let start_time = now + 100;
        let end_time = start_time + 86400; // 1 day
        
        seasons::create_season(
            &publisher,
            @0x123,
            string::utf8(b"Season 1"),
            start_time,
            end_time,
            0, // leaderboard_id
            1000000000 // 10 APT prize pool
        );
        
        assert!(seasons::get_season_count(pub_addr) == 1, 0);
        
        let (exists, name, s_time, e_time, lb_id, prize, finalized) = 
            seasons::get_season(pub_addr, 0);
        assert!(exists, 1);
        assert!(name == string::utf8(b"Season 1"), 2);
        assert!(s_time == start_time, 3);
        assert!(e_time == end_time, 4);
        assert!(lb_id == 0, 5);
        assert!(prize == 1000000000, 6);
        assert!(!finalized, 7);
    }

    #[test]
    #[expected_failure(abort_code = 6, location = sigil::seasons)] // E_INVALID_DURATION
    fun test_create_season_invalid_times_fails() {
        let (publisher, _, _) = setup_accounts();
        
        seasons::init_seasons(&publisher);
        timestamp::set_time_has_started_for_testing(&account::create_signer_for_test(@0x1));
        
        let now = timestamp::now_seconds();
        let start_time = now + 100;
        let end_time = start_time - 50; // End before start!
        
        seasons::create_season(
            &publisher,
            @0x123,
            string::utf8(b"Invalid Season"),
            start_time,
            end_time,
            0,
            0
        );
    }

    #[test]
    #[expected_failure(abort_code = 6, location = sigil::seasons)] // E_INVALID_DURATION
    fun test_create_season_too_long_fails() {
        let (publisher, _, _) = setup_accounts();
        
        seasons::init_seasons(&publisher);
        timestamp::set_time_has_started_for_testing(&account::create_signer_for_test(@0x1));
        
        let now = timestamp::now_seconds();
        let start_time = now + 100;
        let end_time = start_time + 7776001; // > 90 days
        
        seasons::create_season(
            &publisher,
            @0x123,
            string::utf8(b"Too Long Season"),
            start_time,
            end_time,
            0,
            0
        );
    }

    /************
     * Season Status Tests
     ************/

    #[test]
    fun test_season_status_upcoming() {
        let (publisher, _, _) = setup_accounts();
        let pub_addr = signer::address_of(&publisher);
        
        seasons::init_seasons(&publisher);
        timestamp::set_time_has_started_for_testing(&account::create_signer_for_test(@0x1));
        
        let now = timestamp::now_seconds();
        let start_time = now + 1000; // Future
        let end_time = start_time + 86400;
        
        seasons::create_season(
            &publisher,
            @0x123,
            string::utf8(b"Upcoming"),
            start_time,
            end_time,
            0,
            0
        );
        
        let (upcoming, active, ended) = seasons::get_season_status(pub_addr, 0);
        assert!(upcoming, 0);
        assert!(!active, 1);
        assert!(!ended, 2);
    }

    #[test]
    fun test_season_status_active() {
        let (publisher, _, _) = setup_accounts();
        let pub_addr = signer::address_of(&publisher);
        
        seasons::init_seasons(&publisher);
        let framework_signer = account::create_signer_for_test(@0x1);
        timestamp::set_time_has_started_for_testing(&framework_signer);
        timestamp::update_global_time_for_test(1700000000000000); // Set to a high value (microseconds)
        
        let now = timestamp::now_seconds();
        let start_time = now + 100; // Future
        let end_time = now + 86500; // Far future
        
        seasons::create_season(
            &publisher,
            @0x123,
            string::utf8(b"Active"),
            start_time,
            end_time,
            0,
            0
        );
        
        // Fast-forward time to make it active
        timestamp::update_global_time_for_test((now + 200) * 1000000); // Now it's active
        
        let (upcoming, active, ended) = seasons::get_season_status(pub_addr, 0);
        assert!(!upcoming, 0);
        assert!(active, 1);
        assert!(!ended, 2);
        assert!(seasons::is_season_active(pub_addr, 0), 3);
    }

    #[test]
    fun test_season_status_ended() {
        let (publisher, _, _) = setup_accounts();
        let pub_addr = signer::address_of(&publisher);
        
        seasons::init_seasons(&publisher);
        let framework_signer = account::create_signer_for_test(@0x1);
        timestamp::set_time_has_started_for_testing(&framework_signer);
        timestamp::update_global_time_for_test(1700000000000000); // Set to a high value (microseconds)
        
        let now = timestamp::now_seconds();
        let start_time = now + 100; // Future
        let end_time = now + 200; // Short season
        
        seasons::create_season(
            &publisher,
            @0x123,
            string::utf8(b"Ended"),
            start_time,
            end_time,
            0,
            0
        );
        
        // Fast-forward time past the end
        timestamp::update_global_time_for_test((now + 300) * 1000000); // Now it's ended
        
        let (upcoming, active, ended) = seasons::get_season_status(pub_addr, 0);
        assert!(!upcoming, 0);
        assert!(!active, 1);
        assert!(ended, 2);
        assert!(!seasons::is_season_active(pub_addr, 0), 3);
    }

    /************
     * Start/End Tests
     ************/

    #[test]
    fun test_start_season() {
        let (publisher, _, _) = setup_accounts();
        let pub_addr = signer::address_of(&publisher);
        
        seasons::init_seasons(&publisher);
        let framework_signer = account::create_signer_for_test(@0x1);
        timestamp::set_time_has_started_for_testing(&framework_signer);
        let base_time = 1700000000000000; // microseconds
        timestamp::update_global_time_for_test(base_time);
        
        let now = timestamp::now_seconds(); // 1700000000 seconds
        let start_time = now + 10; // Slightly future
        let end_time = now + 86400;
        
        seasons::create_season(
            &publisher,
            @0x123,
            string::utf8(b"Test"),
            start_time,
            end_time,
            0,
            0
        );
        
        // Fast-forward to after start time
        timestamp::update_global_time_for_test(base_time + 20000000); // +20 seconds
        
        seasons::start_season(&publisher, @0x123, 0);
        
        let (has_current, current_id) = seasons::get_current_season(pub_addr);
        assert!(has_current, 0);
        assert!(current_id == 0, 1);
    }

    #[test]
    fun test_end_season() {
        let (publisher, _, _) = setup_accounts();
        let pub_addr = signer::address_of(&publisher);
        
        seasons::init_seasons(&publisher);
        let framework_signer = account::create_signer_for_test(@0x1);
        timestamp::set_time_has_started_for_testing(&framework_signer);
        timestamp::update_global_time_for_test(1700000000000000); // Set to a high value (microseconds)
        
        let now = timestamp::now_seconds();
        seasons::create_season(&publisher, @0x123, string::utf8(b"Test"), now + 10, now + 86400, 0, 0);
        
        // Fast-forward to start time
        timestamp::update_global_time_for_test((now + 20) * 1000000);
        seasons::start_season(&publisher, @0x123, 0);
        
        seasons::end_season(&publisher, @0x123, 0);
        
        let (has_current, _) = seasons::get_current_season(pub_addr);
        assert!(!has_current, 0); // No current season after ending
    }

    /************
     * Score Recording Tests
     ************/

    #[test]
    fun test_record_season_score() {
        let (publisher, player1, _) = setup_accounts();
        let pub_addr = signer::address_of(&publisher);
        let player1_addr = signer::address_of(&player1);
        
        // Setup
        game_platform::init(&publisher);
        game_platform::register_player(&player1, string::utf8(b"Player1"));
        game_platform::register_game(&publisher, string::utf8(b"Game1"));
        
        seasons::init_seasons(&publisher);
        let framework_signer = account::create_signer_for_test(@0x1);
        timestamp::set_time_has_started_for_testing(&framework_signer);
        let base_time = 1700000000000000; // microseconds
        timestamp::update_global_time_for_test(base_time);
        
        let now = timestamp::now_seconds();
        seasons::create_season(&publisher, @0x123, string::utf8(b"Test"), now + 10, now + 86400, 0, 0);
        
        // Fast-forward to after start time
        timestamp::update_global_time_for_test(base_time + 20000000); // +20 seconds
        seasons::start_season(&publisher, @0x123, 0);
        
        // Record scores via internal function
        seasons::record_season_score(pub_addr, player1_addr, 0, 1000);
        seasons::record_season_score(pub_addr, player1_addr, 0, 1500); // Better score
        
        // Check recorded score
        let (has_score, score) = seasons::get_season_score(pub_addr, 0, 0, player1_addr);
        assert!(has_score, 0);
        assert!(score == 1500, 1); // Should keep best score
    }

    /************
     * Multiple Seasons Tests
     ************/

    #[test]
    fun test_two_seasons_isolated() {
        let (publisher, player1, _) = setup_accounts();
        let pub_addr = signer::address_of(&publisher);
        let player1_addr = signer::address_of(&player1);
        
        // Setup
        game_platform::init(&publisher);
        game_platform::register_player(&player1, string::utf8(b"Player1"));
        game_platform::register_game(&publisher, string::utf8(b"Game1"));
        
        seasons::init_seasons(&publisher);
        let framework_signer = account::create_signer_for_test(@0x1);
        timestamp::set_time_has_started_for_testing(&framework_signer);
        timestamp::update_global_time_for_test(1700000000000000); // Set to a high value (microseconds)
        
        let now = timestamp::now_seconds();
        
        // Create two seasons (both in future initially)
        seasons::create_season(&publisher, @0x123, string::utf8(b"Season 1"), now + 100, now + 200, 0, 0);
        seasons::create_season(&publisher, @0x123, string::utf8(b"Season 2"), now + 300, now + 86700, 1, 0);
        
        // Fast-forward to season 0 start time
        timestamp::update_global_time_for_test((now + 150) * 1000000);
        
        // Record score in season 0 (will end soon)
        seasons::start_season(&publisher, @0x123, 0);
        seasons::record_season_score(pub_addr, player1_addr, 0, 1000);
        
        // Check season 1 (future) has no scores
        let (has_score_s1, _) = seasons::get_season_score(pub_addr, 1, 0, player1_addr);
        assert!(!has_score_s1, 0); // Season 1 has no scores yet
        
        // Verify season count
        assert!(seasons::get_season_count(pub_addr) == 2, 1);
    }

    /************
     * Achievement Association Tests
     ************/

    #[test]
    fun test_add_season_achievement() {
        let (publisher, _, _) = setup_accounts();
        let pub_addr = signer::address_of(&publisher);
        
        seasons::init_seasons(&publisher);
        timestamp::set_time_has_started_for_testing(&account::create_signer_for_test(@0x1));
        
        let now = timestamp::now_seconds();
        seasons::create_season(&publisher, @0x123, string::utf8(b"Test"), now + 10, now + 86400, 0, 0);
        
        // Add achievement to season
        seasons::add_season_achievement(&publisher, @0x123, 0, 42);
        
        // Would need a view function to verify, but this tests it doesn't crash
        assert!(seasons::get_season_count(pub_addr) == 1, 0);
    }

    /************
     * View Function Tests
     ************/

    #[test]
    fun test_is_initialized_false() {
        assert!(!seasons::is_initialized(@0x999), 0);
    }

    #[test]
    fun test_get_season_not_found() {
        let (publisher, _, _) = setup_accounts();
        let pub_addr = signer::address_of(&publisher);
        
        seasons::init_seasons(&publisher);
        
        let (exists, _, _, _, _, _, _) = seasons::get_season(pub_addr, 999);
        assert!(!exists, 0);
    }

    #[test]
    fun test_get_season_score_no_season() {
        let (publisher, player1, _) = setup_accounts();
        let pub_addr = signer::address_of(&publisher);
        let player1_addr = signer::address_of(&player1);
        
        seasons::init_seasons(&publisher);
        
        let (has_score, _) = seasons::get_season_score(pub_addr, 0, 0, player1_addr);
        assert!(!has_score, 0);
    }
}

