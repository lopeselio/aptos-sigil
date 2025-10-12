#[test_only]
module sigil::treasury_tests {
    use std::signer;
    use std::option;
    use std::string;
    use aptos_framework::account;
    use aptos_framework::object::{Self, Object};
    use aptos_framework::fungible_asset::{Self, Metadata};
    use sigil::treasury;

    // Test accounts
    const PUBLISHER_ADDR: address = @0x123;
    const DEPOSITOR_ADDR: address = @0x456;
    const RECIPIENT_ADDR: address = @0x789;

    // Helper to create a test FA metadata object
    fun create_test_fa_metadata(creator: &signer): Object<Metadata> {
        let constructor_ref = &object::create_named_object(creator, b"test_fa");
        
        fungible_asset::add_fungibility(
            constructor_ref,
            option::none(), // max_supply (unlimited)
            string::utf8(b"Test Token"),
            string::utf8(b"TST"),
            8, // decimals
            string::utf8(b""), // icon_uri
            string::utf8(b"")  // project_uri
        );

        object::object_from_constructor_ref<Metadata>(constructor_ref)
    }

    // ==================== Initialization Tests ====================

    #[test(publisher = @0x123)]
    fun test_init_treasury(publisher: &signer) {
        let publisher_addr = signer::address_of(publisher);
        account::create_account_for_test(publisher_addr);

        treasury::init_treasury(publisher);

        assert!(treasury::is_initialized(publisher_addr), 0);
    }

    #[test(publisher = @0x123)]
    #[expected_failure(abort_code = 1, location = sigil::treasury)]
    fun test_init_treasury_twice_fails(publisher: &signer) {
        let publisher_addr = signer::address_of(publisher);
        account::create_account_for_test(publisher_addr);

        treasury::init_treasury(publisher);
        treasury::init_treasury(publisher); // Should fail
    }

    // ==================== Balance View Tests ====================

    #[test(publisher = @0x123, creator = @0xFA)]
    fun test_get_balance_empty(publisher: &signer, creator: &signer) {
        let publisher_addr = signer::address_of(publisher);
        let creator_addr = signer::address_of(creator);
        account::create_account_for_test(publisher_addr);
        account::create_account_for_test(creator_addr);

        treasury::init_treasury(publisher);
        
        let fa_metadata = create_test_fa_metadata(creator);

        let (is_init, balance) = treasury::get_balance(publisher_addr, fa_metadata);
        assert!(is_init, 0); // Treasury is initialized
        assert!(balance == 0, 1); // But no deposits yet
    }

    #[test(publisher = @0x123, creator = @0xFA)]
    fun test_get_balance_not_initialized(publisher: &signer, creator: &signer) {
        let publisher_addr = signer::address_of(publisher);
        let creator_addr = signer::address_of(creator);
        account::create_account_for_test(publisher_addr);
        account::create_account_for_test(creator_addr);

        // Don't initialize treasury
        let fa_metadata = create_test_fa_metadata(creator);

        let (is_init, balance) = treasury::get_balance(publisher_addr, fa_metadata);
        assert!(!is_init, 0); // Treasury not initialized
        assert!(balance == 0, 1);
    }

    #[test(publisher = @0x123, creator = @0xFA)]
    fun test_get_stats_empty(publisher: &signer, creator: &signer) {
        let publisher_addr = signer::address_of(publisher);
        let creator_addr = signer::address_of(creator);
        account::create_account_for_test(publisher_addr);
        account::create_account_for_test(creator_addr);

        treasury::init_treasury(publisher);
        
        let fa_metadata = create_test_fa_metadata(creator);

        let (has_store, deposited, withdrawn, balance) = treasury::get_stats(publisher_addr, fa_metadata);
        assert!(!has_store, 0);
        assert!(deposited == 0, 1);
        assert!(withdrawn == 0, 2);
        assert!(balance == 0, 3);
    }

    #[test(publisher = @0x123, creator = @0xFA)]
    fun test_can_withdraw_empty(publisher: &signer, creator: &signer) {
        let publisher_addr = signer::address_of(publisher);
        let creator_addr = signer::address_of(creator);
        account::create_account_for_test(publisher_addr);
        account::create_account_for_test(creator_addr);

        treasury::init_treasury(publisher);
        
        let fa_metadata = create_test_fa_metadata(creator);

        assert!(!treasury::can_withdraw(publisher_addr, fa_metadata, 100), 0);
    }

    // ==================== View Function Edge Cases ====================

    #[test(publisher = @0x123)]
    fun test_is_initialized_false() {
        let publisher_addr = @0x123;
        assert!(!treasury::is_initialized(publisher_addr), 0);
    }
}

