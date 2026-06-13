// Vendors the built Sigil SDK (sdk/typescript/dist) into ./lib/vendor so the app
// is self-contained for deploys (a Vercel CLI upload only includes this app dir,
// not the SDK that lives three levels up). For local dev/build the SDK dist is
// copied in fresh; on Vercel the already-uploaded copy is kept.
import { cpSync, existsSync, rmSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const distSrc = resolve(here, "../../../../dist");
const vendorDest = resolve(here, "../lib/vendor");

if (existsSync(distSrc)) {
  rmSync(vendorDest, { recursive: true, force: true });
  cpSync(distSrc, vendorDest, { recursive: true });
  console.log(`[copy-sdk] vendored SDK dist -> lib/vendor`);
} else if (existsSync(vendorDest)) {
  console.log(`[copy-sdk] SDK dist not found; keeping existing lib/vendor`);
} else {
  console.error(`[copy-sdk] ERROR: no SDK dist at ${distSrc} and no vendored copy. Run 'npm run build' in sdk/typescript first.`);
  process.exit(1);
}
