// Re-export the Sigil SDK from its built dist (one place to manage the path).
// In a real app you'd `import { SigilClient } from "@sigil-aptos/sdk"`; this
// example consumes the local build so it always matches the repo.
export * from "./vendor/index.js";
