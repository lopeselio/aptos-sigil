import { type Account, type AnyNumber, type InputGenerateTransactionOptions } from "@aptos-labs/ts-sdk";
import { SigilModule, normalizeAddress, toBytes, type AddressInput } from "./base.js";

const M = "achievements";

type Bytes = string | Uint8Array;

/** `achievements`: unlockable badges driven by scores/counts. Text args encode to `vector<u8>`. */
export class AchievementsModule extends SigilModule {
  buildInit(args: { sender: Account; options?: InputGenerateTransactionOptions }) {
    return this.buildEntry({ ...args, module: M, func: "init_achievements", functionArguments: [] });
  }

  /** Basic score achievement. `badgeUri` empty = no badge. */
  buildCreate(args: {
    sender: Account;
    title: Bytes;
    description: Bytes;
    minScore: AnyNumber;
    badgeUri?: Bytes;
    publisher?: AddressInput;
    options?: InputGenerateTransactionOptions;
  }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({
      ...args,
      module: M,
      func: "create",
      functionArguments: [publisher, toBytes(args.title), toBytes(args.description), args.minScore, toBytes(args.badgeUri ?? "")],
    });
  }

  /** Score achievement scoped to a specific `gameId`. */
  buildCreateWithGame(args: {
    sender: Account;
    title: Bytes;
    description: Bytes;
    gameId: AnyNumber;
    minScore: AnyNumber;
    badgeUri?: Bytes;
    publisher?: AddressInput;
    options?: InputGenerateTransactionOptions;
  }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({
      ...args,
      module: M,
      func: "create_with_game",
      functionArguments: [publisher, toBytes(args.title), toBytes(args.description), args.gameId, args.minScore, toBytes(args.badgeUri ?? "")],
    });
  }

  /** Advanced: score + repeat-count + min-submissions thresholds. */
  buildCreateAdvanced(args: {
    sender: Account;
    title: Bytes;
    description: Bytes;
    minScore: AnyNumber;
    requiredCount: AnyNumber;
    minSubmissions: AnyNumber;
    badgeUri?: Bytes;
    publisher?: AddressInput;
    options?: InputGenerateTransactionOptions;
  }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({
      ...args,
      module: M,
      func: "create_advanced",
      functionArguments: [
        publisher,
        toBytes(args.title),
        toBytes(args.description),
        args.minScore,
        args.requiredCount,
        args.minSubmissions,
        toBytes(args.badgeUri ?? ""),
      ],
    });
  }

  /** Advanced achievement scoped to a specific `gameId`. */
  buildCreateWithGameAdvanced(args: {
    sender: Account;
    title: Bytes;
    description: Bytes;
    gameId: AnyNumber;
    minScore: AnyNumber;
    requiredCount: AnyNumber;
    minSubmissions: AnyNumber;
    badgeUri?: Bytes;
    publisher?: AddressInput;
    options?: InputGenerateTransactionOptions;
  }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({
      ...args,
      module: M,
      func: "create_with_game_advanced",
      functionArguments: [
        publisher,
        toBytes(args.title),
        toBytes(args.description),
        args.gameId,
        args.minScore,
        args.requiredCount,
        args.minSubmissions,
        toBytes(args.badgeUri ?? ""),
      ],
    });
  }

  /** Manually grant an achievement to a player (owner/operator). */
  buildGrant(args: { sender: Account; player: AddressInput; achievementId: AnyNumber; publisher?: AddressInput; options?: InputGenerateTransactionOptions }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({ ...args, module: M, func: "grant", functionArguments: [publisher, normalizeAddress(args.player), args.achievementId] });
  }

  /** Drive achievement progress from an off-chain/server score (no Player needed). */
  buildSubmitScoreDirect(args: { sender: Account; player: AddressInput; gameId: AnyNumber; score: AnyNumber; publisher?: AddressInput; options?: InputGenerateTransactionOptions }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({ ...args, module: M, func: "submit_score_direct", functionArguments: [publisher, normalizeAddress(args.player), args.gameId, args.score] });
  }

  // ---- views ----

  viewAchievementCount(owner: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "achievement_count", [normalizeAddress(owner)]);
  }

  /** `(ids[], titles[], descriptions[], min_scores[], game_ids[])`. */
  viewCatalog(owner: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "list_catalog", [normalizeAddress(owner)]);
  }

  viewUnlockedFor(args: { player: AddressInput; owner?: AddressInput }) {
    const owner = args.owner ? normalizeAddress(args.owner) : this.moduleAddress;
    return this.viewCall(M, "unlocked_for", [owner, normalizeAddress(args.player)]);
  }

  /** `(id, title, description, min_score, game_id?, badge_uri?)`. */
  viewAchievement(achievementId: AnyNumber, owner: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "get_achievement", [normalizeAddress(owner), achievementId]);
  }

  viewIsUnlocked(args: { player: AddressInput; achievementId: AnyNumber; owner?: AddressInput }) {
    const owner = args.owner ? normalizeAddress(args.owner) : this.moduleAddress;
    return this.viewCall(M, "is_unlocked", [owner, normalizeAddress(args.player), args.achievementId]);
  }

  /** `(current, required, unlocked)`. */
  viewProgress(args: { player: AddressInput; achievementId: AnyNumber; owner?: AddressInput }) {
    const owner = args.owner ? normalizeAddress(args.owner) : this.moduleAddress;
    return this.viewCall(M, "get_progress", [owner, normalizeAddress(args.player), args.achievementId]);
  }
}
