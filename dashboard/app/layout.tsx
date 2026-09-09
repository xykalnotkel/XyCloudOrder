import "./globals.css";
import type { Metadata } from "next";
import Sidebar from "@/components/layout/Sidebar";
import { Inter, JetBrains_Mono } from "next/font/google";
import AuthGuard from "@/components/layout/AuthGuard";

const inter = Inter({
  subsets: ["latin"],
  weight: ["400","500","600","700"],
  variable: "--font-inter",
  display: "swap",
});

const mono = JetBrains_Mono({
  subsets: ["latin"],
  weight: ["400","600"],
  variable: "--font-mono",
  display: "swap",
});

export const metadata: Metadata = {
  title: "XyCloud Admin — Console",
  description: "XyCloudStore admin dashboard — light theme ala xycloud.my.id, Lucide, Inter",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="id" className={`${inter.variable} ${mono.variable}`}>
      <body className="antialiased flex min-h-screen font-[var(--font-inter)] bg-[#F5F3FF] text-[#1E1B2E]">
        <Sidebar />
        <main className="flex-1 min-w-0 bg-[#F5F3FF]">
          <div className="max-w-[1600px] mx-auto p-4 md:p-6">
            <AuthGuard>{children}</AuthGuard>
          </div>
        </main>
      </body>
    </html>
  );
}
