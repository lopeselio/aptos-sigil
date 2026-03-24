/// Guilds — lightweight on-chain teams per publisher.
///
/// MVP: one guild per player, fixed max size, string name, leader promotion on leave.
/// Does not move NFTs; use for social / matchmaking / season grouping.
module sigil::guilds {
    use std::signer;
    use std::string::{Self, String};
    use std::vector;
    use aptos_std::table::{Self, Table};
    use aptos_framework::account;
    use aptos_framework::event::{Self, EventHandle};
    use sigil::roles;

    const MAX_GUILD_MEMBERS: u64 = 100;

    const E_NOT_INITIALIZED: u64 = 0;
    const E_ALREADY_INITIALIZED: u64 = 1;
    const E_GUILD_NOT_FOUND: u64 = 2;
    const E_ALREADY_IN_GUILD: u64 = 3;
    const E_GUILD_FULL: u64 = 4;
    const E_NOT_IN_GUILD: u64 = 5;
    const E_NO_PERMISSION: u64 = 6;
    const E_NOT_MEMBER: u64 = 7;

    struct Guild has store, drop {
        id: u64,
        name: String,
        leader: address,
        members: vector<address>,
    }

    struct Guilds has key {
        publisher: address,
        next_guild_id: u64,
        guilds: Table<u64, Guild>,
        /// player (any) -> guild_id
        member_of: Table<address, u64>,
        events: GuildEvents,
    }

    struct GuildCreatedEvent has drop, store {
        publisher: address,
        guild_id: u64,
        leader: address,
    }

    struct GuildJoinedEvent has drop, store {
        publisher: address,
        guild_id: u64,
        player: address,
    }

    struct GuildLeftEvent has drop, store {
        publisher: address,
        guild_id: u64,
        player: address,
    }

    struct GuildEvents has store {
        created: EventHandle<GuildCreatedEvent>,
        joined: EventHandle<GuildJoinedEvent>,
        left: EventHandle<GuildLeftEvent>,
    }

    public entry fun init_guilds(publisher: &signer) {
        let addr = signer::address_of(publisher);
        assert!(!exists<Guilds>(addr), E_ALREADY_INITIALIZED);
        move_to(
            publisher,
            Guilds {
                publisher: addr,
                next_guild_id: 0,
                guilds: table::new(),
                member_of: table::new(),
                events: GuildEvents {
                    created: account::new_event_handle<GuildCreatedEvent>(publisher),
                    joined: account::new_event_handle<GuildJoinedEvent>(publisher),
                    left: account::new_event_handle<GuildLeftEvent>(publisher),
                },
            }
        );
    }

    /// Player creates a new guild (becomes leader).
    public entry fun create_guild(
        founder: &signer,
        publisher: address,
        name: String
    ) acquires Guilds {
        let founder_addr = signer::address_of(founder);
        assert!(exists<Guilds>(publisher), E_NOT_INITIALIZED);
        let regs = borrow_global_mut<Guilds>(publisher);
        assert!(!table::contains(&regs.member_of, founder_addr), E_ALREADY_IN_GUILD);

        let gid = regs.next_guild_id;
        regs.next_guild_id = gid + 1;

        let members = vector::empty<address>();
        vector::push_back(&mut members, founder_addr);

        let g = Guild { id: gid, name, leader: founder_addr, members };
        table::add(&mut regs.guilds, gid, g);
        table::add(&mut regs.member_of, founder_addr, gid);

        event::emit_event(
            &mut regs.events.created,
            GuildCreatedEvent { publisher, guild_id: gid, leader: founder_addr }
        );
    }

    public entry fun join_guild(
        player: &signer,
        publisher: address,
        guild_id: u64
    ) acquires Guilds {
        let player_addr = signer::address_of(player);
        assert!(exists<Guilds>(publisher), E_NOT_INITIALIZED);
        let regs = borrow_global_mut<Guilds>(publisher);
        assert!(!table::contains(&regs.member_of, player_addr), E_ALREADY_IN_GUILD);
        assert!(table::contains(&regs.guilds, guild_id), E_GUILD_NOT_FOUND);

        let g = table::borrow_mut(&mut regs.guilds, guild_id);
        assert!(
            (vector::length(&g.members) as u64) < MAX_GUILD_MEMBERS,
            E_GUILD_FULL
        );
        vector::push_back(&mut g.members, player_addr);
        table::add(&mut regs.member_of, player_addr, guild_id);

        event::emit_event(
            &mut regs.events.joined,
            GuildJoinedEvent { publisher, guild_id, player: player_addr }
        );
    }

