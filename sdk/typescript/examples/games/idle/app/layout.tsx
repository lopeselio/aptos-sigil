import type { ReactNode } from "react";
import { Providers } from "./providers";

const title = "Sigil Idle";
const description = "An idle Aptos game: accumulate, checkpoint on chain, complete quests.";

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
      <body style={{ margin: 0, fontFamily: "system-ui, sans-serif", background: "#081016", color: "#dff3ff" }}>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
