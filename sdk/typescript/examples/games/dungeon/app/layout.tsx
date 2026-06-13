import type { ReactNode } from "react";
import { Providers } from "./providers";

const title = "Sigil Dungeon";
const description = "A run-based Aptos game with on-chain scores, loot, and guilds.";

export const metadata = {
  title,
  description,
  icons: { icon: "/logo.png", apple: "/logo.png" },
  openGraph: { title, description, images: ["/logo.png"], type: "website" },
  twitter: { card: "summary", title, description, images: ["/logo.png"] },
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
