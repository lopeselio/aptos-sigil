#[test_only]
module sigil::shadow_signers_tests {
    use std::vector;
    use std::signer;
    use aptos_framework::timestamp;
    use aptos_framework::account;
    use sigil::shadow_signers;

    // Test accounts
    const AUTHORITY_ADDR: address = @0xACE;
    const PAYER_ADDR: address = @0xFEE;
    
    // Sample ed25519 public key (32 bytes) - just for testing structure
    // In real usage, this would be a real ed25519 public key
    fun sample_pubkey(): vector<u8> {
        vector[
            1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
            17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32
        ]
    }

    fun sample_pubkey_2(): vector<u8> {
        vector[
            32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17,
            16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1
        ]
    }

    fun sample_scopes(): vector<vector<u8>> {
        vector[b"submit_score", b"claim_reward"]
    }

    fun sample_single_scope(): vector<vector<u8>> {
        vector[b"submit_score"]
    }

    // ==================== Initialization Tests ====================

    #[test(authority = @0xACE)]
    fun test_init_sessions(authority: &signer) {
        let authority_addr = signer::address_of(authority);
        
        // Create account
        account::create_account_for_test(authority_addr);
        
        // Initialize
        shadow_signers::init_sessions(authority);
        
        // Verify initialized
        assert!(shadow_signers::is_initialized(authority_addr), 0);
    }

    #[test(authority = @0xACE)]
    #[expected_failure(abort_code = 1, location = sigil::shadow_signers)] // E_ALREADY_INITIALIZED
    fun test_init_sessions_twice_fails(authority: &signer) {
        let authority_addr = signer::address_of(authority);
        account::create_account_for_test(authority_addr);
        
        shadow_signers::init_sessions(authority);
        shadow_signers::init_sessions(authority); // Should fail
    }

    // ==================== Create Session Tests ====================

    #[test(authority = @0xACE, aptos_framework = @aptos_framework)]
    fun test_create_session(authority: &signer, aptos_framework: &signer) {
        let authority_addr = signer::address_of(authority);
        account::create_account_for_test(authority_addr);
        timestamp::set_time_has_started_for_testing(aptos_framework);
        
        let pubkey = sample_pubkey();
        let scopes = sample_scopes();
        let ttl = 3600; // 1 hour
        
        shadow_signers::create_session(authority, pubkey, scopes, ttl);
        
        // Verify session exists
        assert!(shadow_signers::session_exists(authority_addr, pubkey), 0);
        
        // Verify details
        let (exists, revoked, expires_at, is_expired) = shadow_signers::get_session(authority_addr, pubkey);
        assert!(exists, 1);
        assert!(!revoked, 2);
        assert!(expires_at == 3600, 3);
        assert!(!is_expired, 4);
    }

    #[test(authority = @0xACE, aptos_framework = @aptos_framework)]
    fun test_create_session_auto_init(authority: &signer, aptos_framework: &signer) {
        let authority_addr = signer::address_of(authority);
        account::create_account_for_test(authority_addr);
        timestamp::set_time_has_started_for_testing(aptos_framework);
        
        // Don't call init_sessions explicitly - should auto-initialize
        let pubkey = sample_pubkey();
        let scopes = sample_scopes();
        
        shadow_signers::create_session(authority, pubkey, scopes, 3600);
        
        assert!(shadow_signers::is_initialized(authority_addr), 0);
        assert!(shadow_signers::session_exists(authority_addr, pubkey), 1);
    }

    #[test(authority = @0xACE, aptos_framework = @aptos_framework)]
    fun test_create_session_default_ttl(authority: &signer, aptos_framework: &signer) {
        let authority_addr = signer::address_of(authority);
        account::create_account_for_test(authority_addr);
        timestamp::set_time_has_started_for_testing(aptos_framework);
        
        let pubkey = sample_pubkey();
        let scopes = sample_scopes();
        
        // Pass 0 for TTL - should use default (3600 seconds)
        shadow_signers::create_session(authority, pubkey, scopes, 0);
        
        let (_, _, expires_at, _) = shadow_signers::get_session(authority_addr, pubkey);
        assert!(expires_at == 3600, 0); // Default is 1 hour
    }

    #[test(authority = @0xACE, aptos_framework = @aptos_framework)]
    fun test_create_session_max_ttl(authority: &signer, aptos_framework: &signer) {
        let authority_addr = signer::address_of(authority);
        account::create_account_for_test(authority_addr);
        timestamp::set_time_has_started_for_testing(aptos_framework);
        
        let pubkey = sample_pubkey();
        let scopes = sample_scopes();
        let max_ttl = 7 * 24 * 60 * 60; // 7 days
        
        shadow_signers::create_session(authority, pubkey, scopes, max_ttl);
        
        let (_, _, expires_at, _) = shadow_signers::get_session(authority_addr, pubkey);
        assert!(expires_at == max_ttl, 0);
    }

