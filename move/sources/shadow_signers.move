/// Session Keys Module - Temporary delegated authorization for gasless gameplay
/// 
/// Allows players to create ephemeral session keys that can:
/// - Sign transactions on their behalf
/// - Have limited scopes (e.g., only submit_score)
/// - Expire after a time limit (max 7 days)
/// - Be revoked anytime
///
/// Inspired by Magicblock's GPL Session design for Solana, adapted for Aptos Move, for Move developers

module sigil::shadow_signers {
    use std::vector;
    use std::signer;
    use aptos_std::ed25519;
    use aptos_std::table::{Self, Table};
    use aptos_framework::timestamp;
    use aptos_framework::account;
    use aptos_framework::event::{Self, EventHandle};

    // ==================== Constants ====================

    /// Maximum session validity: 7 days (in seconds)
    const MAX_TTL_SECS: u64 = 7 * 24 * 60 * 60; // 604,800 seconds

    /// Default TTL if not specified: 1 hour
    const DEFAULT_TTL_SECS: u64 = 60 * 60;

    // ==================== Errors ====================

    const E_NOT_INITIALIZED: u64 = 0;
    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_SESSION_NOT_FOUND: u64 = 2;
    const E_SESSION_EXPIRED: u64 = 3;
    const E_SESSION_REVOKED: u64 = 4;
    const E_INVALID_TTL: u64 = 5;
    const E_INVALID_SIGNATURE: u64 = 6;
    const E_SCOPE_NOT_ALLOWED: u64 = 7;
    const E_INVALID_MESSAGE: u64 = 8;
    const E_INVALID_NONCE: u64 = 9;
    const E_INVALID_PUBKEY_LENGTH: u64 = 10;
    const E_NOT_AUTHORITY: u64 = 11;

    // ==================== Structs ====================

    /// Session token - represents a temporary delegation
    struct Session has store, drop {
        /// The address that created this session (owner)
        authority: address,
        /// The ed25519 public key of the session signer (32 bytes)
        pubkey: vector<u8>,
        /// Allowed scopes (list of scope identifiers)
        /// Format: b"submit_score", b"claim_reward", etc.
        scopes: vector<vector<u8>>,
        /// Unix timestamp when this session expires
        expires_at_secs: u64,
        /// Whether this session has been revoked
        revoked: bool,
        /// Last nonce used (for replay protection)
        last_nonce: u64,
        /// Address that paid for initialization (receives refund on revoke)
        /// For Aptos, this is mainly for tracking; no actual refund like Solana rent
        fee_payer: address,
    }

    /// Container for all sessions created by a user
    struct Sessions has key {
        /// Map: pubkey -> Session
        /// Each user can have multiple sessions with different keys
        by_pubkey: Table<vector<u8>, Session>,
        /// Events
        events: SessionEvents,
    }

    /// Event handles for session lifecycle
    struct SessionEvents has store {
        create_events: EventHandle<SessionCreatedEvent>,
        revoke_events: EventHandle<SessionRevokedEvent>,
        used_events: EventHandle<SessionUsedEvent>,
    }

    /// Emitted when a session is created
    struct SessionCreatedEvent has drop, store {
        authority: address,
        pubkey: vector<u8>,
        expires_at_secs: u64,
        scopes: vector<vector<u8>>,
    }

    /// Emitted when a session is revoked
    struct SessionRevokedEvent has drop, store {
        authority: address,
        pubkey: vector<u8>,
        revoked_by: address,
    }

    /// Emitted when a session is successfully used
    struct SessionUsedEvent has drop, store {
        authority: address,
        pubkey: vector<u8>,
        scope: vector<u8>,
        nonce: u64,
    }

    // ==================== Initialization ====================

    /// Initialize session storage for a user
    /// Must be called once before creating sessions
    public entry fun init_sessions(user: &signer) {
        let addr = signer::address_of(user);
        assert!(!exists<Sessions>(addr), E_ALREADY_INITIALIZED);

        move_to(user, Sessions {
            by_pubkey: table::new(),
            events: SessionEvents {
                create_events: account::new_event_handle<SessionCreatedEvent>(user),
                revoke_events: account::new_event_handle<SessionRevokedEvent>(user),
                used_events: account::new_event_handle<SessionUsedEvent>(user),
            },
        });
    }

