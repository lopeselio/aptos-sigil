import { type Account, type AnyNumber, type InputGenerateTransactionOptions } from "@aptos-labs/ts-sdk";
import { SigilModule, normalizeAddress, toBytes, type AddressInput } from "./base.js";

const M = "attest";

/** `attest`: server-signed score attestation (anti-cheat) config per publisher. */
export class AttestModule extends SigilModule {
  /** Initialize with the game server's ed25519 public key and a max signature age. */
  buildInit(args: { sender: Account; serverPubkey: string | Uint8Array; maxAgeSecs: AnyNumber; options?: InputGenerateTransactionOptions }) {
    return this.buildEntry({ ...args, module: M, func: "init_attest", functionArguments: [toBytes(args.serverPubkey), args.maxAgeSecs] });
  }

  buildUpdateServerKey(args: { sender: Account; newPubkey: string | Uint8Array; options?: InputGenerateTransactionOptions }) {
    return this.buildEntry({ ...args, module: M, func: "update_server_key", functionArguments: [toBytes(args.newPubkey)] });
  }

  // ---- views ----

  viewIsInitialized(publisher: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "is_initialized", [normalizeAddress(publisher)]);
  }

  /** `(exists, pubkey_bytes)`. */
  viewServerPubkey(publisher: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "get_server_pubkey", [normalizeAddress(publisher)]);
  }

  /** `(exists, last_nonce)` for a player (replay protection). */
  viewLastNonce(args: { player: AddressInput; publisher?: AddressInput }) {
    const publisher = args.publisher ? normalizeAddress(args.publisher) : this.moduleAddress;
    return this.viewCall(M, "get_last_nonce", [publisher, normalizeAddress(args.player)]);
  }

  /** `(exists, max_age_secs)`. */
  viewMaxAge(publisher: AddressInput = this.moduleAddress) {
    return this.viewCall(M, "get_max_age", [normalizeAddress(publisher)]);
  }
}
