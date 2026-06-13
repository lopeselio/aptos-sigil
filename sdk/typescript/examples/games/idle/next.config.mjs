import { createRequire } from "node:module";
import { dirname } from "node:path";

const require = createRequire(import.meta.url);
// Resolve a single @aptos-labs/ts-sdk copy. The Sigil SDK is imported from its
// dist (which lives in sdk/typescript and would otherwise resolve its own ts-sdk
// copy), so without this the app page and the SDK could use two different copies
// and `instanceof AccountAddress` checks would fail. Pin both to one.
const tsSdkDir = dirname(require.resolve("@aptos-labs/ts-sdk/package.json"));

/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // The Sigil SDK lives outside this app (we import its built dist from
  // ../../../dist). externalDir lets Next compile modules above the app root.
  experimental: { externalDir: true },
  webpack: (config) => {
    config.resolve.alias = { ...config.resolve.alias, "@aptos-labs/ts-sdk": tsSdkDir };
    return config;
  },
};

export default nextConfig;
