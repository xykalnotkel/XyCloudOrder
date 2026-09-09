import "./globals.css";
import type { Metadata } from "next";
import Sidebar from "@/components/layout/Sidebar";

export const metadata: Metadata = {
  title: "XyCloud Console v3.3 — Next.js",
  description: "Admin dashboard XyCloudStore violet-indigo glossy",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="id">
      <body className="antialiased flex min-h-screen">
        <Sidebar />
        <main className="flex-1 min-w-0">
          <div className="max-w-[1600px] mx-auto p-4 md:p-6">{children}</div>
        </main>
      </body>
    </html>
  );
}
