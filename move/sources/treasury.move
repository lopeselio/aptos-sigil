/// Treasury Module - Fungible Asset management for automated reward distribution
/// 
/// Enables publishers to:
/// - Deposit FA into treasury escrow
/// - Authorize withdrawals for reward distribution
/// - Track balances per FA type
/// - Manage multiple fungible assets
///
/// Designed to integrate with rewards module for automated FA transfers.
module sigil::treasury {
    use std::signer;
    use std::vector;
    use aptos_std::table::{Self, Table};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::fungible_asset::Metadata;
    use aptos_framework::primary_fungible_store;
    use aptos_framework::account;
    use aptos_framework::event::{Self, EventHandle};

    // ==================== Constants ====================

    /// Maximum withdrawal per transaction (anti-drain protection)
    const MAX_WITHDRAWAL: u64 = 1_000_000_000_000; // 10,000 APT (in octas)

    // ==================== Errors ====================

    const E_NOT_INITIALIZED: u64 = 0;
    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_INSUFFICIENT_BALANCE: u64 = 2;
    const E_INVALID_AMOUNT: u64 = 3;
    const E_WITHDRAWAL_TOO_LARGE: u64 = 4;
    const E_NOT_PUBLISHER: u64 = 5;
    const E_STORE_NOT_FOUND: u64 = 6;

    // ==================== Structs ====================

    /// Per-FA tracking information
    /// Treasury uses publisher's primary_fungible_store for actual storage
    struct FATracking has store, drop {
        /// FA metadata address
        fa_metadata_addr: address,
        /// Total deposited (for tracking)
        total_deposited: u64,
        /// Total withdrawn for rewards (for tracking)
        total_withdrawn: u64,
    }

    /// Publisher's treasury - tracks FA for reward distribution
    /// Uses publisher's primary_fungible_store for actual storage
    struct Treasury has key {
        /// Publisher who owns this treasury
        publisher: address,
        /// Map: FA metadata address -> FATracking
        tracking: Table<address, FATracking>,
        /// Events
        events: TreasuryEvents,
    }

    /// Event handles
    struct TreasuryEvents has store {
        deposit_events: EventHandle<DepositEvent>,
        withdraw_events: EventHandle<WithdrawEvent>,
    }

    /// Emitted when FA is deposited
    struct DepositEvent has drop, store {
        publisher: address,
        fa_metadata: address,
        amount: u64,
        depositor: address,
    }

    /// Emitted when FA is withdrawn
    struct WithdrawEvent has drop, store {
        publisher: address,
        fa_metadata: address,
        amount: u64,
        recipient: address,
    }

    // ==================== Initialization ====================

    /// Initialize treasury for a publisher
    public entry fun init_treasury(publisher: &signer) {
        let addr = signer::address_of(publisher);
        assert!(!exists<Treasury>(addr), E_ALREADY_INITIALIZED);

        move_to(publisher, Treasury {
            publisher: addr,
            tracking: table::new(),
            events: TreasuryEvents {
                deposit_events: account::new_event_handle<DepositEvent>(publisher),
                withdraw_events: account::new_event_handle<WithdrawEvent>(publisher),
            },
        });
    }

    // ==================== Deposit Functions ====================

    /// Deposit FA into treasury
    /// Transfers FA from depositor to publisher's primary fungible store
    /// 
    /// # Arguments
    /// * `depositor` - Account depositing the FA (pays gas)
    /// * `publisher_addr` - Treasury owner address
    /// * `fa_metadata` - FA metadata object
    /// * `amount` - Amount to deposit
    public entry fun deposit(
        depositor: &signer,
        publisher_addr: address,
        fa_metadata: Object<Metadata>,
        amount: u64
    ) acquires Treasury {
        assert!(exists<Treasury>(publisher_addr), E_NOT_INITIALIZED);
        assert!(amount > 0, E_INVALID_AMOUNT);

        let depositor_addr = signer::address_of(depositor);
        let metadata_addr = object::object_address(&fa_metadata);

        // Ensure tracking exists for this FA
        let treasury = borrow_global_mut<Treasury>(publisher_addr);
        if (!table::contains(&treasury.tracking, metadata_addr)) {
            table::add(&mut treasury.tracking, metadata_addr, FATracking {
                fa_metadata_addr: metadata_addr,
                total_deposited: 0,
                total_withdrawn: 0,
            });
        };

        // Transfer FA from depositor to publisher's primary store
        primary_fungible_store::transfer(depositor, fa_metadata, publisher_addr, amount);

        // Update tracking
        let fa_tracking = table::borrow_mut(&mut treasury.tracking, metadata_addr);
        fa_tracking.total_deposited = fa_tracking.total_deposited + amount;

        // Emit event
        event::emit_event(
            &mut treasury.events.deposit_events,
            DepositEvent {
                publisher: publisher_addr,
                fa_metadata: metadata_addr,
                amount,
                depositor: depositor_addr,
            }
        );
    }

    // ==================== Withdrawal Functions ====================

