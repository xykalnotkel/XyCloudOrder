"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";

export default function OrdersPage() {
  const [orders, setOrders] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");
  const [selected, setSelected] = useState<Set<string>>(new Set());

  useEffect(() => {
    adminFetch("/api/admin/orders")
      .then((d) => setOrders(d.orders || d.data || []))
      .catch((e) => setErr(e.message))
      .finally(() => setLoading(false));
  }, []);

  const toggle = (id: string) => {
    const n = new Set(selected);
    if (n.has(id)) n.delete(id); else n.add(id);
    setSelected(n);
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-black text-white">Pesanan</h1>
        <div className="flex gap-2">
          <span className="text-xs px-2 py-1 rounded-full bg-white/5 border border-white/10">{selected.size} dipilih (multi-select v3.0b)</span>
          {selected.size > 0 && <button className="text-xs px-3 py-1 rounded-lg xy-btn">Aksi Massal</button>}
        </div>
      </div>
      {loading ? <div className="xy-card rounded-xl p-6 text-center text-white/60">Memuat...</div> : err ? <div className="xy-card rounded-xl p-4 text-red-300">{err}</div> : (
        <div className="xy-card rounded-[16px] overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-[13px]">
              <thead className="bg-white/[0.04] text-violet-200/60 text-[11px] uppercase">
                <tr><th className="p-3 text-left"><input type="checkbox" onChange={(e) => setSelected(e.target.checked ? new Set(orders.map((o: any) => o.id)) : new Set())} /></th><th className="p-3 text-left">ID</th><th className="p-3">User</th><th className="p-3">Paket</th><th className="p-3">Status</th><th className="p-3">Tanggal</th></tr>
              </thead>
              <tbody>
                {orders.slice(0, 50).map((o: any) => (
                  <tr key={o.id} className="border-t border-white/5 hover:bg-white/[0.03]">
                    <td className="p-3"><input type="checkbox" checked={selected.has(o.id)} onChange={() => toggle(o.id)} /></td>
                    <td className="p-3 font-mono text-[11px]">{String(o.id).slice(0, 8)}</td>
                    <td className="p-3">{o.email || o.user_id}</td>
                    <td className="p-3">{o.plan_name || o.paket || "-"}</td>
                    <td className="p-3"><span className="px-2 py-0.5 rounded-full bg-[#7C3AED]/20 border border-[#7C3AED]/30 text-[11px]">{o.status}</span></td>
                    <td className="p-3 text-white/50">{o.created_at ? new Date(o.created_at).toLocaleDateString("id-ID") : "-"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
