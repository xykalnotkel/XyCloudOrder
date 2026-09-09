"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";

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
    <div className="space-y-4">
      <h1 className="text-xl font-black text-white">Pengguna</h1>
      <div className="flex gap-2">
        <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Cari email..." className="px-4 py-2 rounded-xl bg-[#100030] border border-white/10 text-white text-sm w-[260px]" />
        <span className="text-xs px-3 py-2 rounded-xl bg-white/5 border border-white/10">{filtered.length} user</span>
      </div>
      {loading ? <div className="xy-card rounded-xl p-6 text-center text-white/60">Memuat...</div> : err ? <div className="xy-card rounded-xl p-4 text-red-300">{err}</div> : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
          {filtered.slice(0, 60).map((u: any) => (
            <div key={u.id} className="xy-card rounded-[14px] p-4">
              <div className="flex items-center gap-3">
                <div className="w-9 h-9 rounded-xl xy-btn grid place-items-center text-sm font-bold">{(u.email || "U")[0].toUpperCase()}</div>
                <div className="min-w-0">
                  <div className="text-[13px] font-bold text-white truncate">{u.email}</div>
                  <div className="text-[11px] text-violet-200/50">Saldo Rp {(u.saldo || 0).toLocaleString()} • {u.device_count || 1} device</div>
                </div>
              </div>
              <div className="mt-3 flex gap-1.5">
                <span className="text-[10px] px-2 py-0.5 rounded-full bg-white/5 border border-white/10">{u.status || "aktif"}</span>
                {u.is_blocked && <span className="text-[10px] px-2 py-0.5 rounded-full bg-red-500/20 border border-red-500/30">blocked</span>}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
