"use client";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { MENU, MenuIcon } from "@/lib/theme";
import { useState, useEffect } from "react";
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
  const [keyPreview, setKeyPreview] = useState("");

  useEffect(() => {
    const k = typeof window !== "undefined" ? localStorage.getItem("xy_admin_key") || "" : "";
    if (k) setKeyPreview(k.slice(0, 16) + "...");
  }, [pathname]);

  // hide sidebar on login page
  if (pathname === "/login") return null;

  return (
    <aside className={`${collapsed ? "w-[72px]" : "w-[272px]"} shrink-0 transition-all duration-300 flex flex-col h-screen sticky top-0 bg-white border-r border-[#E9E3F5] font-[Plus_Jakarta_Sans]`}>
      <div className={`h-[64px] flex items-center px-3 gap-2 border-b border-[#E9E3F5] bg-gradient-to-r from-[#7C3AED] to-[#5B21B6] ${collapsed ? "justify-center" : ""}`}>
        {collapsed ? (
          <img src="/brand/logo-icon.png" alt="XyCloud" className="w-10 h-10 object-contain" />
        ) : (
          <img src="/brand/logo-full.png" alt="XyCloudStore" className="h-9 w-auto object-contain drop-shadow" />
        )}
        {!collapsed && (
          <button onClick={() => setCollapsed(!collapsed)} className="ml-auto w-8 h-8 rounded-full bg-white/15 hover:bg-white/25 grid place-items-center border border-white/25 shrink-0">
            <ChevronsLeft size={16} className="text-white" />
          </button>
        )}
        {collapsed && (
          <button onClick={() => setCollapsed(!collapsed)} className="absolute left-[62px] top-[14px] w-6 h-6 rounded-full bg-white border border-[#E9E3F5] grid place-items-center shadow">
            <ChevronsRight size={13} className="text-[#7C3AED]" />
          </button>
        )}
      </div>
      {!collapsed && (
        <div className="px-4 py-2 border-b border-[#E9E3F5]/60 bg-[#F5F3FF]">
          <div className="text-[11px] text-[#7C738F] font-medium">v3.3j • {MENU.length} menu • tema web xycloud.my.id</div>
        </div>
      )}
      <div className="flex-1 overflow-y-auto p-2 space-y-1 scrollbar-thin">
        {MENU.map((m) => {
          const active = pathname === m.path || (m.path !== "/" && pathname?.startsWith(m.path));
          const Icon = iconMap[m.icon] || LayoutDashboard;
          return (
            <Link
              key={m.id}
              href={m.path}
              title={m.label}
              className={`group flex items-center gap-3 px-3 py-2.5 rounded-[14px] text-[13px] transition-all
                ${active
                  ? "bg-gradient-to-r from-[#7C3AED] to-[#5B21B6] text-white font-bold shadow-[0_8px_18px_rgba(124,58,237,0.25)]"
                  : "hover:bg-[#F3F0FF] text-[#6B5A8A] hover:text-[#1E1B2E] font-medium"}`}
            >
              <Icon size={18} className={active ? "text-white" : "text-[#9A8CBF] group-hover:text-[#7C3AED]"} />
              {!collapsed && <span className="truncate tracking-tight">{m.label}</span>}
              {!collapsed && (m as any).badge && (
                <span className="ml-auto text-[10px] px-1.5 py-0.5 rounded-full bg-[#A855F7] text-white font-bold tracking-wide">{(m as any).badge}</span>
              )}
            </Link>
          );
        })}
      </div>
      <div className="p-3 border-t border-[#E9E3F5] space-y-2 bg-[#F5F3FF]/70">
        {!collapsed && (
          <div className="bg-[#F3F0FF] border border-[#E9E3F5] rounded-[16px] p-3">
            <div className="text-[11px] text-[#7C738F] font-bold tracking-wide uppercase">Admin</div>
            <div className="text-[12px] text-[#1E1B2E] font-medium mt-1 truncate font-mono">{keyPreview}</div>
            <button onClick={() => { clearAdminKey(); router.push('/login'); }} className="mt-2 w-full h-9 rounded-xl bg-white hover:bg-[#E9E3F5] text-[#6B5A8A] hover:text-[#7C3AED] text-[12px] font-bold flex items-center justify-center gap-1.5 border border-[#E9E3F5]">
              <LogOut size={13} /> Keluar
            </button>
          </div>
        )}
        {collapsed && (
          <button onClick={() => { clearAdminKey(); router.push('/login'); }} title="Keluar"
            className="mx-auto w-9 h-9 rounded-xl bg-white hover:bg-[#F3F0FF] text-[#6B5A8A] hover:text-[#DC2626] grid place-items-center border border-[#E9E3F5]">
            <LogOut size={15} />
          </button>
        )}
      </div>
    </aside>
  );
}
