import { AccountAddress, type Account, type AnyNumber, type InputGenerateTransactionOptions } from "@aptos-labs/ts-sdk";
import { SigilModule, normalizeAddress, type AddressInput } from "./base.js";
import { APTOS_COIN_METADATA_ADDRESS } from "../constants.js";

const M = "treasury";

/** `treasury`: per-publisher fungible-asset vault (funds prize payouts). */
export class TreasuryModule extends SigilModule {
  buildInit(args: { sender: Account; options?: InputGenerateTransactionOptions }) {
    return this.buildEntry({ ...args, module: M, func: "init_treasury", functionArguments: [] });
  }

  /** @see {@link buildInit} */
  walletPayloadInit() {
    return this.payload(M, "init_treasury", []);
  }

  /** @see {@link buildDeposit} */
  walletPayloadDeposit(args: { amount: AnyNumber; faMetadataAddress?: AddressInput; publisher?: AddressInput }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    const meta = args.faMetadataAddress
      ? normalizeAddress(args.faMetadataAddress)
      : AccountAddress.from(APTOS_COIN_METADATA_ADDRESS);
    return this.payload(M, "deposit", [publisher, meta, BigInt(args.amount as never)]);
  }

  /** @see {@link buildWithdraw} */
  walletPayloadWithdraw(args: { recipient: AddressInput; amount: AnyNumber; faMetadataAddress?: AddressInput }) {
    const meta = args.faMetadataAddress
      ? normalizeAddress(args.faMetadataAddress)
      : AccountAddress.from(APTOS_COIN_METADATA_ADDRESS);
    return this.payload(M, "withdraw", [meta, normalizeAddress(args.recipient), BigInt(args.amount as never)]);
  }

  /** Deposit `amount` of an FA (defaults to native APT) into a publisher's treasury. */
  buildDeposit(args: {
    sender: Account;
    amount: AnyNumber;
    faMetadataAddress?: AddressInput;
    publisher?: AddressInput;
    options?: InputGenerateTransactionOptions;
  }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    const meta = args.faMetadataAddress ? normalizeAddress(args.faMetadataAddress) : AccountAddress.from(APTOS_COIN_METADATA_ADDRESS);
    return this.buildEntry({ ...args, module: M, func: "deposit", functionArguments: [publisher, meta, args.amount] });
  }

  /** Publisher-signed withdrawal to `recipient`. */
  buildWithdraw(args: {
    sender: Account;
    recipient: AddressInput;
    amount: AnyNumber;
    faMetadataAddress?: AddressInput;
    options?: InputGenerateTransactionOptions;
  }) {
    const meta = args.faMetadataAddress ? normalizeAddress(args.faMetadataAddress) : AccountAddress.from(APTOS_COIN_METADATA_ADDRESS);
    return this.buildEntry({ ...args, module: M, func: "withdraw", functionArguments: [meta, normalizeAddress(args.recipient), args.amount] });
  }

  // ---- views ----

  private meta(addr?: AddressInput): AccountAddress {
    return addr ? normalizeAddress(addr) : AccountAddress.from(APTOS_COIN_METADATA_ADDRESS);
  }

  viewIsInitialized(publisher: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "is_initialized", [normalizeAddress(publisher)]);
  }

  /** `(exists, balance)`. */
  viewBalance(args?: { publisher?: AddressInput; faMetadataAddress?: AddressInput }) {
    const publisher = args?.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.viewCall(M, "get_balance", [publisher, this.meta(args?.faMetadataAddress)]);
  }

  /** `(exists, balance, total_in, total_out)`. */
  viewStats(args?: { publisher?: AddressInput; faMetadataAddress?: AddressInput }) {
    const publisher = args?.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.viewCall(M, "get_stats", [publisher, this.meta(args?.faMetadataAddress)]);
  }

  viewCanWithdraw(args: { amount: AnyNumber; publisher?: AddressInput; faMetadataAddress?: AddressInput }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.viewCall(M, "can_withdraw", [publisher, this.meta(args.faMetadataAddress), args.amount]);
  }
}
