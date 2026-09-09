export const xyTheme = {
  bg: "#100030",
  bg2: "#200050",
  violet: "#7C3AED",
  violet2: "#8B5CF6",
  violet3: "#A855F7",
  indigo: "#7830C0",
  card: "#1A0A3A",
  border: "rgba(124,58,237,0.22)",
  gradient: "linear-gradient(135deg,#100030 0%,#200050 35%,#2D0A5E 55%,#7C3AED 100%)",
  btn: "linear-gradient(135deg,#7C3AED 0%,#8B5CF6 45%,#A855F7 100%)",
  font: "'Plus Jakarta Sans', Inter, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif",
};

// Icon names map to lucide-react icons — NO EMOJI for cross-platform consistency
export type MenuIcon =
  | "layout-dashboard"
  | "receipt"
  | "users"
  | "monitor"
  | "gamepad"
  | "image"
  | "gift"
  | "ticket"
  | "credit-card"
  | "cpu"
  | "activity"
  | "shield-check"
  | "wallet"
  | "message-circle"
  | "messages-square"
  | "star"
  | "bar-chart-3"
  | "line-chart"
  | "rocket"
  | "bell"
  | "package"
  | "file-text"
  | "settings"
  | "shield-user";

export const MENU: { id: string; label: string; icon: MenuIcon; path: string; badge?: string }[] = [
  { id: "dash", label: "Dashboard", icon: "layout-dashboard", path: "/" },
  { id: "orders", label: "Pesanan", icon: "receipt", path: "/orders" },
  { id: "users", label: "Pengguna", icon: "users", path: "/users" },
  { id: "plans", label: "Paket PC", icon: "monitor", path: "/plans" },
  { id: "produk", label: "Produk Akun", icon: "gamepad", path: "/produk" },
  { id: "banners", label: "Banner", icon: "image", path: "/banners" },
  { id: "promosi", label: "Promosi", icon: "gift", path: "/promosi" },
  { id: "voucher", label: "Voucher", icon: "ticket", path: "/voucher" },
  { id: "topup", label: "TopUp", icon: "credit-card", path: "/topup" },
  { id: "unit", label: "Unit PC", icon: "cpu", path: "/unit" },
  { id: "live", label: "Live Monitor", icon: "activity", path: "/live", badge: "BARU" },
  { id: "security", label: "Security", icon: "shield-check", path: "/security" },
  { id: "keuangan", label: "Keuangan", icon: "wallet", path: "/keuangan", badge: "BARU" },
  { id: "cs", label: "CS Realtime", icon: "message-circle", path: "/cs" },
  { id: "forum", label: "Forum", icon: "messages-square", path: "/forum" },
  { id: "ulasan", label: "Ulasan", icon: "star", path: "/ulasan" },
  { id: "statistik", label: "Statistik", icon: "bar-chart-3", path: "/statistik" },
  { id: "analitik", label: "Analitik", icon: "line-chart", path: "/analitik" },
  { id: "rilis", label: "Rilis App", icon: "rocket", path: "/rilis", badge: "BARU" },
  { id: "push", label: "Push Notif", icon: "bell", path: "/push", badge: "BARU" },
  { id: "media", label: "Media", icon: "package", path: "/media" },
  { id: "audit", label: "Audit Log", icon: "file-text", path: "/audit" },
  { id: "sistem", label: "Sistem", icon: "settings", path: "/sistem" },
  { id: "peran", label: "Peran Admin", icon: "shield-user", path: "/peran" },
] as const;
