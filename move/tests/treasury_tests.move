#[test_only]
module sigil::treasury_tests {
    use std::signer;
    use std::option;
    use std::string;
    use aptos_framework::account;
    use aptos_framework::object::{Self, Object};
    use aptos_framework::fungible_asset::{Self, Metadata, MintRef};
    use aptos_framework::primary_fungible_store;
    use sigil::treasury;

    // Test accounts
    const PUBLISHER_ADDR: address = @0x123;
    const DEPOSITOR_ADDR: address = @0x456;
    const RECIPIENT_ADDR: address = @0x789;

    /// FA with primary stores enabled (DeriveRefPod) and unlimited supply; supports mint + primary_fungible_store deposit.
    fun create_mintable_primary_fa(creator: &signer): (MintRef, Object<Metadata>) {
        let constructor_ref = &object::create_named_object(creator, b"dist_fa");
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::none(),
            string::utf8(b"Dist"),
            string::utf8(b"DST"),
            8,
            string::utf8(b""),
            string::utf8(b"")
        );
        let meta = object::object_from_constructor_ref<Metadata>(constructor_ref);
        let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
        (mint_ref, meta)
    }

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

    // ==================== distribute_fa_equal ====================

    #[test(publisher = @0x123, creator = @0xFA)]
    fun test_distribute_fa_equal_success(publisher: &signer, creator: &signer) {
        let publisher_addr = signer::address_of(publisher);
        let creator_addr = signer::address_of(creator);
        account::create_account_for_test(publisher_addr);
        account::create_account_for_test(creator_addr);

        let r1_addr = @0xAAA;
        let r2_addr = @0xBBB;
        account::create_account_for_test(r1_addr);
        account::create_account_for_test(r2_addr);

        let (mint_ref, meta) = create_mintable_primary_fa(creator);
        treasury::init_treasury(publisher);

        let fa = fungible_asset::mint(&mint_ref, 1000);
        primary_fungible_store::deposit_with_signer(creator, fa);
        treasury::deposit(creator, publisher_addr, meta, 1000);

        let recipients = vector[r1_addr, r2_addr];
        treasury::distribute_fa_equal(publisher, meta, recipients, 300);

        assert!(primary_fungible_store::balance(r1_addr, meta) == 300, 0);
        assert!(primary_fungible_store::balance(r2_addr, meta) == 300, 1);
        assert!(primary_fungible_store::balance(publisher_addr, meta) == 400, 2);

        let (_has, _dep, withdrawn, _bal) = treasury::get_stats(publisher_addr, meta);
        assert!(withdrawn == 600, 3);
    }

    #[test(publisher = @0x123, creator = @0xFA)]
    #[expected_failure(abort_code = 2, location = sigil::treasury)]
    fun test_distribute_fa_equal_insufficient_balance_fails(
        publisher: &signer,
        creator: &signer
    ) {
        let publisher_addr = signer::address_of(publisher);
        let creator_addr = signer::address_of(creator);
        account::create_account_for_test(publisher_addr);
        account::create_account_for_test(creator_addr);

        let r1_addr = @0xAAA;
        let r2_addr = @0xBBB;
        account::create_account_for_test(r1_addr);
        account::create_account_for_test(r2_addr);

        let (mint_ref, meta) = create_mintable_primary_fa(creator);
        treasury::init_treasury(publisher);

        let fa = fungible_asset::mint(&mint_ref, 100);
        primary_fungible_store::deposit_with_signer(creator, fa);
        treasury::deposit(creator, publisher_addr, meta, 100);

        let recipients = vector[r1_addr, r2_addr];
        treasury::distribute_fa_equal(publisher, meta, recipients, 100);
    }
}

