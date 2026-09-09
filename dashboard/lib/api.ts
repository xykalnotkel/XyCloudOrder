export type AdminFetchOpts = {
  adminKey?: string;
  method?: string;
  body?: any;
  headers?: Record<string,string>;
};

const BASE = process.env.NEXT_PUBLIC_API_BASE || "https://api.xycloud.my.id";

export async function adminFetch(path: string, opts: AdminFetchOpts = {}) {
  const key = opts.adminKey || (typeof window !== "undefined" ? localStorage.getItem("xy_admin_key") || "" : "");
  const headers: Record<string,string> = {
    "Content-Type": "application/json",
    ...(opts.headers || {}),
  };
  if (key) headers["x-admin-key"] = key;
  // device fingerprint passthrough
  if (typeof window !== "undefined") {
    const did = localStorage.getItem("xy_device_id");
    if (did) headers["x-xy-device"] = did;
  }
  const res = await fetch(`${BASE}${path}`, {
    method: opts.method || "GET",
    headers,
    body: opts.body ? JSON.stringify(opts.body) : undefined,
    cache: "no-store",
  });
  const text = await res.text();
  let data: any;
  try { data = JSON.parse(text); } catch { data = { raw: text }; }
  if (!res.ok) throw new Error(data?.error || data?.message || `HTTP ${res.status}`);
  return data;
}

// client side helpers
export function getAdminKey(): string {
  if (typeof window === "undefined") return "";
  return localStorage.getItem("xy_admin_key") || "";
}
export function setAdminKey(k: string) {
  if (typeof window !== "undefined") localStorage.setItem("xy_admin_key", k);
}

export async function loginAdmin(key: string) {
  // quick ping to /api/admin/dashboard
  return adminFetch("/api/admin/dashboard", { adminKey: key });
}
