import { AptosWalletAdapterProvider } from "@aptos-labs/wallet-adapter-react";
import { Network } from "@aptos-labs/ts-sdk";
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { App } from "./App.js";

const root = document.getElementById("root");
if (!root) throw new Error("Missing #root");

createRoot(root).render(
  <StrictMode>
    <AptosWalletAdapterProvider
      autoConnect={false}
      dappConfig={{ network: Network.DEVNET }}
    >
      <App />
    </AptosWalletAdapterProvider>
  </StrictMode>,
);
