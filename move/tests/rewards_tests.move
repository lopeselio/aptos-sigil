#[test_only]
module sigil::rewards_tests {
    use std::string;
    use std::option;
    use std::vector;
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::object;
    use aptos_framework::fungible_asset::{Self, Metadata};
    use sigil::rewards;

    // Helper to create test accounts
    fun setup_test_accounts(): (signer, signer, signer) {
        let publisher = account::create_account_for_test(@0x123);
        let player1 = account::create_account_for_test(@0x456);
        let player2 = account::create_account_for_test(@0x789);
        (publisher, player1, player2)
    }

    // Helper to create a mock FA metadata object
    fun create_mock_fa_metadata(creator: &signer): object::Object<Metadata> {
        // Create a simple fungible asset for testing
        let constructor_ref = &object::create_named_object(creator, b"test_fa");
        
        fungible_asset::add_fungibility(
            constructor_ref,
            option::none(),  // max supply
            string::utf8(b"Test Token"),
            string::utf8(b"TST"),
            0,  // decimals
            string::utf8(b""),  // icon uri
            string::utf8(b"")   // project uri
        );
        
        object::object_from_constructor_ref<Metadata>(constructor_ref)
    }

    #[test]
    fun test_init_rewards() {
        let publisher = account::create_account_for_test(@0x123);
        rewards::init_rewards(&publisher);
        
        // Verify no rewards attached yet
        let (exists, _) = rewards::get_available(@0x123, 0);
        assert!(!exists, 0);
    }

    #[test]
    #[expected_failure(abort_code = 0, location = sigil::rewards)] // E_ALREADY_INIT
    fun test_init_rewards_twice_fails() {
        let publisher = account::create_account_for_test(@0x123);
        rewards::init_rewards(&publisher);
        rewards::init_rewards(&publisher); // Should fail
    }

    #[test]
    fun test_attach_fa_reward() {
        let (publisher, _, _) = setup_test_accounts();
        rewards::init_rewards_for_test(&publisher);
        
        let fa_meta = create_mock_fa_metadata(&publisher);
        
        // Attach reward: 1000 tokens, supply of 10
        rewards::attach_fa_reward(
            &publisher,
            @0x123,
            0,       // achievement_id
            fa_meta,
            1000,    // amount
            10       // supply
        );
        
        // Verify reward details
        let (exists, is_ft, amount, claimed, supply) = rewards::get_reward(@0x123, 0);
        assert!(exists, 10);
        assert!(is_ft, 11);
        assert!(amount == 1000, 12);
        assert!(claimed == 0, 13);
        assert!(supply == 10, 14);
    }

    #[test]
    fun test_attach_fa_reward_unlimited() {
        let (publisher, _, _) = setup_test_accounts();
        rewards::init_rewards_for_test(&publisher);
        
        let fa_meta = create_mock_fa_metadata(&publisher);
        
        // Attach unlimited supply
        rewards::attach_fa_reward(&publisher, @0x123, 0, fa_meta, 500, 0);
        
        let (_, _, _, _, supply) = rewards::get_reward(@0x123, 0);
        assert!(supply == 0, 20);  // 0 = unlimited
        
        let (exists, available) = rewards::get_available(@0x123, 0);
        assert!(exists, 21);
        assert!(available == 0, 22);  // 0 = unlimited
    }

    #[test]
    fun test_attach_nft_reward() {
        let (publisher, _, _) = setup_test_accounts();
        rewards::init_rewards_for_test(&publisher);
        
        rewards::attach_nft_reward(
            &publisher,
            @0x123,
            1,  // achievement_id
            @0xabc,  // collection address
            string::utf8(b"Gold Medal"),
            string::utf8(b"Achievement NFT"),
            string::utf8(b"https://example.com/nft.png"),
            100  // supply
        );
        
        let (exists, is_ft, _, _, supply, claimed) = rewards::get_reward_details(@0x123, 1);
        assert!(exists, 30);
        assert!(!is_ft, 31);  // Not FT
        assert!(supply == 100, 32);
        assert!(claimed == 0, 33);
    }

    #[test]
    #[expected_failure(abort_code = 6, location = sigil::rewards)] // E_INVALID_SUPPLY
    fun test_attach_nft_with_zero_supply_fails() {
        let (publisher, _, _) = setup_test_accounts();
        rewards::init_rewards_for_test(&publisher);
        
        // NFT rewards must have limited supply
        rewards::attach_nft_reward(
            &publisher,
            @0x123,
            0,
            @0xabc,
            string::utf8(b"Test"),
            string::utf8(b"Test"),
            string::utf8(b""),
            0  // Invalid for NFT
        );
    }

