import {
  AccountAddress,
  type Account,
  type AnyNumber,
  type Aptos,
  createResourceAddress,
  type InputGenerateTransactionOptions,
} from "@aptos-labs/ts-sdk";

/** Seed passed to `account::create_resource_account(publisher, b"rewards_v1")` in `rewards::init_rewards`. */
export const SIGIL_REWARDS_RESOURCE_SEED = "rewards_v1" as const;

/** Native APT fungible metadata object (matches CLI `address:0xa` for treasury / FA rewards on devnet). */
export const APTOS_COIN_METADATA_ADDRESS =
  "0x000000000000000000000000000000000000000000000000000000000000000a" as const;

export type SigilClientOptions = {
  aptos: Aptos;
  /** Published package address (`[addresses].sigil` / module publisher). */
  moduleAddress: AccountAddress;
};

/**
 * Thin wrapper for Sigil entry functions and common views.
 * Transaction building is explicit so you can integrate any signer (CLI keyfile, wallet adapter, KMS).
 */
export class SigilClient {
  readonly aptos: Aptos;
  readonly moduleAddress: AccountAddress;

  constructor(opts: SigilClientOptions) {
    this.aptos = opts.aptos;
    this.moduleAddress = opts.moduleAddress;
  }

  private fid(module: string, func: string): `${string}::${string}::${string}` {
    return `${this.moduleAddress}::${module}::${func}`;
  }

  /** Address that holds FA/NFT inventory for `rewards` (fund this account’s APT primary store for FA payouts). */
  rewardsPoolAddress(): AccountAddress {
    return createResourceAddress(this.moduleAddress, SIGIL_REWARDS_RESOURCE_SEED);
  }

  buildAttachFaReward(args: {
    sender: Account;
    achievementId: AnyNumber;
    faMetadataAddress?: AccountAddress;
    amount: AnyNumber;
    supply: AnyNumber;
    options?: InputGenerateTransactionOptions;
  }) {
    const meta = args.faMetadataAddress ?? AccountAddress.from(APTOS_COIN_METADATA_ADDRESS);
    return this.aptos.transaction.build.simple({
      sender: args.sender.accountAddress,
      data: {
        function: this.fid("rewards", "attach_fa_reward"),
        functionArguments: [this.moduleAddress, args.achievementId, meta, args.amount, args.supply],
      },
      options: args.options,
    });
  }

  buildClaimTesting(args: {
    sender: Account;
    achievementId: AnyNumber;
    options?: InputGenerateTransactionOptions;
  }) {
    return this.aptos.transaction.build.simple({
      sender: args.sender.accountAddress,
      data: {
        function: this.fid("rewards", "claim_testing"),
        functionArguments: [this.moduleAddress, args.achievementId],
      },
      options: args.options,
    });
  }

  /** Scopes are UTF-8 byte vectors on-chain (e.g. `"submit_score"`). */
  buildCreateSession(args: {
    sender: Account;
    shadowPublicKey: Uint8Array;
    scopes: string[];
    ttlSecs: AnyNumber;
    options?: InputGenerateTransactionOptions;
  }) {
    const scopeBytes = args.scopes.map((s) => new TextEncoder().encode(s));
    return this.aptos.transaction.build.simple({
      sender: args.sender.accountAddress,
      data: {
        function: this.fid("shadow_signers", "create_session"),
        functionArguments: [args.shadowPublicKey, scopeBytes, args.ttlSecs],
      },
      options: args.options,
    });
  }

  async viewReward(achievementId: AnyNumber) {
    return this.aptos.view({
      payload: {
        function: this.fid("rewards", "get_reward"),
        functionArguments: [this.moduleAddress, achievementId],
      },
    });
  }

  async viewSessionValid(authority: AddressInput, shadowPublicKey: Uint8Array) {
    const auth = normalizeAddress(authority);
    return this.aptos.view({
      payload: {
        function: this.fid("shadow_signers", "is_session_valid"),
        functionArguments: [auth, shadowPublicKey],
      },
    });
  }

  async viewSessionScopes(authority: AddressInput, shadowPublicKey: Uint8Array) {
    const auth = normalizeAddress(authority);
    return this.aptos.view({
      payload: {
        function: this.fid("shadow_signers", "get_session_scopes"),
        functionArguments: [auth, shadowPublicKey],
      },
    });
  }
}

type AddressInput = AccountAddress | string;

function normalizeAddress(a: AddressInput): AccountAddress {
  return a instanceof AccountAddress ? a : AccountAddress.from(a);
}
