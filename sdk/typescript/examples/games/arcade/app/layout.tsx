import type { ReactNode } from "react";
import { Providers } from "./providers";

export const metadata = {
  title: "Sigil Arcade",
  description: "A playable Aptos game with on-chain scores, leaderboards, and gasless submission.",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body style={{ margin: 0, fontFamily: "system-ui, sans-serif", background: "#0b1020", color: "#e8ecf6" }}>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
