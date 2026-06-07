import {
  AccountAddress,
  type Aptos as AptosInstance,
  createResourceAddress,
} from "@aptos-labs/ts-sdk";
import { SIGIL_REWARDS_RESOURCE_SEED } from "./constants.js";
import type { SigilModuleContext } from "./modules/base.js";
import { AchievementsModule } from "./modules/achievements.js";
import { AttestModule } from "./modules/attest.js";
import { GamePlatformModule } from "./modules/gamePlatform.js";
import { GuildsModule } from "./modules/guilds.js";
import { LeaderboardModule } from "./modules/leaderboard.js";
import { MergeModule } from "./modules/merge.js";
import { QuestsModule } from "./modules/quests.js";
import { RewardsModule } from "./modules/rewards.js";
import { RolesModule } from "./modules/roles.js";
import { SeasonsModule } from "./modules/seasons.js";
import { ShadowSignersModule } from "./modules/shadowSigners.js";
import { TreasuryModule } from "./modules/treasury.js";

// Re-export shared constants/helpers so existing `import … from "./client.js"` keeps working.
export {
  APTOS_COIN_METADATA_ADDRESS,
  createAptosClient,
  DEFAULT_SIGIL_TX_GAS,
  SIGIL_REWARDS_RESOURCE_SEED,
} from "./constants.js";

export type SigilClientOptions = {
  aptos: AptosInstance;
  /** Published package address (`[addresses].sigil` / module publisher). */
  moduleAddress: AccountAddress;
};

/**
 * Sigil SDK entrypoint. Contract functions are grouped by Move module and
 * reached through namespaced accessors, e.g.:
 *
 * ```ts
 * client.gamePlatform.buildSubmitScore({ sender, gameId: 0, score: 100, username: "p1" });
 * await client.leaderboard.viewTopEntriesForGame(0);
 * client.rewards.buildClaimReward({ sender, achievementId: 1 });
 * ```
 *
 * Transaction building is explicit so any signer works (CLI keyfile, wallet
 * adapter, KMS). Most methods default `publisher`/`owner` to {@link moduleAddress}.
 */
export class SigilClient implements SigilModuleContext {
  readonly aptos: AptosInstance;
  readonly moduleAddress: AccountAddress;

  readonly gamePlatform: GamePlatformModule;
  readonly leaderboard: LeaderboardModule;
  readonly rewards: RewardsModule;
  readonly achievements: AchievementsModule;
  readonly quests: QuestsModule;
  readonly seasons: SeasonsModule;
  readonly guilds: GuildsModule;
  readonly merge: MergeModule;
  readonly treasury: TreasuryModule;
  readonly roles: RolesModule;
  readonly attest: AttestModule;
  readonly shadowSigners: ShadowSignersModule;

  constructor(opts: SigilClientOptions) {
    this.aptos = opts.aptos;
    this.moduleAddress = opts.moduleAddress;

    this.gamePlatform = new GamePlatformModule(this);
    this.leaderboard = new LeaderboardModule(this);
    this.rewards = new RewardsModule(this);
    this.achievements = new AchievementsModule(this);
    this.quests = new QuestsModule(this);
    this.seasons = new SeasonsModule(this);
    this.guilds = new GuildsModule(this);
    this.merge = new MergeModule(this);
    this.treasury = new TreasuryModule(this);
    this.roles = new RolesModule(this);
    this.attest = new AttestModule(this);
    this.shadowSigners = new ShadowSignersModule(this);
  }

  fid(module: string, func: string): `${string}::${string}::${string}` {
    return `${this.moduleAddress}::${module}::${func}`;
  }

  /** Address that holds FA/NFT inventory for `rewards` (fund this account’s APT primary store for FA payouts). */
  rewardsPoolAddress(): AccountAddress {
    return createResourceAddress(this.moduleAddress, SIGIL_REWARDS_RESOURCE_SEED);
  }
}
