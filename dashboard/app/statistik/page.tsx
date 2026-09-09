"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { BarChart3, Flame, MessageSquare, Package, Server, Star, Users, Wallet } from "lucide-react";

const rupiah = (n: number | string | undefined | null) => "Rp " + Number(n || 0).toLocaleString("id-ID");

function TrenBaris({ d, v, total }: { d: string; v: number; total: number }) {
  const p = total ? Math.max(2, Math.round((v / total) * 100)) : 0;
  return (
    <div className="grid grid-cols-[86px_1fr_86px] items-center gap-2 text-[11px]">
      <span className="text-[#7C738F] font-medium">{String(d).slice(5)}</span>
      <div className="h-2 rounded-full bg-[#F3F0FF] overflow-hidden">
        <div className="h-full rounded-full bg-gradient-to-r from-[#7C3AED] to-[#A855F7]" style={{ width: `${p}%` }} />
      </div>
      <span className="text-right font-mono text-[#1E1B2E]">{v}</span>
    </div>
  );
}

export default function StatistikPage() {
  const [d, setD] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");

  useEffect(() => {
    adminFetch("/api/admin/statistik")
      .then(setD)
      .catch((e) => setErr(e.message))
      .finally(() => setLoading(false));
  }, []);

  const k = (o: any, def = 0) => Number(o ?? def);

  const cards = [
    { l: "Pengguna", v: String(k(d?.pengguna?.total)), s: `+${k(d?.pengguna?.baru7Hari)} / 7 hari`, Icon: Users },
    { l: "Pesanan", v: String(k(d?.order?.total)), s: `${k(d?.order?.aktif)} aktif`, Icon: Package },
    { l: "Omzet Order", v: rupiah(k(d?.order?.omzet)), s: "dari pesanan selesai", Icon: Wallet },
    { l: "Saldo Beredar", v: rupiah(k(d?.saldoBeredar)), s: "di dompet user", Icon: Wallet },
    { l: "Produk", v: String(k(d?.produk?.total)), s: `${k(d?.produk?.terjual)} terjual • stok ${k(d?.produk?.stok)}`, Icon: Package },
    { l: "Unit PC", v: String(k(d?.unit?.total)), s: `${k(d?.unit?.hidup)} online`, Icon: Server },
    { l: "Sesi Aktif", v: String(k(d?.sesiAktif)), s: "belum selesai", Icon: Server },
    { l: "Forum", v: String(k(d?.forum?.post)), s: `${k(d?.forum?.balasan)} balasan`, Icon: MessageSquare },
  ];

  const totHarian = (d?.harian || []).reduce((s: number, r: any) => s + k(r.v), 0);
  const totPengguna = (d?.penggunaHarian || []).reduce((s: number, r: any) => s + k(r.n), 0);

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl xy-btn grid place-items-center"><BarChart3 size={18} className="text-white" /></div>
        <div>
          <h1 className="text-xl font-black text-[#1E1B2E] tracking-tight">Statistik</h1>
          <p className="text-sm text-[#7C738F] font-medium">Ringkasan bisnis dari /api/admin/statistik (D1 agregat)</p>
        </div>
      </div>

      {loading ? (
        <div className="xy-card rounded-xl p-10 text-center text-[#7C738F] font-medium">Menghitung statistik…</div>
      ) : err ? (
        <div className="xy-card rounded-xl p-4 text-red-600 font-medium">{err} — pastikan endpoint /api/admin/statistik tersedia di Worker.</div>
      ) : (
        <>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            {cards.map((c) => (
              <div key={c.l} className="xy-card rounded-[14px] p-4">
                <div className="flex items-center justify-between">
                  <div className="w-8 h-8 rounded-lg bg-[#F3F0FF] border border-[#E9E3F5] grid place-items-center"><c.Icon size={15} className="text-[#7C3AED]" /></div>
                  <span className="text-[9px] px-1.5 py-0.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium text-[#7C738F]">{c.l}</span>
                </div>
                <div className="mt-3 text-lg font-bold text-[#1E1B2E] tracking-tight truncate">{c.v}</div>
                <div className="text-[10px] text-[#7C738F] font-medium mt-0.5">{c.s}</div>
              </div>
            ))}
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
            <div className="xy-card rounded-[16px] p-5">
              <h3 className="font-bold text-[#1E1B2E] tracking-tight flex items-center gap-2"><Flame size={15} className="text-[#7C3AED]" /> Pesanan per Hari (30 hari)</h3>
              <div className="mt-4 space-y-1.5 max-h-[260px] overflow-auto pr-1">
                {(d?.harian || []).slice(-14).map((r: any) => (
                  <TrenBaris key={r.d} d={r.d} v={k(r.n)} total={Math.max(1, (d?.harian || []).reduce((s2: number, x: any) => s2 + k(x.n), 0))} />
                ))}
                {(d?.harian || []).length === 0 && <div className="py-8 text-center text-[#7C738F] text-sm font-medium">Belum ada pesanan.</div>}
              </div>
            </div>

            <div className="xy-card rounded-[16px] p-5">
              <h3 className="font-bold text-[#1E1B2E] tracking-tight flex items-center gap-2"><Users size={15} className="text-[#7C3AED]" /> Pengguna Baru per Hari</h3>
              <div className="mt-4 space-y-1.5 max-h-[260px] overflow-auto pr-1">
                {(d?.penggunaHarian || []).slice(-14).map((r: any) => (
                  <TrenBaris key={r.d} d={r.d} v={k(r.n)} total={totPengguna || 1} />
                ))}
                {(d?.penggunaHarian || []).length === 0 && <div className="py-8 text-center text-[#7C738F] text-sm font-medium">Belum ada pendaftar baru.</div>}
              </div>
            </div>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
            <div className="xy-card rounded-[16px] p-5">
              <h3 className="font-bold text-[#1E1B2E] tracking-tight flex items-center gap-2"><Star size={15} className="text-amber-600" /> Produk Terlaris</h3>
              <div className="mt-3 space-y-2">
                {(d?.produkTeratas || []).map((p: any, i: number) => (
                  <div key={p.nama + i} className="flex items-center justify-between p-2.5 rounded-xl bg-[#F3F0FF] border border-[#E9E3F5]">
                    <span className="text-[12px] text-[#1E1B2E] font-semibold truncate">{i + 1}. {p.nama}</span>
                    <span className="text-[11px] font-mono text-[#7C3AED] shrink-0">{k(p.terjual)} terjual{k(p.rating) ? ` • ★${k(p.rating)}` : ""}</span>
                  </div>
                ))}
                {(d?.produkTeratas || []).length === 0 && <div className="py-6 text-center text-[#7C738F] text-sm font-medium">Belum ada produk terjual.</div>}
              </div>
            </div>
            <div className="xy-card rounded-[16px] p-5">
              <h3 className="font-bold text-[#1E1B2E] tracking-tight flex items-center gap-2"><Wallet size={15} className="text-emerald-600" /> Paket PC Terlaris</h3>
              <div className="mt-3 space-y-2">
                {(d?.paketTeratas || []).map((p: any, i: number) => (
                  <div key={p.nama + i} className="flex items-center justify-between p-2.5 rounded-xl bg-[#F3F0FF] border border-[#E9E3F5]">
                    <span className="text-[12px] text-[#1E1B2E] font-semibold truncate">{i + 1}. {p.nama}</span>
                    <span className="text-[11px] font-mono text-[#7C3AED] shrink-0">{k(p.n)}x • {rupiah(p.v)}</span>
                  </div>
                ))}
                {(d?.paketTeratas || []).length === 0 && <div className="py-6 text-center text-[#7C738F] text-sm font-medium">Belum ada order sewa.</div>}
              </div>
              {totHarian > 0 && <div className="mt-3 text-[11px] text-[#7C738F] font-medium">Omzet 30 hari (chart atas) total {rupiah(totHarian)}.</div>}
            </div>
          </div>
        </>
      )}
    </div>
  );
}
