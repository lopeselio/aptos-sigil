#[test_only]
module sigil::roles_tests {
    use std::signer;
    use aptos_framework::account;
    use sigil::roles;

    // Test accounts
    fun setup_test_accounts(): (signer, signer, signer, signer) {
        let publisher = account::create_account_for_test(@0xCAFE);
        let admin = account::create_account_for_test(@0xABCD);
        let operator = account::create_account_for_test(@0x1234);
        let random_user = account::create_account_for_test(@0x9999);
        (publisher, admin, operator, random_user)
    }

    /************
     * Init Tests
     ************/

    #[test]
    fun test_init_roles() {
        let (publisher, _, _, _) = setup_test_accounts();
        let pub_addr = signer::address_of(&publisher);
        
        roles::init_roles(&publisher);
        
        assert!(roles::is_initialized(pub_addr), 0);
        assert!(roles::get_owner(pub_addr) == pub_addr, 1);
        assert!(roles::is_owner(pub_addr, pub_addr), 2);
    }

    #[test]
    #[expected_failure(abort_code = 0, location = sigil::roles)] // E_ALREADY_INIT
    fun test_init_roles_twice_fails() {
        let (publisher, _, _, _) = setup_test_accounts();
        
        roles::init_roles(&publisher);
        roles::init_roles(&publisher); // Should fail
    }

    /************
     * Admin Management Tests
     ************/

    #[test]
    fun test_add_admin() {
        let (publisher, admin, _, _) = setup_test_accounts();
        let pub_addr = signer::address_of(&publisher);
        let admin_addr = signer::address_of(&admin);
        
        roles::init_roles(&publisher);
        roles::add_admin(&publisher, pub_addr, admin_addr);
        
        assert!(roles::is_admin(pub_addr, admin_addr), 0);
        assert!(roles::is_authorized(pub_addr, admin_addr), 1);
        assert!(roles::can_manage_achievements(pub_addr, admin_addr), 2);
        assert!(roles::can_manage_rewards(pub_addr, admin_addr), 3);
        assert!(roles::can_manage_treasury(pub_addr, admin_addr), 4);
        assert!(roles::can_manage_roles(pub_addr, admin_addr), 5);
    }

    #[test]
    #[expected_failure(abort_code = 2, location = sigil::roles)] // E_NOT_OWNER
    fun test_add_admin_not_owner_fails() {
        let (publisher, admin, operator, _) = setup_test_accounts();
        let pub_addr = signer::address_of(&publisher);
        let admin_addr = signer::address_of(&admin);
        let op_addr = signer::address_of(&operator);
        
        roles::init_roles(&publisher);
        roles::add_admin(&admin, pub_addr, op_addr); // Admin tries to add another admin (should fail)
    }

    #[test]
    #[expected_failure(abort_code = 5, location = sigil::roles)] // E_ALREADY_HAS_ROLE
    fun test_add_admin_twice_fails() {
        let (publisher, admin, _, _) = setup_test_accounts();
        let pub_addr = signer::address_of(&publisher);
        let admin_addr = signer::address_of(&admin);
        
        roles::init_roles(&publisher);
        roles::add_admin(&publisher, pub_addr, admin_addr);
        roles::add_admin(&publisher, pub_addr, admin_addr); // Should fail
    }

    #[test]
    #[expected_failure(abort_code = 7, location = sigil::roles)] // E_CANNOT_MODIFY_OWNER
    fun test_add_admin_owner_fails() {
        let (publisher, _, _, _) = setup_test_accounts();
        let pub_addr = signer::address_of(&publisher);
        
        roles::init_roles(&publisher);
        roles::add_admin(&publisher, pub_addr, pub_addr); // Cannot modify owner (should fail)
    }

    #[test]
    fun test_remove_admin() {
        let (publisher, admin, _, _) = setup_test_accounts();
        let pub_addr = signer::address_of(&publisher);
        let admin_addr = signer::address_of(&admin);
        
        roles::init_roles(&publisher);
        roles::add_admin(&publisher, pub_addr, admin_addr);
        assert!(roles::is_admin(pub_addr, admin_addr), 0);
        
        roles::remove_admin(&publisher, pub_addr, admin_addr);
        assert!(!roles::is_admin(pub_addr, admin_addr), 1);
        assert!(!roles::is_authorized(pub_addr, admin_addr), 2);
    }

