"use client";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
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
  Sticker,
  Trash2,
  Smartphone,
  ShieldAlert,
  Wrench,
  Database,
  LogOut,
} from "lucide-react";
import { clearAdminKey } from "@/lib/api";

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
  sticker: Sticker,
  trash: Trash2,
  smartphone: Smartphone,
  "shield-alert": ShieldAlert,
  tool: Wrench,
  database: Database,
};

export default function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();
  const [collapsed, setCollapsed] = useState(false);

  // hide sidebar on login page
  if (pathname === "/login") return null;

  return (
    <aside className={`${collapsed ? "w-[72px]" : "w-[272px]"} shrink-0 transition-all duration-300 flex flex-col h-screen sticky top-0 bg-[#1A0A3A] border-r border-[#2D1B5E] font-[Plus_Jakarta_Sans]`}>
      <div className="h-[64px] flex items-center px-4 gap-3 border-b border-[#2D1B5E]">
        <img src="/brand/logo.png" alt="logo" className="w-9 h-9 rounded-xl object-contain bg-[#21114A] border border-[#2D1B5E] p-1" />
        {!collapsed && (
          <div className="leading-tight">
            <div className="font-bold text-white tracking-tight text-[14px]">XyCloud Console</div>
            <div className="text-[11px] text-[#9A8CBF] font-medium">v3.3e • {MENU.length} menu • Solid</div>
          </div>
        )}
        <button onClick={() => setCollapsed(!collapsed)} className="ml-auto w-8 h-8 rounded-lg bg-[#21114A] hover:bg-[#2A1A5E] grid place-items-center border border-[#2D1B5E]">
          {collapsed ? <ChevronsRight size={16} className="text-[#9A8CBF]"/> : <ChevronsLeft size={16} className="text-[#9A8CBF]"/>}
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
                ${active ? "bg-[#7C3AED] text-white font-semibold" : "hover:bg-[#21114A] text-[#9A8CBF] hover:text-white font-medium"}`}
            >
              <Icon size={18} className={active ? "text-white" : "text-[#9A8CBF] group-hover:text-white"} />
              {!collapsed && <span className="truncate tracking-tight">{m.label}</span>}
              {!collapsed && (m as any).badge && (
                <span className="ml-auto text-[10px] px-1.5 py-0.5 rounded-full bg-[#A855F7] text-white font-bold tracking-wide">{(m as any).badge}</span>
              )}
            </Link>
          );
        })}
      </div>
      <div className="p-3 border-t border-[#2D1B5E] space-y-2">
        {!collapsed && (
          <div className="bg-[#21114A] border border-[#2D1B5E] rounded-xl p-3">
            <div className="text-[11px] text-[#9A8CBF] font-bold tracking-wide uppercase">Admin</div>
            <div className="text-[12px] text-white font-medium mt-1 truncate">{typeof window !== 'undefined' ? (localStorage.getItem('xy_admin_key')||'').slice(0,16)+'...' : ''}</div>
            <button onClick={()=>{ clearAdminKey(); router.push('/login'); }} className="mt-2 w-full h-8 rounded-lg bg-[#2A1A5E] hover:bg-[#3A2A6E] text-[#9A8CBF] hover:text-white text-[12px] font-semibold flex items-center justify-center gap-1.5">
              <LogOut size={14}/> Keluar
            </button>
          </div>
        )}
        {!collapsed && <div className="text-[11px] text-center text-[#6B5A8A] font-medium">Next.js 14 • Solid • No Glass • Lucide</div>}
      </div>
    </aside>
  );
}
