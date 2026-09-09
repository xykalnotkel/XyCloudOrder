"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { Users, Search } from "lucide-react";

export default function UsersPage() {
  const [users, setUsers] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");
  const [q, setQ] = useState("");

  useEffect(() => {
    adminFetch("/api/admin/users")
      .then((d) => setUsers(d.users || d.data || []))
      .catch((e) => setErr(e.message))
      .finally(() => setLoading(false));
  }, []);

  const filtered = users.filter((u: any) => !q || (u.email || "").toLowerCase().includes(q.toLowerCase()));

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl xy-btn grid place-items-center"><Users size={18} className="text-white" /></div>
        <h1 className="text-xl font-black text-[#1E1B2E] tracking-tight">Pengguna</h1>
      </div>
      <div className="flex gap-2">
        <div className="relative">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-[#7C738F]" />
          <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Cari email..." className="pl-9 pr-4 py-2 rounded-xl bg-[#FFFFFF] border border-[#E9E3F5] text-[#1E1B2E] text-sm w-[260px] font-medium outline-none focus:border-[#7C3AED]" />
        </div>
        <span className="text-xs px-3 py-2 rounded-xl bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{filtered.length} user</span>
      </div>
      {loading ? <div className="xy-card rounded-xl p-6 text-center text-[#7C738F] font-medium">Memuat...</div> : err ? <div className="xy-card rounded-xl p-4 text-red-600 font-medium">{err}</div> : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
          {filtered.slice(0, 60).map((u: any) => (
            <div key={u.id} className="xy-card rounded-[14px] p-4">
              <div className="flex items-center gap-3">
                <div className="w-9 h-9 rounded-xl xy-btn grid place-items-center text-sm font-bold tracking-tight">{(u.email || "U")[0].toUpperCase()}</div>
                <div className="min-w-0">
                  <div className="text-[13px] font-bold text-[#1E1B2E] truncate tracking-tight">{u.email}</div>
                  <div className="text-[11px] text-[#7C738F] font-medium">Saldo Rp {(u.saldo || 0).toLocaleString()} • {u.device_count || 1} device</div>
                </div>
              </div>
              <div className="mt-3 flex gap-1.5">
                <span className="text-[10px] px-2 py-0.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-semibold">{u.status || "aktif"}</span>
                {u.is_blocked && <span className="text-[10px] px-2 py-0.5 rounded-full bg-red-500/20 border border-red-500/30 font-semibold">blocked</span>}
              </div>
            </div>
          ))}
        </div>
      )}
      <div className="xy-card rounded-xl p-3 text-[11px] text-[#7C738F] font-medium">Icons Lucide, font Plus Jakarta Sans, no emoji</div>
    </div>
  );
}
