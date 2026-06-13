import { useWallet, WalletItem } from "@aptos-labs/wallet-adapter-react";
import { AccountAddress, Network } from "@aptos-labs/ts-sdk";
import React, { useMemo, useState } from "react";
import { createAptosClient, DEFAULT_SIGIL_TX_GAS, SigilClient } from "../../../src/client.js";
import {
  buildSponsoredTransaction,
  requestSponsorship,
  submitSponsored,
} from "../../../src/sponsor.js";

const DEFAULT_MODULE =
  import.meta.env.VITE_SIGIL_MODULE_ADDRESS ??
  "0x694fd0c04ecf4ec750450d3c1a4d318d5869f2cf762562a8a586a44e1c29d1c1";

/** Aptos chain (AIP-62) name in `@aptos-labs/wallet-adapter-core` registry — not “Nightly (Solana)”. */
const NIGHTLY_APTOS_WALLET_NAME = "Nightly";

/** Network the app targets (default testnet — the stable home; devnet wipes weekly). */
function parseNetwork(raw: string | null): Network {
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
const APP_NETWORK = parseNetwork(import.meta.env.VITE_APTOS_NETWORK ?? null);
const NETWORK_LABEL = String(APP_NETWORK);

/** Gas-station endpoint for ⚡ gasless (sponsored) submits. Empty disables the feature. */
const SPONSOR_ENDPOINT = (import.meta.env.VITE_SPONSOR_ENDPOINT ?? "/api/sponsor").trim();

/** Raw env; see {@link normalizeFullnodeUrl}. */
const RAW_APTOS_FULLNODE = import.meta.env.VITE_APTOS_FULLNODE_URL?.trim() || null;

/** Aptos REST base must end with `/v1` for the TS SDK. */
function normalizeFullnodeUrl(raw: string | null): string | null {
  if (!raw) return null;
  const base = raw.replace(/\/+$/, "");
  if (base.endsWith("/v1")) return base;
  return `${base}/v1`;
}

/** Should match the wallet’s node for {@link APP_NETWORK} (staging vs public are different ledgers). */
const APP_FULLNODE = normalizeFullnodeUrl(RAW_APTOS_FULLNODE);

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
      "→ HTTP 429 / Geomi: you hit the API compute-unit quota for this key or IP. Wait ~5 minutes, raise the limit in the Geomi dashboard for your key, or switch the wallet’s RPC.",
    );
    lines.push("→ Geomi FAQ: https://geomi.dev/docs/faq");
  }

  if (
    m.includes("504") ||
    m.includes("failed to fetch") ||
    m.includes("upstream request timeout") ||
    m.includes("stream timeout") ||
    m.includes("networkerror") ||
    m.includes("load failed") ||
    m.includes("timed out") ||
    m.includes("timeout")
  ) {
    lines.push(
      "→ Network/RPC error reaching the fullnode — commonly an overloaded simulate endpoint. This is infrastructure, NOT your transaction.",
    );
    lines.push(
      "→ The submit path is usually still healthy: click the action and Approve in your wallet. If Approve stays disabled, the wallet ran the same simulate against its own RPC — switch the wallet’s Custom RPC or retry in a minute.",
    );
  }

  if (
    m.includes("not valid json") ||
    m.includes("unexpected token") ||
    m.includes("bad gateway") ||
    m.includes("per anonym")
  ) {
    lines.push(
      "→ RPC returned non-JSON (often 502 Bad Gateway, rate limit, or wrong URL). The SDK then throws “not valid JSON”.",
    );
    lines.push(
      `→ Set VITE_APTOS_FULLNODE_URL to match your wallet’s ${NETWORK_LABEL} RPC, include /v1, restart \`npm run dev\`.`,
    );
  }

  return lines;
}

/**
 * A network/transport failure (couldn't reach or get a response from the RPC),
 * as opposed to a real VM failure. These should be treated as non-blocking:
 * the transaction itself is fine, the simulate call just couldn't complete.
 */
function isNetworkSimError(message: string): boolean {
  const m = message.toLowerCase();
  return (
    m.includes("failed to fetch") ||
    m.includes("504") ||
    m.includes("upstream request timeout") ||
    m.includes("stream timeout") ||
    m.includes("networkerror") ||
    m.includes("load failed") ||
    m.includes("timed out") ||
    m.includes("timeout")
  );
}

/** Reject after `ms` so a stuck simulate fails fast instead of hanging ~30s. */
function withTimeout<T>(p: Promise<T>, ms: number, label: string): Promise<T> {
  return Promise.race([
    p,
    new Promise<T>((_, reject) =>
      setTimeout(() => reject(new Error(`${label} timed out after ${ms}ms`)), ms),
    ),
  ]);
}

/** True when the simulated execution succeeded (vm_status formats differ by SDK path). */
function isTxSimulationSuccess(sim: Record<string, unknown>): boolean {
  if (sim.success === true) return true;
  const vm = String(sim.vm_status ?? "");
  if (vm.includes("Executed successfully")) return true;
  if (/EXECUTED/i.test(vm) && /Execution/i.test(vm)) return true;
  return false;
}

/** Human label for a wallet-payload argument's runtime type (teaching aid). */
function argTypeHint(v: unknown): string {
  if (typeof v === "bigint") return "u64/integer";
  if (typeof v === "boolean") return "bool";
  if (typeof v === "number") return "u8/number";
  if (v instanceof AccountAddress) return "address";
  if (typeof v === "string") return /^0x[0-9a-fA-F]+$/.test(v) ? "address" : "string";
  if (v instanceof Uint8Array || Array.isArray(v)) return "vector<u8>";
  return typeof v;
}

type Tab = "guided" | "player" | "publisher" | "views";

/** Wallet-adapter `InputTransactionData`-shaped payload (matches the SDK's `walletPayload*` return). */
type SigilWalletPayload = {
  data: { function: string; typeArguments?: string[]; functionArguments: unknown[] };
};

