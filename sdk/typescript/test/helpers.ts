import { AccountAddress } from "@aptos-labs/ts-sdk";
import { SigilClient } from "../src/index.js";

/** Module address used in tests; `fid()` renders it as `0x1::module::func`. */
export const MOD = "0x1";
/** A distinct sender address so we can assert it is never leaked into functionArguments. */
export const SENDER = "0x9";

export type Capture = {
  kind: "simple" | "multiAgent" | "view";
  fn: string;
  args: unknown[];
  secondary?: string[];
};

/**
 * Build a SigilClient backed by a mock Aptos that records the function id and
 * arguments of every entry/view call instead of hitting the network.
 */
export function makeClient() {
  const calls: Capture[] = [];
  const record =
    (kind: Capture["kind"]) =>
    (x: { data?: { function: string; functionArguments: unknown[] }; payload?: { function: string; functionArguments: unknown[] }; secondarySignerAddresses?: unknown[] }) => {
      const d = x.data ?? x.payload!;
      calls.push({
        kind,
        fn: d.function,
        args: d.functionArguments,
        secondary: x.secondarySignerAddresses?.map(String),
      });
      return x;
    };

  const aptos = {
    transaction: { build: { simple: record("simple"), multiAgent: record("multiAgent") } },
    view: record("view"),
    getAccountResource: async () => ({}),
  };

  const client = new SigilClient({ aptos: aptos as never, moduleAddress: AccountAddress.from(MOD) });
  const sender = { accountAddress: AccountAddress.from(SENDER) } as never;
  return { client, sender, calls, last: () => calls[calls.length - 1] };
}

/** Normalize an argument to a stable, comparable form (addresses/bytes/numbers → strings). */
export function norm(a: unknown): unknown {
  if (a instanceof AccountAddress) return a.toString();
  if (a instanceof Uint8Array) return `bytes:${Buffer.from(a).toString("hex")}`;
  if (typeof a === "bigint" || typeof a === "number") return String(a);
  if (Array.isArray(a)) return a.map(norm);
  return a;
}

export const normArgs = (args: unknown[]): unknown[] => args.map(norm);

/** Hex of a UTF-8 string, prefixed `bytes:` to match {@link norm} output. */
export const utf8 = (s: string): string => `bytes:${Buffer.from(new TextEncoder().encode(s)).toString("hex")}`;
