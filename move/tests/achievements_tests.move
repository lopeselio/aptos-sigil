#[test_only]
module sigil::achievements_tests {
    use std::vector;
    use std::option;
    use std::signer;
    use aptos_framework::account;
    use sigil::achievements;

    // Test helper to create test accounts
    fun setup_test_accounts(): (signer, signer, signer, signer) {
        let publisher = account::create_account_for_test(@0x123);
        let player1 = account::create_account_for_test(@0x456);
        let player2 = account::create_account_for_test(@0x789);
        let player3 = account::create_account_for_test(@0xabc);
        (publisher, player1, player2, player3)
    }

    #[test]
    fun test_init_achievements() {
        let publisher = account::create_account_for_test(@0x123);
        achievements::init_achievements(&publisher);
        
        // Verify initialization
        let count = achievements::achievement_count(@0x123);
        assert!(count == 0, 0);
    }

    #[test]
    #[expected_failure(abort_code = 0)] // E_ALREADY_INIT
    fun test_init_achievements_twice_fails() {
        let publisher = account::create_account_for_test(@0x123);
        achievements::init_achievements(&publisher);
        achievements::init_achievements(&publisher); // Should fail
    }

    #[test]
    fun test_create_basic_achievement() {
        let publisher = account::create_account_for_test(@0x123);
        achievements::init_achievements(&publisher);
        
        // Create achievement: "Score 1000+"
        achievements::create(
            &publisher,
            b"High Scorer",
            b"Score 1000 or more",
            1000,
            vector::empty<u8>()  // no badge URI
        );
        
        let count = achievements::achievement_count(@0x123);
        assert!(count == 1, 1);
        
        // Verify details
        let (id, title, desc, min_score, game_id, badge) = 
            achievements::get_achievement(@0x123, 0);
        
        assert!(id == 0, 2);
        assert!(title == b"High Scorer", 3);
        assert!(desc == b"Score 1000 or more", 4);
        assert!(min_score == 1000, 5);
        assert!(option::is_none(&game_id), 6);
        assert!(option::is_none(&badge), 7);
    }

    #[test]
    fun test_create_achievement_with_badge() {
        let publisher = account::create_account_for_test(@0x123);
        achievements::init_achievements(&publisher);
        
        achievements::create(
            &publisher,
            b"Gold Medal",
            b"Top performer",
            5000,
            b"https://example.com/gold.png"
        );
        
        let (_, _, _, _, _, badge) = achievements::get_achievement(@0x123, 0);
        assert!(option::is_some(&badge), 10);
        assert!(*option::borrow(&badge) == b"https://example.com/gold.png", 11);
    }

    #[test]
    fun test_create_with_game() {
        let publisher = account::create_account_for_test(@0x123);
        achievements::init_achievements(&publisher);
        
        achievements::create_with_game(
            &publisher,
            b"Game Master",
            b"Master of Game 0",
            0,      // game_id
            2000,
            vector::empty<u8>()
        );
        
        let (_, _, _, _, game_id, _) = achievements::get_achievement(@0x123, 0);
        assert!(option::is_some(&game_id), 20);
        assert!(*option::borrow(&game_id) == 0, 21);
    }

    #[test]
    fun test_grant_achievement() {
        let (publisher, _, _, _) = setup_test_accounts();
        achievements::init_achievements(&publisher);
        
        achievements::create(
            &publisher,
            b"Special Award",
            b"Manually granted",
            0,
            vector::empty<u8>()
        );
        
        // Publisher grants achievement to player
        achievements::grant(&publisher, @0x456, 0);
        
        // Verify unlocked
        let unlocked = achievements::is_unlocked(@0x123, @0x456, 0);
        assert!(unlocked, 30);
        
        let unlocked_list = achievements::unlocked_for(@0x123, @0x456);
        assert!(vector::length(&unlocked_list) == 1, 31);
        assert!(*vector::borrow(&unlocked_list, 0) == 0, 32);
    }

    #[test]
    fun test_basic_score_unlock() {
        let (publisher, _, _, _) = setup_test_accounts();
        achievements::init_achievements(&publisher);
        
        // Create achievement: "Score 1000+"
        achievements::create(
            &publisher,
            b"High Scorer",
            b"Score 1000+",
            1000,
            vector::empty<u8>()
        );
        
        // Submit score below threshold (should not unlock)
        achievements::on_score(@0x123, @0x456, 0, 500);
        assert!(!achievements::is_unlocked(@0x123, @0x456, 0), 40);
        
        // Submit score at threshold (should unlock)
        achievements::on_score(@0x123, @0x456, 0, 1000);
        assert!(achievements::is_unlocked(@0x123, @0x456, 0), 41);
    }

