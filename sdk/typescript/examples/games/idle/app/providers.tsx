"use client";

import { AptosWalletAdapterProvider } from "@aptos-labs/wallet-adapter-react";
import type { ReactNode } from "react";
import { APP_NETWORK } from "@/lib/config";

export function Providers({ children }: { children: ReactNode }) {
  return (
    <AptosWalletAdapterProvider
      autoConnect={false}
      dappConfig={{ network: APP_NETWORK }}
      optInWallets={["Nightly"]}
    >
      {children}
    </AptosWalletAdapterProvider>
  );
}
