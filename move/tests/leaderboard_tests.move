#[test_only]
module sigil::leaderboard_tests {
    use std::string;
    use std::vector;
    use std::signer;
    use aptos_framework::account;
    use sigil::game_platform;
    use sigil::leaderboard;

    // Test helper to create test accounts
    fun setup_test_accounts(): (signer, signer, signer, signer) {
        let publisher = account::create_account_for_test(@0x123);
        let player1 = account::create_account_for_test(@0x456);
        let player2 = account::create_account_for_test(@0x789);
        let player3 = account::create_account_for_test(@0xabc);
        (publisher, player1, player2, player3)
    }

    #[test]
    fun test_init_leaderboards() {
        let publisher = account::create_account_for_test(@0x123);
        leaderboard::init_leaderboards(&publisher);
        
        // Verify initialization
        let count = leaderboard::get_leaderboard_count(@0x123);
        assert!(count == 0, 0);
    }

    #[test]
    #[expected_failure(abort_code = 0)] // E_ALREADY_INIT
    fun test_init_leaderboards_twice_fails() {
        let publisher = account::create_account_for_test(@0x123);
        leaderboard::init_leaderboards(&publisher);
        leaderboard::init_leaderboards(&publisher); // Should fail
    }

    #[test]
    fun test_create_leaderboard() {
        let (publisher, _, _, _) = setup_test_accounts();
        
        // Initialize game platform first (required for validation)
        game_platform::init(&publisher);
        game_platform::register_game(&publisher, string::utf8(b"Test Game"));
        
        // Initialize leaderboards
        leaderboard::init_leaderboards(&publisher);
        
        // Create leaderboard for game 0
        leaderboard::create_leaderboard(
            &publisher,
            0,      // game_id
            0,      // decimals
            0,      // min_score
            1000,   // max_score
            false,  // is_ascending (higher is better)
            false,  // allow_multiple
            5       // scores_to_retain
        );
        
        // Verify leaderboard was created
        let count = leaderboard::get_leaderboard_count(@0x123);
        assert!(count == 1, 1);
        
        // Verify config
        let (game_id, decimals, min, max, ascending, multiple, retain) = 
            leaderboard::get_leaderboard_config(@0x123, 0);
        
        assert!(game_id == 0, 2);
        assert!(decimals == 0, 3);
        assert!(min == 0, 4);
        assert!(max == 1000, 5);
        assert!(ascending == false, 6);
        assert!(multiple == false, 7);
        assert!(retain == 5, 8);
    }

    #[test]
    fun test_create_leaderboard_independent() {
        let publisher = account::create_account_for_test(@0x123);
        
        // Initialize game platform but DON'T create a game
        game_platform::init(&publisher);
        leaderboard::init_leaderboards(&publisher);
        
        // Create leaderboard without game (works in independent mode)
        leaderboard::create_leaderboard(
            &publisher,
            0,      // game_id (no validation in independent mode)
            0,      // decimals
            0,      // min_score
            1000,   // max_score
            false,  // is_ascending
            false,  // allow_multiple
            5       // scores_to_retain
        ); // Works in independent deployment mode
        
        let count = leaderboard::get_leaderboard_count(@0x123);
        assert!(count == 1, 77);
    }

    #[test]
    fun test_submit_score_and_ranking() {
        let (publisher, player1, player2, player3) = setup_test_accounts();
        
        // Setup game and leaderboard
        game_platform::init(&publisher);
        game_platform::register_game(&publisher, string::utf8(b"Test Game"));
        leaderboard::init_leaderboards(&publisher);
        leaderboard::create_leaderboard(&publisher, 0, 0, 0, 10000, false, false, 5);
        
        // Submit scores
        leaderboard::on_score(@0x123, 0, @0x456, 1000); // player1: 1000
        leaderboard::on_score(@0x123, 0, @0x789, 1500); // player2: 1500
        leaderboard::on_score(@0x123, 0, @0xabc, 800);  // player3: 800
        
        // Get top entries
        let (players, scores) = leaderboard::get_top_entries(@0x123, 0);
        
        // Verify count
        assert!(vector::length(&players) == 3, 10);
        assert!(vector::length(&scores) == 3, 11);
        
        // Verify ranking (descending order: 1500, 1000, 800)
        assert!(*vector::borrow(&players, 0) == @0x789, 12); // player2
        assert!(*vector::borrow(&scores, 0) == 1500, 13);
        
        assert!(*vector::borrow(&players, 1) == @0x456, 14); // player1
        assert!(*vector::borrow(&scores, 1) == 1000, 15);
        
        assert!(*vector::borrow(&players, 2) == @0xabc, 16); // player3
        assert!(*vector::borrow(&scores, 2) == 800, 17);
    }