    #[test]
    fun test_game_specific_achievement() {
        let (publisher, _, _, _) = setup_test_accounts();
        achievements::init_achievements(&publisher);
        
        // Achievement only for game 1
        achievements::create_with_game(
            &publisher,
            b"Game 1 Master",
            b"High score on Game 1",
            1,      // game_id
            1000,
            vector::empty<u8>()
        );
        
        // Score on game 0 (should not unlock)
        achievements::on_score(@0x123, @0x456, 0, 1500);
        assert!(!achievements::is_unlocked(@0x123, @0x456, 0), 50);
        
        // Score on game 1 (should unlock)
        achievements::on_score(@0x123, @0x456, 1, 1500);
        assert!(achievements::is_unlocked(@0x123, @0x456, 0), 51);
    }

    #[test]
    fun test_advanced_required_count() {
        let (publisher, _, _, _) = setup_test_accounts();
        achievements::init_achievements(&publisher);
        
        // "Score 1000+ three times"
        achievements::create_advanced(
            &publisher,
            b"Consistent Performer",
            b"Score 1000+ three times",
            1000,   // min_score
            3,      // required_count
            0,      // min_submissions (ignored)
            vector::empty<u8>()
        );
        
        // First time
        achievements::on_score(@0x123, @0x456, 0, 1200);
        let (thresh, subs, unlocked) = achievements::get_progress(@0x123, @0x456, 0);
        assert!(thresh == 1, 60);
        assert!(subs == 1, 61);
        assert!(!unlocked, 62);
        
        // Second time
        achievements::on_score(@0x123, @0x456, 0, 1500);
        let (thresh2, subs2, unlocked2) = achievements::get_progress(@0x123, @0x456, 0);
        assert!(thresh2 == 2, 63);
        assert!(subs2 == 2, 64);
        assert!(!unlocked2, 65);
        
        // Third time (should unlock)
        achievements::on_score(@0x123, @0x456, 0, 1100);
        let (thresh3, subs3, unlocked3) = achievements::get_progress(@0x123, @0x456, 0);
        assert!(thresh3 == 3, 66);
        assert!(subs3 == 3, 67);
        assert!(unlocked3, 68);  // Unlocked!
    }

    #[test]
    fun test_advanced_min_submissions() {
        let (publisher, _, _, _) = setup_test_accounts();
        achievements::init_achievements(&publisher);
        
        // "Play 5 times" (regardless of score)
        achievements::create_advanced(
            &publisher,
            b"Dedicated Player",
            b"Play 5 times",
            0,      // min_score (0 = any score counts)
            0,      // required_count (ignored)
            5,      // min_submissions
            vector::empty<u8>()
        );
        
        // Submit 4 times
        achievements::on_score(@0x123, @0x456, 0, 100);
        achievements::on_score(@0x123, @0x456, 0, 200);
        achievements::on_score(@0x123, @0x456, 0, 50);
        achievements::on_score(@0x123, @0x456, 0, 300);
        
        let (_, subs, unlocked) = achievements::get_progress(@0x123, @0x456, 0);
        assert!(subs == 4, 70);
        assert!(!unlocked, 71);
        
        // 5th time (should unlock)
        achievements::on_score(@0x123, @0x456, 0, 1);
        let (_, subs2, unlocked2) = achievements::get_progress(@0x123, @0x456, 0);
        assert!(subs2 == 5, 72);
        assert!(unlocked2, 73);
    }

