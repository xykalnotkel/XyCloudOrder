import "./globals.css";
import type { Metadata } from "next";
import Sidebar from "@/components/layout/Sidebar";
import { Plus_Jakarta_Sans, JetBrains_Mono } from "next/font/google";

const jakarta = Plus_Jakarta_Sans({
  subsets: ["latin"],
  weight: ["400", "500", "600", "700", "800"],
  variable: "--font-jakarta",
  display: "swap",
});

const mono = JetBrains_Mono({
  subsets: ["latin"],
  weight: ["400", "600"],
  variable: "--font-mono",
  display: "swap",
});

export const metadata: Metadata = {
  title: "XyCloud Console v3.3 — Next.js",
  description: "Admin dashboard XyCloudStore violet-indigo glossy — Lucide icons, Plus Jakarta Sans, no emoji",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="id" className={`${jakarta.variable} ${mono.variable}`}>
      <body className="antialiased flex min-h-screen font-[var(--font-jakarta)] bg-[#100030] text-white">
        <Sidebar />
        <main className="flex-1 min-w-0">
          <div className="max-w-[1600px] mx-auto p-4 md:p-6">{children}</div>
        </main>
      </body>
    </html>
  );
}