    #[test(authority = @0xACE, aptos_framework = @aptos_framework)]
    #[expected_failure(abort_code = 5, location = sigil::shadow_signers)] // E_INVALID_TTL
    fun test_create_session_ttl_too_long_fails(authority: &signer, aptos_framework: &signer) {
        let authority_addr = signer::address_of(authority);
        account::create_account_for_test(authority_addr);
        timestamp::set_time_has_started_for_testing(aptos_framework);
        
        let pubkey = sample_pubkey();
        let scopes = sample_scopes();
        let too_long = 8 * 24 * 60 * 60; // 8 days - exceeds max
        
        shadow_signers::create_session(authority, pubkey, scopes, too_long);
    }

    #[test(authority = @0xACE, aptos_framework = @aptos_framework)]
    #[expected_failure(abort_code = 10, location = sigil::shadow_signers)] // E_INVALID_PUBKEY_LENGTH
    fun test_create_session_invalid_pubkey_fails(authority: &signer, aptos_framework: &signer) {
        let authority_addr = signer::address_of(authority);
        account::create_account_for_test(authority_addr);
        timestamp::set_time_has_started_for_testing(aptos_framework);
        
        let invalid_pubkey = vector[1, 2, 3]; // Only 3 bytes, need 32
        let scopes = sample_scopes();
        
        shadow_signers::create_session(authority, invalid_pubkey, scopes, 3600);
    }

    #[test(authority = @0xACE, aptos_framework = @aptos_framework)]
    fun test_create_session_overwrites_existing(authority: &signer, aptos_framework: &signer) {
        let authority_addr = signer::address_of(authority);
        account::create_account_for_test(authority_addr);
        timestamp::set_time_has_started_for_testing(aptos_framework);
        
        let pubkey = sample_pubkey();
        let scopes = sample_single_scope();
        
        // Create first session
        shadow_signers::create_session(authority, pubkey, scopes, 3600);
        
        // Create second session with same pubkey (should overwrite)
        let new_scopes = sample_scopes();
        shadow_signers::create_session(authority, pubkey, new_scopes, 7200);
        
        // Verify new session
        let (_, _, expires_at, _) = shadow_signers::get_session(authority_addr, pubkey);
        assert!(expires_at == 7200, 0);
        
        let (_, scopes_result) = shadow_signers::get_session_scopes(authority_addr, pubkey);
        assert!(vector::length(&scopes_result) == 2, 1); // Should have 2 scopes now
    }

    // ==================== Create with Payer Tests ====================

    #[test(authority = @0xACE, payer = @0xFEE, aptos_framework = @aptos_framework)]
    fun test_create_session_with_payer(authority: &signer, payer: &signer, aptos_framework: &signer) {
        let authority_addr = signer::address_of(authority);
        let payer_addr = signer::address_of(payer);
        account::create_account_for_test(authority_addr);
        account::create_account_for_test(payer_addr);
        timestamp::set_time_has_started_for_testing(aptos_framework);
        
        let pubkey = sample_pubkey();
        let scopes = sample_scopes();
        
        shadow_signers::create_session_with_payer(authority, payer, pubkey, scopes, 3600);
        
        // Verify session exists
        assert!(shadow_signers::session_exists(authority_addr, pubkey), 0);
        
        // Verify fee payer is recorded
        let (exists, fee_payer) = shadow_signers::get_fee_payer(authority_addr, pubkey);
        assert!(exists, 1);
        assert!(fee_payer == payer_addr, 2);
    }

    // ==================== Revoke Session Tests ====================

    #[test(authority = @0xACE, aptos_framework = @aptos_framework)]
    fun test_revoke_session_by_authority(authority: &signer, aptos_framework: &signer) {
        let authority_addr = signer::address_of(authority);
        account::create_account_for_test(authority_addr);
        timestamp::set_time_has_started_for_testing(aptos_framework);
        
        let pubkey = sample_pubkey();
        let scopes = sample_scopes();
        
        // Create session
        shadow_signers::create_session(authority, pubkey, scopes, 3600);
        
        // Revoke
        shadow_signers::revoke_session(authority, authority_addr, pubkey);
        
        // Verify revoked
        let (_, revoked, _, _) = shadow_signers::get_session(authority_addr, pubkey);
        assert!(revoked, 0);
        
        // Session should no longer be valid
        assert!(!shadow_signers::is_session_valid(authority_addr, pubkey), 1);
    }

