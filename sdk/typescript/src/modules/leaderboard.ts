import { type Account, type AnyNumber, type InputGenerateTransactionOptions } from "@aptos-labs/ts-sdk";
import { SigilModule, normalizeAddress, type AddressInput } from "./base.js";

const M = "leaderboard";

/** `leaderboard`: per-game ranked top-N boards. */
export class LeaderboardModule extends SigilModule {
  /** One-time `Leaderboards` resource under the sender (publisher). */
  buildInit(args: { sender: Account; options?: InputGenerateTransactionOptions }) {
    return this.buildEntry({ ...args, module: M, func: "init_leaderboards", functionArguments: [] });
  }

  /** @see {@link buildInit} */
  walletPayloadInit() {
    return this.payload(M, "init_leaderboards", []);
  }

  /** @see {@link buildCreateLeaderboard} */
  walletPayloadCreateLeaderboard(args: {
    gameId: AnyNumber;
    decimals: AnyNumber;
    minScore: AnyNumber;
    maxScore: AnyNumber;
    isAscending: boolean;
    allowMultiple: boolean;
    scoresToRetain: AnyNumber;
    publisher?: AddressInput;
  }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.payload(M, "create_leaderboard", [
      publisher,
      BigInt(args.gameId as never),
      // `decimals` is a Move u8 — the ts-sdk argument checker rejects BigInt for
      // u8 client-side (only number|string allowed below u64). Pass a Number.
      Number(args.decimals as never),
      BigInt(args.minScore as never),
      BigInt(args.maxScore as never),
      args.isAscending,
      args.allowMultiple,
      BigInt(args.scoresToRetain as never),
    ]);
  }

  /**
   * Create a board bound to `gameId`. `submit_score` then updates it automatically.
   * `actor` may be the owner or a roles-authorized operator; `publisher` owns the resource.
   */
  buildCreateLeaderboard(args: {
    sender: Account;
    gameId: AnyNumber;
    decimals: AnyNumber;
    minScore: AnyNumber;
    maxScore: AnyNumber;
    isAscending: boolean;
    allowMultiple: boolean;
    scoresToRetain: AnyNumber;
    publisher?: AddressInput;
    options?: InputGenerateTransactionOptions;
  }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({
      ...args,
      module: M,
      func: "create_leaderboard",
      functionArguments: [
        publisher,
        args.gameId,
        args.decimals,
        args.minScore,
        args.maxScore,
        args.isAscending,
        args.allowMultiple,
        args.scoresToRetain,
      ],
    });
  }

  /** Push a score directly to a board by leaderboard id (admin/testing path). */
  buildSubmitScoreDirect(args: {
    sender: Account;
    leaderboardId: AnyNumber;
    player: AddressInput;
    score: AnyNumber;
    publisher?: AddressInput;
    options?: InputGenerateTransactionOptions;
  }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({
      ...args,
      module: M,
      func: "submit_score_direct",
      functionArguments: [publisher, args.leaderboardId, normalizeAddress(args.player), args.score],
    });
  }

  // ---- views ----

  viewLeaderboardCount(owner: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "get_leaderboard_count", [normalizeAddress(owner)]);
  }

  /** `(game_id, decimals, min, max, is_ascending, allow_multiple, scores_to_retain)`. */
  viewLeaderboardConfig(leaderboardId: AnyNumber, owner: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "get_leaderboard_config", [normalizeAddress(owner), leaderboardId]);
  }

  /** `(addresses[], scores[])` ranked top-N for a sequential leaderboard id. */
  viewTopEntries(leaderboardId: AnyNumber, owner: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "get_top_entries", [normalizeAddress(owner), leaderboardId]);
  }

  /** Top-N for the board bound to `gameId`. */
  viewTopEntriesForGame(gameId: AnyNumber, owner: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "get_top_entries_for_game", [normalizeAddress(owner), gameId]);
  }

  viewHasLeaderboardForGame(gameId: AnyNumber, owner: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "has_leaderboard_for_game", [normalizeAddress(owner), gameId]);
  }

  viewLeaderboardIdForGame(gameId: AnyNumber, owner: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "get_leaderboard_id_for_game", [normalizeAddress(owner), gameId]);
  }
}