    /// Withdraw FA from treasury (publisher only)
    /// Transfers from publisher's primary store to recipient
    /// 
    /// # Arguments
    /// * `publisher` - Publisher withdrawing funds
    /// * `fa_metadata` - FA metadata object
    /// * `recipient` - Address to send FA to
    /// * `amount` - Amount to withdraw
    public entry fun withdraw(
        publisher: &signer,
        fa_metadata: Object<Metadata>,
        recipient: address,
        amount: u64
    ) acquires Treasury {
        let publisher_addr = signer::address_of(publisher);
        assert!(exists<Treasury>(publisher_addr), E_NOT_INITIALIZED);
        assert!(amount > 0, E_INVALID_AMOUNT);
        assert!(amount <= MAX_WITHDRAWAL, E_WITHDRAWAL_TOO_LARGE);

        let metadata_addr = object::object_address(&fa_metadata);

        // Check balance in publisher's primary store
        let balance = primary_fungible_store::balance(publisher_addr, fa_metadata);
        assert!(balance >= amount, E_INSUFFICIENT_BALANCE);

        // Transfer from publisher's primary store to recipient
        primary_fungible_store::transfer(publisher, fa_metadata, recipient, amount);

        // Update tracking
        let treasury = borrow_global_mut<Treasury>(publisher_addr);
        if (table::contains(&treasury.tracking, metadata_addr)) {
            let fa_tracking = table::borrow_mut(&mut treasury.tracking, metadata_addr);
            fa_tracking.total_withdrawn = fa_tracking.total_withdrawn + amount;
        };

        // Emit event
        event::emit_event(
            &mut treasury.events.withdraw_events,
            WithdrawEvent {
                publisher: publisher_addr,
                fa_metadata: metadata_addr,
                amount,
                recipient,
            }
        );
    }

    /// Send `amount_each` of FA from the publisher's primary store to every address in `recipients`.
    /// Used by `seasons` for equal prize splits. Publisher must be the transaction sender.
    public fun distribute_fa_equal(
        publisher: &signer,
        fa_metadata: Object<Metadata>,
        recipients: vector<address>,
        amount_each: u64
    ) acquires Treasury {
        let publisher_addr = signer::address_of(publisher);
        assert!(exists<Treasury>(publisher_addr), E_NOT_INITIALIZED);
        assert!(amount_each > 0, E_INVALID_AMOUNT);

        let n = vector::length(&recipients);
        assert!(n > 0, E_INVALID_AMOUNT);

        let total = amount_each * n;
        assert!(total / n == amount_each, E_INVALID_AMOUNT);

        assert!(amount_each <= MAX_WITHDRAWAL, E_WITHDRAWAL_TOO_LARGE);

        let balance = primary_fungible_store::balance(publisher_addr, fa_metadata);
        assert!(balance >= total, E_INSUFFICIENT_BALANCE);

        let metadata_addr = object::object_address(&fa_metadata);

        let treasury = borrow_global_mut<Treasury>(publisher_addr);
        let i = 0;
        while (i < n) {
            let to = *vector::borrow(&recipients, i);
            primary_fungible_store::transfer(publisher, fa_metadata, to, amount_each);
            event::emit_event(
                &mut treasury.events.withdraw_events,
                WithdrawEvent {
                    publisher: publisher_addr,
                    fa_metadata: metadata_addr,
                    amount: amount_each,
                    recipient: to,
                }
            );
            i = i + 1;
        };

        if (!table::contains(&treasury.tracking, metadata_addr)) {
            table::add(
                &mut treasury.tracking,
                metadata_addr,
                FATracking {
                    fa_metadata_addr: metadata_addr,
                    total_deposited: 0,
                    total_withdrawn: 0,
                }
            );
        };
        let fa_tracking = table::borrow_mut(&mut treasury.tracking, metadata_addr);
        fa_tracking.total_withdrawn = fa_tracking.total_withdrawn + total;
    }

    /// Check if treasury can fulfill a reward withdrawal
    /// Used by rewards module to verify funds before claiming
    /// 
    /// # Note
    /// Actual withdrawal in Phase Final will require signer capability
    /// or the publisher manually calling withdraw() after detecting claim events
    public fun can_fulfill_reward(
        publisher_addr: address,
        fa_metadata: Object<Metadata>,
        amount: u64
    ): bool {
        if (!exists<Treasury>(publisher_addr)) {
            return false
        };

        // Check publisher's primary store balance
        let balance = primary_fungible_store::balance(publisher_addr, fa_metadata);
        balance >= amount
    }

    // ==================== View Functions ====================

    #[view]
    /// Check if treasury is initialized
    public fun is_initialized(publisher: address): bool {
        exists<Treasury>(publisher)
    }

    #[view]
    /// Get balance for a specific FA in publisher's primary store
    /// Returns: (is_initialized, balance)
    public fun get_balance(
        publisher: address,
        fa_metadata: Object<Metadata>
    ): (bool, u64) {
        if (!exists<Treasury>(publisher)) {
            return (false, 0)
        };

        // Query publisher's primary fungible store
        let balance = primary_fungible_store::balance(publisher, fa_metadata);

        (true, balance)
    }

    #[view]
    /// Get deposit/withdrawal stats for an FA
    /// Returns: (has_tracking, total_deposited, total_withdrawn, current_balance)
    public fun get_stats(
        publisher: address,
        fa_metadata: Object<Metadata>
    ): (bool, u64, u64, u64) acquires Treasury {
        if (!exists<Treasury>(publisher)) {
            return (false, 0, 0, 0)
        };

        let treasury = borrow_global<Treasury>(publisher);
        let metadata_addr = object::object_address(&fa_metadata);

        // Get current balance from primary store
        let balance = primary_fungible_store::balance(publisher, fa_metadata);

        if (!table::contains(&treasury.tracking, metadata_addr)) {
            // Has balance but no tracking yet
            return (false, 0, 0, balance)
        };

        let fa_tracking = table::borrow(&treasury.tracking, metadata_addr);

        (true, fa_tracking.total_deposited, fa_tracking.total_withdrawn, balance)
    }

    #[view]
    /// Check if treasury has sufficient balance for a withdrawal
    public fun can_withdraw(
        publisher: address,
        fa_metadata: Object<Metadata>,
        amount: u64
    ): bool {
        let (is_init, balance) = get_balance(publisher, fa_metadata);
        is_init && balance >= amount
    }
}