    #[test(authority = @0xACE, other = @0xBAD, aptos_framework = @aptos_framework)]
    #[expected_failure(abort_code = 11, location = sigil::shadow_signers)] // E_NOT_AUTHORITY
    fun test_revoke_active_session_by_non_authority_fails(
        authority: &signer,
        other: &signer,
        aptos_framework: &signer
    ) {
        let authority_addr = signer::address_of(authority);
        let other_addr = signer::address_of(other);
        account::create_account_for_test(authority_addr);
        account::create_account_for_test(other_addr);
        timestamp::set_time_has_started_for_testing(aptos_framework);
        
        let pubkey = sample_pubkey();
        let scopes = sample_scopes();
        
        // Create session
        shadow_signers::create_session(authority, pubkey, scopes, 3600);
        
        // Try to revoke by non-authority (should fail)
        shadow_signers::revoke_session(other, authority_addr, pubkey);
    }

    #[test(authority = @0xACE, other = @0xBAD, aptos_framework = @aptos_framework)]
    fun test_revoke_expired_session_by_anyone(
        authority: &signer,
        other: &signer,
        aptos_framework: &signer
    ) {
        let authority_addr = signer::address_of(authority);
        let other_addr = signer::address_of(other);
        account::create_account_for_test(authority_addr);
        account::create_account_for_test(other_addr);
        timestamp::set_time_has_started_for_testing(aptos_framework);
        
        let pubkey = sample_pubkey();
        let scopes = sample_scopes();
        
        // Create session with 1 hour TTL
        shadow_signers::create_session(authority, pubkey, scopes, 3600);
        
        // Fast forward time past expiry
        timestamp::update_global_time_for_test_secs(3601);
        
        // Non-authority can revoke expired session
        shadow_signers::revoke_session(other, authority_addr, pubkey);
        
        // Verify revoked
        let (_, revoked, _, _) = shadow_signers::get_session(authority_addr, pubkey);
        assert!(revoked, 0);
    }

    // ==================== View Functions Tests ====================

    #[test(authority = @0xACE, aptos_framework = @aptos_framework)]
    fun test_session_exists(authority: &signer, aptos_framework: &signer) {
        let authority_addr = signer::address_of(authority);
        account::create_account_for_test(authority_addr);
        timestamp::set_time_has_started_for_testing(aptos_framework);
        
        let pubkey = sample_pubkey();
        let pubkey2 = sample_pubkey_2();
        let scopes = sample_scopes();
        
        // Before creation
        assert!(!shadow_signers::session_exists(authority_addr, pubkey), 0);
        
        // After creation
        shadow_signers::create_session(authority, pubkey, scopes, 3600);
        assert!(shadow_signers::session_exists(authority_addr, pubkey), 1);
        assert!(!shadow_signers::session_exists(authority_addr, pubkey2), 2);
    }

    #[test(authority = @0xACE, aptos_framework = @aptos_framework)]
    fun test_is_session_valid(authority: &signer, aptos_framework: &signer) {
        let authority_addr = signer::address_of(authority);
        account::create_account_for_test(authority_addr);
        timestamp::set_time_has_started_for_testing(aptos_framework);
        
        let pubkey = sample_pubkey();
        let scopes = sample_scopes();
        
        // Create session
        shadow_signers::create_session(authority, pubkey, scopes, 3600);
        
        // Should be valid initially
        assert!(shadow_signers::is_session_valid(authority_addr, pubkey), 0);
        
        // Should be invalid after revocation
        shadow_signers::revoke_session(authority, authority_addr, pubkey);
        assert!(!shadow_signers::is_session_valid(authority_addr, pubkey), 1);
    }

    #[test(authority = @0xACE, aptos_framework = @aptos_framework)]
    fun test_is_session_valid_after_expiry(authority: &signer, aptos_framework: &signer) {
        let authority_addr = signer::address_of(authority);
        account::create_account_for_test(authority_addr);
        timestamp::set_time_has_started_for_testing(aptos_framework);
        
        let pubkey = sample_pubkey();
        let scopes = sample_scopes();
        
        // Create session
        shadow_signers::create_session(authority, pubkey, scopes, 3600);
        
        // Valid initially
        assert!(shadow_signers::is_session_valid(authority_addr, pubkey), 0);
        
        // Fast forward past expiry
        timestamp::update_global_time_for_test_secs(3601);
        
        // Should be invalid after expiry
        assert!(!shadow_signers::is_session_valid(authority_addr, pubkey), 1);
    }

