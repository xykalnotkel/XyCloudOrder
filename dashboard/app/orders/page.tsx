"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { Receipt, CheckSquare } from "lucide-react";

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
    <div className="space-y-4 font-[Plus_Jakarta_Sans]">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl xy-btn grid place-items-center"><Receipt size={18} className="text-white" /></div>
          <h1 className="text-xl font-black text-white tracking-tight">Pesanan</h1>
        </div>
        <div className="flex gap-2">
          <span className="text-xs px-2 py-1 rounded-full bg-[#21114A] border border-[#2D1B5E] font-medium flex items-center gap-1"><CheckSquare size={12} /> {selected.size} dipilih (multi-select v3.0b)</span>
          {selected.size > 0 && <button className="text-xs px-3 py-1 rounded-lg xy-btn font-semibold">Aksi Massal</button>}
        </div>
      </div>
      {loading ? <div className="xy-card rounded-xl p-6 text-center text-[#9A8CBF] font-medium">Memuat...</div> : err ? <div className="xy-card rounded-xl p-4 text-red-300 font-medium">{err}</div> : (
        <div className="xy-card rounded-[16px] overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-[13px]">
              <thead className="bg-[#21114A] text-[#9A8CBF] text-[11px] uppercase font-semibold tracking-wide">
                <tr><th className="p-3 text-left"><input type="checkbox" onChange={(e) => setSelected(e.target.checked ? new Set(orders.map((o: any) => o.id)) : new Set())} /></th><th className="p-3 text-left">ID</th><th className="p-3">User</th><th className="p-3">Paket</th><th className="p-3">Status</th><th className="p-3">Tanggal</th></tr>
              </thead>
              <tbody>
                {orders.slice(0, 50).map((o: any) => (
                  <tr key={o.id} className="border-t border-[#2D1B5E] hover:bg-[#21114A]">
                    <td className="p-3"><input type="checkbox" checked={selected.has(o.id)} onChange={() => toggle(o.id)} /></td>
                    <td className="p-3 font-mono text-[11px]">{String(o.id).slice(0, 8)}</td>
                    <td className="p-3 font-medium">{o.email || o.user_id}</td>
                    <td className="p-3 font-medium">{o.plan_name || o.paket || "-"}</td>
                    <td className="p-3"><span className="px-2 py-0.5 rounded-full bg-[#21114A] border border-[#2D1B5E] text-[11px] font-semibold">{o.status}</span></td>
                    <td className="p-3 text-[#9A8CBF] font-medium">{o.created_at ? new Date(o.created_at).toLocaleDateString("id-ID") : "-"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
      <div className="xy-card rounded-xl p-3 text-[11px] text-[#6B5A8A] font-medium">Icons Lucide, font Plus Jakarta Sans, no emoji • multi-select v3.0b</div>
    </div>
  );
}