    #[test]
    #[expected_failure(abort_code = 6, location = sigil::roles)] // E_DOES_NOT_HAVE_ROLE
    fun test_remove_admin_not_admin_fails() {
        let (publisher, admin, _, _) = setup_test_accounts();
        let pub_addr = signer::address_of(&publisher);
        let admin_addr = signer::address_of(&admin);
        
        roles::init_roles(&publisher);
        roles::remove_admin(&publisher, pub_addr, admin_addr); // Not admin (should fail)
    }

    /************
     * Operator Management Tests
     ************/

    #[test]
    fun test_add_operator() {
        let (publisher, _, operator, _) = setup_test_accounts();
        let pub_addr = signer::address_of(&publisher);
        let op_addr = signer::address_of(&operator);
        
        roles::init_roles(&publisher);
        roles::add_operator(&publisher, pub_addr, op_addr);
        
        assert!(roles::is_operator(pub_addr, op_addr), 0);
        assert!(roles::is_authorized(pub_addr, op_addr), 1);
        assert!(roles::can_manage_achievements(pub_addr, op_addr), 2);
        assert!(roles::can_manage_rewards(pub_addr, op_addr), 3);
        assert!(roles::can_manage_leaderboards(pub_addr, op_addr), 4);
        // Operator cannot manage treasury
        assert!(!roles::can_manage_treasury(pub_addr, op_addr), 5);
        assert!(!roles::can_manage_roles(pub_addr, op_addr), 6);
    }

    #[test]
    fun test_admin_can_add_operator() {
        let (publisher, admin, operator, _) = setup_test_accounts();
        let pub_addr = signer::address_of(&publisher);
        let admin_addr = signer::address_of(&admin);
        let op_addr = signer::address_of(&operator);
        
        roles::init_roles(&publisher);
        roles::add_admin(&publisher, pub_addr, admin_addr);
        roles::add_operator(&admin, pub_addr, op_addr); // Admin adds operator
        
        assert!(roles::is_operator(pub_addr, op_addr), 0);
    }

    #[test]
    #[expected_failure(abort_code = 3, location = sigil::roles)] // E_NOT_ADMIN
    fun test_operator_cannot_add_operator() {
        let (publisher, _, operator, random) = setup_test_accounts();
        let pub_addr = signer::address_of(&publisher);
        let op_addr = signer::address_of(&operator);
        let random_addr = signer::address_of(&random);
        
        roles::init_roles(&publisher);
        roles::add_operator(&publisher, pub_addr, op_addr);
        roles::add_operator(&operator, pub_addr, random_addr); // Operator tries to add another (should fail)
    }

    #[test]
    #[expected_failure(abort_code = 5, location = sigil::roles)] // E_ALREADY_HAS_ROLE
    fun test_add_operator_twice_fails() {
        let (publisher, _, operator, _) = setup_test_accounts();
        let pub_addr = signer::address_of(&publisher);
        let op_addr = signer::address_of(&operator);
        
        roles::init_roles(&publisher);
        roles::add_operator(&publisher, pub_addr, op_addr);
        roles::add_operator(&publisher, pub_addr, op_addr); // Should fail
    }

    #[test]
    fun test_remove_operator() {
        let (publisher, _, operator, _) = setup_test_accounts();
        let pub_addr = signer::address_of(&publisher);
        let op_addr = signer::address_of(&operator);
        
        roles::init_roles(&publisher);
        roles::add_operator(&publisher, pub_addr, op_addr);
        assert!(roles::is_operator(pub_addr, op_addr), 0);
        
        roles::remove_operator(&publisher, pub_addr, op_addr);
        assert!(!roles::is_operator(pub_addr, op_addr), 1);
        assert!(!roles::is_authorized(pub_addr, op_addr), 2);
    }

    #[test]
    fun test_admin_can_remove_operator() {
        let (publisher, admin, operator, _) = setup_test_accounts();
        let pub_addr = signer::address_of(&publisher);
        let admin_addr = signer::address_of(&admin);
        let op_addr = signer::address_of(&operator);
        
        roles::init_roles(&publisher);
        roles::add_admin(&publisher, pub_addr, admin_addr);
        roles::add_operator(&publisher, pub_addr, op_addr);
        
        roles::remove_operator(&admin, pub_addr, op_addr); // Admin removes operator
        assert!(!roles::is_operator(pub_addr, op_addr), 0);
    }