    // ==================== Session Management ====================

    /// Create a new session
    /// 
    /// # Arguments
    /// * `authority` - The user creating the session
    /// * `pubkey` - The ed25519 public key of the session signer (32 bytes)
    /// * `scopes` - List of allowed scope identifiers (e.g., ["submit_score", "claim_reward"])
    /// * `ttl_secs` - Time-to-live in seconds (max 7 days, 0 = default 1 hour)
    public entry fun create_session(
        authority: &signer,
        pubkey: vector<u8>,
        scopes: vector<vector<u8>>,
        ttl_secs: u64
    ) acquires Sessions {
        let addr = signer::address_of(authority);
        
        // Ensure initialized
        if (!exists<Sessions>(addr)) {
            init_sessions(authority);
        };

        // Validate pubkey length (ed25519 = 32 bytes)
        assert!(vector::length(&pubkey) == 32, E_INVALID_PUBKEY_LENGTH);

        // Validate TTL
        let actual_ttl = if (ttl_secs == 0) { DEFAULT_TTL_SECS } else { ttl_secs };
        assert!(actual_ttl > 0 && actual_ttl <= MAX_TTL_SECS, E_INVALID_TTL);

        let expires_at = timestamp::now_seconds() + actual_ttl;

        // Create session
        let session = Session {
            authority: addr,
            pubkey: pubkey,
            scopes: scopes,
            expires_at_secs: expires_at,
            revoked: false,
            last_nonce: 0,
            fee_payer: addr, // Authority is also fee payer by default
        };

        // Store (overwrites if exists)
        let sessions = borrow_global_mut<Sessions>(addr);
        let pk_copy = session.pubkey;
        let scopes_copy = session.scopes;
        if (table::contains(&sessions.by_pubkey, pk_copy)) {
            table::remove(&mut sessions.by_pubkey, pk_copy);
        };
        table::add(&mut sessions.by_pubkey, pk_copy, session);

        // Emit event
        event::emit_event(
            &mut sessions.events.create_events,
            SessionCreatedEvent {
                authority: addr,
                pubkey: pk_copy,
                expires_at_secs: expires_at,
                scopes: scopes_copy,
            }
        );
    }

    /// Create a session with a separate fee payer
    /// Useful when a relayer/backend pays for the session creation
    public entry fun create_session_with_payer(
        authority: &signer,
        fee_payer: &signer,
        pubkey: vector<u8>,
        scopes: vector<vector<u8>>,
        ttl_secs: u64
    ) acquires Sessions {
        let addr = signer::address_of(authority);
        let payer_addr = signer::address_of(fee_payer);
        
        // Ensure initialized (using fee_payer for gas)
        if (!exists<Sessions>(addr)) {
            init_sessions(authority);
        };

        // Validate pubkey length
        assert!(vector::length(&pubkey) == 32, E_INVALID_PUBKEY_LENGTH);

        // Validate TTL
        let actual_ttl = if (ttl_secs == 0) { DEFAULT_TTL_SECS } else { ttl_secs };
        assert!(actual_ttl > 0 && actual_ttl <= MAX_TTL_SECS, E_INVALID_TTL);

        let expires_at = timestamp::now_seconds() + actual_ttl;

        // Create session with explicit fee_payer
        let session = Session {
            authority: addr,
            pubkey: pubkey,
            scopes: scopes,
            expires_at_secs: expires_at,
            revoked: false,
            last_nonce: 0,
            fee_payer: payer_addr,
        };

        // Store
        let sessions = borrow_global_mut<Sessions>(addr);
        let pk_copy = session.pubkey;
        let scopes_copy = session.scopes;
        if (table::contains(&sessions.by_pubkey, pk_copy)) {
            table::remove(&mut sessions.by_pubkey, pk_copy);
        };
        table::add(&mut sessions.by_pubkey, pk_copy, session);

        // Emit event
        event::emit_event(
            &mut sessions.events.create_events,
            SessionCreatedEvent {
                authority: addr,
                pubkey: pk_copy,
                expires_at_secs: expires_at,
                scopes: scopes_copy,
            }
        );
    }

