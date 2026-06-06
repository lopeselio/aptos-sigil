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

/** Matches `aptos move run --max-gas 200000 --gas-unit-price 100` for `build.simple` defaults. */
export const DEFAULT_SIGIL_TX_GAS: InputGenerateTransactionOptions = {
  maxGasAmount: 200_000,
  gasUnitPrice: 100,
};

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
      options: { ...DEFAULT_SIGIL_TX_GAS, ...args.options } as InputGenerateTransactionOptions,
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
      options: { ...DEFAULT_SIGIL_TX_GAS, ...args.options } as InputGenerateTransactionOptions,
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
      options: { ...DEFAULT_SIGIL_TX_GAS, ...args.options } as InputGenerateTransactionOptions,
    });
  }

  /**
   * Optional: set/update the sender's `game_platform::Player` username.
   * NOT required before {@link buildSubmitScore} — `submit_score` auto-registers
   * the player on first submit. Call this only to set a display username.
   */
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
      options: { ...DEFAULT_SIGIL_TX_GAS, ...args.options } as InputGenerateTransactionOptions,
    });
  }

  /**
   * Player-signed score for a publisher’s game with a display `username`.
   * Registers the player on-chain on first submit (one funded tx — no separate
   * `register_player` needed) and keeps the username current. Pass a non-empty
   * `username`; an empty string leaves any existing name untouched.
   */
  buildSubmitScore(args: {
    sender: Account;
    gameId: AnyNumber;
    score: AnyNumber;
    username: string;
    options?: InputGenerateTransactionOptions;
  }) {
    return this.aptos.transaction.build.simple({
      sender: args.sender.accountAddress,
      data: {
        function: this.fid("game_platform", "submit_score_named"),
        functionArguments: [this.moduleAddress, args.gameId, args.score, args.username],
      },
      options: { ...DEFAULT_SIGIL_TX_GAS, ...args.options } as InputGenerateTransactionOptions,
    });
  }

  /**
   * Payload for `useWallet().signAndSubmitTransaction` / Petra (sender = connected account).
   * Matches `@aptos-labs/wallet-adapter-react` `InputTransactionData` shape.
   *
   * Uses hex `address` strings and `bigint` `u64`s so every wallet encodes the same BCS as the CLI.
   */
  walletPayloadRegisterPlayer(username: string) {
    return {
      data: {
        function: this.fid("game_platform", "register_player"),
        typeArguments: [],
        functionArguments: [username],
      },
    };
  }

  /** @see {@link walletPayloadRegisterPlayer} */
  walletPayloadSubmitScore(args: { gameId: AnyNumber; score: AnyNumber; username: string }) {
    const gid = BigInt(args.gameId as bigint | number | string);
    const sc = BigInt(args.score as bigint | number | string);
    const publisher = this.moduleAddress.toString();
    return {
      data: {
        function: this.fid("game_platform", "submit_score_named"),
        typeArguments: [],
        functionArguments: [publisher, gid, sc, args.username],
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

  /** All scores `submit_score` stored for `(player, game_id)` under this publisher (`Sigil.scores`). */
  async viewPlayerGameScores(args: { player: AddressInput; gameId: AnyNumber }) {
    const player = normalizeAddress(args.player);
    return this.aptos.view({
      payload: {
        function: this.fid("game_platform", "get_scores"),
        functionArguments: [this.moduleAddress, player, args.gameId],
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

  /** Top-N for the leaderboard bound to this `game_id` (after `create_leaderboard` for that game). */
  async viewTopEntriesForGame(gameId: AnyNumber) {
    return this.aptos.view({
      payload: {
        function: this.fid("leaderboard", "get_top_entries_for_game"),
        functionArguments: [this.moduleAddress, gameId],
      },
    });
  }

  /**
   * Whether `game_platform::Player` exists under this address (i.e. the player
   * has set a username). NOT a prerequisite for `submit_score` — that
   * auto-registers. Use this only to decide whether to prompt for a username.
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
