// Re-export the Sigil SDK. `lib/vendor` is a self-contained copy of the built SDK
// dist (sdk/typescript/dist), vendored by scripts/copy-sdk.mjs (runs on predev/
// prebuild) so the app deploys without the out-of-tree SDK. In a real app you'd
// `import { SigilClient } from "@sigil-aptos/sdk"`.
export * from "./vendor/index.js";
