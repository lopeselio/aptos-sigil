import { type Account, type AnyNumber, type InputGenerateTransactionOptions } from "@aptos-labs/ts-sdk";
import { SigilModule, normalizeAddress, type AddressInput } from "./base.js";

const M = "game_platform";

/** `game_platform` (sigil_core): games, players, scores. */
export class GamePlatformModule extends SigilModule {
  /** One-time publisher initializer (`Sigil` resource under the sender). */
  buildInit(args: { sender: Account; options?: InputGenerateTransactionOptions }) {
    return this.buildEntry({ ...args, module: M, func: "init", functionArguments: [] });
  }

  /** Create a game under the sender (publisher). */
  buildRegisterGame(args: { sender: Account; title: string; options?: InputGenerateTransactionOptions }) {
    return this.buildEntry({ ...args, module: M, func: "register_game", functionArguments: [args.title] });
  }

  /**
   * Optional: set/update the sender's display username. NOT required before a
   * score — {@link buildSubmitScore} / {@link walletPayloadSubmitScore} register
   * the player on first submit.
   */
  buildRegisterPlayer(args: { sender: Account; username: string; options?: InputGenerateTransactionOptions }) {
    return this.buildEntry({ ...args, module: M, func: "register_player", functionArguments: [args.username] });
  }

  /** @see {@link buildRegisterPlayer} */
  walletPayloadRegisterPlayer(username: string) {
    return this.payload(M, "register_player", [username]);
  }

  /**
   * Player-signed score with a display `username` (primary client entrypoint).
   * Registers the player on first submit and refreshes the username (one funded
   * tx — no separate register step). A blank `username` never overwrites a name.
   */
  buildSubmitScore(args: {
    sender: Account;
    gameId: AnyNumber;
    score: AnyNumber;
    username: string;
    publisher?: AddressInput;
    options?: InputGenerateTransactionOptions;
  }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({
      ...args,
      module: M,
      func: "submit_score_named",
      functionArguments: [publisher, args.gameId, args.score, args.username],
    });
  }

  /** @see {@link buildSubmitScore} */
  walletPayloadSubmitScore(args: { gameId: AnyNumber; score: AnyNumber; username: string; publisher?: AddressInput }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.payload(M, "submit_score_named", [publisher, BigInt(args.gameId as never), BigInt(args.score as never), args.username]);
  }

  /** Score without setting a username (auto-registers a blank-name player). */
  buildSubmitScoreAnon(args: {
    sender: Account;
    gameId: AnyNumber;
    score: AnyNumber;
    publisher?: AddressInput;
    options?: InputGenerateTransactionOptions;
  }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({
      ...args,
      module: M,
      func: "submit_score",
      functionArguments: [publisher, args.gameId, args.score],
    });
  }

  /** Score with a server attestation (anti-cheat). `signature` is the ed25519 sig bytes. */
  buildSubmitScoreAttested(args: {
    sender: Account;
    gameId: AnyNumber;
    score: AnyNumber;
    timestampSigned: AnyNumber;
    nonce: AnyNumber;
    signature: Uint8Array;
    publisher?: AddressInput;
    options?: InputGenerateTransactionOptions;
  }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({
      ...args,
      module: M,
      func: "submit_score_attested",
      functionArguments: [publisher, args.gameId, args.score, args.timestampSigned, args.nonce, args.signature],
    });
  }

  // ---- views ----

  /** Number of games registered by `owner` (defaults to publisher). */
  viewGameCount(owner: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "game_count", [normalizeAddress(owner)]);
  }

  viewHasGame(gameId: AnyNumber, owner: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "has_game", [normalizeAddress(owner), gameId]);
  }

  /** Returns `(id, title, creator)`. */
  viewGame(gameId: AnyNumber, owner: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "get_game", [normalizeAddress(owner), gameId]);
  }

  /** All scores `submit_score` stored for `(player, game_id)` under this publisher. */
  viewPlayerGameScores(args: { player: AddressInput; gameId: AnyNumber; owner?: AddressInput }) {
    const owner = args.owner ? normalizeAddress(args.owner) : this.moduleAddress;
    return this.viewCall(M, "get_scores", [owner, normalizeAddress(args.player), args.gameId]);
  }

  /** Convenience: `(exists, last_score, max_score)`. */
  viewScoreSummary(args: { player: AddressInput; gameId: AnyNumber; owner?: AddressInput }) {
    const owner = args.owner ? normalizeAddress(args.owner) : this.moduleAddress;
    return this.viewCall(M, "score_summary", [owner, normalizeAddress(args.player), args.gameId]);
  }

  /**
   * Whether a `game_platform::Player` exists under this address (i.e. they have
   * submitted at least once / set a username). NOT a prerequisite for submitting.
   */
  async isPlayerRegistered(player: AddressInput): Promise<boolean> {
    const addr = normalizeAddress(player);
    const resourceType = `${this.moduleAddress}::game_platform::Player` as `${string}::${string}::${string}`;
    try {
      await this.aptos.getAccountResource({ accountAddress: addr, resourceType });
      return true;
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      if (/resource not found|404/i.test(msg)) return false;
      throw e;
    }
  }
}