    /************
     * Multiple Roles Tests
     ************/

    #[test]
    fun test_user_can_be_both_admin_and_operator() {
        let (publisher, admin, _, _) = setup_test_accounts();
        let pub_addr = signer::address_of(&publisher);
        let admin_addr = signer::address_of(&admin);
        
        roles::init_roles(&publisher);
        roles::add_admin(&publisher, pub_addr, admin_addr);
        roles::add_operator(&publisher, pub_addr, admin_addr);
        
        assert!(roles::is_admin(pub_addr, admin_addr), 0);
        assert!(roles::is_operator(pub_addr, admin_addr), 1);
        assert!(roles::can_manage_treasury(pub_addr, admin_addr), 2); // Admin perk
        assert!(roles::can_manage_achievements(pub_addr, admin_addr), 3); // Operator perk
    }

    #[test]
    fun test_remove_admin_keeps_operator() {
        let (publisher, admin, _, _) = setup_test_accounts();
        let pub_addr = signer::address_of(&publisher);
        let admin_addr = signer::address_of(&admin);
        
        roles::init_roles(&publisher);
        roles::add_admin(&publisher, pub_addr, admin_addr);
        roles::add_operator(&publisher, pub_addr, admin_addr);
        
        roles::remove_admin(&publisher, pub_addr, admin_addr);
        
        assert!(!roles::is_admin(pub_addr, admin_addr), 0);
        assert!(roles::is_operator(pub_addr, admin_addr), 1); // Operator role retained
        assert!(!roles::can_manage_treasury(pub_addr, admin_addr), 2); // Lost admin perk
        assert!(roles::can_manage_achievements(pub_addr, admin_addr), 3); // Kept operator perk
    }

    #[test]
    fun test_remove_operator_keeps_admin() {
        let (publisher, admin, _, _) = setup_test_accounts();
        let pub_addr = signer::address_of(&publisher);
        let admin_addr = signer::address_of(&admin);
        
        roles::init_roles(&publisher);
        roles::add_admin(&publisher, pub_addr, admin_addr);
        roles::add_operator(&publisher, pub_addr, admin_addr);
        
        roles::remove_operator(&publisher, pub_addr, admin_addr);
        
        assert!(roles::is_admin(pub_addr, admin_addr), 0); // Admin role retained
        assert!(!roles::is_operator(pub_addr, admin_addr), 1);
        assert!(roles::can_manage_treasury(pub_addr, admin_addr), 2); // Kept admin perk
    }

    /************
     * View Function Tests
     ************/

    #[test]
    fun test_get_role() {
        let (publisher, admin, operator, random) = setup_test_accounts();
        let pub_addr = signer::address_of(&publisher);
        let admin_addr = signer::address_of(&admin);
        let op_addr = signer::address_of(&operator);
        let random_addr = signer::address_of(&random);
        
        roles::init_roles(&publisher);
        roles::add_admin(&publisher, pub_addr, admin_addr);
        roles::add_operator(&publisher, pub_addr, op_addr);
        
        // Owner has all permissions (returns 3 = ADMIN | OPERATOR)
        assert!(roles::get_role(pub_addr, pub_addr) == 3, 0);
        // Admin has admin flag (1)
        assert!(roles::get_role(pub_addr, admin_addr) == 1, 1);
        // Operator has operator flag (2)
        assert!(roles::get_role(pub_addr, op_addr) == 2, 2);
        // Random user has no role (0)
        assert!(roles::get_role(pub_addr, random_addr) == 0, 3);
    }