    #[test(authority = @0xACE, aptos_framework = @aptos_framework)]
    fun test_get_session_scopes(authority: &signer, aptos_framework: &signer) {
        let authority_addr = signer::address_of(authority);
        account::create_account_for_test(authority_addr);
        timestamp::set_time_has_started_for_testing(aptos_framework);
        
        let pubkey = sample_pubkey();
        let scopes = sample_scopes();
        
        // Before creation
        let (exists, _) = shadow_signers::get_session_scopes(authority_addr, pubkey);
        assert!(!exists, 0);
        
        // After creation
        shadow_signers::create_session(authority, pubkey, scopes, 3600);
        let (exists, returned_scopes) = shadow_signers::get_session_scopes(authority_addr, pubkey);
        assert!(exists, 1);
        assert!(vector::length(&returned_scopes) == 2, 2);
    }

    #[test(authority = @0xACE, aptos_framework = @aptos_framework)]
    fun test_get_last_nonce(authority: &signer, aptos_framework: &signer) {
        let authority_addr = signer::address_of(authority);
        account::create_account_for_test(authority_addr);
        timestamp::set_time_has_started_for_testing(aptos_framework);
        
        let pubkey = sample_pubkey();
        let scopes = sample_scopes();
        
        // Create session
        shadow_signers::create_session(authority, pubkey, scopes, 3600);
        
        // Initial nonce should be 0
        let (exists, nonce) = shadow_signers::get_last_nonce(authority_addr, pubkey);
        assert!(exists, 0);
        assert!(nonce == 0, 1);
    }

    // ==================== Multiple Sessions Tests ====================

    #[test(authority = @0xACE, aptos_framework = @aptos_framework)]
    fun test_multiple_sessions_different_keys(authority: &signer, aptos_framework: &signer) {
        let authority_addr = signer::address_of(authority);
        account::create_account_for_test(authority_addr);
        timestamp::set_time_has_started_for_testing(aptos_framework);
        
        let pubkey1 = sample_pubkey();
        let pubkey2 = sample_pubkey_2();
        let scopes1 = sample_single_scope();
        let scopes2 = sample_scopes();
        
        // Create two sessions
        shadow_signers::create_session(authority, pubkey1, scopes1, 3600);
        shadow_signers::create_session(authority, pubkey2, scopes2, 7200);
        
        // Both should exist
        assert!(shadow_signers::session_exists(authority_addr, pubkey1), 0);
        assert!(shadow_signers::session_exists(authority_addr, pubkey2), 1);
        
        // Each should have correct scopes
        let (_, scopes_result1) = shadow_signers::get_session_scopes(authority_addr, pubkey1);
        let (_, scopes_result2) = shadow_signers::get_session_scopes(authority_addr, pubkey2);
        assert!(vector::length(&scopes_result1) == 1, 2);
        assert!(vector::length(&scopes_result2) == 2, 3);
        
        // Revoking one shouldn't affect the other
        shadow_signers::revoke_session(authority, authority_addr, pubkey1);
        assert!(!shadow_signers::is_session_valid(authority_addr, pubkey1), 4);
        assert!(shadow_signers::is_session_valid(authority_addr, pubkey2), 5);
    }

    // ==================== Cleanup Tests ====================

    #[test(authority = @0xACE, aptos_framework = @aptos_framework)]
    fun test_cleanup_expired_session(authority: &signer, aptos_framework: &signer) {
        let authority_addr = signer::address_of(authority);
        account::create_account_for_test(authority_addr);
        timestamp::set_time_has_started_for_testing(aptos_framework);
        
        let pubkey = sample_pubkey();
        let scopes = sample_scopes();
        
        // Create session
        shadow_signers::create_session(authority, pubkey, scopes, 3600);
        
        // Fast forward past expiry
        timestamp::update_global_time_for_test_secs(3601);
        
        // Cleanup
        shadow_signers::cleanup_expired_session(authority_addr, pubkey);
        
        // Session should no longer exist
        assert!(!shadow_signers::session_exists(authority_addr, pubkey), 0);
    }

    #[test(authority = @0xACE, aptos_framework = @aptos_framework)]
    #[expected_failure(abort_code = 3, location = sigil::shadow_signers)] // E_SESSION_EXPIRED
    fun test_cleanup_non_expired_session_fails(authority: &signer, aptos_framework: &signer) {
        let authority_addr = signer::address_of(authority);
        account::create_account_for_test(authority_addr);
        timestamp::set_time_has_started_for_testing(aptos_framework);
        
        let pubkey = sample_pubkey();
        let scopes = sample_scopes();
        
        // Create session
        shadow_signers::create_session(authority, pubkey, scopes, 3600);
        
        // Try to cleanup before expiry (should fail)
        shadow_signers::cleanup_expired_session(authority_addr, pubkey);
    }
}

