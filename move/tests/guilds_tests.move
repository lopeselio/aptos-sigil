#[test_only]
module sigil::guilds_tests {
    use std::signer;
    use std::string;
    use aptos_framework::account;
    use sigil::guilds;

    fun setup(): (signer, signer, signer) {
        let publisher = account::create_account_for_test(@0x123);
        let p1 = account::create_account_for_test(@0x456);
        let p2 = account::create_account_for_test(@0x789);
        (publisher, p1, p2)
    }

    #[test]
    fun test_init_guilds() {
        let (publisher, _, _) = setup();
        let addr = signer::address_of(&publisher);
        guilds::init_guilds(&publisher);
        assert!(guilds::is_initialized(addr), 0);
        assert!(guilds::guild_count(addr) == 0, 1);
    }

    #[test]
    #[expected_failure(abort_code = 1, location = sigil::guilds)]
    fun test_init_twice_fails() {
        let (publisher, _, _) = setup();
        guilds::init_guilds(&publisher);
        guilds::init_guilds(&publisher);
    }

    #[test]
    fun test_create_join_leave() {
        let (publisher, p1, p2) = setup();
        let pub_addr = signer::address_of(&publisher);
        let a1 = signer::address_of(&p1);
        let _a2 = signer::address_of(&p2);

        guilds::init_guilds(&publisher);
        guilds::create_guild(&p1, pub_addr, string::utf8(b"Raiders"));

        let (ok, name, leader, n) = guilds::get_guild(pub_addr, 0);
        assert!(ok, 0);
        assert!(name == string::utf8(b"Raiders"), 1);
        assert!(leader == a1, 2);
        assert!(n == 1, 3);

        let (in_g, gid) = guilds::player_guild_id(pub_addr, a1);
        assert!(in_g && gid == 0, 4);

        guilds::join_guild(&p2, pub_addr, 0);
        let (_, _, _, n2) = guilds::get_guild(pub_addr, 0);
        assert!(n2 == 2, 5);

        guilds::leave_guild(&p2, pub_addr);
        let (_, _, _, n3) = guilds::get_guild(pub_addr, 0);
        assert!(n3 == 1, 6);
    }

    #[test]
    fun test_leader_leave_promotes() {
        let (publisher, p1, p2) = setup();
        let pub_addr = signer::address_of(&publisher);
        let _a1 = signer::address_of(&p1);
        let a2 = signer::address_of(&p2);

        guilds::init_guilds(&publisher);
        guilds::create_guild(&p1, pub_addr, string::utf8(b"G"));
        guilds::join_guild(&p2, pub_addr, 0);

        guilds::leave_guild(&p1, pub_addr);
        let (_, _, leader, n) = guilds::get_guild(pub_addr, 0);
        assert!(n == 1, 0);
        assert!(leader == a2, 1);
    }

    #[test]
    fun test_disband_guild() {
        let (publisher, p1, p2) = setup();
        let pub_addr = signer::address_of(&publisher);
        let a1 = signer::address_of(&p1);

        guilds::init_guilds(&publisher);
        guilds::create_guild(&p1, pub_addr, string::utf8(b"X"));
        guilds::join_guild(&p2, pub_addr, 0);

        guilds::disband_guild(&publisher, pub_addr, 0);
        let (ok, _, _, _) = guilds::get_guild(pub_addr, 0);
        assert!(!ok, 0);
        let (in_g, _) = guilds::player_guild_id(pub_addr, a1);
        assert!(!in_g, 1);
    }
}
