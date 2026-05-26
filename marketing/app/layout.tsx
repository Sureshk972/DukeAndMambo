import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Duke and Mambo — Trusted dog walkers in Chicago",
  description:
    "Book a verified, background-checked dog walker or drop-in visit. Chicago only, for now.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
