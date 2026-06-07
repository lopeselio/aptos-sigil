import { type Account, type AnyNumber, type InputGenerateTransactionOptions } from "@aptos-labs/ts-sdk";
import { SigilModule, normalizeAddress, type AddressInput } from "./base.js";

const M = "merge";

/** `merge`: item inventory + crafting recipes (combine inputs into outputs). */
export class MergeModule extends SigilModule {
  buildInit(args: { sender: Account; options?: InputGenerateTransactionOptions }) {
    return this.buildEntry({ ...args, module: M, func: "init_merge", functionArguments: [] });
  }

  /** @see {@link buildInit} */
  walletPayloadInit() {
    return this.payload(M, "init_merge", []);
  }

  /** @see {@link buildRegisterRecipe} */
  walletPayloadRegisterRecipe(args: {
    inputItemId: AnyNumber;
    inputQty: AnyNumber;
    outputItemId: AnyNumber;
    outputQty: AnyNumber;
    publisher?: AddressInput;
  }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.payload(M, "register_recipe", [
      publisher,
      BigInt(args.inputItemId as never),
      BigInt(args.inputQty as never),
      BigInt(args.outputItemId as never),
      BigInt(args.outputQty as never),
    ]);
  }

  /** @see {@link buildGrantItems} */
  walletPayloadGrantItems(args: { player: AddressInput; itemId: AnyNumber; qty: AnyNumber; publisher?: AddressInput }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.payload(M, "grant_items", [
      publisher,
      normalizeAddress(args.player),
      BigInt(args.itemId as never),
      BigInt(args.qty as never),
    ]);
  }

  /** Define a recipe: `inputQty` of `inputItemId` -> `outputQty` of `outputItemId`. */
  buildRegisterRecipe(args: {
    sender: Account;
    inputItemId: AnyNumber;
    inputQty: AnyNumber;
    outputItemId: AnyNumber;
    outputQty: AnyNumber;
    publisher?: AddressInput;
    options?: InputGenerateTransactionOptions;
  }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({
      ...args,
      module: M,
      func: "register_recipe",
      functionArguments: [publisher, args.inputItemId, args.inputQty, args.outputItemId, args.outputQty],
    });
  }

  /** Grant `qty` of `itemId` to a player (owner/operator). */
  buildGrantItems(args: { sender: Account; player: AddressInput; itemId: AnyNumber; qty: AnyNumber; publisher?: AddressInput; options?: InputGenerateTransactionOptions }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({ ...args, module: M, func: "grant_items", functionArguments: [publisher, normalizeAddress(args.player), args.itemId, args.qty] });
  }

  /** Player consumes recipe inputs to mint outputs. */
  buildExecuteMerge(args: { sender: Account; recipeId: AnyNumber; publisher?: AddressInput; options?: InputGenerateTransactionOptions }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({ ...args, module: M, func: "execute_merge", functionArguments: [publisher, args.recipeId] });
  }

  /** @see {@link buildExecuteMerge} */
  walletPayloadExecuteMerge(args: { recipeId: AnyNumber; publisher?: AddressInput }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.payload(M, "execute_merge", [publisher, BigInt(args.recipeId as never)]);
  }

  // ---- views ----

  viewIsInitialized(publisher: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "is_initialized", [normalizeAddress(publisher)]);
  }

  viewRecipeCount(publisher: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "recipe_count", [normalizeAddress(publisher)]);
  }

  viewItemQty(args: { player: AddressInput; itemId: AnyNumber; publisher?: AddressInput }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.viewCall(M, "get_item_qty", [publisher, normalizeAddress(args.player), args.itemId]);
  }

  /** `(exists, input_item, input_qty, output_item, output_qty)`. */
  viewRecipe(recipeId: AnyNumber, publisher: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "get_recipe", [normalizeAddress(publisher), recipeId]);
  }
}