    /// Revoke a session (can be called by authority or after expiry by anyone)
    public entry fun revoke_session(
        revoker: &signer,
        authority_addr: address,
        pubkey: vector<u8>
    ) acquires Sessions {
        let revoker_addr = signer::address_of(revoker);
        
        assert!(exists<Sessions>(authority_addr), E_NOT_INITIALIZED);
        let sessions = borrow_global_mut<Sessions>(authority_addr);
        
        assert!(table::contains(&sessions.by_pubkey, pubkey), E_SESSION_NOT_FOUND);
        
        let session = table::borrow_mut(&mut sessions.by_pubkey, pubkey);
        
        // If session is still active, only authority can revoke
        // If expired, anyone can revoke to clean up
        let now = timestamp::now_seconds();
        if (now < session.expires_at_secs) {
            assert!(revoker_addr == session.authority, E_NOT_AUTHORITY);
        };

        session.revoked = true;

        // Emit event
        event::emit_event(
            &mut sessions.events.revoke_events,
            SessionRevokedEvent {
                authority: authority_addr,
                pubkey: pubkey,
                revoked_by: revoker_addr,
            }
        );
    }

    // ==================== Verification ====================

    /// Verify a session signature and check authorization
    /// 
    /// This is the core verification function that should be called
    /// from other modules to validate session-based transactions.
    /// 
    /// # Arguments
    /// * `authority` - The user who owns the session
    /// * `scope` - The scope being requested (e.g., b"submit_score")
    /// * `message` - The message that was signed
    /// * `signature` - The ed25519 signature (64 bytes)
    /// * `pubkey` - The session public key (32 bytes)
    /// 
    /// # Returns
    /// * `true` if session is valid and signature verifies
    /// * `false` otherwise
    /// 
    /// # Message Format
    /// The message should include (to prevent replay/misuse):
    /// - Domain separator (e.g., b"SIGIL_SESSION_V1")
    /// - Scope (e.g., b"submit_score")
    /// - Authority address
    /// - Nonce (monotonic)
    /// - Message expiration timestamp
    /// - Any action-specific data (game_id, score, etc.)
    public fun verify_session(
        authority: address,
        scope: vector<u8>,
        message: vector<u8>,
        signature: vector<u8>,
        pubkey: vector<u8>
    ): bool acquires Sessions {
        // Check if sessions exist for this authority
        if (!exists<Sessions>(authority)) {
            return false
        };

        let sessions = borrow_global<Sessions>(authority);
        
        // Check if session exists
        if (!table::contains(&sessions.by_pubkey, pubkey)) {
            return false
        };

        let session = table::borrow(&sessions.by_pubkey, pubkey);

        // Check if revoked
        if (session.revoked) {
            return false
        };

        // Check if expired
        let now = timestamp::now_seconds();
        if (now >= session.expires_at_secs) {
            return false
        };

        // Check if scope is allowed
        if (!is_scope_allowed(&session.scopes, &scope)) {
            return false
        };

        // Verify ed25519 signature
        let pk_unvalidated = ed25519::new_unvalidated_public_key_from_bytes(pubkey);
        let sig_struct = ed25519::new_signature_from_bytes(signature);
        
        if (!ed25519::signature_verify_strict(&sig_struct, &pk_unvalidated, message)) {
            return false
        };

        true
    }

    /// Verify session and update nonce (mutating version)
    /// 
    /// Use this version when you want to enforce nonce-based replay protection.
    /// The nonce in the message must be > last_nonce, and will be stored.
    /// 
    /// # Note
    /// You must parse `message` to extract the nonce before calling this.
    public fun verify_session_with_nonce(
        authority: address,
        scope: vector<u8>,
        message: vector<u8>,
        signature: vector<u8>,
        pubkey: vector<u8>,
        nonce: u64
    ): bool acquires Sessions {
        // First do basic verification
        if (!verify_session(authority, scope, message, signature, pubkey)) {
            return false
        };

        // Now check and update nonce
        let sessions = borrow_global_mut<Sessions>(authority);
        let session = table::borrow_mut(&mut sessions.by_pubkey, pubkey);
        
        // Nonce must be strictly increasing
        if (nonce <= session.last_nonce) {
            return false
        };

        // Update nonce
        session.last_nonce = nonce;

        // Emit usage event
        event::emit_event(
            &mut sessions.events.used_events,
            SessionUsedEvent {
                authority,
                pubkey,
                scope,
                nonce,
            }
        );

        true
    }

