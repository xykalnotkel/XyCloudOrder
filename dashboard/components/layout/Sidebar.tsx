"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { MENU } from "@/lib/theme";
import { useState } from "react";

export default function Sidebar() {
  const pathname = usePathname();
  const [collapsed, setCollapsed] = useState(false);
  return (
    <aside className={`${collapsed ? "w-[72px]" : "w-[272px]"} shrink-0 transition-all duration-300 flex flex-col h-screen sticky top-0 xy-card border-r`}>
      <div className="h-[64px] flex items-center px-4 gap-3 border-b border-white/10">
        <div className="w-9 h-9 rounded-xl xy-btn grid place-items-center font-black text-white">XY</div>
        {!collapsed && (
          <div className="leading-tight">
            <div className="font-bold text-white tracking-wide">XyCloud Console</div>
            <div className="text-[11px] text-violet-200/70">v3.3 Next.js • {MENU.length} menu</div>
          </div>
        )}
        <button onClick={() => setCollapsed(!collapsed)} className="ml-auto w-8 h-8 rounded-lg bg-white/5 hover:bg-white/10 grid place-items-center text-sm">
          {collapsed ? "→" : "←"}
        </button>
      </div>
      <div className="flex-1 overflow-y-auto p-2 space-y-1">
        {MENU.map((m) => {
          const active = pathname === m.path || (m.path !== "/" && pathname?.startsWith(m.path));
          return (
            <Link
              key={m.id}
              href={m.path}
              className={`group flex items-center gap-3 px-3 py-2.5 rounded-xl text-[13.5px] transition-all
                ${active ? "xy-btn text-white shadow-glow" : "hover:bg-white/[0.06] text-violet-100/80 hover:text-white"}`}
            >
              <span className="text-[16px]">{m.icon}</span>
              {!collapsed && <span className="truncate font-medium">{m.label}</span>}
              {!collapsed && (m as any).badge && (
                <span className="ml-auto text-[10px] px-1.5 py-0.5 rounded-full bg-[#A855F7] text-white font-bold">{(m as any).badge}</span>
              )}
            </Link>
          );
        })}
      </div>
      <div className="p-3 border-t border-white/10 space-y-2">
        <div className="xy-card rounded-xl p-3">
          <div className="text-[11px] text-violet-200/60">Palette v3.2</div>
          <div className="flex gap-1.5 mt-1.5">
            <div className="w-5 h-5 rounded-full" style={{ background: "#100030", border: "1px solid #7C3AED" }} />
            <div className="w-5 h-5 rounded-full" style={{ background: "#7C3AED" }} />
            <div className="w-5 h-5 rounded-full" style={{ background: "#8B5CF6" }} />
            <div className="w-5 h-5 rounded-full" style={{ background: "#A855F7" }} />
          </div>
        </div>
        {!collapsed && <div className="text-[11px] text-center text-white/30">Next.js 14 • Tailwind • API Worker</div>}
      </div>
    </aside>
  );
}
