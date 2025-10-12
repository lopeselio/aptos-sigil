/// Attest Module - Server-side score attestation for anti-cheat
/// 
/// Enables publishers to:
/// - Register a server public key for score signing
/// - Verify scores are signed by their game server
/// - Prevent client-side score manipulation
/// - Track nonces to prevent replay attacks
///
/// Use case: Competitive games where scores must be validated by authoritative server
module sigil::attest {
    use std::vector;
    use std::signer;
    use std::bcs;
    use aptos_std::ed25519;
    use aptos_std::table::{Self, Table};
    use aptos_framework::timestamp;
    use aptos_framework::account;
    use aptos_framework::event::{Self, EventHandle};

    // ==================== Constants ====================

    /// Maximum age for attestation (60 seconds)
    const MAX_ATTESTATION_AGE_SECS: u64 = 60;

    /// Domain separator for messages
    const DOMAIN_SEPARATOR: vector<u8> = b"SIGIL_ATTEST_V1";

    // ==================== Errors ====================

    const E_NOT_INITIALIZED: u64 = 0;
    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_INVALID_SIGNATURE: u64 = 2;
    const E_ATTESTATION_TOO_OLD: u64 = 3;
    const E_INVALID_NONCE: u64 = 4;
    const E_INVALID_PUBKEY_LENGTH: u64 = 5;

    // ==================== Structs ====================

    /// Attestation configuration per publisher
    struct AttestConfig has key {
        /// Publisher who owns this config
        publisher: address,
        /// Server's ed25519 public key (32 bytes)
        server_pubkey: vector<u8>,
        /// Nonce tracking per player (anti-replay)
        nonces: Table<address, u64>,
        /// Maximum age for attestations in seconds
        max_age_secs: u64,
        /// Events
        events: AttestEvents,
    }

    /// Event handles
    struct AttestEvents has store {
        verified_events: EventHandle<AttestationVerifiedEvent>,
        rejected_events: EventHandle<AttestationRejectedEvent>,
    }

    /// Emitted when attestation is verified
    struct AttestationVerifiedEvent has drop, store {
        publisher: address,
        player: address,
        game_id: u64,
        score: u64,
        nonce: u64,
    }

    /// Emitted when attestation is rejected
    struct AttestationRejectedEvent has drop, store {
        publisher: address,
        player: address,
        reason: vector<u8>,
    }

    // ==================== Initialization ====================

    /// Initialize attestation system for a publisher
    /// 
    /// # Arguments
    /// * `publisher` - Publisher setting up attestations
    /// * `server_pubkey` - Ed25519 public key of the game server (32 bytes)
    /// * `max_age_secs` - Max age for attestations (0 = default 60s, max 300s)
    public entry fun init_attest(
        publisher: &signer,
        server_pubkey: vector<u8>,
        max_age_secs: u64
    ) {
        let addr = signer::address_of(publisher);
        assert!(!exists<AttestConfig>(addr), E_ALREADY_INITIALIZED);
        assert!(vector::length(&server_pubkey) == 32, E_INVALID_PUBKEY_LENGTH);

        let actual_max_age = if (max_age_secs == 0) {
            MAX_ATTESTATION_AGE_SECS
        } else {
            if (max_age_secs > 300) { 300 } else { max_age_secs }
        };

        move_to(publisher, AttestConfig {
            publisher: addr,
            server_pubkey: server_pubkey,
            nonces: table::new(),
            max_age_secs: actual_max_age,
            events: AttestEvents {
                verified_events: account::new_event_handle<AttestationVerifiedEvent>(publisher),
                rejected_events: account::new_event_handle<AttestationRejectedEvent>(publisher),
            },
        });
    }

    /// Update server public key
    public entry fun update_server_key(
        publisher: &signer,
        new_pubkey: vector<u8>
    ) acquires AttestConfig {
        let addr = signer::address_of(publisher);
        assert!(exists<AttestConfig>(addr), E_NOT_INITIALIZED);
        assert!(vector::length(&new_pubkey) == 32, E_INVALID_PUBKEY_LENGTH);

        let config = borrow_global_mut<AttestConfig>(addr);
        config.server_pubkey = new_pubkey;
    }

    // ==================== Verification ====================

