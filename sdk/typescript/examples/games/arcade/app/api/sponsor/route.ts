import {
  Account,
  Aptos,
  AptosConfig,
  Ed25519PrivateKey,
  PrivateKey,
  PrivateKeyVariants,
} from "@aptos-labs/ts-sdk";
import { sponsorTransaction, sponsoredFunctionId } from "@/lib/sdk";
import { APP_NETWORK, MODULE_ADDRESS } from "@/lib/config";

/**
 * Gas station: signs a player's transaction as the **fee payer** so they pay 0
 * gas. The browser POSTs a built fee-payer transaction (BCS hex); we sign it
 * with SPONSOR_PRIVATE_KEY and return the fee-payer authenticator.
 *
 * Swap SPONSOR_PRIVATE_KEY for your own funded account to sponsor your own app.
 * The `allow` guard means this sponsor only pays for Sigil module calls — never
 * remove it, or anyone could drain the fee payer (open gas relay).
 */

// The gas station may run on a different origin than the dapp using it (e.g. the
// web-petra console). Allow cross-origin POSTs; the allowlist is the real guard.
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "content-type",
};

const SPONSORED_MODULE = process.env.SIGIL_MODULE_ADDRESS ?? MODULE_ADDRESS;

export function OPTIONS() {
  return new Response(null, { status: 204, headers: CORS });
}

export async function POST(req: Request) {
  const pkRaw = process.env.SPONSOR_PRIVATE_KEY;
  if (!pkRaw) {
    return Response.json(
      { error: "gas station not configured — set SPONSOR_PRIVATE_KEY in the server environment." },
      { status: 500, headers: CORS },
    );
  }

  let serializedTransaction: string;
  try {
    const body = (await req.json()) as { transaction?: string };
    if (!body.transaction) throw new Error("missing `transaction`");
    serializedTransaction = body.transaction;
  } catch (e) {
    return Response.json(
      { error: `bad request: ${e instanceof Error ? e.message : String(e)}` },
      { status: 400, headers: CORS },
    );
  }

  try {
    const aptos = new Aptos(new AptosConfig({ network: APP_NETWORK }));
    const feePayer = Account.fromPrivateKey({
      privateKey: new Ed25519PrivateKey(
        PrivateKey.formatPrivateKey(pkRaw, PrivateKeyVariants.Ed25519),
      ),
    });

    const body = sponsorTransaction({
      aptos,
      feePayer,
      serializedTransaction,
      allow: (tx) => (sponsoredFunctionId(tx) ?? "").startsWith(`${SPONSORED_MODULE}::`),
    });
    return Response.json(body, { headers: CORS });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    const status = /not allowed by gas-station policy/.test(msg) ? 403 : 500;
    return Response.json({ error: msg }, { status, headers: CORS });
  }
}