    #[test]
    #[expected_failure(abort_code = 2, location = sigil::rewards)] // E_ALREADY_ATTACHED
    fun test_attach_reward_twice_fails() {
        let (publisher, _, _) = setup_test_accounts();
        rewards::init_rewards_for_test(&publisher);
        
        let fa_meta = create_mock_fa_metadata(&publisher);
        
        rewards::attach_fa_reward(&publisher, @0x123, 0, fa_meta, 100, 10);
        rewards::attach_fa_reward(&publisher, @0x123, 0, fa_meta, 200, 20); // Should fail
    }

    #[test]
    fun test_claim_fa_reward() {
        let (publisher, player1, _) = setup_test_accounts();
        rewards::init_rewards_for_test(&publisher);
        
        let fa_meta = create_mock_fa_metadata(&publisher);
        rewards::attach_fa_reward(&publisher, @0x123, 0, fa_meta, 1000, 5);
        
        // Claim reward (using testing function that skips achievement check)
        rewards::claim_testing(&player1, @0x123, 0);
        
        // Verify claimed
        assert!(rewards::is_claimed(@0x123, @0x456, 0), 40);
        
        // Verify claimed count increased
        let (_, _, _, claimed, _) = rewards::get_reward(@0x123, 0);
        assert!(claimed == 1, 41);
        
        // Verify available decreased
        let (_, available) = rewards::get_available(@0x123, 0);
        assert!(available == 4, 42);  // 5 - 1 = 4
    }

    #[test]
    fun test_claim_nft_reward() {
        let (publisher, player1, _) = setup_test_accounts();
        rewards::init_rewards_for_test(&publisher);
        
        rewards::attach_nft_reward(
            &publisher,
            @0x123,
            0,
            @0xabc,
            string::utf8(b"Badge"), string::utf8(b"Desc"),
            string::utf8(b"uri"), 10
        );
        
        rewards::claim_testing(&player1, @0x123, 0);
        
        assert!(rewards::is_claimed(@0x123, @0x456, 0), 50);
        
        let (_, available) = rewards::get_available(@0x123, 0);
        assert!(available == 9, 51);  // 10 - 1 = 9
    }

    #[test]
    #[expected_failure(abort_code = 4, location = sigil::rewards)] // E_ALREADY_CLAIMED
    fun test_double_claim_fails() {
        let (publisher, player1, _) = setup_test_accounts();
        rewards::init_rewards_for_test(&publisher);
        
        let fa_meta = create_mock_fa_metadata(&publisher);
        rewards::attach_fa_reward(&publisher, @0x123, 0, fa_meta, 100, 10);
        
        // First claim
        rewards::claim_testing(&player1, @0x123, 0);
        
        // Second claim (should fail)
        rewards::claim_testing(&player1, @0x123, 0);
    }

    #[test]
    #[expected_failure(abort_code = 5, location = sigil::rewards)] // E_OUT_OF_STOCK
    fun test_claim_out_of_stock_fails() {
        let (publisher, player1, player2) = setup_test_accounts();
        let player3 = account::create_account_for_test(@0xdef);
        
        rewards::init_rewards_for_test(&publisher);
        
        let fa_meta = create_mock_fa_metadata(&publisher);
        rewards::attach_fa_reward(&publisher, @0x123, 0, fa_meta, 100, 2);  // Only 2 available
        
        // Claim 1
        rewards::claim_testing(&player1, @0x123, 0);
        
        // Claim 2
        rewards::claim_testing(&player2, @0x123, 0);
        
        // Claim 3 (should fail - out of stock)
        rewards::claim_testing(&player3, @0x123, 0);
    }

    #[test]
    #[expected_failure(abort_code = 1, location = sigil::rewards)] // E_NOT_FOUND
    fun test_claim_non_existent_reward_fails() {
        let (publisher, player1, _) = setup_test_accounts();
        rewards::init_rewards_for_test(&publisher);
        
        // Try to claim reward that doesn't exist
        rewards::claim_testing(&player1, @0x123, 999);
    }

