"use client";

import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { AccountAddress } from "@aptos-labs/ts-sdk";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  SigilClient,
  createAptosClient,
  buildSponsoredTransaction,
  requestSponsorship,
  submitSponsored,
} from "@/lib/sdk";
import { APP_NETWORK, ARCADE_GAME_ID as GAME_ID, MODULE_ADDRESS, NETWORK_LABEL, SPONSOR_ENDPOINT } from "@/lib/config";

type Entry = { player: string; score: number };

export default function IdlePage() {
  const { account, connected, connect, disconnect, wallets, signAndSubmitTransaction, signTransaction } = useWallet();
  const sigil = useMemo(
    () => new SigilClient({ aptos: createAptosClient({ network: APP_NETWORK }), moduleAddress: AccountAddress.from(MODULE_ADDRESS) }),
    [],
  );

  const [essence, setEssence] = useState(0); // accumulated, local
  const [rate, setRate] = useState(1); // per second
  const [username, setUsername] = useState("idler1");
  const [questId, setQuestId] = useState("1");
  const [status, setStatus] = useState("");
  const [busy, setBusy] = useState(false);
  const [board, setBoard] = useState<Entry[]>([]);
  const [season, setSeason] = useState<string>("");
  const me = account?.address.toString().toLowerCase();
  const say = (s: string) => setStatus(s);

  // Idle accumulation.
  useEffect(() => {
    const id = setInterval(() => setEssence((e) => e + rate), 1000);
    return () => clearInterval(id);
  }, [rate]);

  const score = Math.floor(essence);

  const refreshBoard = useCallback(async () => {
    try {
      const res = (await sigil.leaderboard.viewTopEntriesForGame(GAME_ID)) as unknown as [string[], string[]];
      setBoard((res?.[0] ?? []).map((p, i) => ({ player: p, score: Number(res?.[1]?.[i] ?? 0) })));
    } catch (e) { say(`Leaderboard read failed: ${e instanceof Error ? e.message : String(e)}`); }
  }, [sigil]);
  useEffect(() => { void refreshBoard(); }, [refreshBoard]);

  const viewSeason = useCallback(async () => {
    try { setSeason(JSON.stringify(await sigil.seasons.viewCurrentSeason())); }
    catch (e) { setSeason(`(read failed: ${e instanceof Error ? e.message : String(e)})`); }
  }, [sigil]);
  useEffect(() => { void viewSeason(); }, [viewSeason]);

  const connectNightly = async () => {
    try { await connect((wallets.find((w) => w.name === "Nightly")?.name ?? "Nightly") as never); }
    catch (e) { say(`Connect failed: ${e instanceof Error ? e.message : String(e)}`); }
  };

  const run = async (label: string, fn: () => Promise<void>) => {
    if (!connected || !account) return say("Connect your wallet first.");
    setBusy(true);
    try { await fn(); } catch (e) { say(`${label} failed: ${e instanceof Error ? e.message : String(e)}`); }
    finally { setBusy(false); }
  };

  /** Checkpoint the accumulated essence as your on-chain score (gasless). */
  const checkpointGasless = () => run("Checkpoint", async () => {
    const payload = sigil.gamePlatform.walletPayloadSubmitScore({ gameId: GAME_ID, score: BigInt(score), username: username.trim() });
    const tx = await buildSponsoredTransaction({ aptos: sigil.aptos, sender: account!.address.toString(), data: payload.data as never });
    say("Sign in your wallet (you pay 0 gas)…");
    const senderAuth = await signTransaction({ transactionOrPayload: tx as never });
    const { feePayerAuthenticator, feePayerAddress } = await requestSponsorship({ endpoint: SPONSOR_ENDPOINT, transaction: tx });
    const c = await submitSponsored({ aptos: sigil.aptos, transaction: tx, senderAuthenticator: senderAuth.authenticator as never, feePayerAuthenticator, feePayerAddress });
    say("success" in c && c.success ? `⚡ Checkpoint saved gaslessly (fee: ${short(feePayerAddress.toString())}). ${c.hash}` : `Aborted: ${JSON.stringify(c).slice(0, 160)}`);
    await refreshBoard();
  });

  const checkpoint = () => run("Checkpoint", async () => {
    const payload = sigil.gamePlatform.walletPayloadSubmitScore({ gameId: GAME_ID, score: BigInt(score), username: username.trim() });
    const res = await signAndSubmitTransaction(payload as never);
    const c = await sigil.aptos.waitForTransaction({ transactionHash: res.hash });
    say(c.success ? `Checkpoint saved! ${res.hash}` : `Aborted: ${c.vm_status}`);
    await refreshBoard();
  });

  const questWrite = (label: string, payload: () => { data: unknown }) => run(label, async () => {
    const res = await signAndSubmitTransaction(payload() as never);
    const c = await sigil.aptos.waitForTransaction({ transactionHash: res.hash });
    say(c.success ? `${label}: OK ${res.hash}` : `${label} aborted: ${c.vm_status}`);
  });

  return (
    <main style={{ maxWidth: 880, margin: "0 auto", padding: "24px 16px 64px" }}>
      <header style={{ display: "flex", justifyContent: "space-between", alignItems: "center", flexWrap: "wrap", gap: 12 }}>
        <div>
          <h1 style={{ margin: 0, fontSize: 30 }}>🌀 Sigil Idle</h1>
          <p style={{ margin: "4px 0 0", color: "#7fa8c4", fontSize: 14 }}>
            Accumulate essence, checkpoint on chain · game {GAME_ID.toString()} on Aptos {NETWORK_LABEL}
          </p>
        </div>
        <div style={{ textAlign: "right" }}>
          {connected && account ? (
            <>
              <div style={{ fontSize: 12, color: "#7fa8c4" }}>{short(account.address.toString())}</div>
              <button onClick={() => disconnect()} style={btn("#1c3242")}>Disconnect</button>
            </>
          ) : <button onClick={() => void connectNightly()} style={btn("#0ea5e9")}>Connect Nightly</button>}
        </div>
      </header>

      <section style={panel()}>
        <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 12 }}>
          <Stat label="Essence" value={score.toLocaleString()} />
          <Stat label="Rate" value={`${rate}/s`} />
          <Stat label="Best on board" value={board[0]?.score?.toLocaleString() ?? 0} />
        </div>
        <div style={{ display: "flex", gap: 10, justifyContent: "center", flexWrap: "wrap", alignItems: "center" }}>
          <button onClick={() => setEssence((e) => e + 5)} style={btn("#0ea5e9", 16)}>⛏️ Channel (+5)</button>
          <button onClick={() => { if (essence >= 50) { setEssence((e) => e - 50); setRate((r) => r + 1); } else say("Need 50 essence to upgrade rate."); }} style={btn("#1c3242")}>⬆ Upgrade rate (−50)</button>
        </div>
        <div style={{ marginTop: 16, display: "flex", gap: 10, justifyContent: "center", flexWrap: "wrap", alignItems: "center" }}>
          <input value={username} onChange={(e) => setUsername(e.target.value)} placeholder="name" style={input()} />
          <button onClick={() => void checkpointGasless()} disabled={busy || !connected} style={btn("#f59e0b")}>⚡ Checkpoint gasless</button>
          <button onClick={() => void checkpoint()} disabled={busy || !connected} style={btn("#3b82f6")}>Checkpoint (pay gas)</button>
        </div>
        {status && <p style={{ marginTop: 12, color: "#dff3ff", fontSize: 13, wordBreak: "break-word" }}>{status}</p>}
      </section>

      <section style={panel()}>
        <h2 style={{ margin: "0 0 8px", fontSize: 18 }}>🎯 Quests &amp; season</h2>
        <p style={{ color: "#7fa8c4", fontSize: 13, marginTop: 0 }}>
          Opt into a quest, then a checkpoint that also advances it. Score quests advance only via
          <code> submit_score_with_quest</code>.
        </p>
        <div style={{ display: "flex", gap: 8, flexWrap: "wrap", alignItems: "center" }}>
          <input value={questId} onChange={(e) => setQuestId(e.target.value)} placeholder="quest id" style={input(80)} />
          <button onClick={() => void questWrite("start_quest", () => sigil.quests.walletPayloadStartQuest({ questId: BigInt(questId || "0") }))} disabled={busy} style={btn("#7c3aed")}>Start quest</button>
          <button onClick={() => void questWrite("submit_score_with_quest", () => sigil.quests.walletPayloadSubmitScoreWithQuest({ gameId: GAME_ID, score: BigInt(score) }))} disabled={busy} style={btn("#1c3242")}>Checkpoint + advance quest</button>
          <button onClick={() => void viewSeason()} style={btn("#1c3242")}>Refresh season</button>
        </div>
        <p style={{ color: "#7fa8c4", fontSize: 12, marginTop: 8 }}>Current season: <code>{season || "…"}</code></p>
      </section>

      <section style={panel()}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <h2 style={{ margin: 0, fontSize: 18 }}>🏆 Idle leaderboard (game {GAME_ID.toString()})</h2>
          <button onClick={() => void refreshBoard()} style={btn("#1c3242")}>Refresh</button>
        </div>
        <ol style={{ margin: "12px 0 0", padding: "0 0 0 24px" }}>
          {board.length === 0 && <li style={{ color: "#7fa8c4", listStyle: "none", marginLeft: -24 }}>No checkpoints yet.</li>}
          {board.map((e, i) => (
            <li key={i} style={{ padding: "4px 0", color: e.player.toLowerCase() === me ? "#fcd34d" : "#dff3ff" }}>
              <span style={{ display: "inline-block", width: 220 }}>{short(e.player)}</span>
              <strong>{e.score.toLocaleString()}</strong>{e.player.toLowerCase() === me ? " ← you" : ""}
            </li>
          ))}
        </ol>
      </section>
    </main>
  );
}

function Stat({ label, value }: { label: string; value: number | string }) {
  return <div style={{ textAlign: "center" }}><div style={{ fontSize: 12, color: "#7fa8c4", textTransform: "uppercase", letterSpacing: 1 }}>{label}</div><div style={{ fontSize: 24, fontWeight: 700 }}>{value}</div></div>;
}
function short(a: string) { return a.length > 14 ? `${a.slice(0, 8)}…${a.slice(-4)}` : a; }
function panel(): React.CSSProperties { return { background: "#0c1822", border: "1px solid #1c3242", borderRadius: 16, padding: 20, marginTop: 20 }; }
function btn(bg: string, fontSize = 14): React.CSSProperties { return { background: bg, color: "#fff", border: "none", borderRadius: 10, padding: "8px 14px", fontSize, fontWeight: 600, cursor: "pointer" }; }
function input(width = 120): React.CSSProperties { return { background: "#081016", color: "#dff3ff", border: "1px solid #1c3242", borderRadius: 8, padding: "8px 10px", width }; }
