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
import { APP_NETWORK, ARCADE_GAME_ID, MODULE_ADDRESS, NETWORK_LABEL, SPONSOR_ENDPOINT } from "@/lib/config";

const GRID = 9; // 3x3
const ROUND_SECONDS = 15;
const POINTS_PER_HIT = 100;
type Phase = "idle" | "playing" | "over";
type Entry = { player: string; score: number };

export default function ArcadePage() {
  const { account, connected, connect, disconnect, wallets, signAndSubmitTransaction, signTransaction } = useWallet();

  const sigil = useMemo(
    () => new SigilClient({ aptos: createAptosClient({ network: APP_NETWORK }), moduleAddress: AccountAddress.from(MODULE_ADDRESS) }),
    [],
  );

  const [phase, setPhase] = useState<Phase>("idle");
  const [active, setActive] = useState<number>(-1);
  const [score, setScore] = useState(0);
  const [timeLeft, setTimeLeft] = useState(ROUND_SECONDS);
  const [username, setUsername] = useState("player1");
  const [status, setStatus] = useState<string>("");
  const [busy, setBusy] = useState(false);
  const [board, setBoard] = useState<Entry[]>([]);
  const tickRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const me = account?.address.toString().toLowerCase();
  const say = (s: string) => setStatus(s);

  const nextCell = useCallback(() => setActive(Math.floor(Math.random() * GRID)), []);

  const startGame = () => {
    setScore(0);
    setTimeLeft(ROUND_SECONDS);
    setPhase("playing");
    setStatus("");
    nextCell();
    tickRef.current = setInterval(() => {
      setTimeLeft((t) => {
        if (t <= 1) {
          if (tickRef.current) clearInterval(tickRef.current);
          setActive(-1);
          setPhase("over");
          return 0;
        }
        return t - 1;
      });
    }, 1000);
  };

  useEffect(() => () => { if (tickRef.current) clearInterval(tickRef.current); }, []);

  const hit = (i: number) => {
    if (phase !== "playing" || i !== active) return;
    setScore((s) => s + POINTS_PER_HIT);
    nextCell();
  };

  const refreshBoard = useCallback(async () => {
    try {
      const res = (await sigil.leaderboard.viewTopEntriesForGame(ARCADE_GAME_ID)) as unknown as [string[], string[]];
      const players = res?.[0] ?? [];
      const scores = res?.[1] ?? [];
      setBoard(players.map((p, i) => ({ player: p, score: Number(scores[i] ?? 0) })));
    } catch (e) {
      say(`Leaderboard read failed: ${e instanceof Error ? e.message : String(e)}`);
    }
  }, [sigil]);

  useEffect(() => { void refreshBoard(); }, [refreshBoard]);

  const connectNightly = async () => {
    try {
      const nightly = wallets.find((w) => w.name === "Nightly");
      await connect((nightly?.name ?? "Nightly") as never);
    } catch (e) {
      say(`Connect failed: ${e instanceof Error ? e.message : String(e)}`);
    }
  };

  /** Sign & submit a normal (player-pays-gas) score. */
  const submitScore = async () => {
    if (!connected || !account) return say("Connect your wallet first.");
    setBusy(true);
    try {
      const payload = sigil.gamePlatform.walletPayloadSubmitScore({ gameId: ARCADE_GAME_ID, score: BigInt(score), username: username.trim() });
      const res = await signAndSubmitTransaction(payload as never);
      const committed = await sigil.aptos.waitForTransaction({ transactionHash: res.hash });
      say(committed.success ? `Score submitted! ${res.hash}` : `Aborted: ${committed.vm_status}`);
      await refreshBoard();
    } catch (e) {
      say(`Submit failed: ${e instanceof Error ? e.message : String(e)}`);
    } finally {
      setBusy(false);
    }
  };

  /** ⚡ Gasless: the player signs but a gas station pays — 0 APT from the player. */
  const submitScoreGasless = async () => {
    if (!connected || !account) return say("Connect your wallet first.");
    setBusy(true);
    try {
      const payload = sigil.gamePlatform.walletPayloadSubmitScore({ gameId: ARCADE_GAME_ID, score: BigInt(score), username: username.trim() });
      const transaction = await buildSponsoredTransaction({ aptos: sigil.aptos, sender: account.address.toString(), data: payload.data as never });
      say("Sign in your wallet (you pay 0 gas)…");
      const senderAuth = await signTransaction({ transactionOrPayload: transaction as never });
      say("Gas station is covering the fee…");
      const { feePayerAuthenticator, feePayerAddress } = await requestSponsorship({ endpoint: SPONSOR_ENDPOINT, transaction });
      const committed = await submitSponsored({
        aptos: sigil.aptos,
        transaction,
        senderAuthenticator: senderAuth.authenticator as never,
        feePayerAuthenticator,
        feePayerAddress,
      });
      const ok = "success" in committed ? committed.success : false;
      say(ok ? `⚡ Gasless score submitted! Fee paid by ${shorten(feePayerAddress.toString())}. ${committed.hash}` : `Aborted: ${JSON.stringify(committed).slice(0, 200)}`);
      await refreshBoard();
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      say(`Gasless submit failed: ${msg}${/gas station|fetch|500/i.test(msg) ? " — is the gas station configured (SPONSOR_PRIVATE_KEY)?" : ""}`);
    } finally {
      setBusy(false);
    }
  };

  return (
    <main style={{ maxWidth: 880, margin: "0 auto", padding: "24px 16px 64px" }}>
      <header style={{ display: "flex", justifyContent: "space-between", alignItems: "center", flexWrap: "wrap", gap: 12 }}>
        <div>
          <h1 style={{ margin: 0, fontSize: 30, letterSpacing: 1 }}>🕹️ Sigil Arcade</h1>
          <p style={{ margin: "4px 0 0", color: "#9aa6c4", fontSize: 14 }}>
            Reaction grid · scores live on Aptos {NETWORK_LABEL} · powered by <code style={{ color: "#cdd6f4" }}>@sigil-aptos/sdk</code>
          </p>
        </div>
        <div style={{ textAlign: "right" }}>
          {connected && account ? (
            <>
              <div style={{ fontSize: 12, color: "#9aa6c4" }}>{shorten(account.address.toString())}</div>
              <button onClick={() => disconnect()} style={btnStyle("#2a3354")}>Disconnect</button>
            </>
          ) : (
            <button onClick={() => void connectNightly()} style={btnStyle("#5566ff")}>Connect Nightly</button>
          )}
        </div>
      </header>

      <section style={panel()}>
        <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 12 }}>
          <Stat label="Score" value={score} />
          <Stat label="Time" value={phase === "playing" ? `${timeLeft}s` : "—"} />
          <Stat label="Best on board" value={board[0]?.score ?? 0} />
        </div>

        <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 10 }}>
          {Array.from({ length: GRID }).map((_, i) => (
            <button
              key={i}
              onClick={() => hit(i)}
              disabled={phase !== "playing"}
              style={{
                aspectRatio: "1 / 1",
                borderRadius: 14,
                border: "none",
                cursor: phase === "playing" ? "pointer" : "default",
                background: i === active ? "radial-gradient(circle, #ffe066, #ff9f1c)" : "#161d36",
                boxShadow: i === active ? "0 0 24px #ff9f1caa" : "inset 0 0 0 1px #232c4d",
                transition: "background 80ms, box-shadow 80ms",
              }}
            />
          ))}
        </div>

        <div style={{ marginTop: 16, textAlign: "center" }}>
          {phase === "idle" && <button onClick={startGame} style={btnStyle("#22c55e", 16)}>▶ Start (15s)</button>}
          {phase === "playing" && <span style={{ color: "#9aa6c4" }}>Tap the glowing tile!</span>}
          {phase === "over" && (
            <div style={{ display: "flex", gap: 10, justifyContent: "center", alignItems: "center", flexWrap: "wrap" }}>
              <strong style={{ fontSize: 18 }}>Final score: {score}</strong>
              <input value={username} onChange={(e) => setUsername(e.target.value)} placeholder="username" style={inputStyle()} />
              <button onClick={() => void submitScoreGasless()} disabled={busy || !connected} style={btnStyle("#ff9f1c")}>⚡ Submit gasless</button>
              <button onClick={() => void submitScore()} disabled={busy || !connected} style={btnStyle("#3b82f6")}>Submit (pay gas)</button>
              <button onClick={startGame} style={btnStyle("#2a3354")}>Play again</button>
            </div>
          )}
        </div>
        {status && <p style={{ marginTop: 12, color: "#cdd6f4", fontSize: 13, wordBreak: "break-word" }}>{status}</p>}
        {!connected && phase === "over" && <p style={{ color: "#f59e0b", fontSize: 13 }}>Connect your wallet to submit your score.</p>}
      </section>

      <section style={panel()}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <h2 style={{ margin: 0, fontSize: 18 }}>🏆 Leaderboard (game {ARCADE_GAME_ID.toString()})</h2>
          <button onClick={() => void refreshBoard()} style={btnStyle("#2a3354")}>Refresh</button>
        </div>
        <ol style={{ margin: "12px 0 0", padding: "0 0 0 24px" }}>
          {board.length === 0 && <li style={{ color: "#9aa6c4", listStyle: "none", marginLeft: -24 }}>No scores yet — be the first!</li>}
          {board.map((e, i) => (
            <li key={i} style={{ padding: "4px 0", color: e.player.toLowerCase() === me ? "#ffe066" : "#cdd6f4" }}>
              <span style={{ display: "inline-block", width: 220 }}>{shorten(e.player)}</span>
              <strong>{e.score.toLocaleString()}</strong>
              {e.player.toLowerCase() === me ? " ← you" : ""}
            </li>
          ))}
        </ol>
      </section>

      <footer style={{ color: "#6b769c", fontSize: 12, marginTop: 24, lineHeight: 1.6 }}>
        Module <code>{shorten(MODULE_ADDRESS)}</code>. The ⚡ gasless path builds a fee-payer transaction, you sign as sender,
        and the <code>/api/sponsor</code> gas station signs as fee payer so you pay 0 APT. For the full module console (quests,
        achievements, seasons, guilds) see the web-petra example.
      </footer>
    </main>
  );
}

function Stat({ label, value }: { label: string; value: number | string }) {
  return (
    <div style={{ textAlign: "center" }}>
      <div style={{ fontSize: 12, color: "#9aa6c4", textTransform: "uppercase", letterSpacing: 1 }}>{label}</div>
      <div style={{ fontSize: 24, fontWeight: 700 }}>{value}</div>
    </div>
  );
}

function shorten(addr: string) {
  return addr.length > 14 ? `${addr.slice(0, 8)}…${addr.slice(-4)}` : addr;
}
function panel(): React.CSSProperties {
  return { background: "#0f1530", border: "1px solid #1d2746", borderRadius: 16, padding: 20, marginTop: 20 };
}
function btnStyle(bg: string, fontSize = 14): React.CSSProperties {
  return { background: bg, color: "#fff", border: "none", borderRadius: 10, padding: "8px 14px", fontSize, fontWeight: 600, cursor: "pointer" };
}
function inputStyle(): React.CSSProperties {
  return { background: "#0b1020", color: "#e8ecf6", border: "1px solid #2a3354", borderRadius: 8, padding: "8px 10px", width: 120 };
}
