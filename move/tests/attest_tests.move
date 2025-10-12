#[test_only]
module sigil::attest_tests {
    use std::vector;
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use sigil::attest;

    // Test accounts
    const PUBLISHER_ADDR: address = @0x123;
    const PLAYER_ADDR: address = @0x456;

    // Sample ed25519 public key (32 bytes)
    fun sample_server_pubkey(): vector<u8> {
        vector[
            1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
            17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32
        ]
    }

    fun different_pubkey(): vector<u8> {
        vector[
            32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17,
            16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1
        ]
    }

    // ==================== Initialization Tests ====================

    #[test(publisher = @0x123)]
    fun test_init_attest(publisher: &signer) {
        let publisher_addr = signer::address_of(publisher);
        account::create_account_for_test(publisher_addr);

        let pubkey = sample_server_pubkey();
        attest::init_attest(publisher, pubkey, 60);

        assert!(attest::is_initialized(publisher_addr), 0);
    }

    #[test(publisher = @0x123)]
    fun test_init_attest_default_max_age(publisher: &signer) {
        let publisher_addr = signer::address_of(publisher);
        account::create_account_for_test(publisher_addr);

        let pubkey = sample_server_pubkey();
        attest::init_attest(publisher, pubkey, 0); // 0 = use default

        let (exists, max_age) = attest::get_max_age(publisher_addr);
        assert!(exists, 0);
        assert!(max_age == 60, 1); // Default is 60 seconds
    }

    #[test(publisher = @0x123)]
    fun test_init_attest_caps_max_age(publisher: &signer) {
        let publisher_addr = signer::address_of(publisher);
        account::create_account_for_test(publisher_addr);

        let pubkey = sample_server_pubkey();
        attest::init_attest(publisher, pubkey, 500); // Try 500s

        let (_, max_age) = attest::get_max_age(publisher_addr);
        assert!(max_age == 300, 0); // Capped at 300
    }

    #[test(publisher = @0x123)]
    #[expected_failure(abort_code = 1, location = sigil::attest)]
    fun test_init_attest_twice_fails(publisher: &signer) {
        let publisher_addr = signer::address_of(publisher);
        account::create_account_for_test(publisher_addr);

        let pubkey = sample_server_pubkey();
        attest::init_attest(publisher, pubkey, 60);
        attest::init_attest(publisher, pubkey, 60); // Should fail
    }

    #[test(publisher = @0x123)]
    #[expected_failure(abort_code = 5, location = sigil::attest)]
    fun test_init_invalid_pubkey_length_fails(publisher: &signer) {
        let publisher_addr = signer::address_of(publisher);
        account::create_account_for_test(publisher_addr);

        let invalid_pubkey = vector[1, 2, 3]; // Only 3 bytes
        attest::init_attest(publisher, invalid_pubkey, 60);
    }

    // ==================== Update Server Key Tests ====================

    #[test(publisher = @0x123)]
    fun test_update_server_key(publisher: &signer) {
        let publisher_addr = signer::address_of(publisher);
        account::create_account_for_test(publisher_addr);

        let pubkey1 = sample_server_pubkey();
        attest::init_attest(publisher, pubkey1, 60);

        // Verify initial key
        let (_, key1) = attest::get_server_pubkey(publisher_addr);
        assert!(key1 == pubkey1, 0);

        // Update key
        let pubkey2 = different_pubkey();
        attest::update_server_key(publisher, pubkey2);

        // Verify updated
        let (_, key2) = attest::get_server_pubkey(publisher_addr);
        assert!(key2 == pubkey2, 1);
        assert!(key2 != key1, 2);
    }

    // ==================== View Function Tests ====================

    #[test(publisher = @0x123)]
    fun test_is_initialized_false() {
        assert!(!attest::is_initialized(@0x123), 0);
    }

    #[test(publisher = @0x123)]
    fun test_get_server_pubkey_not_initialized() {
        let (exists, _) = attest::get_server_pubkey(@0x123);
        assert!(!exists, 0);
    }

    #[test(publisher = @0x123)]
    fun test_get_last_nonce_no_submissions(publisher: &signer) {
        let publisher_addr = signer::address_of(publisher);
        account::create_account_for_test(publisher_addr);

        let pubkey = sample_server_pubkey();
        attest::init_attest(publisher, pubkey, 60);

        let (exists, nonce) = attest::get_last_nonce(publisher_addr, @0x456);
        assert!(exists, 0);
        assert!(nonce == 0, 1); // No submissions yet
    }

    #[test(publisher = @0x123)]
    fun test_get_last_nonce_not_initialized() {
        let (exists, nonce) = attest::get_last_nonce(@0x123, @0x456);
        assert!(!exists, 0);
        assert!(nonce == 0, 1);
    }

    // ==================== Nonce Tests ====================
    
    // Note: Full verification tests with actual signatures would require
    // generating real ed25519 signatures, which is complex in Move tests.
    // In production, these are tested via integration tests with real game servers.
}