    #[test]
    fun test_score_update_replaces_old_score() {
        let (publisher, player1, _, _) = setup_test_accounts();
        
        // Setup
        game_platform::init(&publisher);
        game_platform::register_game(&publisher, string::utf8(b"Test Game"));
        leaderboard::init_leaderboards(&publisher);
        leaderboard::create_leaderboard(&publisher, 0, 0, 0, 10000, false, false, 5);
        
        // Submit initial score
        leaderboard::on_score(@0x123, 0, @0x456, 1000);
        
        let (players, scores) = leaderboard::get_top_entries(@0x123, 0);
        assert!(vector::length(&players) == 1, 20);
        assert!(*vector::borrow(&scores, 0) == 1000, 21);
        
        // Submit better score
        leaderboard::on_score(@0x123, 0, @0x456, 1500);
        
        let (players2, scores2) = leaderboard::get_top_entries(@0x123, 0);
        assert!(vector::length(&players2) == 1, 22); // Still only 1 entry
        assert!(*vector::borrow(&scores2, 0) == 1500, 23); // Updated to new score
    }

    #[test]
    fun test_worse_score_ignored() {
        let (publisher, player1, _, _) = setup_test_accounts();
        
        // Setup
        game_platform::init(&publisher);
        game_platform::register_game(&publisher, string::utf8(b"Test Game"));
        leaderboard::init_leaderboards(&publisher);
        leaderboard::create_leaderboard(&publisher, 0, 0, 0, 10000, false, false, 5);
        
        // Submit initial score
        leaderboard::on_score(@0x123, 0, @0x456, 1500);
        
        // Submit worse score (should be ignored)
        leaderboard::on_score(@0x123, 0, @0x456, 1000);
        
        let (_, scores) = leaderboard::get_top_entries(@0x123, 0);
        assert!(*vector::borrow(&scores, 0) == 1500, 30); // Still the better score
    }

    #[test]
    fun test_ascending_order() {
        let (publisher, player1, player2, _) = setup_test_accounts();
        
        // Setup with ascending order (lower is better)
        game_platform::init(&publisher);
        game_platform::register_game(&publisher, string::utf8(b"Speedrun"));
        leaderboard::init_leaderboards(&publisher);
        leaderboard::create_leaderboard(
            &publisher, 
            0,      // game_id
            0,      // decimals
            0,      // min_score
            10000,  // max_score
            true,   // is_ascending = true (lower is better)
            false,  // allow_multiple
            5       // scores_to_retain
        );
        
        // Submit times (lower is better)
        leaderboard::on_score(@0x123, 0, @0x456, 5000); // player1: 5 seconds
        leaderboard::on_score(@0x123, 0, @0x789, 3000); // player2: 3 seconds (better)
        
        let (players, scores) = leaderboard::get_top_entries(@0x123, 0);
        
        // Verify player2 (3000) ranks first
        assert!(*vector::borrow(&players, 0) == @0x789, 40);
        assert!(*vector::borrow(&scores, 0) == 3000, 41);
        
        assert!(*vector::borrow(&players, 1) == @0x456, 42);
        assert!(*vector::borrow(&scores, 1) == 5000, 43);
    }

    #[test]
    fun test_score_gates_min() {
        let (publisher, player1, _, _) = setup_test_accounts();
        
        // Setup with min score = 100
        game_platform::init(&publisher);
        game_platform::register_game(&publisher, string::utf8(b"Test Game"));
        leaderboard::init_leaderboards(&publisher);
        leaderboard::create_leaderboard(
            &publisher, 
            0,      // game_id
            0,      // decimals
            100,    // min_score
            10000,  // max_score
            false,  // is_ascending
            false,  // allow_multiple
            5       // scores_to_retain
        );
        
        // Submit score below minimum (should be ignored)
        leaderboard::on_score(@0x123, 0, @0x456, 50);
        
        let (players, _) = leaderboard::get_top_entries(@0x123, 0);
        assert!(vector::length(&players) == 0, 50); // No entries
        
        // Submit valid score
        leaderboard::on_score(@0x123, 0, @0x456, 500);
        
        let (players2, scores2) = leaderboard::get_top_entries(@0x123, 0);
        assert!(vector::length(&players2) == 1, 51);
        assert!(*vector::borrow(&scores2, 0) == 500, 52);
    }

