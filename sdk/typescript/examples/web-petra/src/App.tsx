import { PETRA_WALLET_NAME, useWallet, WalletItem } from "@aptos-labs/wallet-adapter-react";
import { Aptos, AptosConfig, AccountAddress, Network } from "@aptos-labs/ts-sdk";
import React, { useMemo, useState } from "react";
import { SigilClient } from "../../../src/client.js";

const DEFAULT_MODULE =
  import.meta.env.VITE_SIGIL_MODULE_ADDRESS ??
  "0xe68ef23cb6316728ae3b0f3edcc96640219275c2ed62c405578cc486a12dfac6";

export function App() {
  const { wallets, connect, disconnect, connected, account, signAndSubmitTransaction } = useWallet();
  const [log, setLog] = useState<string[]>([]);
  const [username, setUsername] = useState("player1");
  const [gameId, setGameId] = useState("0");
  const [score, setScore] = useState("1000");

  const sigil = useMemo(() => {
    const aptos = new Aptos(new AptosConfig({ network: Network.DEVNET }));
    return new SigilClient({
      aptos,
      moduleAddress: AccountAddress.from(DEFAULT_MODULE),
    });
  }, []);

  const push = (line: string) => setLog((prev) => [...prev, line]);

  const onRegister = async () => {
    if (!connected) return;
    const res = await signAndSubmitTransaction(
      sigil.walletPayloadRegisterPlayer(username) as Parameters<typeof signAndSubmitTransaction>[0],
    );
    push(`register_player: ${res.hash}`);
  };

  const onSubmitScore = async () => {
    if (!connected) return;
    const res = await signAndSubmitTransaction(
      sigil.walletPayloadSubmitScore({
        gameId: BigInt(gameId),
        score: BigInt(score),
      }) as Parameters<typeof signAndSubmitTransaction>[0],
    );
    push(`submit_score: ${res.hash}`);
  };

  const onLoadBoard = async () => {
    const top = await sigil.viewTopEntries(0);
    push(`get_top_entries (lb 0): ${JSON.stringify(top)}`);
  };

  const petra = wallets.find((w) => w.name === PETRA_WALLET_NAME);

  return (
    <div style={{ fontFamily: "system-ui", maxWidth: 520, margin: "2rem auto", padding: 16 }}>
      <h1>Sigil + Petra (devnet)</h1>
      <p style={{ color: "#444" }}>
        Module: <code>{DEFAULT_MODULE}</code>. Set <code>VITE_SIGIL_MODULE_ADDRESS</code> to override.
      </p>

      {!connected && (
        <section>
          <h2>Connect</h2>
          {petra ? (
            <WalletItem wallet={petra} onConnect={() => connect(PETRA_WALLET_NAME)}>
              <WalletItem.Icon />
              <WalletItem.Name />
              <WalletItem.ConnectButton />
            </WalletItem>
          ) : (
            <p>Petra not detected. Install the Petra extension and use a devnet account.</p>
          )}
        </section>
      )}

      {connected && account && (
        <section>
          <h2>Connected</h2>
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
