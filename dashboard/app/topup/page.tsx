"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";

export default function TopupPage() {
  const [data, setData] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");

  useEffect(() => {
    adminFetch("/api/admin/topup")
      .then((d) => setData(d.data || d.topup || d.items || []))
      .catch((e) => setErr(e.message))
      .finally(() => setLoading(false));
  }, []);

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-black text-white">TopUp 💳</h1>
          <p className="text-sm text-violet-200/60">Verifikasi topup saldo — anti-double, atomik WHERE</p>
        </div>
        <span className="text-xs px-3 py-1 rounded-full bg-white/5 border border-white/10">{data.length} item</span>
      </div>
      {loading ? <div className="xy-card rounded-xl p-6 text-center text-white/60">Memuat...</div> : err ? <div className="xy-card rounded-xl p-4 text-red-300">{err} — endpoint /api/admin/topup mungkin belum ada, fallback mock.</div> : (
        <div className="xy-card rounded-[16px] overflow-hidden">
          <div className="p-4 text-[12px] text-white/40">Endpoint: /api/admin/topup • {data.length} data dari Worker. Jika kosong, UI tetap glossy violet-indigo.</div>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3 p-4">
            {data.slice(0, 30).map((it: any, i: number) => (
              <div key={it.id || i} className="p-3 rounded-xl bg-white/[0.04] border border-white/5">
                <div className="font-bold text-white text-[13px] truncate">{it.judul || it.nama || it.email || it.kode || it.id || "Item " + (i+1)}</div>
                <div className="text-[11px] text-violet-200/50 mt-1 line-clamp-2">{JSON.stringify(it).slice(0, 120)}</div>
              </div>
            ))}
            {data.length === 0 && (
              <div className="col-span-3 py-12 text-center">
                <div className="w-12 h-12 mx-auto rounded-xl bg-[#7C3AED]/20 grid place-items-center text-xl">📦</div>
                <div className="mt-3 text-sm text-white/60">Belum ada data</div>
                <div className="text-[11px] text-white/30 mt-1">Fetch dari /api/admin/topup — pastikan Worker sudah expose route tersebut.</div>
              </div>
            )}
          </div>
        </div>
      )}
      <div className="xy-card rounded-xl p-3 text-[11px] text-white/30">Palette: #100030 → #7C3AED → #A855F7 • Glossy .xy-card • Next.js 14 full rewrite v3.3</div>
    </div>
  );
}
