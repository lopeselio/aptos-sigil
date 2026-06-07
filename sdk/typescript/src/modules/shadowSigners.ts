import { type Account, type AnyNumber, type InputGenerateTransactionOptions } from "@aptos-labs/ts-sdk";
import { SigilModule, normalizeAddress, type AddressInput } from "./base.js";
import { DEFAULT_SIGIL_TX_GAS } from "../constants.js";

const M = "shadow_signers";

const encodeScopes = (scopes: string[]) => scopes.map((s) => new TextEncoder().encode(s));

/** `shadow_signers`: scoped, expiring session keys (optionally fee-sponsored). */
export class ShadowSignersModule extends SigilModule {
  /** One-time `Sessions` resource under the user. */
  buildInit(args: { sender: Account; options?: InputGenerateTransactionOptions }) {
    return this.buildEntry({ ...args, module: M, func: "init_sessions", functionArguments: [] });
  }

  /** Create a session key with `scopes` (UTF-8 strings, e.g. `"submit_score"`) valid for `ttlSecs`. */
  buildCreateSession(args: {
    sender: Account;
    shadowPublicKey: Uint8Array;
    scopes: string[];
    ttlSecs: AnyNumber;
    options?: InputGenerateTransactionOptions;
  }) {
    return this.buildEntry({
      ...args,
      module: M,
      func: "create_session",
      functionArguments: [args.shadowPublicKey, encodeScopes(args.scopes), args.ttlSecs],
    });
  }

  /**
   * Create a session where `feePayer` co-signs to sponsor gas. Returns a
   * multi-agent transaction — both the authority (sender) and the fee payer
   * must sign before submission.
   */
  buildCreateSessionWithPayer(args: {
    sender: Account;
    feePayer: AddressInput;
    shadowPublicKey: Uint8Array;
    scopes: string[];
    ttlSecs: AnyNumber;
    options?: InputGenerateTransactionOptions;
  }) {
    return this.aptos.transaction.build.multiAgent({
      sender: args.sender.accountAddress,
      secondarySignerAddresses: [normalizeAddress(args.feePayer)],
      data: {
        function: this.ctx.fid(M, "create_session_with_payer"),
        functionArguments: [args.shadowPublicKey, encodeScopes(args.scopes), args.ttlSecs],
      },
      options: { ...DEFAULT_SIGIL_TX_GAS, ...args.options } as InputGenerateTransactionOptions,
    });
  }

  /** Revoke a session under `authorityAddr`. */
  buildRevokeSession(args: { sender: Account; authorityAddr: AddressInput; shadowPublicKey: Uint8Array; options?: InputGenerateTransactionOptions }) {
    return this.buildEntry({
      ...args,
      module: M,
      func: "revoke_session",
      functionArguments: [normalizeAddress(args.authorityAddr), args.shadowPublicKey],
    });
  }

  /** Permissionless cleanup of an expired session (any sender). */
  buildCleanupExpiredSession(args: { sender: Account; authorityAddr: AddressInput; shadowPublicKey: Uint8Array; options?: InputGenerateTransactionOptions }) {
    return this.buildEntry({
      ...args,
      module: M,
      func: "cleanup_expired_session",
      functionArguments: [normalizeAddress(args.authorityAddr), args.shadowPublicKey],
    });
  }

  // ---- views ----

  viewIsInitialized(addr: AddressInput) {
    return this.viewCall(M, "is_initialized", [normalizeAddress(addr)]);
  }

  viewSessionExists(authority: AddressInput, shadowPublicKey: Uint8Array) {
    return this.viewCall(M, "session_exists", [normalizeAddress(authority), shadowPublicKey]);
  }

  /** `(exists, valid, expires_at, revoked)`. */
  viewSession(authority: AddressInput, shadowPublicKey: Uint8Array) {
    return this.viewCall(M, "get_session", [normalizeAddress(authority), shadowPublicKey]);
  }

  viewSessionValid(authority: AddressInput, shadowPublicKey: Uint8Array) {
    return this.viewCall(M, "is_session_valid", [normalizeAddress(authority), shadowPublicKey]);
  }

  /** `(exists, scopes[])` where scopes are `vector<u8>` byte arrays. */
  viewSessionScopes(authority: AddressInput, shadowPublicKey: Uint8Array) {
    return this.viewCall(M, "get_session_scopes", [normalizeAddress(authority), shadowPublicKey]);
  }

  /** `(exists, last_nonce)`. */
  viewLastNonce(authority: AddressInput, shadowPublicKey: Uint8Array) {
    return this.viewCall(M, "get_last_nonce", [normalizeAddress(authority), shadowPublicKey]);
  }

  /** `(exists, fee_payer)`. */
  viewFeePayer(authority: AddressInput, shadowPublicKey: Uint8Array) {
    return this.viewCall(M, "get_fee_payer", [normalizeAddress(authority), shadowPublicKey]);
  }
}
