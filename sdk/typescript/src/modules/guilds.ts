import { type Account, type AnyNumber, type InputGenerateTransactionOptions } from "@aptos-labs/ts-sdk";
import { SigilModule, normalizeAddress, type AddressInput } from "./base.js";

const M = "guilds";

/** `guilds`: player groups under a publisher. */
export class GuildsModule extends SigilModule {
  buildInit(args: { sender: Account; options?: InputGenerateTransactionOptions }) {
    return this.buildEntry({ ...args, module: M, func: "init_guilds", functionArguments: [] });
  }

  /** Sender becomes the founder of the new guild. */
  buildCreateGuild(args: { sender: Account; name: string; publisher?: AddressInput; options?: InputGenerateTransactionOptions }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({ ...args, module: M, func: "create_guild", functionArguments: [publisher, args.name] });
  }

  buildJoinGuild(args: { sender: Account; guildId: AnyNumber; publisher?: AddressInput; options?: InputGenerateTransactionOptions }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({ ...args, module: M, func: "join_guild", functionArguments: [publisher, args.guildId] });
  }

  buildLeaveGuild(args: { sender: Account; publisher?: AddressInput; options?: InputGenerateTransactionOptions }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({ ...args, module: M, func: "leave_guild", functionArguments: [publisher] });
  }

  buildDisbandGuild(args: { sender: Account; guildId: AnyNumber; publisher?: AddressInput; options?: InputGenerateTransactionOptions }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({ ...args, module: M, func: "disband_guild", functionArguments: [publisher, args.guildId] });
  }

  // ---- views ----

  viewIsInitialized(publisher: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "is_initialized", [normalizeAddress(publisher)]);
  }

  viewGuildCount(publisher: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "guild_count", [normalizeAddress(publisher)]);
  }

  /** `(in_guild, guild_id)` for a player. */
  viewPlayerGuildId(args: { player: AddressInput; publisher?: AddressInput }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.viewCall(M, "player_guild_id", [publisher, normalizeAddress(args.player)]);
  }

  /** `(exists, name, founder, member_count)`. */
  viewGuild(guildId: AnyNumber, publisher: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "get_guild", [normalizeAddress(publisher), guildId]);
  }
}