    #[test]
    fun test_multiple_rewards_different_achievements() {
        let (publisher, player1, _) = setup_test_accounts();
        rewards::init_rewards_for_test(&publisher);
        
        let fa_meta = create_mock_fa_metadata(&publisher);
        
        // Attach rewards to multiple achievements
        rewards::attach_fa_reward(&publisher, @0x123, 0, fa_meta, 100, 5);
        rewards::attach_fa_reward(&publisher, @0x123, 1, fa_meta, 200, 10);
        rewards::attach_nft_reward(
            &publisher,
            @0x123,
            2,
            @0xabc,
            string::utf8(b"NFT"), string::utf8(b"Desc"),
            string::utf8(b"uri"), 3
        );
        
        // Claim from different achievements
        rewards::claim_testing(&player1, @0x123, 0);
        rewards::claim_testing(&player1, @0x123, 1);
        rewards::claim_testing(&player1, @0x123, 2);
        
        // Verify all claimed
        assert!(rewards::is_claimed(@0x123, @0x456, 0), 60);
        assert!(rewards::is_claimed(@0x123, @0x456, 1), 61);
        assert!(rewards::is_claimed(@0x123, @0x456, 2), 62);
        
        // Verify claimed list
        let claimed_list = rewards::get_claimed_rewards(@0x123, @0x456);
        assert!(vector::length(&claimed_list) == 3, 63);
    }

    #[test]
    fun test_multiple_players_same_reward() {
        let (publisher, player1, player2) = setup_test_accounts();
        rewards::init_rewards_for_test(&publisher);
        
        let fa_meta = create_mock_fa_metadata(&publisher);
        rewards::attach_fa_reward(&publisher, @0x123, 0, fa_meta, 100, 5);
        
        // Both players claim
        rewards::claim_testing(&player1, @0x123, 0);
        rewards::claim_testing(&player2, @0x123, 0);
        
        // Both should have claimed
        assert!(rewards::is_claimed(@0x123, @0x456, 0), 70);
        assert!(rewards::is_claimed(@0x123, @0x789, 0), 71);
        
        // Claimed count should be 2
        let (_, _, _, claimed, _) = rewards::get_reward(@0x123, 0);
        assert!(claimed == 2, 72);
        
        // Available should be 3
        let (_, available) = rewards::get_available(@0x123, 0);
        assert!(available == 3, 73);
    }

    #[test]
    fun test_unlimited_supply() {
        let (publisher, player1, player2) = setup_test_accounts();
        let player3 = account::create_account_for_test(@0xabc);
        let player4 = account::create_account_for_test(@0xdef);
        
        rewards::init_rewards_for_test(&publisher);
        
        let fa_meta = create_mock_fa_metadata(&publisher);
        rewards::attach_fa_reward(&publisher, @0x123, 0, fa_meta, 50, 0);  // Unlimited
        
        // Multiple claims should all work
        rewards::claim_testing(&player1, @0x123, 0);
        rewards::claim_testing(&player2, @0x123, 0);
        rewards::claim_testing(&player3, @0x123, 0);
        rewards::claim_testing(&player4, @0x123, 0);
        
        let (_, _, _, claimed, supply) = rewards::get_reward(@0x123, 0);
        assert!(claimed == 4, 80);
        assert!(supply == 0, 81);  // Still unlimited
    }

    #[test]
    fun test_increase_supply() {
        let (publisher, player1, _) = setup_test_accounts();
        rewards::init_rewards_for_test(&publisher);
        
        let fa_meta = create_mock_fa_metadata(&publisher);
        rewards::attach_fa_reward(&publisher, @0x123, 0, fa_meta, 100, 5);
        
        // Claim 3
        rewards::claim_testing(&player1, @0x123, 0);
        
        let (_, available) = rewards::get_available(@0x123, 0);
        assert!(available == 4, 90);
        
        // Increase supply by 10
        rewards::increase_supply(&publisher, 0, 10);
        
        let (_, available2) = rewards::get_available(@0x123, 0);
        assert!(available2 == 14, 91);  // 4 + 10
    }

    #[test]
    fun test_remove_reward_no_claims() {
        let (publisher, _, _) = setup_test_accounts();
        rewards::init_rewards_for_test(&publisher);
        
        let fa_meta = create_mock_fa_metadata(&publisher);
        rewards::attach_fa_reward(&publisher, @0x123, 0, fa_meta, 100, 5);
        
        // Remove before any claims
        rewards::remove_reward(&publisher, 0);
        
        let (exists, _) = rewards::get_available(@0x123, 0);
        assert!(!exists, 100);  // Should not exist anymore
    }

    #[test]
    #[expected_failure(abort_code = 4, location = sigil::rewards)] // E_ALREADY_CLAIMED
    fun test_remove_reward_with_claims_fails() {
        let (publisher, player1, _) = setup_test_accounts();
        rewards::init_rewards_for_test(&publisher);
        
        let fa_meta = create_mock_fa_metadata(&publisher);
        rewards::attach_fa_reward(&publisher, @0x123, 0, fa_meta, 100, 5);
        
        // Claim once
        rewards::claim_testing(&player1, @0x123, 0);
        
        // Try to remove (should fail)
        rewards::remove_reward(&publisher, 0);
    }

