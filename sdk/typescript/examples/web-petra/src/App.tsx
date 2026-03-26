import { useWallet, WalletItem } from "@aptos-labs/wallet-adapter-react";
import { AccountAddress, Network } from "@aptos-labs/ts-sdk";
import React, { useMemo, useState } from "react";
import { createAptosClient, SigilClient } from "../../../src/client.js";

const DEFAULT_MODULE =
  import.meta.env.VITE_SIGIL_MODULE_ADDRESS ??
  "0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6";

/** Aptos chain (AIP-62) name in `@aptos-labs/wallet-adapter-core` registry — not “Nightly (Solana)”. */
const NIGHTLY_APTOS_WALLET_NAME = "Nightly";

/** Raw env; see {@link normalizeDevnetFullnodeUrl}. */
const RAW_APTOS_FULLNODE = import.meta.env.VITE_APTOS_FULLNODE_URL?.trim() || null;

/** Aptos REST base must end with `/v1` for the TS SDK. */
function normalizeDevnetFullnodeUrl(raw: string | null): string | null {
  if (!raw) return null;
  const base = raw.replace(/\/+$/, "");
  if (base.endsWith("/v1")) return base;
  return `${base}/v1`;
}

/** Should match Nightly’s Aptos devnet node (staging vs public devnet are different ledgers). */
const APP_FULLNODE = normalizeDevnetFullnodeUrl(RAW_APTOS_FULLNODE);

/** Optional Aptos Labs / Geomi API key (`Authorization: Bearer`) for higher rate limits on the node API. */
const APTOS_API_KEY = import.meta.env.VITE_APTOS_API_KEY?.trim() || null;

/** Extra lines for logs when the fullnode returns HTML/text (502, rate limit) instead of JSON. */
function rpcParseErrorHints(message: string): string[] {
  const m = message.toLowerCase();
  const lines: string[] = [];

  if (
    m.includes("429") ||
    m.includes("compute unit") ||
    m.includes("rate limit") ||
    m.includes("per application")
  ) {
    lines.push(
      "→ HTTP 429 / Geomi: you hit the API compute-unit quota for this key or IP. Wait ~5 minutes, raise the limit in the Geomi dashboard for your key, or switch Nightly’s devnet RPC from staging to public: https://api.devnet.aptoslabs.com/v1",
    );
    lines.push("→ Geomi FAQ: https://geomi.dev/docs/faq");
  }

  if (
    m.includes("not valid json") ||
    m.includes("unexpected token") ||
    m.includes("bad gateway") ||
    m.includes("per anonym")
  ) {
    const staging = RAW_APTOS_FULLNODE?.includes("staging") ?? false;
    lines.push(
      "→ RPC returned non-JSON (often 502 Bad Gateway, rate limit, or wrong URL). The SDK then throws “not valid JSON”.",
    );
    lines.push(
      staging
        ? "→ You are on staging devnet (…staging.aptoslabs.com). It is a different chain from public devnet. For the README demo module, use https://api.devnet.aptoslabs.com/v1 in both .env and Nightly’s devnet RPC."
        : "→ Set VITE_APTOS_FULLNODE_URL to match your wallet’s Devnet Custom RPC, include /v1, restart `npm run dev`. Public devnet: https://api.devnet.aptoslabs.com/v1",
    );
  }

  return lines;
}

