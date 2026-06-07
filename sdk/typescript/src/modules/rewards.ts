import { AccountAddress, type Account, type AnyNumber, type InputGenerateTransactionOptions } from "@aptos-labs/ts-sdk";
import { SigilModule, normalizeAddress, toBytes, type AddressInput } from "./base.js";
import { APTOS_COIN_METADATA_ADDRESS } from "../constants.js";

const M = "rewards";

/** `rewards`: fungible-asset and NFT payouts attached to achievements. */
export class RewardsModule extends SigilModule {
  /** One-time `Rewards` resource (creates the resource account that holds inventory). */
  buildInit(args: { sender: Account; options?: InputGenerateTransactionOptions }) {
    return this.buildEntry({ ...args, module: M, func: "init_rewards", functionArguments: [] });
  }

  /** Create an NFT collection used by {@link buildAttachNftReward}. Strings encode to bytes. */
  buildCreateNftCollection(args: {
    sender: Account;
    name: string | Uint8Array;
    description: string | Uint8Array;
    uri: string | Uint8Array;
    publisher?: AddressInput;
    options?: InputGenerateTransactionOptions;
  }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({
      ...args,
      module: M,
      func: "create_nft_collection",
      functionArguments: [publisher, toBytes(args.name), toBytes(args.description), toBytes(args.uri)],
    });
  }

  /** Attach a fungible-asset reward to an achievement (defaults to native APT metadata). */
  buildAttachFaReward(args: {
    sender: Account;
    achievementId: AnyNumber;
    amount: AnyNumber;
    supply: AnyNumber;
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
      func: "attach_fa_reward",
      functionArguments: [publisher, args.achievementId, meta, args.amount, args.supply],
    });
  }

  /** Attach an NFT reward (mints from `collection` on claim). */
  buildAttachNftReward(args: {
    sender: Account;
    achievementId: AnyNumber;
    collection: AddressInput;
    name: string;
    description: string;
    uri: string;
    supply: AnyNumber;
    publisher?: AddressInput;
    options?: InputGenerateTransactionOptions;
  }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({
      ...args,
      module: M,
      func: "attach_nft_reward",
      functionArguments: [
        publisher,
        args.achievementId,
        normalizeAddress(args.collection),
        args.name,
        args.description,
        args.uri,
        args.supply,
      ],
    });
  }

  /** Player-signed reward claim (requires the achievement to be unlocked). */
  buildClaimReward(args: {
    sender: Account;
    achievementId: AnyNumber;
    publisher?: AddressInput;
    options?: InputGenerateTransactionOptions;
  }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({ ...args, module: M, func: "claim_reward", functionArguments: [publisher, args.achievementId] });
  }

  /** @see {@link buildClaimReward} */
  walletPayloadClaimReward(args: { achievementId: AnyNumber; publisher?: AddressInput }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.payload(M, "claim_reward", [publisher, BigInt(args.achievementId as never)]);
  }

  /** Testing-only claim that skips the unlock check. */
  buildClaimTesting(args: {
    sender: Account;
    achievementId: AnyNumber;
    publisher?: AddressInput;
    options?: InputGenerateTransactionOptions;
  }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({ ...args, module: M, func: "claim_testing", functionArguments: [publisher, args.achievementId] });
  }

  buildIncreaseSupply(args: { sender: Account; achievementId: AnyNumber; additional: AnyNumber; options?: InputGenerateTransactionOptions }) {
    return this.buildEntry({ ...args, module: M, func: "increase_supply", functionArguments: [args.achievementId, args.additional] });
  }

  buildRemoveReward(args: { sender: Account; achievementId: AnyNumber; options?: InputGenerateTransactionOptions }) {
    return this.buildEntry({ ...args, module: M, func: "remove_reward", functionArguments: [args.achievementId] });
  }

  // ---- views ----

  /** `(exists, is_nft, amount, supply, claimed)`. */
  viewReward(achievementId: AnyNumber, owner: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "get_reward", [normalizeAddress(owner), achievementId]);
  }

  /** Richer form: `(exists, is_nft, amount, name_bytes, supply, claimed)`. */
  viewRewardDetails(achievementId: AnyNumber, owner: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "get_reward_details", [normalizeAddress(owner), achievementId]);
  }

  /** `(exists, remaining)` claimable supply. */
  viewAvailable(achievementId: AnyNumber, owner: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "get_available", [normalizeAddress(owner), achievementId]);
  }

  viewIsClaimed(args: { player: AddressInput; achievementId: AnyNumber; owner?: AddressInput }) {
    const owner = args.owner ? normalizeAddress(args.owner) : this.moduleAddress;
    return this.viewCall(M, "is_claimed", [owner, normalizeAddress(args.player), args.achievementId]);
  }

  viewRewardedAchievements(owner: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "list_rewarded_achievements", [normalizeAddress(owner)]);
  }

  viewClaimedRewards(args: { player: AddressInput; owner?: AddressInput }) {
    const owner = args.owner ? normalizeAddress(args.owner) : this.moduleAddress;
    return this.viewCall(M, "get_claimed_rewards", [owner, normalizeAddress(args.player)]);
  }
}