    /// Helper: Check if a scope is in the allowed list
    fun is_scope_allowed(allowed: &vector<vector<u8>>, requested: &vector<u8>): bool {
        let len = vector::length(allowed);
        let i = 0;
        while (i < len) {
            let scope = vector::borrow(allowed, i);
            if (scope == requested) {
                return true
            };
            i = i + 1;
        };
        false
    }

    // ==================== View Functions ====================

    #[view]
    /// Check if sessions are initialized for a user
    public fun is_initialized(addr: address): bool {
        exists<Sessions>(addr)
    }

    #[view]
    /// Check if a specific session exists
    public fun session_exists(authority: address, pubkey: vector<u8>): bool acquires Sessions {
        if (!exists<Sessions>(authority)) {
            return false
        };
        let sessions = borrow_global<Sessions>(authority);
        table::contains(&sessions.by_pubkey, pubkey)
    }

    #[view]
    /// Get session details
    /// Returns: (exists, revoked, expires_at_secs, is_expired)
    public fun get_session(
        authority: address,
        pubkey: vector<u8>
    ): (bool, bool, u64, bool) acquires Sessions {
        if (!session_exists(authority, pubkey)) {
            return (false, false, 0, false)
        };

        let sessions = borrow_global<Sessions>(authority);
        let session = table::borrow(&sessions.by_pubkey, pubkey);
        let now = timestamp::now_seconds();
        let is_expired = now >= session.expires_at_secs;

        (true, session.revoked, session.expires_at_secs, is_expired)
    }

    #[view]
    /// Check if session is currently valid (not revoked, not expired)
    public fun is_session_valid(authority: address, pubkey: vector<u8>): bool acquires Sessions {
        let (exists, revoked, expires_at, _) = get_session(authority, pubkey);
        if (!exists || revoked) {
            return false
        };
        let now = timestamp::now_seconds();
        now < expires_at
    }

    #[view]
    /// Get session scopes
    /// Returns: (exists, scopes)
    public fun get_session_scopes(
        authority: address,
        pubkey: vector<u8>
    ): (bool, vector<vector<u8>>) acquires Sessions {
        if (!session_exists(authority, pubkey)) {
            return (false, vector::empty())
        };

        let sessions = borrow_global<Sessions>(authority);
        let session = table::borrow(&sessions.by_pubkey, pubkey);
        (true, session.scopes)
    }

    #[view]
    /// Get last nonce used
    public fun get_last_nonce(authority: address, pubkey: vector<u8>): (bool, u64) acquires Sessions {
        if (!session_exists(authority, pubkey)) {
            return (false, 0)
        };

        let sessions = borrow_global<Sessions>(authority);
        let session = table::borrow(&sessions.by_pubkey, pubkey);
        (true, session.last_nonce)
    }

    #[view]
    /// Get fee payer address
    public fun get_fee_payer(authority: address, pubkey: vector<u8>): (bool, address) acquires Sessions {
        if (!session_exists(authority, pubkey)) {
            return (false, @0x0)
        };

        let sessions = borrow_global<Sessions>(authority);
        let session = table::borrow(&sessions.by_pubkey, pubkey);
        (true, session.fee_payer)
    }

    // ==================== Admin/Cleanup ====================

    /// Clean up an expired session (anyone can call after expiry)
    public entry fun cleanup_expired_session(
        authority_addr: address,
        pubkey: vector<u8>
    ) acquires Sessions {
        assert!(exists<Sessions>(authority_addr), E_NOT_INITIALIZED);
        let sessions = borrow_global_mut<Sessions>(authority_addr);
        
        assert!(table::contains(&sessions.by_pubkey, pubkey), E_SESSION_NOT_FOUND);
        
        let session = table::borrow(&sessions.by_pubkey, pubkey);
        let now = timestamp::now_seconds();
        assert!(now >= session.expires_at_secs, E_SESSION_EXPIRED);

        // Remove the session
        table::remove(&mut sessions.by_pubkey, pubkey);
    }
}

