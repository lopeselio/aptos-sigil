module sigil::core {
    use std::string::{Self, String};
    use aptos_std::table::{Self, Table};
    use aptos_framework::event;
    use aptos_framework::signer;
    use aptos_framework::account;

    /// A simple Game descriptor (we'll grow this later).
    struct Game has store, drop {
        id: u64,
        title: String,
        creator: address,
    }

    /// Events
    struct GameRegisteredEvent has drop, store {
        id: u64,
        creator: address,
        title: String,
    }

    /// Event handle container must have `store` (it's a field of a `key` resource).
    struct Events has key, store {
        game_registered: event::EventHandle<GameRegisteredEvent>,
    }

    /// The per-publisher “Sigil” state. Lives under the publisher’s account.
    struct Sigil has key {
        next_game_id: u64,
        games: Table<u64, Game>,
        events: Events,
    }

    /// One-time initializer. Publishes `Sigil` under the caller’s account.
    public entry fun init(publisher: &signer) {
        let addr = signer::address_of(publisher);
        assert!(!exists<Sigil>(addr), 0);

        // Create an event handle via a GUID generator.
        let events = Events {
            game_registered: account::new_event_handle<GameRegisteredEvent>(publisher),
        };

        move_to<Sigil>(publisher, Sigil {
            next_game_id: 0,
            games: table::new<u64, Game>(),
            events,
        });
    }

    /// Register a new game title. Emits an event; stores in the table by id.
    public entry fun register_game(publisher: &signer, title: String) acquires Sigil {
        let addr = signer::address_of(publisher);
        let sigil = borrow_global_mut<Sigil>(addr);

        let id = sigil.next_game_id;
        sigil.next_game_id = id + 1;

        // Manually clone the String: copy bytes then rebuild.
        let title_bytes = string::bytes(&title);
        let title_copy = string::utf8(*title_bytes);


        let game = Game { id, title, creator: addr };
        table::add<u64, Game>(&mut sigil.games, id, game);

        event::emit_event<GameRegisteredEvent>(
            &mut sigil.events.game_registered,
            GameRegisteredEvent { id, creator: addr, title: title_copy }
        );
    }

    #[view]
    /// Return how many games have been registered (monotonic id counter).
    public fun game_count(owner: address): u64 acquires Sigil {
        borrow_global<Sigil>(owner).next_game_id
    }

    #[view]
    /// Quick existence check for an id.
    public fun has_game(owner: address, id: u64): bool acquires Sigil {
        let sigil = borrow_global<Sigil>(owner);
        table::contains<u64, Game>(&sigil.games, id)
    }
}
