/// # Sigil Roles Module
///
/// Enables multi-admin and operator management for game publishers.
/// Per-publisher role registry that allows delegation of administrative tasks.
///
/// ## Role Hierarchy
/// - **Owner**: The publisher who initialized roles (immutable, highest authority)
/// - **Admin**: Can add/remove operators, manage most platform functions
/// - **Operator**: Can create achievements, attach rewards, manage leaderboards
///
/// ## Key Features
/// - Per-publisher role management (each publisher has their own roles)
/// - Granular permission checking (can_manage_achievements, can_manage_rewards, etc.)
/// - Events for all role changes (auditable)
/// - Gas-efficient lookups using Table<address, u8>
/// - View functions for off-chain role discovery
///
/// ## Example Usage
///
/// ```move
/// // Publisher initializes roles
/// roles::init_roles(publisher);
///
/// // Add an admin (only owner can do this)
/// roles::add_admin(publisher, admin_address);
///
/// // Admin adds an operator
/// roles::add_operator(admin, operator_address);
///
/// // Check permissions before sensitive operations
/// assert!(roles::can_manage_achievements(publisher, caller), E_NO_PERMISSION);
/// ```
///
/// ## Integration with Other Modules
///
/// Other modules can use roles for access control:
/// - achievements::create() → check roles::can_manage_achievements()
/// - rewards::attach_reward() → check roles::can_manage_rewards()
/// - leaderboard::create() → check roles::can_manage_leaderboards()
///
/// ## Gas Cost
/// - init_roles: ~300 gas
/// - add_admin: ~200 gas
/// - add_operator: ~150 gas
/// - is_authorized: ~50 gas (read-only)
///
module sigil::roles {
    use std::signer;
    use aptos_std::table::{Self, Table};
    use aptos_framework::account;
    use aptos_framework::event::{Self, EventHandle};

    /************
     * Constants
     ************/

    /// Role flags (bitwise)
    const ROLE_NONE: u8 = 0;
    const ROLE_ADMIN: u8 = 1;
    const ROLE_OPERATOR: u8 = 2;
    const ROLE_ALL: u8 = 255; // All bits set for bitwise NOT operations

    /************
     * Errors
     ************/

    const E_ALREADY_INIT: u64 = 0;
    const E_NOT_INITIALIZED: u64 = 1;
    const E_NOT_OWNER: u64 = 2;
    const E_NOT_ADMIN: u64 = 3;
    const E_NO_PERMISSION: u64 = 4;
    const E_ALREADY_HAS_ROLE: u64 = 5;
    const E_DOES_NOT_HAVE_ROLE: u64 = 6;
    const E_CANNOT_MODIFY_OWNER: u64 = 7;

    /************
     * Structs
     ************/

    /// Event: Admin role granted
    struct AdminGrantedEvent has drop, store {
        publisher: address,
        admin: address,
        granted_by: address,
    }

    /// Event: Admin role revoked
    struct AdminRevokedEvent has drop, store {
        publisher: address,
        admin: address,
        revoked_by: address,
    }

    /// Event: Operator role granted
    struct OperatorGrantedEvent has drop, store {
        publisher: address,
        operator: address,
        granted_by: address,
    }

    /// Event: Operator role revoked
    struct OperatorRevokedEvent has drop, store {
        publisher: address,
        operator: address,
        revoked_by: address,
    }

    /// Event handles for role changes
    struct RoleEvents has store {
        admin_granted: EventHandle<AdminGrantedEvent>,
        admin_revoked: EventHandle<AdminRevokedEvent>,
        operator_granted: EventHandle<OperatorGrantedEvent>,
        operator_revoked: EventHandle<OperatorRevokedEvent>,
    }

    /// Per-publisher role registry
    /// - owner: The original publisher (immutable)
    /// - roles: address -> role flags (bitwise: ADMIN | OPERATOR)
    struct Roles has key {
        owner: address,
        roles: Table<address, u8>,
        events: RoleEvents,
    }

    /************
     * Init
     ************/

    /// Initialize roles for a publisher.
    /// Can only be called once per publisher.
    /// The caller becomes the owner (immutable).
    public entry fun init_roles(publisher: &signer) {
        let addr = signer::address_of(publisher);
        assert!(!exists<Roles>(addr), E_ALREADY_INIT);
        
        move_to<Roles>(publisher, Roles {
            owner: addr,
            roles: table::new<address, u8>(),
            events: RoleEvents {
                admin_granted: account::new_event_handle<AdminGrantedEvent>(publisher),
                admin_revoked: account::new_event_handle<AdminRevokedEvent>(publisher),
                operator_granted: account::new_event_handle<OperatorGrantedEvent>(publisher),
                operator_revoked: account::new_event_handle<OperatorRevokedEvent>(publisher),
            },
        });
    }

    /************
     * Admin Management (Owner only)
     ************/