    #[test]
    fun test_advanced_combined_conditions() {
        let (publisher, _, _, _) = setup_test_accounts();
        achievements::init_achievements(&publisher);
        
        // "Score 500+ in 3 out of 5 games"
        achievements::create_advanced(
            &publisher,
            b"Combo Master",
            b"Score 500+ three times in five attempts",
            500,    // min_score
            3,      // required_count (3 times above 500)
            5,      // min_submissions (total 5 games)
            vector::empty<u8>()
        );
        
        // Submit 5 scores: 2 above threshold, 3 below
        achievements::on_score(@0x123, @0x456, 0, 600);  // ✓ above
        achievements::on_score(@0x123, @0x456, 0, 300);  // ✗ below
        achievements::on_score(@0x123, @0x456, 0, 700);  // ✓ above
        achievements::on_score(@0x123, @0x456, 0, 200);  // ✗ below
        
        let (thresh, subs, unlocked) = achievements::get_progress(@0x123, @0x456, 0);
        assert!(thresh == 2, 80);
        assert!(subs == 4, 81);
        assert!(!unlocked, 82);  // Not yet (need 3 above, have 2)
        
        // 5th submission below threshold
        achievements::on_score(@0x123, @0x456, 0, 100);  // ✗ below
        let (thresh2, subs2, unlocked2) = achievements::get_progress(@0x123, @0x456, 0);
        assert!(thresh2 == 2, 83);
        assert!(subs2 == 5, 84);
        assert!(!unlocked2, 85);  // Still not unlocked (only 2/3 above threshold)
        
        // One more above threshold
        achievements::on_score(@0x123, @0x456, 0, 800);  // ✓ above
        let (thresh3, subs3, unlocked3) = achievements::get_progress(@0x123, @0x456, 0);
        assert!(thresh3 == 3, 86);
        assert!(subs3 == 6, 87);
        assert!(unlocked3, 88);  // Unlocked! (3 above threshold, 6 total submissions)
    }

    #[test]
    fun test_multiple_achievements() {
        let (publisher, _, _, _) = setup_test_accounts();
        achievements::init_achievements(&publisher);
        
        // Create 3 achievements
        achievements::create(&publisher, b"Novice", b"Score 100+", 100, vector::empty<u8>());
        achievements::create(&publisher, b"Expert", b"Score 1000+", 1000, vector::empty<u8>());
        achievements::create(&publisher, b"Master", b"Score 5000+", 5000, vector::empty<u8>());
        
        // Submit score that unlocks first two
        achievements::on_score(@0x123, @0x456, 0, 1500);
        
        let unlocked_list = achievements::unlocked_for(@0x123, @0x456);
        assert!(vector::length(&unlocked_list) == 2, 90);
        assert!(*vector::borrow(&unlocked_list, 0) == 0, 91);  // Novice
        assert!(*vector::borrow(&unlocked_list, 1) == 1, 92);  // Expert
        
        // Submit higher score (unlocks all three)
        achievements::on_score(@0x123, @0x456, 0, 6000);
        let unlocked_list2 = achievements::unlocked_for(@0x123, @0x456);
        assert!(vector::length(&unlocked_list2) == 3, 93);
    }

    #[test]
    fun test_already_unlocked_not_duplicate() {
        let (publisher, _, _, _) = setup_test_accounts();
        achievements::init_achievements(&publisher);
        
        achievements::create(&publisher, b"Test", b"Test", 100, vector::empty<u8>());
        
        // Unlock once
        achievements::on_score(@0x123, @0x456, 0, 200);
        assert!(achievements::is_unlocked(@0x123, @0x456, 0), 100);
        
        // Submit again (should not duplicate)
        achievements::on_score(@0x123, @0x456, 0, 300);
        
        let unlocked_list = achievements::unlocked_for(@0x123, @0x456);
        assert!(vector::length(&unlocked_list) == 1, 101);  // Still just 1
    }

    #[test]
    fun test_progress_tracking() {
        let (publisher, _, _, _) = setup_test_accounts();
        achievements::init_achievements(&publisher);
        
        achievements::create_advanced(
            &publisher,
            b"Grinder",
            b"Score 500+ five times",
            500,
            5,
            0,
            vector::empty<u8>()
        );
        
        // Submit mix of scores
        achievements::on_score(@0x123, @0x456, 0, 600);  // Above
        achievements::on_score(@0x123, @0x456, 0, 300);  // Below
        achievements::on_score(@0x123, @0x456, 0, 700);  // Above
        
        let (thresh, subs, unlocked) = achievements::get_progress(@0x123, @0x456, 0);
        assert!(thresh == 2, 110);          // 2 times above 500
        assert!(subs == 3, 111);            // 3 total submissions
        assert!(!unlocked, 112);            // Not yet unlocked
    }

