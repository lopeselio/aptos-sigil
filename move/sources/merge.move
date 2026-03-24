/// Merge / crafting — publisher-defined recipes over abstract item IDs.
///
/// MVP: inventory keyed by `(publisher, player, item_id)` as u64 quantities.
/// Integrate with real NFT/FA burns in a future version; this layer is game-defined materials.
module sigil::merge {
    use std::signer;
    use aptos_std::table::{Self, Table};
    use aptos_framework::account;
    use aptos_framework::event::{Self, EventHandle};
    use sigil::roles;

    const E_NOT_INITIALIZED: u64 = 0;
    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_RECIPE_NOT_FOUND: u64 = 2;
    const E_INSUFFICIENT_ITEMS: u64 = 3;
    const E_NO_PERMISSION: u64 = 4;
    const E_INVALID_QUANTITY: u64 = 5;

    struct Recipe has store, drop {
        id: u64,
        input_item_id: u64,
        input_qty: u64,
        output_item_id: u64,
        output_qty: u64,
    }

    struct MergeRegistry has key {
        publisher: address,
        next_recipe_id: u64,
        recipes: Table<u64, Recipe>,
        /// player -> item_id -> qty
        inventory: Table<address, Table<u64, u64>>,
        events: MergeEvents,
    }

    struct RecipeRegisteredEvent has drop, store {
        publisher: address,
        recipe_id: u64,
        input_item_id: u64,
        input_qty: u64,
        output_item_id: u64,
        output_qty: u64,
    }

    struct MergeExecutedEvent has drop, store {
        publisher: address,
        player: address,
        recipe_id: u64,
    }

    struct MergeEvents has store {
        recipe_registered: EventHandle<RecipeRegisteredEvent>,
        merge_executed: EventHandle<MergeExecutedEvent>,
    }

    public entry fun init_merge(publisher: &signer) {
        let addr = signer::address_of(publisher);
        assert!(!exists<MergeRegistry>(addr), E_ALREADY_INITIALIZED);
        move_to(
            publisher,
            MergeRegistry {
                publisher: addr,
                next_recipe_id: 0,
                recipes: table::new(),
                inventory: table::new(),
                events: MergeEvents {
                    recipe_registered: account::new_event_handle<RecipeRegisteredEvent>(
                        publisher
                    ),
                    merge_executed: account::new_event_handle<MergeExecutedEvent>(publisher),
                },
            }
        );
    }

    fun assert_merge_admin(caller: address, publisher: address) {
        if (roles::is_initialized(publisher)) {
            assert!(roles::can_manage_achievements(publisher, caller), E_NO_PERMISSION);
        } else {
            assert!(caller == publisher, E_NO_PERMISSION);
        };
    }

    /// Register a recipe: consume `input_qty` of `input_item_id` -> gain `output_qty` of `output_item_id`.
    public entry fun register_recipe(
        actor: &signer,
        publisher: address,
        input_item_id: u64,
        input_qty: u64,
        output_item_id: u64,
        output_qty: u64
    ) acquires MergeRegistry {
        let caller = signer::address_of(actor);
        assert_merge_admin(caller, publisher);
        assert!(exists<MergeRegistry>(publisher), E_NOT_INITIALIZED);
        assert!(input_qty > 0 && output_qty > 0, E_INVALID_QUANTITY);

        let regs = borrow_global_mut<MergeRegistry>(publisher);
        let rid = regs.next_recipe_id;
        regs.next_recipe_id = rid + 1;

        let r = Recipe {
            id: rid,
            input_item_id,
            input_qty,
            output_item_id,
            output_qty,
        };
        table::add(&mut regs.recipes, rid, r);

        event::emit_event(
            &mut regs.events.recipe_registered,
            RecipeRegisteredEvent {
                publisher,
                recipe_id: rid,
                input_item_id,
                input_qty,
                output_item_id,
                output_qty,
            }
        );
    }

