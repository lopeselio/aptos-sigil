import {
  Aptos,
  AptosConfig,
  type Aptos as AptosInstance,
  type InputGenerateTransactionOptions,
  Network,
} from "@aptos-labs/ts-sdk";

/** Seed passed to `account::create_resource_account(publisher, b"rewards_v1")` in `rewards::init_rewards`. */
export const SIGIL_REWARDS_RESOURCE_SEED = "rewards_v1" as const;

/** Native APT fungible metadata object (matches CLI `address:0xa` for treasury / FA rewards on devnet). */
export const APTOS_COIN_METADATA_ADDRESS =
  "0x000000000000000000000000000000000000000000000000000000000000000a" as const;

/** Matches `aptos move run --max-gas 200000 --gas-unit-price 100` for `build.simple` defaults. */
export const DEFAULT_SIGIL_TX_GAS: InputGenerateTransactionOptions = {
  maxGasAmount: 200_000,
  gasUnitPrice: 100,
};

/**
 * Builds an {@link Aptos} client with optional fullnode URL and API key.
 * Keys are sent as `Authorization: Bearer …` (see [Geomi](https://geomi.dev/docs/api-reference) / Aptos Labs node access).
 */
export function createAptosClient(options: {
  network: Network;
  /** REST base URL, e.g. `https://api.devnet.aptoslabs.com/v1` */
  fullnode?: string | null;
  /** Higher rate limits on Aptos Labs / Geomi gateways; prefer a **frontend** key in browser apps. */
  apiKey?: string | null;
}): AptosInstance {
  const fullnode = options.fullnode?.trim() || undefined;
  const apiKey = options.apiKey?.trim() || undefined;
  return new Aptos(
    new AptosConfig({
      network: options.network,
      ...(fullnode ? { fullnode } : {}),
      ...(apiKey ? { clientConfig: { API_KEY: apiKey } } : {}),
    }),
  );
}