    #[test]
    fun test_score_gates_max() {
        let (publisher, player1, _, _) = setup_test_accounts();
        
        // Setup with max score = 1000
        game_platform::init(&publisher);
        game_platform::register_game(&publisher, string::utf8(b"Test Game"));
        leaderboard::init_leaderboards(&publisher);
        leaderboard::create_leaderboard(
            &publisher, 
            0,      // game_id
            0,      // decimals
            0,      // min_score
            1000,   // max_score
            false,  // is_ascending
            false,  // allow_multiple
            5       // scores_to_retain
        );
        
        // Submit score above maximum (should be ignored)
        leaderboard::on_score(@0x123, 0, @0x456, 2000);
        
        let (players, _) = leaderboard::get_top_entries(@0x123, 0);
        assert!(vector::length(&players) == 0, 60); // No entries
        
        // Submit valid score
        leaderboard::on_score(@0x123, 0, @0x456, 500);
        
        let (players2, scores2) = leaderboard::get_top_entries(@0x123, 0);
        assert!(vector::length(&players2) == 1, 61);
        assert!(*vector::borrow(&scores2, 0) == 500, 62);
    }

    #[test]
    fun test_top_n_retention() {
        let (publisher, _, _, _) = setup_test_accounts();
        
        // Setup with retain = 3 (keep only top 3)
        game_platform::init(&publisher);
        game_platform::register_game(&publisher, string::utf8(b"Test Game"));
        leaderboard::init_leaderboards(&publisher);
        leaderboard::create_leaderboard(
            &publisher, 
            0,      // game_id
            0,      // decimals
            0,      // min_score
            10000,  // max_score
            false,  // is_ascending
            false,  // allow_multiple
            3       // scores_to_retain = 3
        );
        
        // Submit 5 scores
        leaderboard::on_score(@0x123, 0, @0x111, 1000);
        leaderboard::on_score(@0x123, 0, @0x222, 2000);
        leaderboard::on_score(@0x123, 0, @0x333, 3000);
        leaderboard::on_score(@0x123, 0, @0x444, 4000);
        leaderboard::on_score(@0x123, 0, @0x555, 5000);
        
        let (players, scores) = leaderboard::get_top_entries(@0x123, 0);
        
        // Should only keep top 3
        assert!(vector::length(&players) == 3, 70);
        assert!(*vector::borrow(&scores, 0) == 5000, 71);
        assert!(*vector::borrow(&scores, 1) == 4000, 72);
        assert!(*vector::borrow(&scores, 2) == 3000, 73);
    }

    #[test]
    fun test_multiple_leaderboards_per_game() {
        let (publisher, player1, _, _) = setup_test_accounts();
        
        // Setup
        game_platform::init(&publisher);
        game_platform::register_game(&publisher, string::utf8(b"Test Game"));
        leaderboard::init_leaderboards(&publisher);
        
        // Create two leaderboards for the same game
        leaderboard::create_leaderboard(&publisher, 0, 0, 0, 10000, false, false, 5);
        leaderboard::create_leaderboard(&publisher, 0, 0, 0, 10000, true, false, 3);
        
        let count = leaderboard::get_leaderboard_count(@0x123);
        assert!(count == 2, 80);
        
        // Submit score to each
        leaderboard::on_score(@0x123, 0, @0x456, 1000);
        leaderboard::on_score(@0x123, 1, @0x456, 2000);
        
        let (_, scores1) = leaderboard::get_top_entries(@0x123, 0);
        let (_, scores2) = leaderboard::get_top_entries(@0x123, 1);
        
        assert!(*vector::borrow(&scores1, 0) == 1000, 81);
        assert!(*vector::borrow(&scores2, 0) == 2000, 82);
    }

    #[test]
    fun test_player_ranking_update() {
        let (publisher, _, _, _) = setup_test_accounts();
        
        // Setup
        game_platform::init(&publisher);
        game_platform::register_game(&publisher, string::utf8(b"Test Game"));
        leaderboard::init_leaderboards(&publisher);
        leaderboard::create_leaderboard(&publisher, 0, 0, 0, 10000, false, false, 5);
        
        // Initial rankings
        leaderboard::on_score(@0x123, 0, @0x111, 1000);
        leaderboard::on_score(@0x123, 0, @0x222, 2000);
        leaderboard::on_score(@0x123, 0, @0x333, 3000);
        
        let (players, _) = leaderboard::get_top_entries(@0x123, 0);
        assert!(*vector::borrow(&players, 0) == @0x333, 90); // 3000
        assert!(*vector::borrow(&players, 1) == @0x222, 91); // 2000
        assert!(*vector::borrow(&players, 2) == @0x111, 92); // 1000
        
        // Player 1 improves to first place
        leaderboard::on_score(@0x123, 0, @0x111, 5000);
        
        let (players2, scores2) = leaderboard::get_top_entries(@0x123, 0);
        assert!(*vector::borrow(&players2, 0) == @0x111, 93); // Now first
        assert!(*vector::borrow(&scores2, 0) == 5000, 94);
        assert!(*vector::borrow(&players2, 1) == @0x333, 95); // 3000
        assert!(*vector::borrow(&players2, 2) == @0x222, 96); // 2000
    }

