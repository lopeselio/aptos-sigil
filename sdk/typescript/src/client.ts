import {
  AccountAddress,
  Aptos,
  AptosConfig,
  type Account,
  type AnyNumber,
  type Aptos as AptosInstance,
  createResourceAddress,
  type InputGenerateTransactionOptions,
  Network,
} from "@aptos-labs/ts-sdk";

/** Seed passed to `account::create_resource_account(publisher, b"rewards_v1")` in `rewards::init_rewards`. */
export const SIGIL_REWARDS_RESOURCE_SEED = "rewards_v1" as const;

/** Native APT fungible metadata object (matches CLI `address:0xa` for treasury / FA rewards on devnet). */
export const APTOS_COIN_METADATA_ADDRESS =
  "0x000000000000000000000000000000000000000000000000000000000000000a" as const;

/**
 * Builds an {@link Aptos} client with optional fullnode URL and API key.
 * Keys are sent as `Authorization: Bearer …` (see [Geomi](https://geomi.dev/docs/api-reference) / Aptos Labs node access).
 */
export function createAptosClient(options: {
  network: Network;
  /** REST base URL, e.g. `https://api.devnet.aptoslabs.com/v1` */
  fullnode?: string | null;
  /** Higher rate limits on Aptos Labs / Geomi gateways; prefer a **frontend** key in browser apps. */
  apiKey?: string | null;
}): AptosInstance {
  const fullnode = options.fullnode?.trim() || undefined;
  const apiKey = options.apiKey?.trim() || undefined;
  return new Aptos(
    new AptosConfig({
      network: options.network,
      ...(fullnode ? { fullnode } : {}),
      ...(apiKey ? { clientConfig: { API_KEY: apiKey } } : {}),
    }),
  );
}

export type SigilClientOptions = {
  aptos: AptosInstance;
  /** Published package address (`[addresses].sigil` / module publisher). */
  moduleAddress: AccountAddress;
};

/**
 * Thin wrapper for Sigil entry functions and common views.
 * Transaction building is explicit so you can integrate any signer (CLI keyfile, wallet adapter, KMS).
 */
export class SigilClient {
  readonly aptos: AptosInstance;
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

  /** Publishes `game_platform::Player` under the sender (one-time per address). */
  buildRegisterPlayer(args: {
    sender: Account;
    username: string;
    options?: InputGenerateTransactionOptions;
  }) {
    return this.aptos.transaction.build.simple({
      sender: args.sender.accountAddress,
      data: {
        function: this.fid("game_platform", "register_player"),
        functionArguments: [args.username],
      },
      options: args.options,
    });
  }

  /** Player-signed score for a publisher’s game (requires `register_player` first). */
  buildSubmitScore(args: {
    sender: Account;
    gameId: AnyNumber;
    score: AnyNumber;
    options?: InputGenerateTransactionOptions;
  }) {
    return this.aptos.transaction.build.simple({
      sender: args.sender.accountAddress,
      data: {
        function: this.fid("game_platform", "submit_score"),
        functionArguments: [this.moduleAddress, args.gameId, args.score],
      },
      options: args.options,
    });
  }

  /**
   * Payload for `useWallet().signAndSubmitTransaction` / Petra (sender = connected account).
   * Matches `@aptos-labs/wallet-adapter-react` `InputTransactionData` shape.
   */
  walletPayloadRegisterPlayer(username: string) {
    return {
      data: {
        function: this.fid("game_platform", "register_player"),
        functionArguments: [username],
      },
    };
  }

  /** @see {@link walletPayloadRegisterPlayer} */
  walletPayloadSubmitScore(args: { gameId: AnyNumber; score: AnyNumber }) {
    const gid = BigInt(args.gameId as bigint | number | string);
    const sc = BigInt(args.score as bigint | number | string);
    // Wallets often encode `u64` more reliably as JS numbers when values are small.
    const u64Arg = (n: bigint) =>
      n <= BigInt(Number.MAX_SAFE_INTEGER) ? Number(n) : n;
    return {
      data: {
        function: this.fid("game_platform", "submit_score"),
        functionArguments: [this.moduleAddress, u64Arg(gid), u64Arg(sc)],
      },
    };
  }

  async viewGameCount() {
    return this.aptos.view({
      payload: {
        function: this.fid("game_platform", "game_count"),
        functionArguments: [this.moduleAddress],
      },
    });
  }

  async viewHasGame(gameId: AnyNumber) {
    return this.aptos.view({
      payload: {
        function: this.fid("game_platform", "has_game"),
        functionArguments: [this.moduleAddress, gameId],
      },
    });
  }

  async viewLeaderboardCount() {
    return this.aptos.view({
      payload: {
        function: this.fid("leaderboard", "get_leaderboard_count"),
        functionArguments: [this.moduleAddress],
      },
    });
  }

  async viewTopEntries(leaderboardId: AnyNumber) {
    return this.aptos.view({
      payload: {
        function: this.fid("leaderboard", "get_top_entries"),
        functionArguments: [this.moduleAddress, leaderboardId],
      },
    });
  }

  /**
   * Whether `game_platform::Player` exists under this address (same check as `submit_score` on-chain).
   * Uses the indexer/fullnode resource API — no extra Move view required.
   */
  async isPlayerRegistered(player: AddressInput): Promise<boolean> {
    const addr = normalizeAddress(player);
    const resourceType =
      `${this.moduleAddress}::game_platform::Player` as `${string}::${string}::${string}`;
    try {
      await this.aptos.getAccountResource({
        accountAddress: addr,
        resourceType,
      });
      return true;
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      if (/resource not found|404/i.test(msg)) return false;
      throw e;
    }
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