    #[test]
    fun test_list_rewarded_achievements() {
        let (publisher, _, _) = setup_test_accounts();
        rewards::init_rewards_for_test(&publisher);
        
        let fa_meta = create_mock_fa_metadata(&publisher);
        
        // Attach to multiple achievements
        rewards::attach_fa_reward(&publisher, @0x123, 0, fa_meta, 100, 5);
        rewards::attach_fa_reward(&publisher, @0x123, 2, fa_meta, 200, 10);
        rewards::attach_nft_reward(
            &publisher,
            @0x123,
            5,
            @0xabc,
            string::utf8(b"NFT"), string::utf8(b"Desc"),
            string::utf8(b"uri"), 3
        );
        
        let rewarded = rewards::list_rewarded_achievements(@0x123);
        assert!(vector::length(&rewarded) == 3, 110);
        assert!(*vector::borrow(&rewarded, 0) == 0, 111);
        assert!(*vector::borrow(&rewarded, 1) == 2, 112);
        assert!(*vector::borrow(&rewarded, 2) == 5, 113);
    }

    #[test]
    fun test_get_claimed_rewards_list() {
        let (publisher, player1, _) = setup_test_accounts();
        rewards::init_rewards_for_test(&publisher);
        
        let fa_meta = create_mock_fa_metadata(&publisher);
        
        // Attach 3 rewards
        rewards::attach_fa_reward(&publisher, @0x123, 0, fa_meta, 100, 10);
        rewards::attach_fa_reward(&publisher, @0x123, 1, fa_meta, 200, 10);
        rewards::attach_fa_reward(&publisher, @0x123, 2, fa_meta, 300, 10);
        
        // Player claims 2 of them
        rewards::claim_testing(&player1, @0x123, 0);
        rewards::claim_testing(&player1, @0x123, 2);
        
        let claimed_list = rewards::get_claimed_rewards(@0x123, @0x456);
        assert!(vector::length(&claimed_list) == 2, 120);
        assert!(*vector::borrow(&claimed_list, 0) == 0, 121);
        assert!(*vector::borrow(&claimed_list, 1) == 2, 122);
    }

    #[test]
    fun test_mixed_ft_and_nft_rewards() {
        let (publisher, player1, _) = setup_test_accounts();
        rewards::init_rewards_for_test(&publisher);
        
        let fa_meta = create_mock_fa_metadata(&publisher);
        
        // Attach both types
        rewards::attach_fa_reward(&publisher, @0x123, 0, fa_meta, 500, 10);
        rewards::attach_nft_reward(
            &publisher,
            @0x123,
            1,
            @0xabc,
            string::utf8(b"Badge"), string::utf8(b"Desc"),
            string::utf8(b"uri"), 5
        );
        
        // Claim both
        rewards::claim_testing(&player1, @0x123, 0);
        rewards::claim_testing(&player1, @0x123, 1);
        
        // Verify both claimed
        assert!(rewards::is_claimed(@0x123, @0x456, 0), 130);
        assert!(rewards::is_claimed(@0x123, @0x456, 1), 131);
        
        // Verify different types
        let (_, is_ft1, _, _, _, _) = rewards::get_reward_details(@0x123, 0);
        let (_, is_ft2, _, _, _, _) = rewards::get_reward_details(@0x123, 1);
        assert!(is_ft1, 132);   // Achievement 0 is FT
        assert!(!is_ft2, 133);  // Achievement 1 is NFT
    }

    #[test]
    fun test_reward_details_with_nft_name() {
        let (publisher, _, _) = setup_test_accounts();
        rewards::init_rewards_for_test(&publisher);
        
        rewards::attach_nft_reward(
            &publisher,
            @0x123,
            0,
            @0xabc,
            string::utf8(b"Gold Medal"),
            string::utf8(b"Top achievement"),
            string::utf8(b"https://nft.com/gold.png"),
            50
        );
        
        let (exists, is_ft, _, name_bytes, supply, claimed) = 
            rewards::get_reward_details(@0x123, 0);
        
        assert!(exists, 140);
        assert!(!is_ft, 141);
        assert!(name_bytes == b"Gold Medal", 142);
        assert!(supply == 50, 143);
        assert!(claimed == 0, 144);
    }

    #[test]
    fun test_empty_claimed_list() {
        let (publisher, _, _) = setup_test_accounts();
        rewards::init_rewards_for_test(&publisher);
        
        // No claims yet
        let claimed_list = rewards::get_claimed_rewards(@0x123, @0x456);
        assert!(vector::length(&claimed_list) == 0, 150);
    }