    #[test]
    fun test_empty_leaderboard() {
        let publisher = account::create_account_for_test(@0x123);
        
        // Setup
        game_platform::init(&publisher);
        game_platform::register_game(&publisher, string::utf8(b"Test Game"));
        leaderboard::init_leaderboards(&publisher);
        leaderboard::create_leaderboard(&publisher, 0, 0, 0, 10000, false, false, 5);
        
        // Query empty leaderboard
        let (players, scores) = leaderboard::get_top_entries(@0x123, 0);
        
        assert!(vector::length(&players) == 0, 100);
        assert!(vector::length(&scores) == 0, 101);
    }

    #[test]
    fun test_submit_score_direct_wrapper() {
        let (publisher, player1, _, _) = setup_test_accounts();
        
        // Setup
        game_platform::init(&publisher);
        game_platform::register_game(&publisher, string::utf8(b"Test Game"));
        leaderboard::init_leaderboards(&publisher);
        leaderboard::create_leaderboard(&publisher, 0, 0, 0, 10000, false, false, 5);
        
        // Use the CLI wrapper function
        leaderboard::submit_score_direct(&player1, @0x123, 0, @0x456, 1000);
        
        let (players, scores) = leaderboard::get_top_entries(@0x123, 0);
        assert!(vector::length(&players) == 1, 110);
        assert!(*vector::borrow(&scores, 0) == 1000, 111);
    }

    /************
     * Roles Integration Tests
     ************/

    #[test]
    fun test_roles_operator_can_create_leaderboard() {
        use sigil::roles;
        
        let publisher = account::create_account_for_test(@0x123);
        let operator = account::create_account_for_test(@0x456);
        let pub_addr = signer::address_of(&publisher);
        let op_addr = signer::address_of(&operator);
        
        // Setup
        leaderboard::init_leaderboards(&publisher);
        roles::init_roles(&publisher);
        roles::add_operator(&publisher, pub_addr, op_addr);
        
        // Operator should be able to create leaderboard
        leaderboard::create_leaderboard(
            &operator,
            0,      // game_id
            0,      // decimals
            0,      // min_score
            10000,  // max_score
            false,  // is_ascending
            false,  // allow_multiple
            10      // scores_to_retain
        );
        
        // Verify it was created
        assert!(leaderboard::get_leaderboard_count(pub_addr) == 1, 0);
    }

    #[test]
    #[expected_failure(abort_code = 4, location = sigil::leaderboard)] // E_NO_PERMISSION
    fun test_roles_unauthorized_cannot_create_leaderboard() {
        use sigil::roles;
        
        let publisher = account::create_account_for_test(@0x123);
        let unauthorized = account::create_account_for_test(@0x999);
        
        // Setup
        leaderboard::init_leaderboards(&publisher);
        roles::init_roles(&publisher);
        
        // Unauthorized user tries to create leaderboard (should fail)
        leaderboard::create_leaderboard(
            &unauthorized,
            0,
            0,
            0,
            10000,
            false,
            false,
            10
        );
    }

    #[test]
    fun test_roles_admin_can_create_leaderboard() {
        use sigil::roles;
        
        let publisher = account::create_account_for_test(@0x123);
        let admin = account::create_account_for_test(@0x456);
        let pub_addr = signer::address_of(&publisher);
        let admin_addr = signer::address_of(&admin);
        
        // Setup
        leaderboard::init_leaderboards(&publisher);
        roles::init_roles(&publisher);
        roles::add_admin(&publisher, pub_addr, admin_addr);
        
        // Admin should be able to create leaderboard
        leaderboard::create_leaderboard(
            &admin,
            0,
            0,
            0,
            10000,
            false,
            false,
            10
        );
        
        // Verify it was created
        assert!(leaderboard::get_leaderboard_count(pub_addr) == 1, 0);
    }

    #[test]
    fun test_roles_owner_always_has_permission_for_leaderboard() {
        use sigil::roles;
        
        let publisher = account::create_account_for_test(@0x123);
        let pub_addr = signer::address_of(&publisher);
        
        // Setup
        leaderboard::init_leaderboards(&publisher);
        roles::init_roles(&publisher);
        
        // Owner can always create leaderboards
        leaderboard::create_leaderboard(
            &publisher,
            0,
            0,
            0,
            10000,
            false,
            false,
            10
        );
        
        // Verify
        assert!(leaderboard::get_leaderboard_count(pub_addr) == 1, 0);
    }
}

