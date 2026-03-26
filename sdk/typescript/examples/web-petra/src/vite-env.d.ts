/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_SIGIL_MODULE_ADDRESS?: string;
  /** Optional devnet fullnode base URL (e.g. https://fullnode.devnet.aptoslabs.com/v1) for views + preflight simulate */
  readonly VITE_APTOS_FULLNODE_URL?: string;
  /**
   * Optional Aptos node API key (Geomi / Aptos Labs). Sent as `Authorization: Bearer` by `@aptos-labs/ts-sdk`.
   * Exposed in the browser bundle — use a Geomi [Frontend Key](https://geomi.dev/docs/api-keys/frontend-keys), not a secret server key.
   */
  readonly VITE_APTOS_API_KEY?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