    public entry fun leave_guild(player: &signer, publisher: address) acquires Guilds {
        let player_addr = signer::address_of(player);
        assert!(exists<Guilds>(publisher), E_NOT_INITIALIZED);
        let regs = borrow_global_mut<Guilds>(publisher);
        assert!(table::contains(&regs.member_of, player_addr), E_NOT_IN_GUILD);

        let guild_id = *table::borrow(&regs.member_of, player_addr);
        let g = table::borrow_mut(&mut regs.guilds, guild_id);

        assert!(vec_remove_address(&mut g.members, player_addr), E_NOT_MEMBER);
        table::remove(&mut regs.member_of, player_addr);

        let remaining = vector::length(&g.members);
        if (remaining == 0) {
            table::remove(&mut regs.guilds, guild_id);
        } else if (g.leader == player_addr) {
            g.leader = *vector::borrow(&g.members, 0);
        };

        event::emit_event(
            &mut regs.events.left,
            GuildLeftEvent { publisher, guild_id, player: player_addr }
        );
    }

    /// Publisher (or delegated role) removes a guild entirely.
    public entry fun disband_guild(
        actor: &signer,
        publisher: address,
        guild_id: u64
    ) acquires Guilds {
        let caller = signer::address_of(actor);
        assert!(exists<Guilds>(publisher), E_NOT_INITIALIZED);
        if (roles::is_initialized(publisher)) {
            assert!(roles::can_manage_achievements(publisher, caller), E_NO_PERMISSION);
        } else {
            assert!(caller == publisher, E_NO_PERMISSION);
        };

        let regs = borrow_global_mut<Guilds>(publisher);
        assert!(table::contains(&regs.guilds, guild_id), E_GUILD_NOT_FOUND);

        let g = table::remove(&mut regs.guilds, guild_id);
        let i = 0;
        let len = vector::length(&g.members);
        while (i < len) {
            let m = *vector::borrow(&g.members, i);
            if (table::contains(&regs.member_of, m)) {
                table::remove(&mut regs.member_of, m);
            };
            i = i + 1;
        };
    }

    fun vec_remove_address(v: &mut vector<address>, a: address): bool {
        let len = vector::length(v);
        let i = 0;
        while (i < len) {
            if (*vector::borrow(v, i) == a) {
                let last = vector::pop_back(v);
                if (i < vector::length(v)) {
                    *vector::borrow_mut(v, i) = last;
                };
                return true
            };
            i = i + 1;
        };
        false
    }

    #[view]
    public fun is_initialized(publisher: address): bool {
        exists<Guilds>(publisher)
    }

    #[view]
    public fun guild_count(publisher: address): u64 acquires Guilds {
        if (!exists<Guilds>(publisher)) return 0;
        borrow_global<Guilds>(publisher).next_guild_id
    }

    #[view]
    public fun player_guild_id(publisher: address, player: address): (bool, u64) acquires Guilds {
        if (!exists<Guilds>(publisher)) return (false, 0);
        let regs = borrow_global<Guilds>(publisher);
        if (!table::contains(&regs.member_of, player)) {
            return (false, 0)
        };
        (true, *table::borrow(&regs.member_of, player))
    }

    #[view]
    public fun get_guild(
        publisher: address,
        guild_id: u64
    ): (bool, String, address, u64) acquires Guilds {
        if (!exists<Guilds>(publisher)) return (false, string::utf8(b""), @0x0, 0);
        let regs = borrow_global<Guilds>(publisher);
        if (!table::contains(&regs.guilds, guild_id)) {
            return (false, string::utf8(b""), @0x0, 0)
        };
        let g = table::borrow(&regs.guilds, guild_id);
        (
            true,
            g.name,
            g.leader,
            vector::length(&g.members) as u64
        )
    }
}
