import type { Metadata } from "next";
import { Cinzel, Exo_2 } from "next/font/google";
import "./globals.css";

const display = Cinzel({
  subsets: ["latin"],
  weight: ["600", "700"],
  variable: "--font-fitrpg-display",
});

const sans = Exo_2({
  subsets: ["latin"],
  weight: ["500", "600", "700", "800"],
  variable: "--font-fitrpg-sans",
});

export const metadata: Metadata = {
  title: "FitRPG — App Store Screenshots",
  description: "Design and export App Store + Google Play screenshots.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${display.variable} ${sans.variable}`}>
      <body className={sans.className}>{children}</body>
    </html>
  );
}
