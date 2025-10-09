module sigil::game_platform {
    use std::string::{Self, String};
    use std::vector;
    use aptos_std::table::{Self, Table};
    use aptos_framework::event;
    use aptos_framework::signer;
    use aptos_framework::account;

    /*************
     *  Types
     *************/

    /// Game descriptor
    struct Game has store, drop {
        id: u64,
        title: String,
        creator: address,
    }

    /// Minimal Player account published under the user's address.
    struct Player has key {
        user: address,
        username: String,
    }

    /// Events
    struct GameRegisteredEvent has drop, store {
        id: u64,
        creator: address,
        title: String,
    }

    struct ScoreSubmittedEvent has drop, store {
        publisher: address,
        player: address,
        game_id: u64,
        score: u64,
    }

    /// Event handle container
    struct Events has key, store {
        game_registered: event::EventHandle<GameRegisteredEvent>,
        score_submitted: event::EventHandle<ScoreSubmittedEvent>,
    }

    /// Per-publisher state
    /// - games: all games created by the publisher
    /// - scores: player -> (game_id -> [scores])
    struct Sigil has key {
        next_game_id: u64,
        games: Table<u64, Game>,
        scores: Table<address, Table<u64, vector<u64>>>,
        events: Events,
    }

    /*************
     *  Errors
     *************/
    const E_ALREADY_INIT: u64 = 0;
    const E_GAME_NOT_FOUND: u64 = 1;
    const E_PLAYER_EXISTS: u64 = 2;
    const E_PLAYER_REQUIRED: u64 = 3;

    /*************
     *  Entry funcs
     *************/

    /// One-time initializer under the publisher’s account.
    public entry fun init(publisher: &signer) {
        let addr = signer::address_of(publisher);
        assert!(!exists<Sigil>(addr), E_ALREADY_INIT);

        let events = Events {
            game_registered: account::new_event_handle<GameRegisteredEvent>(publisher),
            score_submitted: account::new_event_handle<ScoreSubmittedEvent>(publisher),
        };

        move_to<Sigil>(publisher, Sigil {
            next_game_id: 0,
            games: table::new<u64, Game>(),
            scores: table::new<address, Table<u64, vector<u64>>>(),
            events,
        });
    }

    /// Create a new game.
    public entry fun register_game(publisher: &signer, title: String) acquires Sigil {
        let addr = signer::address_of(publisher);
        let sigil = borrow_global_mut<Sigil>(addr);

        let id = sigil.next_game_id;
        sigil.next_game_id = id + 1;

        // clone title for event payload
        let title_copy = string::utf8(*string::bytes(&title));

        let game = Game { id, title, creator: addr };
        table::add<u64, Game>(&mut sigil.games, id, game);

        event::emit_event<GameRegisteredEvent>(
            &mut sigil.events.game_registered,
            GameRegisteredEvent { id, creator: addr, title: title_copy }
        );
    }

    /// Publish a Player under the caller's address.
    public entry fun register_player(user: &signer, username: String) {
        let addr = signer::address_of(user);
        assert!(!exists<Player>(addr), E_PLAYER_EXISTS);
        move_to<Player>(user, Player { user: addr, username });
    }

    /// Submit a score to a publisher’s game. Requires the caller to be a registered Player.
    public entry fun submit_score(
        player: &signer,
        publisher: address,
        game_id: u64,
        score: u64
    ) acquires Sigil {
        let player_addr = signer::address_of(player);
        assert!(exists<Player>(player_addr), E_PLAYER_REQUIRED);

        let sigil = borrow_global_mut<Sigil>(publisher);
        if (!table::contains<u64, Game>(&sigil.games, game_id)) {
            abort E_GAME_NOT_FOUND;
        };

        // player -> inner table (game_id -> vector<u64>)
        let inner: &mut Table<u64, vector<u64>>;
        if (table::contains<address, Table<u64, vector<u64>>>(&sigil.scores, player_addr)) {
            inner = table::borrow_mut<address, Table<u64, vector<u64>>>(&mut sigil.scores, player_addr);
        } else {
            let new_inner = table::new<u64, vector<u64>>();
            table::add<address, Table<u64, vector<u64>>>(&mut sigil.scores, player_addr, new_inner);
            inner = table::borrow_mut<address, Table<u64, vector<u64>>>(&mut sigil.scores, player_addr);
        };

        // push score into per-game vector
        if (table::contains<u64, vector<u64>>(inner, game_id)) {
            let scores_vec = table::borrow_mut<u64, vector<u64>>(inner, game_id);
            vector::push_back<u64>(scores_vec, score);
        } else {
            let v = vector::empty<u64>();
            let v_mut = &mut v;
            vector::push_back<u64>(v_mut, score);
            table::add<u64, vector<u64>>(inner, game_id, v);
        };

        event::emit_event<ScoreSubmittedEvent>(
            &mut sigil.events.score_submitted,
            ScoreSubmittedEvent { publisher, player: player_addr, game_id, score }
        );
    }

    /*************
     *  Views
     *************/

    #[view]
    public fun game_count(owner: address): u64 acquires Sigil {
        borrow_global<Sigil>(owner).next_game_id
    }

    #[view]
    public fun has_game(owner: address, id: u64): bool acquires Sigil {
        let sigil = borrow_global<Sigil>(owner);
        table::contains<u64, Game>(&sigil.games, id)
    }

    #[view]
    public fun get_game(owner: address, id: u64): (u64, String, address) acquires Sigil {
        let s = borrow_global<Sigil>(owner);
        let g = table::borrow<u64, Game>(&s.games, id);
        let title_copy = string::utf8(*string::bytes(&g.title));
        (g.id, title_copy, g.creator)
    }

    #[view]
    /// Return a COPY of all scores a player has for a game.
    public fun get_scores(owner: address, player: address, game_id: u64): vector<u64> acquires Sigil {
        let s = borrow_global<Sigil>(owner);

        if (!table::contains<address, Table<u64, vector<u64>>>(&s.scores, player)) {
            return vector::empty<u64>()
        };

        let inner = table::borrow<address, Table<u64, vector<u64>>>(&s.scores, player);

        if (!table::contains<u64, vector<u64>>(inner, game_id)) {
            return vector::empty<u64>()
        };

        let src = table::borrow<u64, vector<u64>>(inner, game_id);
        let len = vector::length<u64>(src);
        let i = 0;
        let out = vector::empty<u64>();
        while (i < len) {
            vector::push_back<u64>(&mut out, *vector::borrow<u64>(src, i));
            i = i + 1;
        };
        out
    }

    #[view]
    /// Convenience: returns (exists, last_score, max_score)
    public fun score_summary(owner: address, player: address, game_id: u64): (bool, u64, u64) acquires Sigil {
        let s = borrow_global<Sigil>(owner);

        if (!table::contains<address, Table<u64, vector<u64>>>(&s.scores, player)) {
            return (false, 0, 0)
        };
        let inner = table::borrow<address, Table<u64, vector<u64>>>(&s.scores, player);

        if (!table::contains<u64, vector<u64>>(inner, game_id)) {
            return (false, 0, 0)
        };

        let src = table::borrow<u64, vector<u64>>(inner, game_id);
        let n = vector::length<u64>(src);
        if (n == 0) {
            return (true, 0, 0)
        };

        let last = *vector::borrow<u64>(src, n - 1);
        let maxv = last;
        let i = 0;
        while (i < n) {
            let v = *vector::borrow<u64>(src, i);
            if (v > maxv) { maxv = v };
            i = i + 1;
        };
        (true, last, maxv)
    }
}