    #[test]
    fun test_supply_tracking_edge_case() {
        let (publisher, player1, _) = setup_test_accounts();
        rewards::init_rewards_for_test(&publisher);
        
        let fa_meta = create_mock_fa_metadata(&publisher);
        rewards::attach_fa_reward(&publisher, @0x123, 0, fa_meta, 100, 1);  // Only 1 available
        
        let (_, available1) = rewards::get_available(@0x123, 0);
        assert!(available1 == 1, 160);
        
        // Claim the last one
        rewards::claim_testing(&player1, @0x123, 0);
        
        let (_, available2) = rewards::get_available(@0x123, 0);
        assert!(available2 == 0, 161);  // Out of stock
    }

    #[test]
    fun test_is_claimed_returns_false_for_unclaimed() {
        let (publisher, _, _) = setup_test_accounts();
        rewards::init_rewards_for_test(&publisher);
        
        let fa_meta = create_mock_fa_metadata(&publisher);
        rewards::attach_fa_reward(&publisher, @0x123, 0, fa_meta, 100, 5);
        
        // No claims yet
        assert!(!rewards::is_claimed(@0x123, @0x456, 0), 170);
    }

    #[test]
    fun test_get_reward_non_existent() {
        let (publisher, _, _) = setup_test_accounts();
        rewards::init_rewards_for_test(&publisher);
        
        let (exists, _, _, _, _) = rewards::get_reward(@0x123, 999);
        assert!(!exists, 180);
    }

    /************
     * Roles Integration Tests
     ************/

    #[test]
    fun test_roles_operator_can_attach_reward() {
        use sigil::roles;
        
        let publisher = account::create_account_for_test(@0x123);
        let operator = account::create_account_for_test(@0x456);
        let pub_addr = signer::address_of(&publisher);
        let op_addr = signer::address_of(&operator);
        
        // Setup
        rewards::init_rewards_for_test(&publisher);
        roles::init_roles(&publisher);
        roles::add_operator(&publisher, pub_addr, op_addr);
        
        let fa_metadata = create_mock_fa_metadata(&publisher);
        
        // Operator should be able to attach reward
        rewards::attach_fa_reward(&operator, @0x123, 0, fa_metadata, 100, 10);
        
        // Verify it was attached
        let ids = rewards::list_rewarded_achievements(pub_addr);
        assert!(vector::length(&ids) == 1, 0);
    }

    #[test]
    #[expected_failure(abort_code = 8, location = sigil::rewards)] // E_NO_PERMISSION
    fun test_roles_unauthorized_cannot_attach_reward() {
        use sigil::roles;
        
        let publisher = account::create_account_for_test(@0x123);
        let unauthorized = account::create_account_for_test(@0x999);
        
        // Setup
        rewards::init_rewards_for_test(&publisher);
        roles::init_roles(&publisher);
        
        let fa_metadata = create_mock_fa_metadata(&publisher);
        
        // Unauthorized user tries to attach reward (should fail)
        rewards::attach_fa_reward(&unauthorized, @0x123, 0, fa_metadata, 100, 10);
    }

    #[test]
    fun test_roles_admin_can_attach_reward() {
        use sigil::roles;
        
        let publisher = account::create_account_for_test(@0x123);
        let admin = account::create_account_for_test(@0x456);
        let pub_addr = signer::address_of(&publisher);
        let admin_addr = signer::address_of(&admin);
        
        // Setup
        rewards::init_rewards_for_test(&publisher);
        roles::init_roles(&publisher);
        roles::add_admin(&publisher, pub_addr, admin_addr);
        
        let fa_metadata = create_mock_fa_metadata(&publisher);
        
        // Admin should be able to attach reward
        rewards::attach_fa_reward(&admin, @0x123, 0, fa_metadata, 100, 10);
        
        // Verify it was attached
        let ids = rewards::list_rewarded_achievements(pub_addr);
        assert!(vector::length(&ids) == 1, 0);
    }

    #[test]
    fun test_roles_owner_always_has_permission_for_rewards() {
        use sigil::roles;
        
        let publisher = account::create_account_for_test(@0x123);
        let pub_addr = signer::address_of(&publisher);
        
        // Setup
        rewards::init_rewards_for_test(&publisher);
        roles::init_roles(&publisher);
        
        let fa_metadata = create_mock_fa_metadata(&publisher);
        
        // Owner can always attach rewards
        rewards::attach_fa_reward(&publisher, @0x123, 0, fa_metadata, 100, 10);
        
        // Verify
        let ids = rewards::list_rewarded_achievements(pub_addr);
        assert!(vector::length(&ids) == 1, 0);
    }
}

