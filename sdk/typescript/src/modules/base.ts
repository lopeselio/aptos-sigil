import {
  AccountAddress,
  type Account,
  type AnyNumber,
  type Aptos as AptosInstance,
  type EntryFunctionArgumentTypes,
  type InputGenerateTransactionOptions,
  type SimpleEntryFunctionArgumentTypes,
} from "@aptos-labs/ts-sdk";
import { DEFAULT_SIGIL_TX_GAS } from "../constants.js";

/** Accepted address inputs across the SDK. */
export type AddressInput = AccountAddress | string;

export function normalizeAddress(a: AddressInput): AccountAddress {
  return a instanceof AccountAddress ? a : AccountAddress.from(a);
}

/** Encode a Move `vector<u8>` argument from a string (UTF-8) or raw bytes. */
export function toBytes(v: Uint8Array | string): Uint8Array {
  return typeof v === "string" ? new TextEncoder().encode(v) : v;
}

/** Entry/view argument list accepted by the Aptos TS SDK. */
export type SigilArgs = Array<EntryFunctionArgumentTypes | SimpleEntryFunctionArgumentTypes>;

/** Shared context a {@link SigilModule} needs from the owning {@link SigilClient}. */
export interface SigilModuleContext {
  readonly aptos: AptosInstance;
  readonly moduleAddress: AccountAddress;
  fid(module: string, func: string): `${string}::${string}::${string}`;
}

/** A wallet-adapter `InputTransactionData`-shaped payload (hex address + bigint u64s). */
export type WalletPayload = {
  data: {
    function: `${string}::${string}::${string}`;
    typeArguments: [];
    functionArguments: SigilArgs;
  };
};

/**
 * Base class for per-module SDK wrappers. Centralizes transaction building,
 * wallet-payload construction, and view calls so each module method is one line.
 */
export abstract class SigilModule {
  constructor(protected readonly ctx: SigilModuleContext) {}

  protected get aptos(): AptosInstance {
    return this.ctx.aptos;
  }

  /** Published package address (`[addresses].sigil`); also the default publisher. */
  protected get moduleAddress(): AccountAddress {
    return this.ctx.moduleAddress;
  }

  /** Build a signable transaction for an entry function (sender provides the `&signer`). */
  protected buildEntry(args: {
    sender: Account;
    module: string;
    func: string;
    functionArguments: SigilArgs;
    options?: InputGenerateTransactionOptions;
  }) {
    return this.aptos.transaction.build.simple({
      sender: args.sender.accountAddress,
      data: {
        function: this.ctx.fid(args.module, args.func),
        functionArguments: args.functionArguments,
      },
      options: { ...DEFAULT_SIGIL_TX_GAS, ...args.options } as InputGenerateTransactionOptions,
    });
  }

  /** Build a wallet-adapter payload (`useWallet().signAndSubmitTransaction`). */
  protected payload(module: string, func: string, functionArguments: SigilArgs): WalletPayload {
    return {
      data: {
        function: this.ctx.fid(module, func),
        typeArguments: [],
        functionArguments,
      },
    };
  }

  /** Call a `#[view]` function. */
  protected viewCall(module: string, func: string, functionArguments: SigilArgs) {
    return this.aptos.view({
      payload: {
        function: this.ctx.fid(module, func),
        functionArguments,
      },
    });
  }
}

export type { Account, AnyNumber, InputGenerateTransactionOptions };
