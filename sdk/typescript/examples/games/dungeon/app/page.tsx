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

const RUN_SECONDS = 12;
const LOOT = ["🗡️ Rusty blade", "🛡️ Cracked shield", "💰 Gold pouch", "💎 Shard", "🧪 Elixir", "📜 Rune"];
type Phase = "idle" | "running" | "over";
type Entry = { player: string; score: number };

export default function DungeonPage() {
  const { account, connected, connect, disconnect, wallets, signAndSubmitTransaction, signTransaction } = useWallet();
  const sigil = useMemo(
    () => new SigilClient({ aptos: createAptosClient({ network: APP_NETWORK }), moduleAddress: AccountAddress.from(MODULE_ADDRESS) }),
    [],
  );

  const [phase, setPhase] = useState<Phase>("idle");
  const [score, setScore] = useState(0);
  const [timeLeft, setTimeLeft] = useState(RUN_SECONDS);
  const [loot, setLoot] = useState<string[]>([]);
  const [username, setUsername] = useState("delver1");
  const [guildName, setGuildName] = useState("Torchbearers");
  const [guildId, setGuildId] = useState("0");
  const [status, setStatus] = useState("");
  const [busy, setBusy] = useState(false);
  const [board, setBoard] = useState<Entry[]>([]);
  const tick = useRef<ReturnType<typeof setInterval> | null>(null);
  const me = account?.address.toString().toLowerCase();
  const say = (s: string) => setStatus(s);

  const startRun = () => {
    setScore(0); setLoot([]); setTimeLeft(RUN_SECONDS); setPhase("running"); setStatus("");
    tick.current = setInterval(() => setTimeLeft((t) => {
      if (t <= 1) { if (tick.current) clearInterval(tick.current); setPhase("over"); return 0; }
      return t - 1;
    }), 1000);
  };
  useEffect(() => () => { if (tick.current) clearInterval(tick.current); }, []);

  const strike = () => {
    if (phase !== "running") return;
    setScore((s) => s + 50 + Math.floor(Math.random() * 100));
    if (Math.random() < 0.18) setLoot((l) => [LOOT[Math.floor(Math.random() * LOOT.length)], ...l].slice(0, 6));
  };

  const refreshBoard = useCallback(async () => {
    try {
      const res = (await sigil.leaderboard.viewTopEntriesForGame(GAME_ID)) as unknown as [string[], string[]];
      setBoard((res?.[0] ?? []).map((p, i) => ({ player: p, score: Number(res?.[1]?.[i] ?? 0) })));
    } catch (e) { say(`Leaderboard read failed: ${e instanceof Error ? e.message : String(e)}`); }
  }, [sigil]);
  useEffect(() => { void refreshBoard(); }, [refreshBoard]);

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

  const submitScore = () => run("Submit", async () => {
    const payload = sigil.gamePlatform.walletPayloadSubmitScore({ gameId: GAME_ID, score: BigInt(score), username: username.trim() });
    const res = await signAndSubmitTransaction(payload as never);
    const c = await sigil.aptos.waitForTransaction({ transactionHash: res.hash });
    say(c.success ? `Run recorded! ${res.hash}` : `Aborted: ${c.vm_status}`);
    await refreshBoard();
  });

  const submitGasless = () => run("Gasless submit", async () => {
    const payload = sigil.gamePlatform.walletPayloadSubmitScore({ gameId: GAME_ID, score: BigInt(score), username: username.trim() });
    const tx = await buildSponsoredTransaction({ aptos: sigil.aptos, sender: account!.address.toString(), data: payload.data as never });
    say("Sign in your wallet (you pay 0 gas)…");
    const senderAuth = await signTransaction({ transactionOrPayload: tx as never });
    const { feePayerAuthenticator, feePayerAddress } = await requestSponsorship({ endpoint: SPONSOR_ENDPOINT, transaction: tx });
    const c = await submitSponsored({ aptos: sigil.aptos, transaction: tx, senderAuthenticator: senderAuth.authenticator as never, feePayerAuthenticator, feePayerAddress });
    say("success" in c && c.success ? `⚡ Run recorded gaslessly (fee: ${short(feePayerAddress.toString())}). ${c.hash}` : `Aborted: ${JSON.stringify(c).slice(0, 160)}`);
    await refreshBoard();
  });

  const guildWrite = (label: string, payload: () => { data: unknown }) => run(label, async () => {
    const res = await signAndSubmitTransaction(payload() as never);
    const c = await sigil.aptos.waitForTransaction({ transactionHash: res.hash });
    say(c.success ? `${label}: OK ${res.hash}` : `${label} aborted: ${c.vm_status}`);
  });

  return (
    <main style={{ maxWidth: 880, margin: "0 auto", padding: "24px 16px 64px" }}>
      <header style={{ display: "flex", justifyContent: "space-between", alignItems: "center", flexWrap: "wrap", gap: 12 }}>
        <div>
          <h1 style={{ margin: 0, fontSize: 30 }}>🏰 Sigil Dungeon</h1>
          <p style={{ margin: "4px 0 0", color: "#b9a88a", fontSize: 14 }}>
            Raid for score &amp; loot · game {GAME_ID.toString()} on Aptos {NETWORK_LABEL}
          </p>
        </div>
        <div style={{ textAlign: "right" }}>
          {connected && account ? (
            <>
              <div style={{ fontSize: 12, color: "#b9a88a" }}>{short(account.address.toString())}</div>
              <button onClick={() => disconnect()} style={btn("#3a2c1c")}>Disconnect</button>
            </>
          ) : <button onClick={() => void connectNightly()} style={btn("#a8451c")}>Connect Nightly</button>}
        </div>
      </header>

      <section style={panel()}>
        <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 12 }}>
          <Stat label="Score" value={score} />
          <Stat label="Time" value={phase === "running" ? `${timeLeft}s` : "—"} />
          <Stat label="Loot" value={loot.length} />
        </div>
        <div style={{ textAlign: "center", minHeight: 90 }}>
          {phase === "idle" && <button onClick={startRun} style={btn("#16a34a", 16)}>▶ Descend ({RUN_SECONDS}s)</button>}
          {phase === "running" && <button onClick={strike} style={{ ...btn("#dc2626", 22), padding: "22px 40px", borderRadius: 16 }}>⚔️ Strike!</button>}
          {phase === "over" && (
            <div style={{ display: "flex", gap: 10, justifyContent: "center", alignItems: "center", flexWrap: "wrap" }}>
              <strong style={{ fontSize: 18 }}>Run score: {score}</strong>
              <input value={username} onChange={(e) => setUsername(e.target.value)} placeholder="name" style={input()} />
              <button onClick={() => void submitGasless()} disabled={busy || !connected} style={btn("#f59e0b")}>⚡ Submit gasless</button>
              <button onClick={() => void submitScore()} disabled={busy || !connected} style={btn("#3b82f6")}>Submit (pay gas)</button>
              <button onClick={startRun} style={btn("#3a2c1c")}>Descend again</button>
            </div>
          )}
        </div>
        {loot.length > 0 && <p style={{ color: "#d8c08a", fontSize: 13 }}>Loot found: {loot.join(" · ")}</p>}
        {status && <p style={{ color: "#f0e6d2", fontSize: 13, wordBreak: "break-word" }}>{status}</p>}
      </section>

      <section style={panel()}>
        <h2 style={{ margin: "0 0 8px", fontSize: 18 }}>🛡️ Your guild (party)</h2>
        <p style={{ color: "#b9a88a", fontSize: 13, marginTop: 0 }}>
          Guild create/join/leave are player-signed. (On-chain loot crafting via <code>merge</code> needs the publisher to grant
          items — try it in the web-petra console's Publisher tab.)
        </p>
        <div style={{ display: "flex", gap: 8, flexWrap: "wrap", alignItems: "center" }}>
          <input value={guildName} onChange={(e) => setGuildName(e.target.value)} placeholder="guild name" style={input(160)} />
          <button onClick={() => void guildWrite("create_guild", () => sigil.guilds.walletPayloadCreateGuild({ name: guildName.trim() }))} disabled={busy} style={btn("#7c3aed")}>Create guild</button>
          <input value={guildId} onChange={(e) => setGuildId(e.target.value)} placeholder="id" style={input(60)} />
          <button onClick={() => void guildWrite("join_guild", () => sigil.guilds.walletPayloadJoinGuild({ guildId: BigInt(guildId || "0") }))} disabled={busy} style={btn("#3a2c1c")}>Join</button>
          <button onClick={() => void guildWrite("leave_guild", () => sigil.guilds.walletPayloadLeaveGuild())} disabled={busy} style={btn("#3a2c1c")}>Leave</button>
        </div>
      </section>

      <section style={panel()}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <h2 style={{ margin: 0, fontSize: 18 }}>🏆 Dungeon leaderboard (game {GAME_ID.toString()})</h2>
          <button onClick={() => void refreshBoard()} style={btn("#3a2c1c")}>Refresh</button>
        </div>
        <ol style={{ margin: "12px 0 0", padding: "0 0 0 24px" }}>
          {board.length === 0 && <li style={{ color: "#b9a88a", listStyle: "none", marginLeft: -24 }}>No delvers yet — descend!</li>}
          {board.map((e, i) => (
            <li key={i} style={{ padding: "4px 0", color: e.player.toLowerCase() === me ? "#ffd166" : "#f0e6d2" }}>
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
  return <div style={{ textAlign: "center" }}><div style={{ fontSize: 12, color: "#b9a88a", textTransform: "uppercase", letterSpacing: 1 }}>{label}</div><div style={{ fontSize: 24, fontWeight: 700 }}>{value}</div></div>;
}
function short(a: string) { return a.length > 14 ? `${a.slice(0, 8)}…${a.slice(-4)}` : a; }
function panel(): React.CSSProperties { return { background: "#1d160f", border: "1px solid #3a2c1c", borderRadius: 16, padding: 20, marginTop: 20 }; }
function btn(bg: string, fontSize = 14): React.CSSProperties { return { background: bg, color: "#fff", border: "none", borderRadius: 10, padding: "8px 14px", fontSize, fontWeight: 600, cursor: "pointer" }; }
function input(width = 120): React.CSSProperties { return { background: "#14100c", color: "#f0e6d2", border: "1px solid #3a2c1c", borderRadius: 8, padding: "8px 10px", width }; }
