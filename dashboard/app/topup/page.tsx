"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { Check, CreditCard, ExternalLink, X } from "lucide-react";
import { Chip, ErrBox, Header, jam, Load, rupiah, Tabel } from "@/components/ui/kit";

const TONE: Record<string, any> = {
  menunggu: "warn", diperiksa: "info", disetujui: "ok", ditolak: "bad",
};

export default function TopupPage() {
  const [rows, setRows] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");
  const [proses, setProses] = useState<string | null>(null);
  const [catatan, setCatatan] = useState("");

  async function muat() {
    setLoading(true); setErr("");
    try { setRows(await adminFetch("/api/admin/topup")); }
    catch (e: any) { setErr(e.message); }
    finally { setLoading(false); }
  }
  useEffect(() => { muat(); }, []);

  async function aksi(id: string, status: string) {
    if (status === "ditolak" && !confirm("Tolak top up ini? Saldo tidak ditambahkan.")) return;
    if (status === "disetujui" && !confirm("Setujui & tambahkan saldo? Pastikan bukti sudah dicek.")) return;
    setProses(id); setErr("");
    try {
      await adminFetch("/api/admin/topup/" + id, { method: "PATCH", body: { status, catatan: catatan || undefined } });
      setCatatan("");
      await muat();
    } catch (e: any) { setErr(e.message); }
    finally { setProses(null); }
  }

  const n = (s: string) => rows.filter((r) => r.status === s).length;

  return (
    <div className="space-y-4 font-[Plus_Jakarta_Sans]">
      <Header icon={CreditCard} title="TopUp" sub="Permintaan top up saldo + bukti transfer"
        right={
          <div className="flex gap-2">
            <span className="text-xs px-3 py-1.5 rounded-full bg-amber-500/15 border border-amber-500/30 text-amber-700 font-bold">{n("menunggu") + n("diperiksa")} pending</span>
            <span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{rows.length} total</span>
          </div>
        } />
      {loading ? <Load /> : err ? <ErrBox msg={err} /> : (
        <Tabel kosong="Belum ada permintaan top up."
          kolom={[
            { k: "id", label: "ID / User", render: (r) => <div><div className="font-mono text-[11px] text-[#7C738F]">{r.id}</div><div className="font-bold text-[#1E1B2E]">{r.nama || "—"}</div><div className="text-[10.5px] text-[#7C738F]">{r.email || r.phone || ""}</div></div> },
            { k: "nominal", label: "Nominal", render: (r) => <div><div className="font-bold text-[#1E1B2E]">{rupiah(r.nominal)}</div>{r.kode_unik ? <div className="text-[10.5px] text-[#7C738F]">+ unik {r.kode_unik}</div> : null}</div> },
            { k: "total", label: "Total", render: (r) => <div><div className="font-bold text-[#1E1B2E]">{rupiah(r.total || Number(r.nominal || 0) + Number(r.kode_unik || 0))}</div><div className="text-[10.5px] text-[#7C738F]">{r.metode || "-"}</div></div> },
            { k: "bukti", label: "Bukti", render: (r) => r.bukti ? <a href={r.bukti} target="_blank" rel="noreferrer" className="inline-flex items-center gap-1 text-[11px] font-bold text-[#7C3AED]"><ExternalLink size={11} /> lihat</a> : <span className="text-[#B9AECF]">—</span> },
            { k: "status", label: "Status", render: (r) => <div><Chip tone={TONE[r.status] || "netral"}>{r.status}</Chip>{r.catatan && <div className="text-[10px] text-[#7C738F] mt-1 max-w-[160px]">{r.catatan}</div>}</div> },
            { k: "waktu", label: "Waktu", render: (r) => <div className="text-[11px] text-[#7C738F] font-mono">{jam(r.dibuat)}{r.diproses ? <><br />diproses {jam(r.diproses)}</> : null}</div> },
            { k: "aksi", label: "Aksi", render: (r) =>
              r.status === "menunggu" || r.status === "diperiksa" ? (
                <div className="flex items-center gap-1.5">
                  <button onClick={() => aksi(r.id, "disetujui")} disabled={proses === r.id} title="Setujui" className="p-2 rounded-lg bg-emerald-500/15 border border-emerald-500/30 text-emerald-600 hover:bg-emerald-500/25 disabled:opacity-50"><Check size={14} /></button>
                  <button onClick={() => aksi(r.id, "ditolak")} disabled={proses === r.id} title="Tolak" className="p-2 rounded-lg bg-rose-500/10 border border-rose-500/25 text-rose-600 hover:bg-rose-500/20 disabled:opacity-50"><X size={14} /></button>
                </div>
              ) : <span className="text-[#B9AECF]">—</span> },
          ]}
          rows={rows} />
      )}
      <div className="flex items-center gap-2">
        <input value={catatan} onChange={(e) => setCatatan(e.target.value)} placeholder="Catatan untuk aksi (opsional)" className="max-w-[320px] flex-1 px-3.5 py-2 rounded-xl bg-white border border-[#E9E3F5] text-[12.5px] focus:border-[#7C3AED] outline-none" />
        <span className="text-[11px] text-[#7C738F] font-medium">PATCH /api/admin/topup/{'{id}'} • klaim atomik anti saldo ganda</span>
      </div>
    </div>
  );
}
