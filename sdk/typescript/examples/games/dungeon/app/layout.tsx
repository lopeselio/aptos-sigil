import type { ReactNode } from "react";
import { Providers } from "./providers";

export const metadata = {
  title: "Sigil Dungeon",
  description: "A run-based Aptos game with on-chain scores, loot, and guilds.",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body style={{ margin: 0, fontFamily: "system-ui, sans-serif", background: "#14100c", color: "#f0e6d2" }}>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
