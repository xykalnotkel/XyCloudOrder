"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { MENU, MenuIcon } from "@/lib/theme";
import { useState } from "react";
import {
  LayoutDashboard,
  Receipt,
  Users,
  Monitor,
  Gamepad2,
  Image as ImageIcon,
  Gift,
  Ticket,
  CreditCard,
  Cpu,
  Activity,
  ShieldCheck,
  Wallet,
  MessageCircle,
  MessagesSquare,
  Star,
  BarChart3,
  LineChart,
  Rocket,
  Bell,
  Package,
  FileText,
  Settings,
  ShieldUser,
  ChevronsLeft,
  ChevronsRight,
  Share2,
  Heart,
  Bug,
  MonitorSmartphone,
} from "lucide-react";

const iconMap: Record<MenuIcon, any> = {
  "layout-dashboard": LayoutDashboard,
  receipt: Receipt,
  users: Users,
  monitor: Monitor,
  gamepad: Gamepad2,
  image: ImageIcon,
  gift: Gift,
  ticket: Ticket,
  "credit-card": CreditCard,
  cpu: Cpu,
  activity: Activity,
  "shield-check": ShieldCheck,
  wallet: Wallet,
  "message-circle": MessageCircle,
  "messages-square": MessagesSquare,
  star: Star,
  "bar-chart-3": BarChart3,
  "line-chart": LineChart,
  rocket: Rocket,
  bell: Bell,
  package: Package,
  "file-text": FileText,
  settings: Settings,
  "shield-user": ShieldUser,
  "share-2": Share2,
  heart: Heart,
  bug: Bug,
  sesi: MonitorSmartphone,
};

export default function Sidebar() {
  const pathname = usePathname();
  const [collapsed, setCollapsed] = useState(false);
  return (
    <aside className={`${collapsed ? "w-[72px]" : "w-[272px]"} shrink-0 transition-all duration-300 flex flex-col h-screen sticky top-0 xy-card border-r font-[Plus_Jakarta_Sans]`}>
      <div className="h-[64px] flex items-center px-4 gap-3 border-b border-white/10">
        <div className="w-9 h-9 rounded-xl xy-btn grid place-items-center font-black text-white tracking-tight">XY</div>
        {!collapsed && (
          <div className="leading-tight">
            <div className="font-bold text-white tracking-tight text-[14px]">XyCloud Console</div>
            <div className="text-[11px] text-violet-200/70 font-medium">v3.3 Next.js • {MENU.length} menu</div>
          </div>
        )}
        <button onClick={() => setCollapsed(!collapsed)} className="ml-auto w-8 h-8 rounded-lg bg-white/5 hover:bg-white/10 grid place-items-center">
          {collapsed ? <ChevronsRight size={16} /> : <ChevronsLeft size={16} />}
        </button>
      </div>
      <div className="flex-1 overflow-y-auto p-2 space-y-1 scrollbar-thin">
        {MENU.map((m) => {
          const active = pathname === m.path || (m.path !== "/" && pathname?.startsWith(m.path));
          const Icon = iconMap[m.icon] || LayoutDashboard;
          return (
            <Link
              key={m.id}
              href={m.path}
              className={`group flex items-center gap-3 px-3 py-2.5 rounded-xl text-[13px] transition-all
                ${active ? "xy-btn text-white shadow-glow font-semibold" : "hover:bg-white/[0.06] text-violet-100/80 hover:text-white font-medium"}`}
            >
              <Icon size={18} className={active ? "text-white" : "text-violet-200/70 group-hover:text-white"} />
              {!collapsed && <span className="truncate tracking-tight">{m.label}</span>}
              {!collapsed && (m as any).badge && (
                <span className="ml-auto text-[10px] px-1.5 py-0.5 rounded-full bg-[#A855F7] text-white font-bold tracking-wide">{(m as any).badge}</span>
              )}
            </Link>
          );
        })}
      </div>
      <div className="p-3 border-t border-white/10 space-y-2">
        <div className="xy-card rounded-xl p-3">
          <div className="text-[11px] text-violet-200/60 font-semibold tracking-wide uppercase">Palette v3.3</div>
          <div className="flex gap-1.5 mt-2">
            <div className="w-5 h-5 rounded-full" style={{ background: "#100030", border: "1px solid #7C3AED" }} />
            <div className="w-5 h-5 rounded-full" style={{ background: "#7C3AED" }} />
            <div className="w-5 h-5 rounded-full" style={{ background: "#8B5CF6" }} />
            <div className="w-5 h-5 rounded-full" style={{ background: "#A855F7" }} />
          </div>
          <div className="mt-2 text-[10px] text-white/30 font-medium">Font: Plus Jakarta Sans • Icons: Lucide</div>
        </div>
        {!collapsed && <div className="text-[11px] text-center text-white/30 font-medium">Next.js 14 • Tailwind • API Worker</div>}
      </div>
    </aside>
  );
}
