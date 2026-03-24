#[test_only]
module sigil::merge_tests {
    use std::signer;
    use aptos_framework::account;
    use sigil::merge;

    fun setup(): (signer, signer) {
        let publisher = account::create_account_for_test(@0x123);
        let player = account::create_account_for_test(@0x456);
        (publisher, player)
    }

    #[test]
    fun test_init_merge() {
        let (publisher, _) = setup();
        let addr = signer::address_of(&publisher);
        merge::init_merge(&publisher);
        assert!(merge::is_initialized(addr), 0);
        assert!(merge::recipe_count(addr) == 0, 1);
    }

    #[test]
    #[expected_failure(abort_code = 1, location = sigil::merge)]
    fun test_init_merge_twice_fails() {
        let (publisher, _) = setup();
        merge::init_merge(&publisher);
        merge::init_merge(&publisher);
    }

    #[test]
    fun test_recipe_and_execute() {
        let (publisher, player) = setup();
        let pub_addr = signer::address_of(&publisher);
        let player_addr = signer::address_of(&player);

        merge::init_merge(&publisher);
        merge::register_recipe(&publisher, pub_addr, 1, 3, 2, 1);
        assert!(merge::recipe_count(pub_addr) == 1, 0);

        merge::grant_items(&publisher, pub_addr, player_addr, 1, 10);
        assert!(merge::get_item_qty(pub_addr, player_addr, 1) == 10, 1);

        merge::execute_merge(&player, pub_addr, 0);
        assert!(merge::get_item_qty(pub_addr, player_addr, 1) == 7, 2);
        assert!(merge::get_item_qty(pub_addr, player_addr, 2) == 1, 3);
    }

    #[test]
    #[expected_failure(abort_code = 3, location = sigil::merge)]
    fun test_execute_merge_insufficient_fails() {
        let (publisher, player) = setup();
        let pub_addr = signer::address_of(&publisher);

        merge::init_merge(&publisher);
        merge::register_recipe(&publisher, pub_addr, 5, 2, 6, 1);
        merge::grant_items(&publisher, pub_addr, signer::address_of(&player), 5, 1);
        merge::execute_merge(&player, pub_addr, 0);
    }
}