    /// Verify a score attestation
    /// 
    /// # Arguments
    /// * `publisher` - Publisher address
    /// * `player` - Player address
    /// * `game_id` - Game ID
    /// * `score` - Claimed score
    /// * `timestamp_signed` - When server signed (unix seconds)
    /// * `nonce` - Monotonically increasing nonce
    /// * `signature` - Ed25519 signature from server (64 bytes)
    /// 
    /// # Returns
    /// * `true` if attestation is valid
    /// 
    /// # Message Format
    /// Server signs: "SIGIL_ATTEST_V1||publisher||player||game_id||score||nonce||timestamp"
    public fun verify_attestation(
        publisher: address,
        player: address,
        game_id: u64,
        score: u64,
        timestamp_signed: u64,
        nonce: u64,
        signature: vector<u8>
    ): bool acquires AttestConfig {
        // Check if attest is configured
        if (!exists<AttestConfig>(publisher)) {
            return false
        };

        let config = borrow_global_mut<AttestConfig>(publisher);

        // Check attestation age
        let now = timestamp::now_seconds();
        if (now > timestamp_signed + config.max_age_secs) {
            emit_rejected(&mut config.events, publisher, player, b"attestation_too_old");
            return false
        };

        // Check nonce (must be > last nonce for this player)
        let last_nonce = if (table::contains(&config.nonces, player)) {
            *table::borrow(&config.nonces, player)
        } else {
            0
        };

        if (nonce <= last_nonce) {
            emit_rejected(&mut config.events, publisher, player, b"invalid_nonce");
            return false
        };

        // Build message
        let message = build_attestation_message(
            publisher,
            player,
            game_id,
            score,
            nonce,
            timestamp_signed
        );

        // Verify signature
        let pk = ed25519::new_unvalidated_public_key_from_bytes(config.server_pubkey);
        let sig = ed25519::new_signature_from_bytes(signature);

        if (!ed25519::signature_verify_strict(&sig, &pk, message)) {
            emit_rejected(&mut config.events, publisher, player, b"invalid_signature");
            return false
        };

        // Update nonce
        if (table::contains(&config.nonces, player)) {
            let nonce_ref = table::borrow_mut(&mut config.nonces, player);
            *nonce_ref = nonce;
        } else {
            table::add(&mut config.nonces, player, nonce);
        };

        // Emit verified event
        event::emit_event(
            &mut config.events.verified_events,
            AttestationVerifiedEvent {
                publisher,
                player,
                game_id,
                score,
                nonce,
            }
        );

        true
    }

    /// Build the canonical message for attestation
    /// Format: "SIGIL_ATTEST_V1||publisher||player||game_id||score||nonce||timestamp"
    fun build_attestation_message(
        publisher: address,
        player: address,
        game_id: u64,
        score: u64,
        nonce: u64,
        timestamp: u64
    ): vector<u8> {
        let msg = DOMAIN_SEPARATOR;
        
        vector::append(&mut msg, b"||");
        vector::append(&mut msg, address_to_bytes(publisher));
        
        vector::append(&mut msg, b"||");
        vector::append(&mut msg, address_to_bytes(player));
        
        vector::append(&mut msg, b"||");
        vector::append(&mut msg, u64_to_bytes(game_id));
        
        vector::append(&mut msg, b"||");
        vector::append(&mut msg, u64_to_bytes(score));
        
        vector::append(&mut msg, b"||");
        vector::append(&mut msg, u64_to_bytes(nonce));
        
        vector::append(&mut msg, b"||");
        vector::append(&mut msg, u64_to_bytes(timestamp));
        
        msg
    }

    fun emit_rejected(
        events: &mut AttestEvents,
        publisher: address,
        player: address,
        reason: vector<u8>
    ) {
        event::emit_event(
            &mut events.rejected_events,
            AttestationRejectedEvent {
                publisher,
                player,
                reason,
            }
        );
    }

    // ==================== Helpers ====================

    fun address_to_bytes(addr: address): vector<u8> {
        // Use BCS serialization
        bcs::to_bytes(&addr)
    }

    fun u64_to_bytes(val: u64): vector<u8> {
        // Convert u64 to ASCII string representation
        if (val == 0) {
            return b"0"
        };

        let digits = vector::empty<u8>();
        let n = val;
        while (n > 0) {
            let digit = ((n % 10) as u8);
            vector::push_back(&mut digits, digit + 48); // 48 = ASCII '0'
            n = n / 10;
        };

        // Reverse to get correct order
        vector::reverse(&mut digits);
        digits
    }

    // ==================== View Functions ====================

    #[view]
    /// Check if attest is initialized for a publisher
    public fun is_initialized(publisher: address): bool {
        exists<AttestConfig>(publisher)
    }

    #[view]
    /// Get server public key
    public fun get_server_pubkey(publisher: address): (bool, vector<u8>) acquires AttestConfig {
        if (!exists<AttestConfig>(publisher)) {
            return (false, vector::empty())
        };

        let config = borrow_global<AttestConfig>(publisher);
        (true, config.server_pubkey)
    }

    #[view]
    /// Get last nonce for a player
    public fun get_last_nonce(publisher: address, player: address): (bool, u64) acquires AttestConfig {
        if (!exists<AttestConfig>(publisher)) {
            return (false, 0)
        };

        let config = borrow_global<AttestConfig>(publisher);
        if (!table::contains(&config.nonces, player)) {
            return (true, 0)
        };

        (true, *table::borrow(&config.nonces, player))
    }

    #[view]
    /// Get max attestation age
    public fun get_max_age(publisher: address): (bool, u64) acquires AttestConfig {
        if (!exists<AttestConfig>(publisher)) {
            return (false, 0)
        };

        let config = borrow_global<AttestConfig>(publisher);
        (true, config.max_age_secs)
    }
}