export function App() {
  const {
    wallets,
    notDetectedWallets,
    connect,
    disconnect,
    connected,
    account,
    wallet,
    network,
    changeNetwork,
    signAndSubmitTransaction,
  } = useWallet();
  const [log, setLog] = useState<string[]>([]);
  const [username, setUsername] = useState("player1");
  const [gameId, setGameId] = useState("0");
  const [score, setScore] = useState("1000");

  const sigil = useMemo(() => {
    const aptos = createAptosClient({
      network: Network.DEVNET,
      fullnode: APP_FULLNODE,
      apiKey: APTOS_API_KEY,
    });
    return new SigilClient({
      aptos,
      moduleAddress: AccountAddress.from(DEFAULT_MODULE),
    });
  }, []);

  const push = (line: string) => setLog((prev) => [...prev, line]);

  const onConnectNightly = async () => {
    try {
      await connect(NIGHTLY_APTOS_WALLET_NAME);
      try {
        await changeNetwork(Network.DEVNET);
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        push(
          `WARNING: connect ok, but devnet switch failed (${msg}). In Nightly, select Aptos → Devnet (chainId 173). See https://docs.nightly.app/docs/aptos/aptos/change_network`,
        );
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      push(`ERROR connect (Nightly): ${msg}`);
      console.error("connect", e);
    }
  };

  const onSwitchToDevnet = async () => {
    try {
      await changeNetwork(Network.DEVNET);
      push("Switched Nightly to Aptos Devnet.");
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      push(`ERROR changeNetwork: ${msg}`);
    }
  };

  type SigilWalletPayload = { data: { function: string; functionArguments: unknown[] } };

  /** Pre-set gas so the wallet spends less time estimating; tune if simulation still hangs. */
  const WALLET_TX_OPTIONS = {
    maxGasAmount: 150_000,
    gasUnitPrice: 100,
    expirationSecondsFromNow: 600,
  } as const;

  /** Explicit `sender` + gas hints: helps Approve enable after simulation. */
  const walletTx = (payload: SigilWalletPayload) =>
    ({
      sender: account!.address,
      ...payload,
      options: { ...WALLET_TX_OPTIONS },
    }) as Parameters<typeof signAndSubmitTransaction>[0];

  const submitOrLog = async (label: string, tx: Parameters<typeof signAndSubmitTransaction>[0]) => {
    try {
      const res = await signAndSubmitTransaction(tx);
      push(`${label}: ${res.hash}`);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      const name = e instanceof Error ? e.name : "";
      push(`ERROR ${label}: ${msg}`);
      rpcParseErrorHints(msg).forEach(push);
      if (/reject/i.test(msg) || name === "UserRejectedRequestError") {
        push("→ You declined the wallet popup, or the request was cancelled (closing a stuck “simulating…” counts). Try again and approve, or Disconnect and reconnect.");
        push("→ If the popup hung a long time before this, fix RPC errors above so the wallet’s simulation can finish.");
      }
      if (name === "WalletNotConnectedError" || /not connected/i.test(msg)) {
        push("→ Wallet lost the session (often after a rejected tx). Click Disconnect, then connect again.");
      }
      console.error(label, e);
    }
  };

  const onRegister = async () => {
    if (!connected || !account) return;
    await submitOrLog("register_player", walletTx(sigil.walletPayloadRegisterPlayer(username)));
  };

  const onSubmitScore = async () => {
    if (!connected || !account) return;
    let gid: bigint;
    let sc: bigint;
    try {
      gid = BigInt(gameId);
      sc = BigInt(score);
    } catch {
      push("ERROR submit_score: game_id and score must be integers");
      return;
    }
    await submitOrLog(
      "submit_score",
      walletTx(
        sigil.walletPayloadSubmitScore({
          gameId: gid,
          score: sc,
        }),
      ),
    );
  };

  const onLoadBoard = async () => {
    const top = await sigil.viewTopEntries(0);
    push(`get_top_entries (lb 0): ${JSON.stringify(top)}`);
  };

  /** submit_score aborts without Player (run register_player once) and without game_id on-chain. */
  const onCheckPrereqs = async () => {
    try {
      let gid: bigint;
      try {
        gid = BigInt(gameId);
      } catch {
        push("ERROR check: game_id must be an integer");
        return;
      }
      const countRes = await sigil.viewGameCount();
      const hasRes = await sigil.viewHasGame(gid);
      const playerOk = await sigil.isPlayerRegistered(account!.address.toString());
      push(`game_count raw: ${JSON.stringify(countRes)}`);
      push(`has_game(${gameId}) raw: ${JSON.stringify(hasRes)}`);
      push(`player resource (required for submit_score): ${JSON.stringify(playerOk)}`);
      const has = Array.isArray(hasRes) ? hasRes[0] : hasRes;
      if (has !== true) {
        push("→ If has_game is false, register a game for this publisher on THIS network (smoke script / CLI) or fix game_id.");
      }
      if (!playerOk) {
        push("→ submit_score will ABORT (E_PLAYER_REQUIRED) until register_player succeeds for THIS wallet on THIS network.");
      }
      push(
        "→ get_top_entries can list leaderboard rows seeded by tests; that does not mean your wallet has Player or that game_platform wrote those rows.",
      );
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      push(`ERROR check: ${msg}`);
      rpcParseErrorHints(msg).forEach(push);
    }
  };

  /** Same simulate path as Nightly uses; if this is fast but Nightly hangs, change Nightly’s Aptos devnet RPC in wallet settings. */
  const onPreflightSubmitScore = async () => {
    if (!account) return;
    let gid: bigint;
    let sc: bigint;
    try {
      gid = BigInt(gameId);
      sc = BigInt(score);
    } catch {
      push("ERROR preflight: game_id and score must be integers");
      return;
    }
    push("Preflight: building transaction…");
    try {
      const data = sigil.walletPayloadSubmitScore({ gameId: gid, score: sc }).data;
      const t0 = performance.now();
      const transaction = await sigil.aptos.transaction.build.simple({
        sender: account.address.toString(),
        data,
        options: { ...WALLET_TX_OPTIONS },
      });
      push("Preflight: simulating…");
      // `signerPublicKey` is optional; some wallets expose a key shape the SDK rejects — fall back without it.
      let sims: unknown[];
      try {
        sims = await sigil.aptos.transaction.simulate.simple({
          signerPublicKey: account.publicKey as never,
          transaction,
        });
      } catch (simErr) {
        push(
          `Preflight: simulate with wallet public key failed (${simErr instanceof Error ? simErr.message : String(simErr)}), retrying without key…`,
        );
        sims = await sigil.aptos.transaction.simulate.simple({ transaction });
      }
      const sim = sims[0] as Record<string, unknown> | undefined;
      const ms = Math.round(performance.now() - t0);
      if (!sim) {
        push(`ERROR preflight: empty simulate result after ${ms}ms`);
        return;
      }
      const vm = String(sim.vm_status ?? "?");
      push(
        `Preflight simulate (${ms}ms): success=${String(sim.success ?? "?")} vm_status=${vm} gas_used=${String(sim.gas_used ?? "?")}`,
      );
      if (vm !== "Executed successfully" && vm !== "?") {
        push(
          `→ Move did not execute successfully; the wallet may keep Approve disabled. vm_status is the real error (Aptos does not echo println! from simulate).`,
        );
        push(`Snippet: ${JSON.stringify(sim).slice(0, 1200)}`);
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      push(`ERROR preflight: ${msg}`);
      rpcParseErrorHints(msg).forEach(push);
      console.error(e);
    }
  };

  const nightlyInstalled = wallets.find((w) => w.name === NIGHTLY_APTOS_WALLET_NAME);
  const nightlyNotDetected = notDetectedWallets.find((w) => w.name === NIGHTLY_APTOS_WALLET_NAME);
  const onWrongNetwork =
    connected &&
    network != null &&
    String(network.name).toLowerCase() !== String(Network.DEVNET).toLowerCase();

  return (
    <div style={{ fontFamily: "system-ui", maxWidth: 520, margin: "2rem auto", padding: 16 }}>
      <h1>Sigil + Nightly (Aptos devnet)</h1>
      <p style={{ color: "#444" }}>
        Module: <code>{DEFAULT_MODULE}</code>. Set <code>VITE_SIGIL_MODULE_ADDRESS</code> to override.
      </p>
      <p style={{ color: "#444", fontSize: 14 }}>
        App fullnode (views + preflight):{" "}
        <code style={{ fontSize: 12 }}>
          {APP_FULLNODE ?? "TS SDK default for Network.DEVNET (set VITE_APTOS_FULLNODE_URL to match Nightly)"}
        </code>
        {RAW_APTOS_FULLNODE && !RAW_APTOS_FULLNODE.replace(/\/+$/, "").endsWith("/v1") ? (
          <span style={{ color: "#a60" }}> (normalized: appended /v1)</span>
        ) : null}
        {APTOS_API_KEY ? (
          <span style={{ color: "#284", marginLeft: 8 }}>API key: on (Geomi / Aptos Labs)</span>
        ) : (
          <span style={{ color: "#666", marginLeft: 8, fontSize: 13 }}>
            Optional: set <code style={{ fontSize: 12 }}>VITE_APTOS_API_KEY</code> for higher RPC limits
          </span>
        )}
      </p>
      <p style={{ color: "#a60", fontSize: 13 }}>
        <strong>Staging vs public devnet:</strong> <code>api.devnet.staging.aptoslabs.com</code> and{" "}
        <code>api.devnet.aptoslabs.com</code> are <strong>different chains</strong>. Your package and faucet balance must
        exist on the <strong>same</strong> network your wallet uses.
      </p>
      <p style={{ color: "#a22", fontSize: 13, borderLeft: "3px solid #c44", paddingLeft: 10 }}>
        If the wallet shows <strong>Simulation error</strong> with <code>429</code> and{" "}
        <code>api.devnet.staging.aptoslabs.com</code>, it is still using <strong>staging</strong> for simulation. Set Nightly’s
        Aptos devnet node / Custom RPC to{" "}
        <code style={{ fontSize: 12 }}>https://api.devnet.aptoslabs.com/v1</code> to match this app (or use staging everywhere
        if you deploy there). For Geomi quota, see{" "}
        <a href="https://geomi.dev/docs/faq" target="_blank" rel="noreferrer">
          geomi.dev/docs/faq
        </a>
        .
      </p>
      <p style={{ color: "#666", fontSize: 14 }}>
        Approve every transaction prompt in your wallet. If you <strong>Reject</strong>, signing can break until you{" "}
        <strong>Disconnect</strong> and connect again.
      </p>
      <p style={{ color: "#666", fontSize: 14 }}>
        Most wallets enable <strong>Approve</strong> only after <strong>simulation</strong>. Set your wallet’s Devnet{" "}
        <strong>Custom RPC</strong> to the <strong>same</strong> host as this app’s{" "}
        <code style={{ fontSize: 12 }}>VITE_APTOS_FULLNODE_URL</code> (e.g. public devnet{" "}
        <code style={{ fontSize: 12 }}>https://api.devnet.aptoslabs.com/v1</code>), then restart <code>npm run dev</code>. If
        you see <strong>Bad Gateway</strong> or <strong>not valid JSON</strong>, avoid staging unless you deploy on that
        chain. Use <strong>Preflight simulate</strong> to verify RPC from the app.
      </p>
      <p style={{ color: "#666", fontSize: 14 }}>
        <strong>“No coin balance changes”</strong> in the preview is normal for <code>submit_score</code> (it updates game
        state, not your APT balance). If Approve never enables, the simulation may still be running, RPC may be slow, or the
        tx failed on-chain (see <strong>Preflight</strong> log).
      </p>
      <p style={{ color: "#a60", fontSize: 13 }}>
        If the console shows <code>Cannot set property ethereum</code> / MetaMask / Nightly / Backpack fighting over{" "}
        <code>window.ethereum</code>, disable other EVM wallet extensions for this tab (they are unrelated to Aptos).
        Those errors are injected by EVM extensions, not this Aptos app.
      </p>

      {!connected && (
        <section>
          <h2>Connect Nightly</h2>
          <p style={{ color: "#666", fontSize: 13 }}>
            This demo uses only{" "}
            <a href="https://docs.nightly.app/docs/aptos/aptos/detection" target="_blank" rel="noreferrer">
              Nightly on Aptos
            </a>{" "}
            (devnet). Install the Nightly extension and select the <strong>Aptos</strong> account.
          </p>
          {nightlyInstalled ? (
            <WalletItem wallet={nightlyInstalled} onConnect={() => void onConnectNightly()}>
              <WalletItem.Icon />
              <WalletItem.Name />
              <WalletItem.ConnectButton />
            </WalletItem>
          ) : nightlyNotDetected ? (
            <WalletItem wallet={nightlyNotDetected}>
              <WalletItem.Icon />
              <WalletItem.Name />
              <WalletItem.InstallLink />
            </WalletItem>
          ) : (
            <p style={{ color: "#666" }}>Loading Nightly…</p>
          )}
        </section>
      )}

      {connected && account && (
        <section>
          <h2>Connected</h2>
          {wallet?.name ? (
            <p style={{ color: "#666", fontSize: 14 }}>
              Wallet: <strong>{wallet.name}</strong>
            </p>
          ) : null}
          {network ? (
            <p style={{ color: onWrongNetwork ? "#a60" : "#666", fontSize: 14 }}>
              Network: <strong>{String(network.name)}</strong>
              {network.chainId != null ? ` (chain ${network.chainId})` : ""}
            </p>
          ) : null}
          {onWrongNetwork ? (
            <p style={{ marginTop: 8 }}>
              <button type="button" onClick={() => void onSwitchToDevnet()}>
                Switch Nightly to Aptos Devnet
              </button>
            </p>
          ) : null}
          <p>
            <code>{account.address.toString()}</code>
          </p>
          <button type="button" onClick={() => disconnect()}>
            Disconnect
          </button>

          <h3>game_platform</h3>
          <label>
            Username{" "}
            <input value={username} onChange={(e) => setUsername(e.target.value)} />
          </label>
          <button type="button" onClick={() => void onRegister()}>
            register_player
          </button>
          <button type="button" onClick={() => void onCheckPrereqs()} style={{ marginLeft: 8 }}>
            Check game exists
          </button>

          <div style={{ marginTop: 12 }}>
            <label>
              game_id <input value={gameId} onChange={(e) => setGameId(e.target.value)} style={{ width: 64 }} />
            </label>{" "}
            <label>
              score <input value={score} onChange={(e) => setScore(e.target.value)} style={{ width: 96 }} />
            </label>
            <button type="button" onClick={() => void onSubmitScore()}>
              submit_score
            </button>
            <button type="button" onClick={() => void onPreflightSubmitScore()} style={{ marginLeft: 8 }}>
              Preflight simulate
            </button>
          </div>

          <h3>leaderboard (views)</h3>
          <button type="button" onClick={() => void onLoadBoard()}>
            get_top_entries (id 0)
          </button>
        </section>
      )}

      <h2>Log</h2>
      <pre
        style={{
          background: "#111",
          color: "#e0e0e0",
          padding: 12,
          borderRadius: 8,
          minHeight: 80,
          fontSize: 12,
        }}
      >
        {log.length ? log.join("\n") : "…"}
      </pre>
    </div>
  );
}