    #[test]
    fun test_get_role_summary() {
        let (publisher, admin, operator, random) = setup_test_accounts();
        let pub_addr = signer::address_of(&publisher);
        let admin_addr = signer::address_of(&admin);
        let op_addr = signer::address_of(&operator);
        let random_addr = signer::address_of(&random);
        
        roles::init_roles(&publisher);
        roles::add_admin(&publisher, pub_addr, admin_addr);
        roles::add_operator(&publisher, pub_addr, op_addr);
        
        // Owner
        let (is_owner, is_admin, is_operator) = roles::get_role_summary(pub_addr, pub_addr);
        assert!(is_owner && is_admin && is_operator, 0);
        
        // Admin
        let (is_owner, is_admin, is_operator) = roles::get_role_summary(pub_addr, admin_addr);
        assert!(!is_owner && is_admin && !is_operator, 1);
        
        // Operator
        let (is_owner, is_admin, is_operator) = roles::get_role_summary(pub_addr, op_addr);
        assert!(!is_owner && !is_admin && is_operator, 2);
        
        // Random
        let (is_owner, is_admin, is_operator) = roles::get_role_summary(pub_addr, random_addr);
        assert!(!is_owner && !is_admin && !is_operator, 3);
    }

    #[test]
    fun test_unauthorized_user() {
        let (publisher, _, _, random) = setup_test_accounts();
        let pub_addr = signer::address_of(&publisher);
        let random_addr = signer::address_of(&random);
        
        roles::init_roles(&publisher);
        
        assert!(!roles::is_owner(pub_addr, random_addr), 0);
        assert!(!roles::is_admin(pub_addr, random_addr), 1);
        assert!(!roles::is_operator(pub_addr, random_addr), 2);
        assert!(!roles::is_authorized(pub_addr, random_addr), 3);
        assert!(!roles::can_manage_achievements(pub_addr, random_addr), 4);
        assert!(!roles::can_manage_rewards(pub_addr, random_addr), 5);
        assert!(!roles::can_manage_leaderboards(pub_addr, random_addr), 6);
        assert!(!roles::can_manage_treasury(pub_addr, random_addr), 7);
        assert!(!roles::can_manage_roles(pub_addr, random_addr), 8);
    }

    /************
     * Edge Cases
     ************/

    #[test]
    fun test_owner_always_authorized() {
        let (publisher, _, _, _) = setup_test_accounts();
        let pub_addr = signer::address_of(&publisher);
        
        roles::init_roles(&publisher);
        
        // Owner always has all permissions without explicit role assignment
        assert!(roles::is_owner(pub_addr, pub_addr), 0);
        assert!(roles::is_authorized(pub_addr, pub_addr), 1);
        assert!(roles::can_manage_achievements(pub_addr, pub_addr), 2);
        assert!(roles::can_manage_rewards(pub_addr, pub_addr), 3);
        assert!(roles::can_manage_leaderboards(pub_addr, pub_addr), 4);
        assert!(roles::can_manage_treasury(pub_addr, pub_addr), 5);
        assert!(roles::can_manage_roles(pub_addr, pub_addr), 6);
    }

    #[test]
    fun test_roles_not_initialized() {
        let random = account::create_account_for_test(@0x9999);
        let random_addr = signer::address_of(&random);
        
        // All checks should return false for uninitialized publisher
        assert!(!roles::is_initialized(random_addr), 0);
        assert!(!roles::is_owner(random_addr, random_addr), 1);
        assert!(!roles::is_admin(random_addr, random_addr), 2);
        assert!(!roles::is_operator(random_addr, random_addr), 3);
        assert!(!roles::is_authorized(random_addr, random_addr), 4);
        assert!(roles::get_role(random_addr, random_addr) == 0, 5);
    }

    #[test]
    fun test_multiple_publishers_independent() {
        let pub1 = account::create_account_for_test(@0xAAA);
        let pub2 = account::create_account_for_test(@0xBBB);
        let admin = account::create_account_for_test(@0xCCC);
        
        let pub1_addr = signer::address_of(&pub1);
        let pub2_addr = signer::address_of(&pub2);
        let admin_addr = signer::address_of(&admin);
        
        roles::init_roles(&pub1);
        roles::init_roles(&pub2);
        
        roles::add_admin(&pub1, pub1_addr, admin_addr);
        
        // Admin is admin for pub1 but not pub2
        assert!(roles::is_admin(pub1_addr, admin_addr), 0);
        assert!(!roles::is_admin(pub2_addr, admin_addr), 1);
        
        // Each publisher has their own owner
        assert!(roles::is_owner(pub1_addr, pub1_addr), 2);
        assert!(roles::is_owner(pub2_addr, pub2_addr), 3);
        assert!(!roles::is_owner(pub1_addr, pub2_addr), 4);
        assert!(!roles::is_owner(pub2_addr, pub1_addr), 5);
    }
}

