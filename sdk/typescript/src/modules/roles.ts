import { type Account, type InputGenerateTransactionOptions } from "@aptos-labs/ts-sdk";
import { SigilModule, normalizeAddress, type AddressInput } from "./base.js";

const M = "roles";

/** `roles`: owner / admin / operator access control for delegated administration. */
export class RolesModule extends SigilModule {
  buildInit(args: { sender: Account; options?: InputGenerateTransactionOptions }) {
    return this.buildEntry({ ...args, module: M, func: "init_roles", functionArguments: [] });
  }

  buildAddAdmin(args: { sender: Account; admin: AddressInput; publisher?: AddressInput; options?: InputGenerateTransactionOptions }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({ ...args, module: M, func: "add_admin", functionArguments: [publisher, normalizeAddress(args.admin)] });
  }

  buildRemoveAdmin(args: { sender: Account; admin: AddressInput; publisher?: AddressInput; options?: InputGenerateTransactionOptions }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({ ...args, module: M, func: "remove_admin", functionArguments: [publisher, normalizeAddress(args.admin)] });
  }

  buildAddOperator(args: { sender: Account; operator: AddressInput; publisher?: AddressInput; options?: InputGenerateTransactionOptions }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({ ...args, module: M, func: "add_operator", functionArguments: [publisher, normalizeAddress(args.operator)] });
  }

  buildRemoveOperator(args: { sender: Account; operator: AddressInput; publisher?: AddressInput; options?: InputGenerateTransactionOptions }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.buildEntry({ ...args, module: M, func: "remove_operator", functionArguments: [publisher, normalizeAddress(args.operator)] });
  }

  // ---- views ----

  viewIsInitialized(publisher: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "is_initialized", [normalizeAddress(publisher)]);
  }

  viewOwner(publisher: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "get_owner", [normalizeAddress(publisher)]);
  }

  /** Numeric role code for `addr` (0 none / 1 operator / 2 admin / 3 owner — see module). */
  viewRole(args: { addr: AddressInput; publisher?: AddressInput }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.viewCall(M, "get_role", [publisher, normalizeAddress(args.addr)]);
  }

  /** `(is_owner, is_admin, is_operator)`. */
  viewRoleSummary(args: { addr: AddressInput; publisher?: AddressInput }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.viewCall(M, "get_role_summary", [publisher, normalizeAddress(args.addr)]);
  }
}
