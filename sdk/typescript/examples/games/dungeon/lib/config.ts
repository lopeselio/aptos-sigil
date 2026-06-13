import { Network } from "@aptos-labs/ts-sdk";

export function parseNetwork(raw: string | undefined): Network {
  switch ((raw ?? "").trim().toLowerCase()) {
    case "mainnet":
      return Network.MAINNET;
    case "devnet":
      return Network.DEVNET;
    case "local":
      return Network.LOCAL;
    case "testnet":
    default:
      return Network.TESTNET;
  }
}

export const APP_NETWORK = parseNetwork(process.env.NEXT_PUBLIC_APTOS_NETWORK);
export const NETWORK_LABEL = String(APP_NETWORK);

export const MODULE_ADDRESS =
  process.env.NEXT_PUBLIC_SIGIL_MODULE_ADDRESS ??
  "0x568721f98162f03aa564384f15d7ead24b9825a3f35e4c2dba8265bd126ce787";

export const ARCADE_GAME_ID = BigInt(process.env.NEXT_PUBLIC_ARCADE_GAME_ID ?? "0");

export const SPONSOR_ENDPOINT = process.env.NEXT_PUBLIC_SPONSOR_ENDPOINT ?? "/api/sponsor";