    /// Publisher-side grant of crafting materials (off-chain mint / quest reward hooks).
    public entry fun grant_items(
        actor: &signer,
        publisher: address,
        player: address,
        item_id: u64,
        qty: u64
    ) acquires MergeRegistry {
        let caller = signer::address_of(actor);
        assert_merge_admin(caller, publisher);
        assert!(exists<MergeRegistry>(publisher), E_NOT_INITIALIZED);
        assert!(qty > 0, E_INVALID_QUANTITY);

        let regs = borrow_global_mut<MergeRegistry>(publisher);
        ensure_player_inventory(regs, player);
        let inv = table::borrow_mut(&mut regs.inventory, player);
        add_qty(inv, item_id, qty);
    }

    fun ensure_player_inventory(regs: &mut MergeRegistry, player: address) {
        if (!table::contains(&regs.inventory, player)) {
            table::add(&mut regs.inventory, player, table::new());
        };
    }

    fun add_qty(inv: &mut Table<u64, u64>, item_id: u64, qty: u64) {
        if (table::contains(inv, item_id)) {
            let q = table::borrow_mut(inv, item_id);
            *q = *q + qty;
        } else {
            table::add(inv, item_id, qty);
        };
    }

    fun sub_qty(inv: &mut Table<u64, u64>, item_id: u64, qty: u64): bool {
        if (!table::contains(inv, item_id)) {
            return false
        };
        let q = table::borrow_mut(inv, item_id);
        if (*q < qty) {
            return false
        };
        *q = *q - qty;
        true
    }

    /// Player executes a registered recipe under `publisher`.
    public entry fun execute_merge(
        player: &signer,
        publisher: address,
        recipe_id: u64
    ) acquires MergeRegistry {
        let player_addr = signer::address_of(player);
        assert!(exists<MergeRegistry>(publisher), E_NOT_INITIALIZED);

        let regs = borrow_global_mut<MergeRegistry>(publisher);
        assert!(table::contains(&regs.recipes, recipe_id), E_RECIPE_NOT_FOUND);
        let (in_id, in_qty, out_id, out_qty) = {
            let recipe = table::borrow(&regs.recipes, recipe_id);
            (
                recipe.input_item_id,
                recipe.input_qty,
                recipe.output_item_id,
                recipe.output_qty
            )
        };

        ensure_player_inventory(regs, player_addr);
        let inv = table::borrow_mut(&mut regs.inventory, player_addr);

        assert!(sub_qty(inv, in_id, in_qty), E_INSUFFICIENT_ITEMS);
        add_qty(inv, out_id, out_qty);

        event::emit_event(
            &mut regs.events.merge_executed,
            MergeExecutedEvent { publisher, player: player_addr, recipe_id }
        );
    }

    #[view]
    public fun is_initialized(publisher: address): bool {
        exists<MergeRegistry>(publisher)
    }

    #[view]
    public fun recipe_count(publisher: address): u64 acquires MergeRegistry {
        if (!exists<MergeRegistry>(publisher)) return 0;
        borrow_global<MergeRegistry>(publisher).next_recipe_id
    }

    #[view]
    public fun get_item_qty(publisher: address, player: address, item_id: u64): u64 acquires MergeRegistry {
        if (!exists<MergeRegistry>(publisher)) return 0;
        let regs = borrow_global<MergeRegistry>(publisher);
        if (!table::contains(&regs.inventory, player)) return 0;
        let inv = table::borrow(&regs.inventory, player);
        if (!table::contains(inv, item_id)) return 0;
        *table::borrow(inv, item_id)
    }

    #[view]
    public fun get_recipe(
        publisher: address,
        recipe_id: u64
    ): (bool, u64, u64, u64, u64) acquires MergeRegistry {
        if (!exists<MergeRegistry>(publisher)) return (false, 0, 0, 0, 0);
        let regs = borrow_global<MergeRegistry>(publisher);
        if (!table::contains(&regs.recipes, recipe_id)) {
            return (false, 0, 0, 0, 0)
        };
        let r = table::borrow(&regs.recipes, recipe_id);
        (
            true,
            r.input_item_id,
            r.input_qty,
            r.output_item_id,
            r.output_qty
        )
    }
}
