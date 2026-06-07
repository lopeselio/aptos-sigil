import { type Account, type AnyNumber, type InputGenerateTransactionOptions } from "@aptos-labs/ts-sdk";
import { SigilModule, normalizeAddress, type AddressInput } from "./base.js";

const M = "quests";

/** `quests`: score/achievement/play-count/streak/rank objectives with reward hooks. */
export class QuestsModule extends SigilModule {
  buildInit(args: { sender: Account; options?: InputGenerateTransactionOptions }) {
    return this.buildEntry({ ...args, module: M, func: "init_quests", functionArguments: [] });
  }

  /** Reach `targetScore` on `gameId` (0 = any game). */
  buildCreateScoreQuest(args: {
    sender: Account;
    title: string;
    description: string;
    gameId: AnyNumber;
    targetScore: AnyNumber;
    rewardId: AnyNumber;
    isSeasonal: boolean;
    options?: InputGenerateTransactionOptions;
  }) {
    return this.buildEntry({
      ...args,
      module: M,
      func: "create_score_quest",
      functionArguments: [args.title, args.description, args.gameId, args.targetScore, args.rewardId, args.isSeasonal],
    });
  }

  /** Unlock `targetCount` achievements. */
  buildCreateAchievementQuest(args: {
    sender: Account;
    title: string;
    description: string;
    targetCount: AnyNumber;
    rewardId: AnyNumber;
    isSeasonal: boolean;
    options?: InputGenerateTransactionOptions;
  }) {
    return this.buildEntry({
      ...args,
      module: M,
      func: "create_achievement_quest",
      functionArguments: [args.title, args.description, args.targetCount, args.rewardId, args.isSeasonal],
    });
  }

  /** Play `targetPlays` times on `gameId` (0 = any game). */
  buildCreatePlayCountQuest(args: {
    sender: Account;
    title: string;
    description: string;
    gameId: AnyNumber;
    targetPlays: AnyNumber;
    rewardId: AnyNumber;
    isSeasonal: boolean;
    options?: InputGenerateTransactionOptions;
  }) {
    return this.buildEntry({
      ...args,
      module: M,
      func: "create_play_count_quest",
      functionArguments: [args.title, args.description, args.gameId, args.targetPlays, args.rewardId, args.isSeasonal],
    });
  }

  /** Maintain a `targetDays` play streak. */
  buildCreateStreakQuest(args: {
    sender: Account;
    title: string;
    description: string;
    targetDays: AnyNumber;
    rewardId: AnyNumber;
    isSeasonal: boolean;
    options?: InputGenerateTransactionOptions;
  }) {
    return this.buildEntry({
      ...args,
      module: M,
      func: "create_streak_quest",
      functionArguments: [args.title, args.description, args.targetDays, args.rewardId, args.isSeasonal],
    });
  }

  /** Reach `targetRank` on a leaderboard. */
  buildCreateRankQuest(args: {
    sender: Account;
    title: string;
    description: string;
    leaderboardId: AnyNumber;
    targetRank: AnyNumber;
    rewardId: AnyNumber;
    isSeasonal: boolean;
    options?: InputGenerateTransactionOptions;
  }) {
    return this.buildEntry({
      ...args,
      module: M,
      func: "create_rank_quest",
      functionArguments: [args.title, args.description, args.leaderboardId, args.targetRank, args.rewardId, args.isSeasonal],
    });
  }

  /** Player opts into a quest. */
  buildStartQuest(args: { sender: Account; questId: AnyNumber; publisher?: AddressInput; options?: InputGenerateTransactionOptions }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({ ...args, module: M, func: "start_quest", functionArguments: [publisher, args.questId] });
  }

  /** @see {@link buildStartQuest} */
  walletPayloadStartQuest(args: { questId: AnyNumber; publisher?: AddressInput }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.payload(M, "start_quest", [publisher, BigInt(args.questId as never)]);
  }

  /** Submit a score that also advances the player's active quests + achievements. */
  buildSubmitScoreWithQuest(args: { sender: Account; gameId: AnyNumber; score: AnyNumber; publisher?: AddressInput; options?: InputGenerateTransactionOptions }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({ ...args, module: M, func: "submit_score_with_quest", functionArguments: [publisher, args.gameId, args.score] });
  }

  buildUpdateQuestProgress(args: { sender: Account; questId: AnyNumber; publisher?: AddressInput; options?: InputGenerateTransactionOptions }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({ ...args, module: M, func: "update_quest_progress", functionArguments: [publisher, args.questId] });
  }

  // ---- views ----

  viewIsInitialized(publisher: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "is_initialized", [normalizeAddress(publisher)]);
  }

  viewQuestCount(publisher: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "get_quest_count", [normalizeAddress(publisher)]);
  }

  /** `(exists, title, description, quest_type, target, reward_id, is_seasonal)`. */
  viewQuest(questId: AnyNumber, publisher: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "get_quest", [normalizeAddress(publisher), questId]);
  }

  /** `(started, current, target, completed, claimed)`. */
  viewQuestProgress(args: { questId: AnyNumber; player: AddressInput; publisher?: AddressInput }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.viewCall(M, "get_quest_progress", [publisher, args.questId, normalizeAddress(args.player)]);
  }

  viewActiveQuests(args: { player: AddressInput; publisher?: AddressInput }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.viewCall(M, "get_active_quests", [publisher, normalizeAddress(args.player)]);
  }

  viewIsQuestAvailable(questId: AnyNumber, publisher: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "is_quest_available", [normalizeAddress(publisher), questId]);
  }
}
