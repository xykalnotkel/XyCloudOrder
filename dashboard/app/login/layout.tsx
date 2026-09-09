import "../globals.css";
import { Plus_Jakarta_Sans, JetBrains_Mono } from "next/font/google";

const jakarta = Plus_Jakarta_Sans({
  subsets: ["latin"],
  weight: ["400","500","600","700","800"],
  variable: "--font-jakarta",
  display: "swap",
});
const mono = JetBrains_Mono({
  subsets: ["latin"],
  weight: ["400","600"],
  variable: "--font-mono",
  display: "swap",
});

export default function LoginLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="id" className={`${jakarta.variable} ${mono.variable}`}>
      <body className="antialiased min-h-screen bg-[#F5F3FF] text-[#1E1B2E] font-[var(--font-jakarta)]">
        {children}
      </body>
    </html>
  );
}
