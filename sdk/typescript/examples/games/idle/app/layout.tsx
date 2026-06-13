import type { ReactNode } from "react";
import { Providers } from "./providers";

export const metadata = {
  title: "Sigil Idle",
  description: "An idle Aptos game: accumulate, checkpoint on chain, complete quests.",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body style={{ margin: 0, fontFamily: "system-ui, sans-serif", background: "#081016", color: "#dff3ff" }}>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
