import type { ReactNode } from "react";
import { Providers } from "./providers";

const title = "Sigil Arcade";
const description = "A playable Aptos game with on-chain scores, leaderboards, and gasless submission.";

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
      <body style={{ margin: 0, fontFamily: "system-ui, sans-serif", background: "#0b1020", color: "#e8ecf6" }}>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