    #[test]
    fun test_list_catalog() {
        let (publisher, _, _, _) = setup_test_accounts();
        achievements::init_achievements(&publisher);
        
        achievements::create(&publisher, b"Ach1", b"Desc1", 100, vector::empty<u8>());
        achievements::create(&publisher, b"Ach2", b"Desc2", 200, vector::empty<u8>());
        achievements::create_with_game(&publisher, b"Ach3", b"Desc3", 5, 300, vector::empty<u8>());
        
        let (ids, titles, descs, mins, game_ids) = achievements::list_catalog(@0x123);
        
        assert!(vector::length(&ids) == 3, 120);
        assert!(*vector::borrow(&ids, 0) == 0, 121);
        assert!(*vector::borrow(&titles, 0) == b"Ach1", 122);
        assert!(*vector::borrow(&mins, 0) == 100, 123);
        assert!(*vector::borrow(&mins, 2) == 300, 124);
    }

    #[test]
    fun test_multiple_players() {
        let (publisher, _, _, _) = setup_test_accounts();
        achievements::init_achievements(&publisher);
        
        achievements::create(&publisher, b"Champion", b"Score 1000+", 1000, vector::empty<u8>());
        
        // Two players unlock same achievement
        achievements::on_score(@0x123, @0x456, 0, 1200);
        achievements::on_score(@0x123, @0x789, 0, 1500);
        
        assert!(achievements::is_unlocked(@0x123, @0x456, 0), 130);
        assert!(achievements::is_unlocked(@0x123, @0x789, 0), 131);
        
        // Third player doesn't unlock
        achievements::on_score(@0x123, @0xabc, 0, 500);
        assert!(!achievements::is_unlocked(@0x123, @0xabc, 0), 132);
    }

    #[test]
    fun test_progress_persists() {
        let (publisher, _, _, _) = setup_test_accounts();
        achievements::init_achievements(&publisher);
        
        achievements::create_advanced(
            &publisher,
            b"Marathon",
            b"Play 10 times",
            0,
            0,
            10,
            vector::empty<u8>()
        );
        
        // Submit 3 scores
        achievements::on_score(@0x123, @0x456, 0, 100);
        achievements::on_score(@0x123, @0x456, 0, 200);
        achievements::on_score(@0x123, @0x456, 0, 300);
        
        let (_, subs1, _) = achievements::get_progress(@0x123, @0x456, 0);
        assert!(subs1 == 3, 140);
        
        // Continue later (progress should persist)
        achievements::on_score(@0x123, @0x456, 0, 400);
        let (_, subs2, _) = achievements::get_progress(@0x123, @0x456, 0);
        assert!(subs2 == 4, 141);  // Incremented from 3
    }

    #[test]
    fun test_zero_min_score_counts_all() {
        let (publisher, _, _, _) = setup_test_accounts();
        achievements::init_achievements(&publisher);
        
        // min_score = 0 means any score counts
        achievements::create_advanced(
            &publisher,
            b"Participant",
            b"Play 3 times (any score)",
            0,      // min_score = 0
            0,      // required_count ignored
            3,      // min_submissions
            vector::empty<u8>()
        );
        
        // Submit low scores
        achievements::on_score(@0x123, @0x456, 0, 1);
        achievements::on_score(@0x123, @0x456, 0, 2);
        achievements::on_score(@0x123, @0x456, 0, 3);
        
        let (_, _, unlocked) = achievements::get_progress(@0x123, @0x456, 0);
        assert!(unlocked, 150);  // All low scores counted
    }

    #[test]
    fun test_empty_progress() {
        let (publisher, _, _, _) = setup_test_accounts();
        achievements::init_achievements(&publisher);
        
        achievements::create(&publisher, b"Test", b"Test", 100, vector::empty<u8>());
        
        // Check progress before any submissions
        let (thresh, subs, unlocked) = achievements::get_progress(@0x123, @0x456, 0);
        assert!(thresh == 0, 160);
        assert!(subs == 0, 161);
        assert!(!unlocked, 162);
    }

    #[test]
    fun test_unlocked_list_sorted() {
        let (publisher, _, _, _) = setup_test_accounts();
        achievements::init_achievements(&publisher);
        
        // Create multiple achievements
        achievements::create(&publisher, b"Ach0", b"D", 100, vector::empty<u8>());
        achievements::create(&publisher, b"Ach1", b"D", 200, vector::empty<u8>());
        achievements::create(&publisher, b"Ach2", b"D", 300, vector::empty<u8>());
        
        // Unlock in random order
        achievements::on_score(@0x123, @0x456, 0, 500);  // Unlocks all 3
        
        let unlocked_list = achievements::unlocked_for(@0x123, @0x456);
        
        // Should be sorted ascending
        assert!(*vector::borrow(&unlocked_list, 0) == 0, 170);
        assert!(*vector::borrow(&unlocked_list, 1) == 1, 171);
        assert!(*vector::borrow(&unlocked_list, 2) == 2, 172);
    }