/** A single contract write, with everything Inspect/Run/Simulate/Gasless need from one source of truth. */
type ActionDesc = {
  id: string;
  label: string;
  /** The exact SDK call a dev would copy into their own app. */
  sdk: string;
  /** Builds the wallet payload (also drives Inspect, Simulate, Run, Gasless). */
  build: () => SigilWalletPayload;
  /** Show the ⚡ gasless (sponsored) run button. */
  sponsorable?: boolean;
};

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
    signTransaction,
  } = useWallet();
  const [log, setLog] = useState<string[]>([]);
  const [tab, setTab] = useState<Tab>("guided");
  const [open, setOpen] = useState<Record<string, boolean>>({});
  const [step, setStep] = useState(0);

  // Single registry for all text inputs across tabs; `f`/`setF` read & write by key.
  const [fields, setFields] = useState<Record<string, string>>({
    username: "player1",
    gameId: "0",
    score: "1000",
    gameTitle: "My Game",
    lbDecimals: "0",
    lbMin: "0",
    lbMax: "10000000000",
    lbRetain: "10",
    achTitle: "First Win",
    achDesc: "Score 1000+",
    achMin: "1000",
    achBadge: "",
    rewardAchId: "0",
    rewardAmount: "100000",
    rewardSupply: "100",
    questTitle: "Hit 1000",
    questDesc: "Reach a score of 1000",
    questTarget: "1000",
    questReward: "0",
    questId: "0",
    guildName: "My Clan",
    guildId: "0",
    recipeIn: "1",
    recipeInQty: "2",
    recipeOut: "2",
    recipeOutQty: "1",
    recipeId: "0",
    grantItem: "1",
    grantQty: "5",
    seasonName: "Season 1",
    seasonStart: "0",
    seasonEnd: "0",
    seasonLb: "0",
    seasonPrize: "0",
    seasonId: "0",
    treasuryAmount: "100000",
    withdrawTo: "",
    withdrawAmount: "100000",
    adminAddr: "",
  });
  // Boolean flags (checkboxes) kept apart from text fields.
  const [flags, setFlags] = useState<Record<string, boolean>>({
    lbAscending: false,
    lbAllowMultiple: false,
    questSeasonal: false,
  });

  const f = (k: string) => fields[k] ?? "";
  const setF = (k: string, v: string) => setFields((prev) => ({ ...prev, [k]: v }));
  const big = (k: string) => BigInt(f(k).trim());
  const flag = (k: string) => flags[k] ?? false;
  const setFlag = (k: string, v: boolean) => setFlags((prev) => ({ ...prev, [k]: v }));

  const sigil = useMemo(() => {
    const aptos = createAptosClient({
      network: APP_NETWORK,
      fullnode: APP_FULLNODE,
      apiKey: APTOS_API_KEY,
    });
    return new SigilClient({
      aptos,
      moduleAddress: AccountAddress.from(DEFAULT_MODULE),
    });
  }, []);

  const push = (line: string) => setLog((prev) => [...prev, line]);
  const copy = (text: string) => {
    void navigator.clipboard?.writeText(text).then(
      () => push("Copied to clipboard."),
      () => push("Clipboard blocked — select & copy from the Inspect panel."),
    );
  };

  const onConnectNightly = async () => {
    try {
      await connect(NIGHTLY_APTOS_WALLET_NAME);
      try {
        await changeNetwork(APP_NETWORK);
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        push(
          `WARNING: connect ok, but ${NETWORK_LABEL} switch failed (${msg}). In Nightly, select Aptos → ${NETWORK_LABEL}.`,
        );
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      push(`ERROR connect (Nightly): ${msg}`);
      console.error("connect", e);
    }
  };

  const onSwitchNetwork = async () => {
    try {
      await changeNetwork(APP_NETWORK);
      push(`Switched Nightly to Aptos ${NETWORK_LABEL}.`);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      push(`ERROR changeNetwork: ${msg}`);
    }
  };

  /** Pre-set gas: same as `aptos move run --max-gas 200000 --gas-unit-price 100`; wallet expiry is separate. */
  const WALLET_TX_OPTIONS = {
    ...DEFAULT_SIGIL_TX_GAS,
    expirationSecondsFromNow: 600,
  } as const;

  /** Canonical sender + gas hints so wallet simulation matches the app’s preflight. */
  const walletTx = (payload: SigilWalletPayload) =>
    ({
      sender: account!.address.toString(),
      ...payload,
      options: { ...WALLET_TX_OPTIONS },
    }) as Parameters<typeof signAndSubmitTransaction>[0];

  const submitOrLog = async (label: string, tx: Parameters<typeof signAndSubmitTransaction>[0]) => {
    try {
      const res = await signAndSubmitTransaction(tx);
      // A returned hash only means "submitted" — wait for execution, an aborted tx has a hash too.
      const committed = await sigil.aptos.waitForTransaction({ transactionHash: res.hash });
      if (committed.success) {
        push(`${label}: OK ${res.hash}`);
      } else {
        push(`ERROR ${label}: aborted on-chain — ${committed.vm_status} (${res.hash})`);
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      const name = e instanceof Error ? e.name : "";
      push(`ERROR ${label}: ${msg}`);
      rpcParseErrorHints(msg).forEach(push);
      if (/reject/i.test(msg) || name === "UserRejectedRequestError") {
        push("→ You declined the wallet popup, or the request was cancelled. Try again and approve, or Disconnect and reconnect.");
      }
      if (name === "WalletNotConnectedError" || /not connected/i.test(msg)) {
        push("→ Wallet lost the session (often after a rejected tx). Click Disconnect, then connect again.");
      }
      if (/E_NOT_AUTHORIZED|not authorized|0x5000|EPERMISSION|owner/i.test(msg)) {
        push("→ Admin/publisher action: this aborts unless the connected wallet is the publisher (or a roles-authorized admin/operator) for the module address above.");
      }
      console.error(label, e);
    }
  };

  /** Wrap payload construction (incl. BigInt parsing) + submit into one click handler. */
  const write = (label: string, build: () => SigilWalletPayload) => async () => {
    if (!connected || !account) {
      push(`ERROR ${label}: connect a wallet first.`);
      return;
    }
    let payload: SigilWalletPayload;
    try {
      payload = build();
    } catch (e) {
      push(`ERROR ${label}: ${e instanceof Error ? e.message : String(e)} — check that numeric fields are integers.`);
      return;
    }
    await submitOrLog(label, walletTx(payload));
  };

  /** Run a read-only view and log the JSON result (with RPC hints on failure). */
  const view = (label: string, run: () => Promise<unknown>) => async () => {
    try {
      const r = await run();
      push(`${label}: ${JSON.stringify(r)}`);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      push(`ERROR ${label}: ${msg}`);
      rpcParseErrorHints(msg).forEach(push);
      console.error(label, e);
    }
  };

  const me = () => account!.address.toString();

  /** Universal dry-run: build the tx and simulate it, logging success / gas / vm_status. */
  const simulate = async (label: string, build: () => SigilWalletPayload) => {
    if (!account) {
      push(`Simulate ${label}: connect a wallet first.`);
      return;
    }
    let payload: SigilWalletPayload;
    try {
      payload = build();
    } catch (e) {
      push(`Simulate ${label}: ${e instanceof Error ? e.message : String(e)} — check numeric fields.`);
      return;
    }
    push(`Simulate ${label}: building + simulating…`);
    try {
      const transaction = await sigil.aptos.transaction.build.simple({
        sender: me(),
        data: payload.data as never,
        options: { ...DEFAULT_SIGIL_TX_GAS, expireTimestamp: Math.floor(Date.now() / 1000) + 600 },
      });
      const SIM_TIMEOUT_MS = 12_000;
      let sims: unknown[];
      try {
        sims = await withTimeout(
          sigil.aptos.transaction.simulate.simple({ signerPublicKey: account.publicKey as never, transaction }),
          SIM_TIMEOUT_MS,
          "simulate (with key)",
        );
      } catch (simErr) {
        push(`Simulate ${label}: with-key failed (${simErr instanceof Error ? simErr.message : String(simErr)}), retrying without key…`);
        sims = await withTimeout(
          sigil.aptos.transaction.simulate.simple({ transaction }),
          SIM_TIMEOUT_MS,
          "simulate (no key)",
        );
      }
      const sim = sims[0] as Record<string, unknown> | undefined;
      if (!sim) {
        push(`Simulate ${label}: empty result.`);
        return;
      }
      const ok = isTxSimulationSuccess(sim);
      push(
        `Simulate ${label}: success=${String(sim.success ?? "?")} vm_ok=${ok} vm_status=${String(sim.vm_status ?? "?")} gas_used=${String(sim.gas_used ?? "?")}`,
      );
      if (!ok) {
        push(`→ Move did not execute successfully; vm_status is the real error. ${JSON.stringify(sim).slice(0, 500)}`);
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      if (isNetworkSimError(msg)) {
        push(`Simulate ${label}: RPC unreachable (${msg}) — non-blocking; the transaction itself is fine.`);
      } else {
        push(`ERROR simulate ${label}: ${msg}`);
      }
      rpcParseErrorHints(msg).forEach(push);
      console.error(e);
    }
  };

  /** ⚡ Gasless: player signs as sender, a gas station signs as fee payer, then submit with both. */
  const sponsoredSubmit = async (label: string, build: () => SigilWalletPayload) => {
    if (!connected || !account) {
      push(`ERROR ${label} (gasless): connect a wallet first.`);
      return;
    }
    if (!SPONSOR_ENDPOINT) {
      push(`ERROR ${label} (gasless): no gas station configured (set VITE_SPONSOR_ENDPOINT).`);
      return;
    }
    let payload: SigilWalletPayload;
    try {
      payload = build();
    } catch (e) {
      push(`ERROR ${label} (gasless): ${e instanceof Error ? e.message : String(e)}`);
      return;
    }
    try {
      push(`${label} (gasless): building fee-payer tx…`);
      const transaction = await buildSponsoredTransaction({ aptos: sigil.aptos, sender: me(), data: payload.data as never });
      push(`${label} (gasless): sign in your wallet (you pay 0 gas)…`);
      const senderAuth = await signTransaction({ transactionOrPayload: transaction as never });
      push(`${label} (gasless): asking gas station ${SPONSOR_ENDPOINT} to cover gas…`);
      const { feePayerAuthenticator, feePayerAddress } = await requestSponsorship({ endpoint: SPONSOR_ENDPOINT, transaction });
      const committed = await submitSponsored({
        aptos: sigil.aptos,
        transaction,
        // The wallet adapter bundles its own @aptos-labs/ts-sdk copy, so its
        // AccountAuthenticator is a structurally-identical but distinct type.
        senderAuthenticator: senderAuth.authenticator as never,
        feePayerAuthenticator,
        feePayerAddress,
      });
      const ok = "success" in committed ? committed.success : false;
      if (ok) {
        push(`${label} (gasless): OK ${committed.hash} — gas paid by fee payer ${feePayerAddress}`);
      } else {
        push(`ERROR ${label} (gasless): ${JSON.stringify(committed).slice(0, 300)}`);
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      push(`ERROR ${label} (gasless): ${msg}`);
      if (/fetch|gas station|404|500/i.test(msg)) {
        push("→ The gas station endpoint must be running and funded. Locally, run the Arcade example (which serves /api/sponsor) or set VITE_SPONSOR_ENDPOINT to your deployed route.");
      }
      rpcParseErrorHints(msg).forEach(push);
      console.error(label, e);
    }
  };

  /** submit_score aborts without a registered game; surfaces prereqs into the log. */
  const onCheckPrereqs = async () => {
    if (!account) return;
    try {
      const gid = big("gameId");
      const countRes = await sigil.gamePlatform.viewGameCount();
      const hasRes = await sigil.gamePlatform.viewHasGame(gid);
      const playerOk = await sigil.gamePlatform.isPlayerRegistered(me());
      push(`game_count raw: ${JSON.stringify(countRes)}`);
      push(`has_game(${f("gameId")}) raw: ${JSON.stringify(hasRes)}`);
      push(`player registered already: ${JSON.stringify(playerOk)}`);
      const has = Array.isArray(hasRes) ? hasRes[0] : hasRes;
      if (has !== true) {
        push("→ If has_game is false, register a game for this publisher (Publisher tab → register_game) or fix game_id.");
      }
      if (!playerOk) {
        push("→ Not registered yet — that's fine: your first submit_score registers you. Enter a username and submit (one tx).");
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      push(`ERROR check: ${msg}`);
      rpcParseErrorHints(msg).forEach(push);
    }
  };

  const nightlyInstalled = wallets.find((w) => w.name === NIGHTLY_APTOS_WALLET_NAME);
  const nightlyNotDetected = notDetectedWallets.find((w) => w.name === NIGHTLY_APTOS_WALLET_NAME);
  const onWrongNetwork =
    connected &&
    network != null &&
    String(network.name).toLowerCase() !== NETWORK_LABEL.toLowerCase();

  // ---- tiny render helpers (functions, not components, to avoid input remount/focus loss) ----
  const field = (k: string, label: string, width = 96) => (
    <label style={{ marginRight: 10, fontSize: 14 }}>
      {label} <input value={f(k)} onChange={(e) => setF(k, e.target.value)} style={{ width }} />
    </label>
  );
  const check = (k: string, label: string) => (
    <label style={{ marginRight: 10, fontSize: 14 }}>
      <input type="checkbox" checked={flag(k)} onChange={(e) => setFlag(k, e.target.checked)} /> {label}
    </label>
  );
  const row = (children: React.ReactNode) => <div style={{ margin: "8px 0", display: "flex", flexWrap: "wrap", alignItems: "center", gap: 6 }}>{children}</div>;
  const card = (title: string, note: string, children: React.ReactNode) => (
    <div style={{ border: "1px solid #ddd", borderRadius: 8, padding: 12, marginBottom: 12 }}>
      <h4 style={{ margin: "0 0 4px" }}>{title}</h4>
      <p style={{ color: "#666", fontSize: 13, margin: "0 0 8px" }}>{note}</p>
      {children}
    </div>
  );
  const tabBtn = (id: Tab, label: string) => (
    <button
      type="button"
      onClick={() => setTab(id)}
      style={{
        padding: "6px 14px",
        border: "1px solid #ccc",
        borderBottom: tab === id ? "2px solid #2563eb" : "1px solid #ccc",
        background: tab === id ? "#eef2ff" : "#fff",
        fontWeight: tab === id ? 600 : 400,
        cursor: "pointer",
      }}
    >
      {label}
    </button>
  );

  const btn = (label: string, onClick: () => void, title?: string, bg = "#fff") => (
    <button type="button" onClick={onClick} title={title} style={{ padding: "4px 10px", border: "1px solid #ccc", borderRadius: 6, background: bg, cursor: "pointer", fontSize: 13 }}>
      {label}
    </button>
  );

  /**
   * The insight layer: one contract write rendered with Run / Simulate / ⚡Gasless / Inspect.
   * Inspect derives the Move fn id, the typed args, and the exact wallet payload from `build()`
   * so a dev sees (and copies) precisely what hits the chain.
   */
  const action = (a: ActionDesc) => {
    const isOpen = open[a.id] ?? false;
    let fnId = "";
    let args: unknown[] = [];
    let payloadJson = "";
    let buildErr = "";
    try {
      const p = a.build();
      fnId = p.data.function;
      args = p.data.functionArguments;
      payloadJson = JSON.stringify(p.data, (_k, v) => (typeof v === "bigint" ? v.toString() : v), 2);
    } catch (e) {
      buildErr = e instanceof Error ? e.message : String(e);
    }
    return (
      <div key={a.id} style={{ border: "1px solid #eee", borderRadius: 6, padding: "6px 8px", margin: "6px 0" }}>
        <div style={{ display: "flex", gap: 6, flexWrap: "wrap", alignItems: "center" }}>
          {btn(`▶ ${a.label}`, () => void write(a.label, a.build)(), "sign & submit", "#eef2ff")}
          {btn("Simulate", () => void simulate(a.label, a.build), "dry-run: gas + vm_status, no signature")}
          {a.sponsorable && SPONSOR_ENDPOINT
            ? btn("⚡ Gasless", () => void sponsoredSubmit(a.label, a.build), "submit sponsored — you pay 0 gas", "#fef9e7")
            : null}
          {btn(isOpen ? "▾ Inspect" : "▸ Inspect", () => setOpen((o) => ({ ...o, [a.id]: !isOpen })), "see the Move call + payload")}
        </div>
        {isOpen && (
          <div style={{ marginTop: 8, fontSize: 12, background: "#fafafa", border: "1px solid #eee", borderRadius: 6, padding: 8 }}>
            {buildErr ? (
              <div style={{ color: "#a22" }}>Fill in the fields to preview the call ({buildErr}).</div>
            ) : (
              <>
                <div style={{ marginBottom: 4 }}>
                  <strong>Move function</strong>
                  <div><code style={{ wordBreak: "break-all" }}>{fnId}</code></div>
                </div>
                <div style={{ marginBottom: 4 }}>
                  <strong>Arguments</strong>
                  <ol style={{ margin: "2px 0 2px 18px", padding: 0 }}>
                    {args.map((v, i) => (
                      <li key={i}>
                        <code>{typeof v === "bigint" ? v.toString() : JSON.stringify(v)}</code>{" "}
                        <span style={{ color: "#888" }}>({argTypeHint(v)})</span>
                      </li>
                    ))}
                    {args.length === 0 ? <li style={{ color: "#888" }}>none</li> : null}
                  </ol>
                </div>
                <div style={{ marginBottom: 4 }}>
                  <strong>SDK call</strong> {btn("copy", () => copy(a.sdk))}
                  <pre style={{ margin: "2px 0", whiteSpace: "pre-wrap", wordBreak: "break-word" }}>{a.sdk}</pre>
                </div>
                <div>
                  <strong>Wallet payload</strong> {btn("copy", () => copy(payloadJson))}
                  <pre style={{ margin: "2px 0", whiteSpace: "pre-wrap", wordBreak: "break-word" }}>{payloadJson}</pre>
                  <div style={{ color: "#888" }}>Pass this object to <code>signAndSubmitTransaction(payload)</code>.</div>
                </div>
              </>
            )}
          </div>
        )}
      </div>
    );
  };

  // ---- action descriptors (single source of truth for Player tab + Guided steps) ----
  const A = {
    submitScore: (): ActionDesc => ({
      id: "submitScore",
      label: "submit_score",
      sdk: `sigil.gamePlatform.walletPayloadSubmitScore({ gameId: ${f("gameId")}n, score: ${f("score")}n, username: "${f("username").trim()}" })`,
      build: () => sigil.gamePlatform.walletPayloadSubmitScore({ gameId: big("gameId"), score: big("score"), username: f("username").trim() }),
      sponsorable: true,
    }),
    startQuest: (): ActionDesc => ({
      id: "startQuest",
      label: "quests::start_quest",
      sdk: `sigil.quests.walletPayloadStartQuest({ questId: ${f("questId")}n })`,
      build: () => sigil.quests.walletPayloadStartQuest({ questId: big("questId") }),
      sponsorable: true,
    }),
    submitScoreWithQuest: (): ActionDesc => ({
      id: "submitScoreWithQuest",
      label: "quests::submit_score_with_quest",
      sdk: `sigil.quests.walletPayloadSubmitScoreWithQuest({ gameId: ${f("gameId")}n, score: ${f("score")}n })`,
      build: () => sigil.quests.walletPayloadSubmitScoreWithQuest({ gameId: big("gameId"), score: big("score") }),
      sponsorable: true,
    }),
    updateQuest: (): ActionDesc => ({
      id: "updateQuest",
      label: "quests::update_progress",
      sdk: `sigil.quests.walletPayloadUpdateQuestProgress({ questId: ${f("questId")}n })`,
      build: () => sigil.quests.walletPayloadUpdateQuestProgress({ questId: big("questId") }),
    }),
    claimReward: (): ActionDesc => ({
      id: "claimReward",
      label: "rewards::claim_reward",
      sdk: `sigil.rewards.walletPayloadClaimReward({ achievementId: ${f("rewardAchId")}n })`,
      build: () => sigil.rewards.walletPayloadClaimReward({ achievementId: big("rewardAchId") }),
      sponsorable: true,
    }),
    createGuild: (): ActionDesc => ({
      id: "createGuild",
      label: "guilds::create_guild",
      sdk: `sigil.guilds.walletPayloadCreateGuild({ name: "${f("guildName").trim()}" })`,
      build: () => sigil.guilds.walletPayloadCreateGuild({ name: f("guildName").trim() }),
      sponsorable: true,
    }),
    joinGuild: (): ActionDesc => ({
      id: "joinGuild",
      label: "guilds::join_guild",
      sdk: `sigil.guilds.walletPayloadJoinGuild({ guildId: ${f("guildId")}n })`,
      build: () => sigil.guilds.walletPayloadJoinGuild({ guildId: big("guildId") }),
    }),
    leaveGuild: (): ActionDesc => ({
      id: "leaveGuild",
      label: "guilds::leave_guild",
      sdk: `sigil.guilds.walletPayloadLeaveGuild()`,
      build: () => sigil.guilds.walletPayloadLeaveGuild(),
    }),
    executeMerge: (): ActionDesc => ({
      id: "executeMerge",
      label: "merge::execute_merge",
      sdk: `sigil.merge.walletPayloadExecuteMerge({ recipeId: ${f("recipeId")}n })`,
      build: () => sigil.merge.walletPayloadExecuteMerge({ recipeId: big("recipeId") }),
    }),
  };

  // ---- Guided scenario: "Sigil Arcade" — a real game's player lifecycle ----
  type Step = {
    title: string;
    story: string;
    why?: string;
    body: React.ReactNode;
  };
  const guidedSteps: Step[] = [
    {
      title: "1 · A player opens Sigil Arcade",
      story:
        "Maya launches your arcade game. Before she can appear on a leaderboard, the game needs a registered game_id on chain. As the publisher you registered game 0 at deploy time — let's confirm it exists.",
      why: "Reads are free and need no wallet signature. Always check prerequisites before a write so you can give players a clear error instead of an on-chain abort.",
      body: row(<>
        {field("gameId", "game_id", 60)}
        {btn("Check game exists", () => void onCheckPrereqs())}
        {btn("game_count", () => void view("game_count", () => sigil.gamePlatform.viewGameCount())())}
      </>),
    },
    {
      title: "2 · Maya scores for the first time",
      story:
        "Maya hits 1000. Your game records it on chain with submit_score. Her first score also auto-registers her as a player and sets her username — no separate signup transaction. Try ⚡ Gasless: she pays 0 gas, a sponsor covers it.",
      why: "Lazy registration on first score removes an onboarding step. The same call updates the leaderboard for game_id automatically.",
      body: <>
        {row(<>{field("username", "username", 130)}{field("score", "score", 90)}</>)}
        {action(A.submitScore())}
      </>,
    },
    {
      title: "3 · Maya checks the leaderboard",
      story: "Her score is now ranked. Pull the top entries for the game and her personal score summary.",
      why: "View functions return the same data your game UI renders — leaderboards, ranks, and a player's best/last score.",
      body: row(<>
        {btn("top entries (game_id)", () => void view("top_entries_for_game", () => sigil.leaderboard.viewTopEntriesForGame(big("gameId")))())}
        {btn("my score_summary", () => void view("score_summary (me)", () => sigil.gamePlatform.viewScoreSummary({ player: me(), gameId: big("gameId") }))())}
      </>),
    },
    {
      title: "4 · Maya takes on a quest",
      story:
        "Your game offers a 'Hit 1000' quest. She opts in with start_quest, then advances it. Score quests advance only through submit_score_with_quest (plain submit_score just writes the leaderboard).",
      why: "Quests are opt-in missions. The wrapper call records progress against the started quest in the same transaction as the score.",
      body: <>
        {row(field("questId", "quest_id", 80))}
        {action(A.startQuest())}
        {action(A.submitScoreWithQuest())}
      </>,
    },
    {
      title: "5 · Maya claims her reward",
      story:
        "Completing the achievement tied to a reward lets her claim it — an FA (APT) or NFT lands in her wallet in a single transaction. Claiming twice aborts with E_ALREADY_CLAIMED.",
      why: "Rewards are attached to achievements by the publisher; claim_reward distributes from the rewards resource account with no backend.",
      body: <>
        {row(field("rewardAchId", "achievement_id", 110))}
        {action(A.claimReward())}
      </>,
    },
    {
      title: "6 · Maya joins a guild",
      story: "Social layer: she founds or joins a guild to play with friends. One guild membership at a time.",
      why: "Guilds are lightweight on-chain groups keyed by id; create/join/leave are all single calls.",
      body: <>
        {row(<>{field("guildName", "name", 140)}{field("guildId", "guild_id", 80)}</>)}
        {action(A.createGuild())}
        {action(A.joinGuild())}
        {action(A.leaveGuild())}
      </>,
    },
    {
      title: "7 · The season standings",
      story:
        "Your game runs timed seasons over a leaderboard. While a season is active, Maya's scores count toward it. Check the current season and her standing.",
      why: "Seasons are publisher-managed (create/start/finalize in the Publisher tab). Players just play — their scores land on the season's board automatically.",
      body: row(<>
        {btn("current season", () => void view("current_season", () => sigil.seasons.viewCurrentSeason())())}
        {btn("top entries (game_id)", () => void view("top_entries_for_game", () => sigil.leaderboard.viewTopEntriesForGame(big("gameId")))())}
      </>),
    },
  ];

  return (
    <div style={{ minHeight: "100vh", fontFamily: "system-ui", background: "linear-gradient(160deg, #eef2fb 0%, #f6f8ff 45%, #eafbf0 100%)" }}>
    <div style={{ maxWidth: 1100, margin: "0 auto", padding: "28px 16px 56px" }}>
      <div style={{ textAlign: "center", background: "#ffffff", border: "1px solid #e3e8f3", borderTop: "4px solid #2bb24c", borderRadius: 16, padding: "22px 16px", marginBottom: 22, boxShadow: "0 8px 26px rgba(20,30,80,0.07)" }}>
        <img src="/logo.png" alt="Aptos Sigil" height={128} style={{ display: "inline-block" }} />
        <h1 style={{ margin: "10px 0 0", fontSize: 26, color: "#1c2333" }}>Sigil — game-dev console <span style={{ color: "#2bb24c" }}>(Aptos {NETWORK_LABEL})</span></h1>
      </div>
      <p style={{ color: "#444" }}>
        A hybrid console for Aptos game devs: a <strong>Guided</strong> walkthrough of a real game (Sigil Arcade) plus the raw
        technical tabs. Every action shows the Move call, typed args, and the exact SDK + wallet payload — and can be{" "}
        <strong>simulated</strong> before you sign.
      </p>
      <p style={{ color: "#444" }}>
        Module: <code>{DEFAULT_MODULE}</code>. Override with <code>VITE_SIGIL_MODULE_ADDRESS</code>.
      </p>
      <p style={{ color: "#444", fontSize: 14 }}>
        App fullnode (views + simulate):{" "}
        <code style={{ fontSize: 12 }}>{APP_FULLNODE ?? `TS SDK default for ${NETWORK_LABEL}`}</code>
        {APTOS_API_KEY ? <span style={{ color: "#284", marginLeft: 8 }}>API key: on</span> : null}
        <span style={{ marginLeft: 8 }}>Gas station: <code style={{ fontSize: 12 }}>{SPONSOR_ENDPOINT || "(disabled)"}</code></span>
      </p>
      <p style={{ color: "#a60", fontSize: 13 }}>
        Your wallet’s <strong>{NETWORK_LABEL}</strong> RPC must match this app’s fullnode, or simulate (and Approve) will fail.
      </p>

      {!connected && (
        <section>
          <h2>Connect Nightly</h2>
          <p style={{ color: "#666", fontSize: 13 }}>
            This console uses{" "}
            <a href="https://docs.nightly.app/docs/aptos/aptos/detection" target="_blank" rel="noreferrer">
              Nightly on Aptos
            </a>{" "}
            ({NETWORK_LABEL}). Install the extension and select the <strong>Aptos</strong> account.
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
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", flexWrap: "wrap", gap: 8 }}>
            <div style={{ fontSize: 14, color: "#666" }}>
              {wallet?.name ? <strong>{wallet.name}</strong> : null}
              {network ? (
                <span style={{ color: onWrongNetwork ? "#a60" : "#666", marginLeft: 8 }}>
                  {String(network.name)}
                  {network.chainId != null ? ` (chain ${network.chainId})` : ""}
                </span>
              ) : null}
              <div>
                <code style={{ fontSize: 12 }}>{account.address.toString()}</code>
              </div>
            </div>
            <div>
              {onWrongNetwork ? (
                <button type="button" onClick={() => void onSwitchNetwork()} style={{ marginRight: 8 }}>
                  Switch to {NETWORK_LABEL}
                </button>
              ) : null}
              <button type="button" onClick={() => disconnect()}>
                Disconnect
              </button>
            </div>
          </div>

          <div style={{ display: "flex", gap: 0, marginTop: 16 }}>
            {tabBtn("guided", "Guided (Sigil Arcade)")}
            {tabBtn("player", "Player")}
            {tabBtn("publisher", "Publisher (admin)")}
            {tabBtn("views", "Views (read-only)")}
          </div>
          <div style={{ border: "1px solid #ccc", borderTop: "none", padding: 16 }}>

            {tab === "guided" && (
              <>
                <p style={{ color: "#444", fontSize: 14 }}>
                  Follow <strong>Maya</strong> through a real game's on-chain lifecycle. Each step explains the <em>why</em>, then
                  lets you <strong>Simulate</strong> (free dry-run), <strong>Run</strong> (sign &amp; submit), or go{" "}
                  <strong>⚡ Gasless</strong>, and <strong>Inspect</strong> the exact Move call + SDK code.
                </p>
                <div style={{ display: "flex", gap: 6, flexWrap: "wrap", margin: "8px 0" }}>
                  {guidedSteps.map((s, i) => (
                    <button
                      key={i}
                      type="button"
                      onClick={() => setStep(i)}
                      style={{
                        padding: "4px 9px",
                        border: "1px solid #ccc",
                        borderRadius: 14,
                        background: step === i ? "#2563eb" : "#fff",
                        color: step === i ? "#fff" : "#333",
                        cursor: "pointer",
                        fontSize: 12,
                      }}
                    >
                      {i + 1}
                    </button>
                  ))}
                </div>
                {(() => {
                  const s = guidedSteps[step];
                  return (
                    <div style={{ border: "1px solid #ddd", borderRadius: 8, padding: 14 }}>
                      <h3 style={{ margin: "0 0 6px" }}>{s.title}</h3>
                      <p style={{ margin: "0 0 8px", color: "#333" }}>{s.story}</p>
                      {s.why ? (
                        <p style={{ margin: "0 0 10px", color: "#555", fontSize: 13, borderLeft: "3px solid #2563eb", paddingLeft: 10 }}>
                          <strong>Why:</strong> {s.why}
                        </p>
                      ) : null}
                      {s.body}
                      <div style={{ marginTop: 12, display: "flex", gap: 8 }}>
                        {btn("← Prev", () => setStep((n) => Math.max(0, n - 1)))}
                        {btn("Next →", () => setStep((n) => Math.min(guidedSteps.length - 1, n + 1)), undefined, "#eef2ff")}
                      </div>
                    </div>
                  );
                })()}
              </>
            )}

            {tab === "player" && (
              <>
                <p style={{ color: "#666", fontSize: 13 }}>
                  Player write flows — each with <strong>Run / Simulate / Inspect</strong> (and ⚡ Gasless where a sponsor applies).
                  Shared <code>game_id</code> / <code>score</code> / <code>username</code> below feed the calls.
                </p>
                {row(<>
                  {field("username", "username", 130)}
                  {field("gameId", "game_id", 60)}
                  {field("score", "score", 90)}
                </>)}

                {card("game_platform", "First submit_score registers you (sets username) and records the score — one tx, no separate register step.", <>
                  {row(btn("Check game exists", () => void onCheckPrereqs()))}
                  {action(A.submitScore())}
                </>)}

                {card("rewards", "Claim the FA/NFT reward attached to an unlocked achievement.", <>
                  {row(field("rewardAchId", "achievement_id", 110))}
                  {action(A.claimReward())}
                </>)}

                {card("quests", "Opt into a quest, then advance it: score quests via submit_score_with_quest (uses game_id/score above), achievement/rank quests via update_progress.", <>
                  {row(field("questId", "quest_id", 80))}
                  {action(A.startQuest())}
                  {action(A.submitScoreWithQuest())}
                  {action(A.updateQuest())}
                </>)}

                {card("guilds", "Found a guild, join one by id, or leave your current guild.", <>
                  {row(field("guildName", "name", 140))}
                  {action(A.createGuild())}
                  {row(field("guildId", "guild_id", 80))}
                  {action(A.joinGuild())}
                  {action(A.leaveGuild())}
                </>)}

                {card("merge", "Consume a recipe's inputs from your inventory to mint its output (needs granted items — see Publisher tab).", <>
                  {row(field("recipeId", "recipe_id", 80))}
                  {action(A.executeMerge())}
                </>)}
              </>
            )}

            {tab === "publisher" && (
              <>
                <p style={{ color: "#a22", fontSize: 13, borderLeft: "3px solid #c44", paddingLeft: 10 }}>
                  These are <strong>owner/admin</strong> calls. They abort unless the connected wallet is the publisher (or a
                  roles-authorized admin/operator) for the module address above. Most are already initialized on the shared demo
                  module — re-running <code>init_*</code> there will abort (expected).
                </p>

                {card("game_platform", "One-time publisher init, then register a game (returns a new game_id).", row(<>
                  <button type="button" onClick={write("game_platform::init", () => sigil.gamePlatform.walletPayloadInit())}>init</button>
                  {field("gameTitle", "title", 140)}
                  <button type="button" onClick={write("game_platform::register_game", () => sigil.gamePlatform.walletPayloadRegisterGame(f("gameTitle").trim()))}>register_game</button>
                </>))}

                {card("leaderboard", "Create a board bound to game_id; submit_score then updates it automatically.", <>
                  {row(<button type="button" onClick={write("leaderboard::init", () => sigil.leaderboard.walletPayloadInit())}>init_leaderboards</button>)}
                  {row(<>
                    {field("lbDecimals", "decimals", 70)}
                    {field("lbMin", "min", 90)}
                    {field("lbMax", "max", 110)}
                    {field("lbRetain", "retain", 70)}
                  </>)}
                  {row(<>
                    {check("lbAscending", "ascending")}
                    {check("lbAllowMultiple", "allow multiple")}
                    <button type="button" onClick={write("leaderboard::create_leaderboard", () => sigil.leaderboard.walletPayloadCreateLeaderboard({ gameId: big("gameId"), decimals: big("lbDecimals"), minScore: big("lbMin"), maxScore: big("lbMax"), isAscending: flag("lbAscending"), allowMultiple: flag("lbAllowMultiple"), scoresToRetain: big("lbRetain") }))}>create_leaderboard (game_id above)</button>
                  </>)}
                </>)}

                {card("achievements", "Init, then create a score achievement (badge_uri optional).", <>
                  {row(<button type="button" onClick={write("achievements::init", () => sigil.achievements.walletPayloadInit())}>init_achievements</button>)}
                  {row(<>
                    {field("achTitle", "title", 130)}
                    {field("achDesc", "description", 160)}
                    {field("achMin", "min_score", 90)}
                    {field("achBadge", "badge_uri", 120)}
                    <button type="button" onClick={write("achievements::create", () => sigil.achievements.walletPayloadCreate({ title: f("achTitle"), description: f("achDesc"), minScore: big("achMin"), badgeUri: f("achBadge") }))}>create</button>
                  </>)}
                </>)}

                {card("rewards", "Init the reward vault, then attach an FA reward (defaults to APT) to an achievement.", <>
                  {row(<button type="button" onClick={write("rewards::init", () => sigil.rewards.walletPayloadInit())}>init_rewards</button>)}
                  {row(<>
                    {field("rewardAchId", "achievement_id", 110)}
                    {field("rewardAmount", "amount (octas)", 120)}
                    {field("rewardSupply", "supply", 80)}
                    <button type="button" onClick={write("rewards::attach_fa_reward", () => sigil.rewards.walletPayloadAttachFaReward({ achievementId: big("rewardAchId"), amount: big("rewardAmount"), supply: big("rewardSupply") }))}>attach_fa_reward</button>
                  </>)}
                </>)}

                {card("quests", "Init, then create a score quest (reward_id ties to an achievement reward; 0 = none).", <>
                  {row(<button type="button" onClick={write("quests::init", () => sigil.quests.walletPayloadInit())}>init_quests</button>)}
                  {row(<>
                    {field("questTitle", "title", 130)}
                    {field("questDesc", "description", 170)}
                  </>)}
                  {row(<>
                    {field("questTarget", "target_score", 110)}
                    {field("questReward", "reward_id", 90)}
                    {check("questSeasonal", "seasonal")}
                    <button type="button" onClick={write("quests::create_score_quest", () => sigil.quests.walletPayloadCreateScoreQuest({ title: f("questTitle"), description: f("questDesc"), gameId: big("gameId"), targetScore: big("questTarget"), rewardId: big("questReward"), isSeasonal: flag("questSeasonal") }))}>create_score_quest (game_id above)</button>
                  </>)}
                </>)}

                {card("seasons", "Create a season over a leaderboard, then start/end/finalize by id.", <>
                  {row(<button type="button" onClick={write("seasons::init", () => sigil.seasons.walletPayloadInit())}>init_seasons</button>)}
                  {row(<>
                    {field("seasonName", "name", 120)}
                    {field("seasonStart", "start (unix)", 100)}
                    {field("seasonEnd", "end (unix)", 100)}
                    {field("seasonLb", "leaderboard_id", 110)}
                    {field("seasonPrize", "prize_pool", 100)}
                  </>)}
                  {row(<button type="button" onClick={write("seasons::create_season", () => sigil.seasons.walletPayloadCreateSeason({ name: f("seasonName"), startTime: big("seasonStart"), endTime: big("seasonEnd"), leaderboardId: big("seasonLb"), prizePool: big("seasonPrize") }))}>create_season</button>)}
                  {row(<>
                    {field("seasonId", "season_id", 90)}
                    <button type="button" onClick={write("seasons::start_season", () => sigil.seasons.walletPayloadStartSeason({ seasonId: big("seasonId") }))}>start</button>
                    <button type="button" onClick={write("seasons::end_season", () => sigil.seasons.walletPayloadEndSeason({ seasonId: big("seasonId") }))}>end</button>
                    <button type="button" onClick={write("seasons::finalize_season", () => sigil.seasons.walletPayloadFinalizeSeason({ seasonId: big("seasonId") }))}>finalize</button>
                  </>)}
                </>)}

                {card("treasury", "Init the vault, deposit APT, or withdraw to a recipient (publisher-signed).", <>
                  {row(<>
                    <button type="button" onClick={write("treasury::init", () => sigil.treasury.walletPayloadInit())}>init_treasury</button>
                    {field("treasuryAmount", "deposit (octas)", 120)}
                    <button type="button" onClick={write("treasury::deposit", () => sigil.treasury.walletPayloadDeposit({ amount: big("treasuryAmount") }))}>deposit</button>
                  </>)}
                  {row(<>
                    {field("withdrawTo", "recipient", 320)}
                    {field("withdrawAmount", "amount", 100)}
                    <button type="button" onClick={write("treasury::withdraw", () => sigil.treasury.walletPayloadWithdraw({ recipient: f("withdrawTo").trim(), amount: big("withdrawAmount") }))}>withdraw</button>
                  </>)}
                </>)}

                {card("merge / roles / guilds", "Recipe + item grants, role grants, and guild init.", <>
                  {row(<>
                    <button type="button" onClick={write("merge::init", () => sigil.merge.walletPayloadInit())}>init_merge</button>
                    {field("recipeIn", "in_item", 70)}
                    {field("recipeInQty", "in_qty", 60)}
                    {field("recipeOut", "out_item", 70)}
                    {field("recipeOutQty", "out_qty", 60)}
                    <button type="button" onClick={write("merge::register_recipe", () => sigil.merge.walletPayloadRegisterRecipe({ inputItemId: big("recipeIn"), inputQty: big("recipeInQty"), outputItemId: big("recipeOut"), outputQty: big("recipeOutQty") }))}>register_recipe</button>
                  </>)}
                  {row(<>
                    {field("grantItem", "item_id", 70)}
                    {field("grantQty", "qty", 60)}
                    <button type="button" onClick={write("merge::grant_items (to self)", () => sigil.merge.walletPayloadGrantItems({ player: me(), itemId: big("grantItem"), qty: big("grantQty") }))}>grant_items → me</button>
                  </>)}
                  {row(<>
                    {field("adminAddr", "admin address", 320)}
                    <button type="button" onClick={write("roles::init", () => sigil.roles.walletPayloadInit())}>init_roles</button>
                    <button type="button" onClick={write("roles::add_admin", () => sigil.roles.walletPayloadAddAdmin({ admin: f("adminAddr").trim() }))}>add_admin</button>
                    <button type="button" onClick={write("guilds::init", () => sigil.guilds.walletPayloadInit())}>init_guilds</button>
                  </>)}
                </>)}
              </>
            )}

            {tab === "views" && (
              <>
                <p style={{ color: "#666", fontSize: 13 }}>
                  Read-only — no wallet signature. Uses <code>game_id</code> / ids from the fields above and your connected address.
                </p>
                {card("game_platform", "Games, your registration, and your scores.", row(<>
                  <button type="button" onClick={view("game_count", () => sigil.gamePlatform.viewGameCount())}>game_count</button>
                  <button type="button" onClick={view("has_game", () => sigil.gamePlatform.viewHasGame(big("gameId")))}>has_game</button>
                  <button type="button" onClick={view("score_summary (me)", () => sigil.gamePlatform.viewScoreSummary({ player: me(), gameId: big("gameId") }))}>score_summary</button>
                  <button type="button" onClick={view("get_scores (me)", () => sigil.gamePlatform.viewPlayerGameScores({ player: me(), gameId: big("gameId") }))}>get_scores</button>
                </>))}
                {card("leaderboard", "Ranked top-N per game, plus sequential-id reads.", row(<>
                  <button type="button" onClick={view("leaderboard_count", () => sigil.leaderboard.viewLeaderboardCount())}>count</button>
                  <button type="button" onClick={view("top_entries_for_game", () => sigil.leaderboard.viewTopEntriesForGame(big("gameId")))}>top (game_id)</button>
                  <button type="button" onClick={view("top_entries (lb 0)", () => sigil.leaderboard.viewTopEntries(0))}>top (lb 0)</button>
                  <button type="button" onClick={view("config (lb 0)", () => sigil.leaderboard.viewLeaderboardConfig(0))}>config (lb 0)</button>
                </>))}
                {card("achievements", "Catalog + your unlocks.", row(<>
                  <button type="button" onClick={view("achievement_count", () => sigil.achievements.viewAchievementCount())}>count</button>
                  <button type="button" onClick={view("list_catalog", () => sigil.achievements.viewCatalog())}>catalog</button>
                  <button type="button" onClick={view("unlocked_for (me)", () => sigil.achievements.viewUnlockedFor({ player: me() }))}>unlocked (me)</button>
                </>))}
                {card("rewards", "Reward inventory.", row(<>
                  <button type="button" onClick={view("list_rewarded", () => sigil.rewards.viewRewardedAchievements())}>rewarded list</button>
                  <button type="button" onClick={view("get_reward (achievement_id)", () => sigil.rewards.viewReward(big("rewardAchId")))}>get_reward</button>
                </>))}
                {card("quests", "Quest catalog + your progress.", row(<>
                  <button type="button" onClick={view("quest_count", () => sigil.quests.viewQuestCount())}>count</button>
                  <button type="button" onClick={view("get_quest (quest_id)", () => sigil.quests.viewQuest(big("questId")))}>get_quest</button>
                  <button type="button" onClick={view("progress (me)", () => sigil.quests.viewQuestProgress({ questId: big("questId"), player: me() }))}>my progress</button>
                  <button type="button" onClick={view("active_quests (me)", () => sigil.quests.viewActiveQuests({ player: me() }))}>active (me)</button>
                </>))}
                {card("seasons", "Season state.", row(<>
                  <button type="button" onClick={view("season_count", () => sigil.seasons.viewSeasonCount())}>count</button>
                  <button type="button" onClick={view("current_season", () => sigil.seasons.viewCurrentSeason())}>current</button>
                  <button type="button" onClick={view("get_season (season_id)", () => sigil.seasons.viewSeason(big("seasonId")))}>get_season</button>
                </>))}
                {card("guilds / merge", "Guild membership and item inventory.", row(<>
                  <button type="button" onClick={view("guild_count", () => sigil.guilds.viewGuildCount())}>guild_count</button>
                  <button type="button" onClick={view("player_guild_id (me)", () => sigil.guilds.viewPlayerGuildId({ player: me() }))}>my guild</button>
                  <button type="button" onClick={view("recipe_count", () => sigil.merge.viewRecipeCount())}>recipe_count</button>
                  <button type="button" onClick={view("item_qty (me, grant item)", () => sigil.merge.viewItemQty({ player: me(), itemId: big("grantItem") }))}>my item_qty</button>
                </>))}
                {card("treasury / roles / attest", "Vault balance, your role, and module init flags.", row(<>
                  <button type="button" onClick={view("treasury balance", () => sigil.treasury.viewBalance())}>treasury balance</button>
                  <button type="button" onClick={view("treasury stats", () => sigil.treasury.viewStats())}>treasury stats</button>
                  <button type="button" onClick={view("role_summary (me)", () => sigil.roles.viewRoleSummary({ addr: me() }))}>my role</button>
                  <button type="button" onClick={view("attest initialized", () => sigil.attest.viewIsInitialized())}>attest init?</button>
                </>))}
              </>
            )}
          </div>
        </section>
      )}

      <h2>Log</h2>
      <div style={{ marginBottom: 6 }}>
        <button type="button" onClick={() => setLog([])}>Clear log</button>
      </div>
      <pre
        style={{
          background: "#111",
          color: "#e0e0e0",
          padding: 12,
          borderRadius: 8,
          minHeight: 240,
          maxHeight: 480,
          overflow: "auto",
          fontSize: 12,
          whiteSpace: "pre-wrap",
          wordBreak: "break-word",
          width: "100%",
          boxSizing: "border-box",
        }}
      >
        {log.length ? log.join("\n") : "…"}
      </pre>
    </div>
    </div>
  );
}
