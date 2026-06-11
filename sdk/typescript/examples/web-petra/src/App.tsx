import { useWallet, WalletItem } from "@aptos-labs/wallet-adapter-react";
import { AccountAddress, Network } from "@aptos-labs/ts-sdk";
import React, { useMemo, useState } from "react";
import { createAptosClient, DEFAULT_SIGIL_TX_GAS, SigilClient } from "../../../src/client.js";

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
      "→ Network/RPC error reaching the fullnode — commonly a devnet 504 “upstream request timeout” when the simulate endpoint is overloaded. This is infrastructure, NOT your transaction.",
    );
    lines.push(
      "→ The submit path is usually still healthy: click the action and Approve in your wallet. If Approve stays disabled, the wallet ran the same simulate against its own RPC — switch the wallet’s Devnet Custom RPC (e.g. https://api.devnet.aptoslabs.com/v1) or retry in a minute.",
    );
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

/** Reject after `ms` so a stuck simulate (e.g. devnet 504) fails fast instead of hanging ~30s. */
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

type Tab = "player" | "publisher" | "views";

/** Wallet-adapter `InputTransactionData`-shaped payload (matches the SDK's `walletPayload*` return). */
type SigilWalletPayload = {
  data: { function: string; typeArguments?: string[]; functionArguments: unknown[] };
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
  } = useWallet();
  const [log, setLog] = useState<string[]>([]);
  const [tab, setTab] = useState<Tab>("player");

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
        push("→ You declined the wallet popup, or the request was cancelled (closing a stuck “simulating…” counts). Try again and approve, or Disconnect and reconnect.");
        push("→ If the popup hung a long time before this, fix RPC errors above so the wallet’s simulation can finish.");
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
        push("→ If has_game is false, register a game for this publisher on THIS network (Publisher tab → register_game) or fix game_id.");
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

  /** Same simulate path Nightly uses; if this is fast but Nightly hangs, change Nightly’s Aptos devnet RPC. */
  const onPreflightSubmitScore = async () => {
    if (!account) return;
    let gid: bigint;
    let sc: bigint;
    try {
      gid = big("gameId");
      sc = big("score");
    } catch {
      push("ERROR preflight: game_id and score must be integers");
      return;
    }
    push("Preflight: building transaction…");
    try {
      const payload = sigil.gamePlatform.walletPayloadSubmitScore({ gameId: gid, score: sc, username: f("username").trim() || "preflight" });
      const t0 = performance.now();
      const transaction = await sigil.aptos.transaction.build.simple({
        sender: me(),
        data: payload.data,
        options: {
          ...DEFAULT_SIGIL_TX_GAS,
          expireTimestamp: Math.floor(Date.now() / 1000) + 600,
        },
      });
      push("Preflight: simulating…");
      const SIM_TIMEOUT_MS = 12_000;
      let sims: unknown[];
      try {
        sims = await withTimeout(
          sigil.aptos.transaction.simulate.simple({
            signerPublicKey: account.publicKey as never,
            transaction,
          }),
          SIM_TIMEOUT_MS,
          "simulate (with key)",
        );
      } catch (simErr) {
        push(
          `Preflight: simulate with wallet public key failed (${simErr instanceof Error ? simErr.message : String(simErr)}), retrying without key…`,
        );
        sims = await withTimeout(
          sigil.aptos.transaction.simulate.simple({ transaction }),
          SIM_TIMEOUT_MS,
          "simulate (no key)",
        );
      }
      const sim = sims[0] as Record<string, unknown> | undefined;
      const ms = Math.round(performance.now() - t0);
      if (!sim) {
        push(`ERROR preflight: empty simulate result after ${ms}ms`);
        return;
      }
      const vm = String(sim.vm_status ?? "?");
      const ok = isTxSimulationSuccess(sim);
      push(
        `Preflight simulate (${ms}ms): success=${String(sim.success ?? "?")} vm_ok=${ok} vm_status=${vm} gas_used=${String(sim.gas_used ?? "?")}`,
      );
      if (!ok) {
        push(`→ Move did not execute successfully; vm_status is the real error. Snippet: ${JSON.stringify(sim).slice(0, 800)}`);
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      if (isNetworkSimError(msg)) {
        push(`Preflight: simulate could not reach the RPC (${msg}) — treating as non-blocking.`);
        push("→ This is an RPC/network problem, NOT your transaction. submit_score itself is valid.");
      } else {
        push(`ERROR preflight: ${msg}`);
      }
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

  return (
    <div style={{ fontFamily: "system-ui", maxWidth: 1100, margin: "2rem auto", padding: 16 }}>
      <h1>Sigil + Nightly — module testing console (Aptos devnet)</h1>
      <p style={{ color: "#444" }}>
        Module: <code>{DEFAULT_MODULE}</code>. Set <code>VITE_SIGIL_MODULE_ADDRESS</code> to override.
      </p>
      <p style={{ color: "#444", fontSize: 14 }}>
        App fullnode (views + preflight):{" "}
        <code style={{ fontSize: 12 }}>
          {APP_FULLNODE ?? "TS SDK default for Network.DEVNET (set VITE_APTOS_FULLNODE_URL to match Nightly)"}
        </code>
        {APTOS_API_KEY ? (
          <span style={{ color: "#284", marginLeft: 8 }}>API key: on</span>
        ) : (
          <span style={{ color: "#666", marginLeft: 8, fontSize: 13 }}>
            Optional: set <code style={{ fontSize: 12 }}>VITE_APTOS_API_KEY</code> for higher RPC limits
          </span>
        )}
      </p>
      <p style={{ color: "#a60", fontSize: 13 }}>
        <strong>Staging vs public devnet</strong> are different chains. Your wallet’s Devnet Custom RPC must match this app’s
        fullnode, or simulation (and Approve) will fail. Public devnet:{" "}
        <code style={{ fontSize: 12 }}>https://api.devnet.aptoslabs.com/v1</code>.
      </p>

      {!connected && (
        <section>
          <h2>Connect Nightly</h2>
          <p style={{ color: "#666", fontSize: 13 }}>
            This demo uses{" "}
            <a href="https://docs.nightly.app/docs/aptos/aptos/detection" target="_blank" rel="noreferrer">
              Nightly on Aptos
            </a>{" "}
            (devnet). Install the extension and select the <strong>Aptos</strong> account.
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
                <button type="button" onClick={() => void onSwitchToDevnet()} style={{ marginRight: 8 }}>
                  Switch to Devnet
                </button>
              ) : null}
              <button type="button" onClick={() => disconnect()}>
                Disconnect
              </button>
            </div>
          </div>

          <div style={{ display: "flex", gap: 0, marginTop: 16 }}>
            {tabBtn("player", "Player")}
            {tabBtn("publisher", "Publisher (admin)")}
            {tabBtn("views", "Views (read-only)")}
          </div>
          <div style={{ border: "1px solid #ccc", borderTop: "none", padding: 16 }}>
            {/* shared id fields */}
            {row(<>
              {field("username", "username", 130)}
              {field("gameId", "game_id", 60)}
              {field("score", "score", 90)}
            </>)}

            {tab === "player" && (
              <>
                {card("game_platform", "First submit_score registers you (sets username) and records the score — one tx, no separate register step.", row(<>
                  <button type="button" onClick={() => void onCheckPrereqs()}>Check game exists</button>
                  <button type="button" onClick={write("submit_score", () => sigil.gamePlatform.walletPayloadSubmitScore({ gameId: big("gameId"), score: big("score"), username: f("username").trim() }))}>submit_score</button>
                  <button type="button" onClick={() => void onPreflightSubmitScore()}>Preflight simulate</button>
                </>))}

                {card("rewards", "Claim the FA/NFT reward attached to an unlocked achievement.", row(<>
                  {field("rewardAchId", "achievement_id", 110)}
                  <button type="button" onClick={write("rewards::claim_reward", () => sigil.rewards.walletPayloadClaimReward({ achievementId: big("rewardAchId") }))}>claim_reward</button>
                </>))}

                {card("quests", "Opt into a quest, then push your progress (score-driven quests also advance via submit_score).", row(<>
                  {field("questId", "quest_id", 80)}
                  <button type="button" onClick={write("quests::start_quest", () => sigil.quests.walletPayloadStartQuest({ questId: big("questId") }))}>start_quest</button>
                  <button type="button" onClick={write("quests::update_quest_progress", () => sigil.quests.walletPayloadUpdateQuestProgress({ questId: big("questId") }))}>update_progress</button>
                </>))}

                {card("guilds", "Found a guild, join one by id, or leave your current guild.", <>
                  {row(<>
                    {field("guildName", "name", 140)}
                    <button type="button" onClick={write("guilds::create_guild", () => sigil.guilds.walletPayloadCreateGuild({ name: f("guildName").trim() }))}>create_guild</button>
                  </>)}
                  {row(<>
                    {field("guildId", "guild_id", 80)}
                    <button type="button" onClick={write("guilds::join_guild", () => sigil.guilds.walletPayloadJoinGuild({ guildId: big("guildId") }))}>join_guild</button>
                    <button type="button" onClick={write("guilds::leave_guild", () => sigil.guilds.walletPayloadLeaveGuild())}>leave_guild</button>
                  </>)}
                </>)}

                {card("merge", "Consume a recipe's inputs from your inventory to mint its output (needs granted items — see Publisher tab).", row(<>
                  {field("recipeId", "recipe_id", 80)}
                  <button type="button" onClick={write("merge::execute_merge", () => sigil.merge.walletPayloadExecuteMerge({ recipeId: big("recipeId") }))}>execute_merge</button>
                </>))}
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
  );
}
