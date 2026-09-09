"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { BarChart3, Eye, FileText, Globe2, Smartphone } from "lucide-react";

function Baris({ l, v, total, Icon }: { l: string; v: number; total: number; Icon?: any }) {
  const p = total ? Math.max(2, Math.round((v / total) * 100)) : 0;
  return (
    <div className="grid grid-cols-[92px_1fr_60px] items-center gap-2 text-[12px]">
      <span className="text-[#7C738F] font-medium truncate flex items-center gap-1.5">{Icon && <Icon size={11} className="shrink-0" />}{l}</span>
      <div className="h-2 rounded-full bg-[#F3F0FF] overflow-hidden">
        <div className="h-full rounded-full bg-gradient-to-r from-[#7C3AED] to-[#A855F7]" style={{ width: `${p}%` }} />
      </div>
      <span className="text-right font-mono text-[#1E1B2E]">{v}</span>
    </div>
  );
}

export default function AnalitikPage() {
  const [d, setD] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");

  useEffect(() => {
    adminFetch("/api/admin/analitik")
      .then(setD)
      .catch((e) => setErr(e.message))
      .finally(() => setLoading(false));
  }, []);

  const total = k(d?.total);
  function k(v: any) { return Number(v ?? 0); }
  const maxHalaman = Math.max(1, ...(d?.halaman || []).map((h: any) => k(h.n)));

  return (
    <div className="space-y-4 font-[Plus_Jakarta_Sans]">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl xy-btn grid place-items-center"><Eye size={18} className="text-white" /></div>
        <div>
          <h1 className="text-xl font-black text-[#1E1B2E] tracking-tight">Analitik Web</h1>
          <p className="text-sm text-[#7C738F] font-medium">Kunjungan web & aplikasi 30 hari dari /api/admin/analitik</p>
        </div>
      </div>

      {loading ? (
        <div className="xy-card rounded-xl p-10 text-center text-[#7C738F] font-medium">Memuat analitik…</div>
      ) : err ? (
        <div className="xy-card rounded-xl p-4 text-red-600 font-medium">{err}</div>
      ) : (
        <>
          <div className="xy-card rounded-[14px] p-4 flex items-center gap-3">
            <div className="w-9 h-9 rounded-xl bg-[#F3F0FF] border border-[#E9E3F5] grid place-items-center"><BarChart3 size={16} className="text-[#7C3AED]" /></div>
            <div>
              <div className="text-[11px] text-[#7C738F] font-medium tracking-wide uppercase">Total Kunjungan (30 hari)</div>
              <div className="text-lg font-bold text-[#1E1B2E] mt-0.5 tracking-tight">{total.toLocaleString("id-ID")}</div>
            </div>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
            <div className="xy-card rounded-[16px] p-5">
              <h3 className="font-bold text-[#1E1B2E] tracking-tight flex items-center gap-2"><BarChart3 size={15} className="text-[#7C3AED]" /> Tren Kunjungan</h3>
              <div className="mt-4 space-y-1.5 max-h-[280px] overflow-auto pr-1">
                {(d?.harian || []).slice(-14).map((r: any) => (
                  <Baris key={r.d} l={String(r.d).slice(5)} v={k(r.n)} total={total || 1} />
                ))}
                {(d?.harian || []).length === 0 && <div className="py-8 text-center text-[#7C738F] text-sm font-medium">Belum ada kunjungan tercatat.</div>}
              </div>
            </div>

            <div className="xy-card rounded-[16px] p-5">
              <h3 className="font-bold text-[#1E1B2E] tracking-tight flex items-center gap-2"><FileText size={15} className="text-[#7C3AED]" /> Halaman Terpopuler</h3>
              <div className="mt-4 space-y-1.5">
                {(d?.halaman || []).slice(0, 8).map((h: any) => (
                  <Baris key={h.halaman} l={String(h.halaman || "/").slice(0, 26)} v={k(h.n)} total={maxHalaman} />
                ))}
                {(d?.halaman || []).length === 0 && <div className="py-8 text-center text-[#7C738F] text-sm font-medium">Belum ada data halaman.</div>}
              </div>
            </div>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
            <div className="xy-card rounded-[16px] p-5">
              <h3 className="font-bold text-[#1E1B2E] tracking-tight flex items-center gap-2"><Smartphone size={15} className="text-[#7C3AED]" /> Perangkat</h3>
              <div className="mt-4 space-y-1.5">
                {(d?.perangkat || []).map((r: any) => (
                  <Baris key={r.perangkat} l={String(r.perangkat || "-").slice(0, 24)} v={k(r.n)} total={total || 1} />
                ))}
                {(d?.perangkat || []).length === 0 && <div className="py-8 text-center text-[#7C738F] text-sm font-medium">Belum ada data perangkat.</div>}
              </div>
            </div>
            <div className="xy-card rounded-[16px] p-5">
              <h3 className="font-bold text-[#1E1B2E] tracking-tight flex items-center gap-2"><Globe2 size={15} className="text-[#7C3AED]" /> Negara Asal</h3>
              <div className="mt-4 space-y-1.5">
                {(d?.negara || []).map((r: any) => (
                  <Baris key={r.negara} l={String(r.negara || "-").toUpperCase()} v={k(r.n)} total={total || 1} />
                ))}
                {(d?.negara || []).length === 0 && <div className="py-8 text-center text-[#7C738F] text-sm font-medium">Belum ada data negara.</div>}
              </div>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
