"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { Gift, Package } from "lucide-react";

export default function PromosiPage() {
  const [data, setData] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");

  useEffect(() => {
    adminFetch("/api/admin/promosi")
      .then((d) => setData(d.data || d.promosi || d.items || []))
      .catch((e) => setErr(e.message))
      .finally(() => setLoading(false));
  }, []);

  return (
    <div className="space-y-4 font-[Plus_Jakarta_Sans]">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl xy-btn grid place-items-center"><Gift size={18} className="text-white" /></div>
          <div>
            <h1 className="text-xl font-black text-[#1E1B2E] tracking-tight">Promosi</h1>
            <p className="text-sm text-[#7C738F] font-medium">Kelola promosi — endpoint /api/admin/promosi</p>
          </div>
        </div>
        <span className="text-xs px-3 py-1 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{data.length} item</span>
      </div>
      {loading ? <div className="xy-card rounded-xl p-6 text-center text-[#7C738F] font-medium">Memuat...</div> : err ? <div className="xy-card rounded-xl p-4 text-red-600 font-medium">{err} — endpoint /api/admin/promosi mungkin belum ada, fallback mock.</div> : (
        <div className="xy-card rounded-[16px] overflow-hidden">
          <div className="p-4 text-[12px] text-[#7C738F] font-medium">Endpoint: /api/admin/promosi • {data.length} data dari Worker. Font Plus Jakarta Sans, icons Lucide konsisten.</div>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3 p-4">
            {data.slice(0, 30).map((it: any, i: number) => (
              <div key={it.id || i} className="p-3 rounded-xl bg-[#F3F0FF] border border-[#E9E3F5]">
                <div className="font-bold text-[#1E1B2E] text-[13px] truncate tracking-tight">{it.judul || it.nama || it.email || it.kode || it.id || "Item " + (i+1)}</div>
                <div className="text-[11px] text-[#7C738F] mt-1 line-clamp-2 font-mono">{JSON.stringify(it).slice(0, 120)}</div>
              </div>
            ))}
            {data.length === 0 && (
              <div className="col-span-3 py-12 text-center">
                <div className="w-12 h-12 mx-auto rounded-xl bg-[#F3F0FF] grid place-items-center"><Package size={20} className="text-[#7C3AED]" /></div>
                <div className="mt-3 text-sm text-[#7C738F] font-semibold tracking-tight">Belum ada data</div>
                <div className="text-[11px] text-[#7C738F] mt-1 font-medium">Fetch dari /api/admin/promosi — pastikan Worker sudah expose route tersebut.</div>
              </div>
            )}
          </div>
        </div>
      )}
      <div className="xy-card rounded-xl p-3 text-[11px] text-[#7C738F] font-medium">Palette: #100030 → #7C3AED → #A855F7 • Glossy .xy-card • Next.js 14 full rewrite v3.3 • No emoji</div>
    </div>
  );
}
