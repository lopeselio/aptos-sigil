import { AccountAddress, type Account, type AnyNumber, type InputGenerateTransactionOptions } from "@aptos-labs/ts-sdk";
import { SigilModule, normalizeAddress, type AddressInput } from "./base.js";
import { APTOS_COIN_METADATA_ADDRESS } from "../constants.js";

const M = "seasons";

/** `seasons`: time-boxed competitions with optional prize-pool distribution. */
export class SeasonsModule extends SigilModule {
  buildInit(args: { sender: Account; options?: InputGenerateTransactionOptions }) {
    return this.buildEntry({ ...args, module: M, func: "init_seasons", functionArguments: [] });
  }

  /** @see {@link buildInit} */
  walletPayloadInit() {
    return this.payload(M, "init_seasons", []);
  }

  /** @see {@link buildCreateSeason} */
  walletPayloadCreateSeason(args: {
    name: string;
    startTime: AnyNumber;
    endTime: AnyNumber;
    leaderboardId: AnyNumber;
    prizePool: AnyNumber;
    publisher?: AddressInput;
  }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.payload(M, "create_season", [
      publisher,
      args.name,
      BigInt(args.startTime as never),
      BigInt(args.endTime as never),
      BigInt(args.leaderboardId as never),
      BigInt(args.prizePool as never),
    ]);
  }

  /** @see {@link buildStartSeason} */
  walletPayloadStartSeason(args: { seasonId: AnyNumber; publisher?: AddressInput }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.payload(M, "start_season", [publisher, BigInt(args.seasonId as never)]);
  }

  /** @see {@link buildEndSeason} */
  walletPayloadEndSeason(args: { seasonId: AnyNumber; publisher?: AddressInput }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.payload(M, "end_season", [publisher, BigInt(args.seasonId as never)]);
  }

  /** @see {@link buildFinalizeSeason} */
  walletPayloadFinalizeSeason(args: { seasonId: AnyNumber; publisher?: AddressInput }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.payload(M, "finalize_season", [publisher, BigInt(args.seasonId as never)]);
  }

  buildCreateSeason(args: {
    sender: Account;
    name: string;
    startTime: AnyNumber;
    endTime: AnyNumber;
    leaderboardId: AnyNumber;
    prizePool: AnyNumber;
    publisher?: AddressInput;
    options?: InputGenerateTransactionOptions;
  }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({
      ...args,
      module: M,
      func: "create_season",
      functionArguments: [publisher, args.name, args.startTime, args.endTime, args.leaderboardId, args.prizePool],
    });
  }

  buildStartSeason(args: { sender: Account; seasonId: AnyNumber; publisher?: AddressInput; options?: InputGenerateTransactionOptions }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({ ...args, module: M, func: "start_season", functionArguments: [publisher, args.seasonId] });
  }

  buildEndSeason(args: { sender: Account; seasonId: AnyNumber; publisher?: AddressInput; options?: InputGenerateTransactionOptions }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({ ...args, module: M, func: "end_season", functionArguments: [publisher, args.seasonId] });
  }

  buildFinalizeSeason(args: { sender: Account; seasonId: AnyNumber; publisher?: AddressInput; options?: InputGenerateTransactionOptions }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({ ...args, module: M, func: "finalize_season", functionArguments: [publisher, args.seasonId] });
  }

  /**
   * Finalize + pay out the prize pool. Must be signed by the **publisher account**
   * (no operator delegation); requires `treasury` initialized and a
   * primary-store-enabled FA metadata object (defaults to native APT).
   */
  buildFinalizeSeasonAndDistribute(args: {
    sender: Account;
    seasonId: AnyNumber;
    maxPlacements: AnyNumber;
    faMetadataAddress?: AddressInput;
    publisher?: AddressInput;
    options?: InputGenerateTransactionOptions;
  }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    const meta = args.faMetadataAddress
      ? normalizeAddress(args.faMetadataAddress)
      : AccountAddress.from(APTOS_COIN_METADATA_ADDRESS);
    return this.buildEntry({
      ...args,
      module: M,
      func: "finalize_season_and_distribute_prizes",
      functionArguments: [publisher, args.seasonId, meta, args.maxPlacements],
    });
  }

  /** Submit a score that also counts toward the active season. */
  buildSubmitScoreSeasonal(args: { sender: Account; gameId: AnyNumber; score: AnyNumber; publisher?: AddressInput; options?: InputGenerateTransactionOptions }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({ ...args, module: M, func: "submit_score_seasonal", functionArguments: [publisher, args.gameId, args.score] });
  }

  buildAddSeasonAchievement(args: { sender: Account; seasonId: AnyNumber; achievementId: AnyNumber; publisher?: AddressInput; options?: InputGenerateTransactionOptions }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({ ...args, module: M, func: "add_season_achievement", functionArguments: [publisher, args.seasonId, args.achievementId] });
  }

  // ---- views ----

  viewIsInitialized(publisher: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "is_initialized", [normalizeAddress(publisher)]);
  }

  /** `(exists, season_id)` of the active season. */
  viewCurrentSeason(publisher: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "get_current_season", [normalizeAddress(publisher)]);
  }

  viewSeasonCount(publisher: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "get_season_count", [normalizeAddress(publisher)]);
  }

  /** `(exists, name, start, end, leaderboard_id, prize_pool, finalized)`. */
  viewSeason(seasonId: AnyNumber, publisher: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "get_season", [normalizeAddress(publisher), seasonId]);
  }

  /** `(started, ended, finalized)`. */
  viewSeasonStatus(seasonId: AnyNumber, publisher: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "get_season_status", [normalizeAddress(publisher), seasonId]);
  }

  /** `(exists, score)` for a player in a season/game. */
  viewSeasonScore(args: { seasonId: AnyNumber; gameId: AnyNumber; player: AddressInput; publisher?: AddressInput }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.viewCall(M, "get_season_score", [publisher, args.seasonId, args.gameId, normalizeAddress(args.player)]);
  }

  viewIsSeasonActive(seasonId: AnyNumber, publisher: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "is_season_active", [normalizeAddress(publisher), seasonId]);
  }
}