    /************
     * Roles Integration Tests
     ************/

    #[test]
    fun test_roles_operator_can_create_achievement() {
        use sigil::roles;
        
        let publisher = account::create_account_for_test(@0x123);
        let operator = account::create_account_for_test(@0x456);
        let pub_addr = signer::address_of(&publisher);
        let op_addr = signer::address_of(&operator);
        
        // Initialize achievements and roles
        achievements::init_achievements(&publisher);
        roles::init_roles(&publisher);
        roles::add_operator(&publisher, pub_addr, op_addr);
        
        // Operator should be able to create achievement
        achievements::create(
            &operator,  // Operator creates
            b"Operator Achievement",
            b"Created by operator",
            100,
            b""
        );
        
        // Verify it was created (count should be 1)
        assert!(achievements::achievement_count(pub_addr) == 1, 0);
    }

    #[test]
    #[expected_failure(abort_code = 3, location = sigil::achievements)] // E_NO_PERMISSION
    fun test_roles_unauthorized_cannot_create_achievement() {
        use sigil::roles;
        
        let publisher = account::create_account_for_test(@0x123);
        let unauthorized = account::create_account_for_test(@0x999);
        let pub_addr = signer::address_of(&publisher);
        
        // Initialize achievements and roles
        achievements::init_achievements(&publisher);
        roles::init_roles(&publisher);
        
        // Unauthorized user tries to create achievement (should fail)
        achievements::create(
            &unauthorized,
            b"Unauthorized Achievement",
            b"Should fail",
            100,
            b""
        );
    }

    #[test]
    fun test_roles_admin_can_grant_achievement() {
        use sigil::roles;
        
        let publisher = account::create_account_for_test(@0x123);
        let admin = account::create_account_for_test(@0x456);
        let player = account::create_account_for_test(@0x789);
        let pub_addr = signer::address_of(&publisher);
        let admin_addr = signer::address_of(&admin);
        let player_addr = signer::address_of(&player);
        
        // Setup
        achievements::init_achievements(&publisher);
        roles::init_roles(&publisher);
        roles::add_admin(&publisher, pub_addr, admin_addr);
        
        // Create achievement as owner
        achievements::create(&publisher, b"Test", b"Test", 100, b"");
        
        // Admin can grant achievement
        achievements::grant(&admin, player_addr, 0);
        
        // Verify player has achievement
        let unlocked = achievements::unlocked_for(pub_addr, player_addr);
        assert!(vector::length(&unlocked) == 1, 0);
    }

    #[test]
    #[expected_failure(abort_code = 3, location = sigil::achievements)] // E_NO_PERMISSION
    fun test_roles_unauthorized_cannot_grant_achievement() {
        use sigil::roles;
        
        let publisher = account::create_account_for_test(@0x123);
        let unauthorized = account::create_account_for_test(@0x999);
        let player = account::create_account_for_test(@0x789);
        let pub_addr = signer::address_of(&publisher);
        let player_addr = signer::address_of(&player);
        
        // Setup
        achievements::init_achievements(&publisher);
        roles::init_roles(&publisher);
        
        // Create achievement as owner
        achievements::create(&publisher, b"Test", b"Test", 100, b"");
        
        // Unauthorized user tries to grant achievement (should fail)
        achievements::grant(&unauthorized, player_addr, 0);
    }

    #[test]
    fun test_roles_owner_always_has_permission() {
        use sigil::roles;
        
        let publisher = account::create_account_for_test(@0x123);
        let pub_addr = signer::address_of(&publisher);
        
        // Initialize achievements and roles
        achievements::init_achievements(&publisher);
        roles::init_roles(&publisher);
        
        // Owner can always create achievements (even without explicit role)
        achievements::create(&publisher, b"Owner Achievement", b"Test", 100, b"");
        
        // Verify
        assert!(achievements::achievement_count(pub_addr) == 1, 0);
    }
}