    /// Add an admin (only owner can call this).
    /// Admins can add/remove operators and perform most admin tasks.
    public entry fun add_admin(
        caller: &signer,
        publisher: address,
        admin: address
    ) acquires Roles {
        let caller_addr = signer::address_of(caller);
        assert!(exists<Roles>(publisher), E_NOT_INITIALIZED);
        
        let r = borrow_global_mut<Roles>(publisher);
        assert!(caller_addr == r.owner, E_NOT_OWNER);
        assert!(admin != r.owner, E_CANNOT_MODIFY_OWNER);
        
        // Check if already admin
        if (table::contains(&r.roles, admin)) {
            let current = *table::borrow(&r.roles, admin);
            assert!((current & ROLE_ADMIN) == 0, E_ALREADY_HAS_ROLE);
            // Add admin flag to existing role
            let new_role = current | ROLE_ADMIN;
            *table::borrow_mut(&mut r.roles, admin) = new_role;
        } else {
            table::add(&mut r.roles, admin, ROLE_ADMIN);
        };
        
        event::emit_event<AdminGrantedEvent>(
            &mut r.events.admin_granted,
            AdminGrantedEvent { publisher, admin, granted_by: caller_addr }
        );
    }

    /// Remove an admin (only owner can call this).
    public entry fun remove_admin(
        caller: &signer,
        publisher: address,
        admin: address
    ) acquires Roles {
        let caller_addr = signer::address_of(caller);
        assert!(exists<Roles>(publisher), E_NOT_INITIALIZED);
        
        let r = borrow_global_mut<Roles>(publisher);
        assert!(caller_addr == r.owner, E_NOT_OWNER);
        assert!(admin != r.owner, E_CANNOT_MODIFY_OWNER);
        assert!(table::contains(&r.roles, admin), E_DOES_NOT_HAVE_ROLE);
        
        let current = *table::borrow(&r.roles, admin);
        assert!((current & ROLE_ADMIN) != 0, E_DOES_NOT_HAVE_ROLE);
        
        // Remove admin flag using XOR with ROLE_ALL to flip bits
        let new_role = current & (ROLE_ALL ^ ROLE_ADMIN);
        if (new_role == ROLE_NONE) {
            table::remove(&mut r.roles, admin);
        } else {
            *table::borrow_mut(&mut r.roles, admin) = new_role;
        };
        
        event::emit_event<AdminRevokedEvent>(
            &mut r.events.admin_revoked,
            AdminRevokedEvent { publisher, admin, revoked_by: caller_addr }
        );
    }

    /************
     * Operator Management (Owner or Admin)
     ************/

    /// Add an operator (owner or admin can call this).
    /// Operators can create achievements, attach rewards, manage leaderboards.
    public entry fun add_operator(
        caller: &signer,
        publisher: address,
        operator: address
    ) acquires Roles {
        let caller_addr = signer::address_of(caller);
        assert!(exists<Roles>(publisher), E_NOT_INITIALIZED);
        
        let r = borrow_global_mut<Roles>(publisher);
        // Caller must be owner or admin
        assert!(
            caller_addr == r.owner || is_admin_internal(r, caller_addr),
            E_NOT_ADMIN
        );
        assert!(operator != r.owner, E_CANNOT_MODIFY_OWNER);
        
        // Check if already operator
        if (table::contains(&r.roles, operator)) {
            let current = *table::borrow(&r.roles, operator);
            assert!((current & ROLE_OPERATOR) == 0, E_ALREADY_HAS_ROLE);
            // Add operator flag to existing role
            let new_role = current | ROLE_OPERATOR;
            *table::borrow_mut(&mut r.roles, operator) = new_role;
        } else {
            table::add(&mut r.roles, operator, ROLE_OPERATOR);
        };
        
        event::emit_event<OperatorGrantedEvent>(
            &mut r.events.operator_granted,
            OperatorGrantedEvent { publisher, operator, granted_by: caller_addr }
        );
    }

    /// Remove an operator (owner or admin can call this).
    public entry fun remove_operator(
        caller: &signer,
        publisher: address,
        operator: address
    ) acquires Roles {
        let caller_addr = signer::address_of(caller);
        assert!(exists<Roles>(publisher), E_NOT_INITIALIZED);
        
        let r = borrow_global_mut<Roles>(publisher);
        // Caller must be owner or admin
        assert!(
            caller_addr == r.owner || is_admin_internal(r, caller_addr),
            E_NOT_ADMIN
        );
        assert!(operator != r.owner, E_CANNOT_MODIFY_OWNER);
        assert!(table::contains(&r.roles, operator), E_DOES_NOT_HAVE_ROLE);
        
        let current = *table::borrow(&r.roles, operator);
        assert!((current & ROLE_OPERATOR) != 0, E_DOES_NOT_HAVE_ROLE);
        
        // Remove operator flag using XOR with ROLE_ALL to flip bits
        let new_role = current & (ROLE_ALL ^ ROLE_OPERATOR);
        if (new_role == ROLE_NONE) {
            table::remove(&mut r.roles, operator);
        } else {
            *table::borrow_mut(&mut r.roles, operator) = new_role;
        };
        
        event::emit_event<OperatorRevokedEvent>(
            &mut r.events.operator_revoked,
            OperatorRevokedEvent { publisher, operator, revoked_by: caller_addr }
        );
    }

