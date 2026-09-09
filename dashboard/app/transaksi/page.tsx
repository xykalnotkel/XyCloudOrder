"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { ArrowDownLeft, ArrowLeftRight, ArrowUpRight, Search } from "lucide-react";
import { Chip, ErrBox, Header, jam, Load, rupiah, Tabel } from "@/components/ui/kit";

const TONE: Record<string, any> = { sukses: "ok", pending: "warn", gagal: "bad", batal: "bad" };

export default function TransaksiPage() {
  const [rows, setRows] = useState<any[]>([]);
  const [q, setQ] = useState("");
  const [cari, setCari] = useState("");
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");

  async function muat() {
    setLoading(true); setErr("");
    try {
      const d = await adminFetch("/api/admin/transaksi");
      setRows(Array.isArray(d) ? d : []);
    } catch (e: any) { setErr(e.message); }
    finally { setLoading(false); }
  }
  useEffect(() => { muat(); }, []);

  const filter = (r: any) => !cari || (r.user_nama || "").toLowerCase().includes(cari.toLowerCase()) || String(r.id).includes(cari) || String(r.user_id).includes(cari) || (r.judul || "").toLowerCase().includes(cari.toLowerCase());
  const tampil = rows.filter(filter);
  const pemasukan = rows.filter((r) => Number(r.nominal) > 0).reduce((a, r) => a + Number(r.nominal), 0);
  const pengeluaran = Math.abs(rows.filter((r) => Number(r.nominal) < 0).reduce((a, r) => a + Number(r.nominal), 0));

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header icon={ArrowLeftRight} title="Riwayat Transaksi" sub="Pergerakan saldo semua pengguna (300 terakhir)"
        right={
          <div className="flex gap-2">
            <span className="text-xs px-3 py-1.5 rounded-full bg-emerald-500/15 border border-emerald-500/30 text-emerald-700 font-bold">Masuk {rupiah(pemasukan)}</span>
            <span className="text-xs px-3 py-1.5 rounded-full bg-rose-500/10 border border-rose-500/25 text-rose-600 font-bold">Keluar {rupiah(pengeluaran)}</span>
          </div>
        } />
      <div className="flex items-center gap-2">
        <div className="relative max-w-[320px] flex-1">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-[#9A8CBF]" />
          <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Cari nama / ID / judul…" className="w-full pl-9 pr-3 py-2 rounded-xl bg-white border border-[#E9E3F5] text-[12.5px] focus:border-[#7C3AED] outline-none" />
        </div>
        <button onClick={() => setCari(q)} className="px-4 h-9 rounded-xl xy-btn text-white text-[12px] font-bold">Cari</button>
      </div>
      {loading ? <Load /> : err ? <ErrBox msg={err} /> : (
        <Tabel kosong="Belum ada transaksi saldo."
          kolom={[
            { k: "id", label: "ID", render: (r) => <div className="font-mono text-[10.5px] text-[#7C738F] max-w-[120px] truncate">{r.id}</div> },
            { k: "user", label: "Pengguna", render: (r) => <div><div className="font-bold text-[#1E1B2E] text-[12.5px]">{r.user_nama || "—"}</div><div className="text-[10.5px] font-mono text-[#7C738F]">{r.user_email || r.user_id}</div></div> },
            { k: "judul", label: "Keterangan", render: (r) => <div className="text-[12px] font-medium text-[#1E1B2E]">{r.judul}<div className="text-[10.5px] text-[#7C738F]">{r.tipe}</div></div> },
            { k: "nominal", label: "Nominal", render: (r) => (
              <span className={`inline-flex items-center gap-1 font-bold ${Number(r.nominal) > 0 ? "text-emerald-600" : "text-rose-600"}`}>
                {Number(r.nominal) > 0 ? <ArrowUpRight size={12} /> : <ArrowDownLeft size={12} />} {rupiah(Math.abs(Number(r.nominal)))}
              </span> ) },
            { k: "status", label: "Status", render: (r) => <Chip tone={TONE[r.status] || "netral"}>{r.status || "sukses"}</Chip> },
            { k: "waktu", label: "Waktu", render: (r) => <span className="text-[11px] font-mono text-[#7C738F]">{jam(r.waktu)}</span> },
          ]}
          rows={tampil} />
      )}
    </div>
  );
}
