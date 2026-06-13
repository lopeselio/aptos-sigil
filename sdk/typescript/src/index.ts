export {
  APTOS_COIN_METADATA_ADDRESS,
  createAptosClient,
  DEFAULT_SIGIL_TX_GAS,
  SigilClient,
  SIGIL_REWARDS_RESOURCE_SEED,
  type SigilClientOptions,
} from "./client.js";

// Shared module helpers/types
export {
  SigilModule,
  normalizeAddress,
  toBytes,
  type AddressInput,
  type SigilArgs,
  type SigilModuleContext,
  type WalletPayload,
} from "./modules/base.js";

// Sponsored (fee-payer) transactions — gasless gameplay
export {
  buildSponsoredTransaction,
  signSponsoredAsFeePayer,
  submitSponsored,
  serializeTransaction,
  deserializeTransaction,
  serializeAuthenticator,
  deserializeAuthenticator,
  sponsoredFunctionId,
  sponsorTransaction,
  requestSponsorship,
  type SponsorResponse,
} from "./sponsor.js";

// Per-module wrappers (also reachable via client.<module>)
export { AchievementsModule } from "./modules/achievements.js";
export { AttestModule } from "./modules/attest.js";
export { GamePlatformModule } from "./modules/gamePlatform.js";
export { GuildsModule } from "./modules/guilds.js";
export { LeaderboardModule } from "./modules/leaderboard.js";
export { MergeModule } from "./modules/merge.js";
export { QuestsModule } from "./modules/quests.js";
export { RewardsModule } from "./modules/rewards.js";
export { RolesModule } from "./modules/roles.js";
export { SeasonsModule } from "./modules/seasons.js";
export { ShadowSignersModule } from "./modules/shadowSigners.js";
export { TreasuryModule } from "./modules/treasury.js";