    /************
     * Permission Checks (Public)
     ************/

    /// Check if an address is the owner
    public fun is_owner(publisher: address, addr: address): bool acquires Roles {
        if (!exists<Roles>(publisher)) return false;
        let r = borrow_global<Roles>(publisher);
        addr == r.owner
    }

    /// Check if an address is an admin
    public fun is_admin(publisher: address, addr: address): bool acquires Roles {
        if (!exists<Roles>(publisher)) return false;
        let r = borrow_global<Roles>(publisher);
        is_admin_internal(r, addr)
    }

    /// Check if an address is an operator
    public fun is_operator(publisher: address, addr: address): bool acquires Roles {
        if (!exists<Roles>(publisher)) return false;
        let r = borrow_global<Roles>(publisher);
        is_operator_internal(r, addr)
    }

    /// Check if an address has any authorization (owner, admin, or operator)
    public fun is_authorized(publisher: address, addr: address): bool acquires Roles {
        if (!exists<Roles>(publisher)) return false;
        let r = borrow_global<Roles>(publisher);
        addr == r.owner || is_admin_internal(r, addr) || is_operator_internal(r, addr)
    }

    /// Check if an address can manage achievements (owner, admin, or operator)
    public fun can_manage_achievements(publisher: address, addr: address): bool acquires Roles {
        is_authorized(publisher, addr)
    }

    /// Check if an address can manage rewards (owner, admin, or operator)
    public fun can_manage_rewards(publisher: address, addr: address): bool acquires Roles {
        is_authorized(publisher, addr)
    }

    /// Check if an address can manage leaderboards (owner, admin, or operator)
    public fun can_manage_leaderboards(publisher: address, addr: address): bool acquires Roles {
        is_authorized(publisher, addr)
    }

    /// Check if an address can manage treasury (owner or admin only)
    public fun can_manage_treasury(publisher: address, addr: address): bool acquires Roles {
        if (!exists<Roles>(publisher)) return false;
        let r = borrow_global<Roles>(publisher);
        addr == r.owner || is_admin_internal(r, addr)
    }

    /// Check if an address can manage roles (owner or admin only)
    public fun can_manage_roles(publisher: address, addr: address): bool acquires Roles {
        if (!exists<Roles>(publisher)) return false;
        let r = borrow_global<Roles>(publisher);
        addr == r.owner || is_admin_internal(r, addr)
    }

    /************
     * View Functions
     ************/

    #[view]
    /// Get the owner address for a publisher
    public fun get_owner(publisher: address): address acquires Roles {
        assert!(exists<Roles>(publisher), E_NOT_INITIALIZED);
        borrow_global<Roles>(publisher).owner
    }

    #[view]
    /// Check if roles are initialized for a publisher
    public fun is_initialized(publisher: address): bool {
        exists<Roles>(publisher)
    }

    #[view]
    /// Get role flags for an address (0 = none, 1 = admin, 2 = operator, 3 = both)
    public fun get_role(publisher: address, addr: address): u8 acquires Roles {
        if (!exists<Roles>(publisher)) return ROLE_NONE;
        let r = borrow_global<Roles>(publisher);
        if (addr == r.owner) return ROLE_ADMIN | ROLE_OPERATOR; // Owner has all permissions
        if (!table::contains(&r.roles, addr)) return ROLE_NONE;
        *table::borrow(&r.roles, addr)
    }

    #[view]
    /// Get a summary of roles for an address (for UI display)
    /// Returns (is_owner, is_admin, is_operator)
    public fun get_role_summary(publisher: address, addr: address): (bool, bool, bool) acquires Roles {
        if (!exists<Roles>(publisher)) return (false, false, false);
        let r = borrow_global<Roles>(publisher);
        let is_owner_flag = addr == r.owner;
        let is_admin_flag = is_owner_flag || is_admin_internal(r, addr);
        let is_operator_flag = is_owner_flag || is_operator_internal(r, addr);
        (is_owner_flag, is_admin_flag, is_operator_flag)
    }

    /************
     * Internal Helpers
     ************/

    /// Internal: Check if an address is an admin (no existence check)
    fun is_admin_internal(r: &Roles, addr: address): bool {
        if (!table::contains(&r.roles, addr)) return false;
        let role = *table::borrow(&r.roles, addr);
        (role & ROLE_ADMIN) != 0
    }

    /// Internal: Check if an address is an operator (no existence check)
    fun is_operator_internal(r: &Roles, addr: address): bool {
        if (!table::contains(&r.roles, addr)) return false;
        let role = *table::borrow(&r.roles, addr);
        (role & ROLE_OPERATOR) != 0
    }

    /************
     * Test-only Functions
     ************/

    #[test_only]
    public fun init_roles_for_test(publisher: &signer) {
        if (!exists<Roles>(signer::address_of(publisher))) {
            init_roles(publisher);
        };
    }
}

