"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { ChevronDown, ChevronRight, Terminal } from "lucide-react";
import { Chip, EmptyBox, ErrBox, Header, jam, Load, Tabel } from "@/components/ui/kit";

const TONE: Record<string, any> = { antre: "warn", selesai: "ok", gagal: "bad", "diproses": "info" };

export default function PerintahPage() {
  const [rows, setRows] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");
  const [bukaId, setBukaId] = useState<string | null>(null);

  useEffect(() => {
    adminFetch("/api/admin/perintah")
      .then((d) => setRows(Array.isArray(d) ? d : []))
      .catch((e) => setErr(e.message))
      .finally(() => setLoading(false));
  }, []);

  const n = (s: string) => rows.filter((r) => r.status === s).length;

  return (
    <div className="space-y-4 font-[Plus_Jakarta_Sans]">
      <Header icon={Terminal} title="Perintah Agen" sub="Antrean perintah ke agen PC (mulai sesi, pasang pin, dll)"
        right={
          <div className="flex gap-1.5 flex-wrap">
            <span className="text-[11px] px-2.5 py-1 rounded-full bg-amber-500/15 border border-amber-500/30 text-amber-700 font-bold">{n("antre")} antre</span>
            <span className="text-[11px] px-2.5 py-1 rounded-full bg-emerald-500/15 border border-emerald-500/30 text-emerald-700 font-bold">{n("selesai")} selesai</span>
            <span className="text-[11px] px-2.5 py-1 rounded-full bg-rose-500/10 border border-rose-500/25 text-rose-600 font-bold">{n("gagal")} gagal</span>
          </div>
        } />
      {loading ? <Load /> : err ? <ErrBox msg={err} /> : (
        <Tabel kosong="Belum ada perintah ke agen."
          kolom={[
            { k: "id", label: "Perintah", render: (r) => <div><div className="font-mono text-[11px] text-[#7C738F]">{r.id}</div><div className="font-bold text-[#1E1B2E] text-[13px]">{r.jenis}</div></div> },
            { k: "agen", label: "Agen", render: (r) => <div><div className="font-bold text-[#1E1B2E] text-[12.5px]">{r.agen_nama || r.agen_id}</div>{r.host && <div className="font-mono text-[10.5px] text-[#7C738F]">{r.host}</div>}</div> },
            { k: "status", label: "Status", render: (r) => <Chip tone={TONE[r.status] || "netral"}>{r.status}</Chip> },
            { k: "hasil", label: "Hasil", render: (r) => <span className="text-[11.5px] text-[#7C738F] max-w-[200px] block truncate">{r.hasil || "—"}</span> },
            { k: "waktu", label: "Dibuat / Diproses", render: (r) => <div className="text-[11px] font-mono text-[#7C738F]">{jam(r.dibuat)}{r.diproses ? <><br />{jam(r.diproses)}</> : null}</div> },
            { k: "muatan", label: "Muatan", render: (r) =>
              <button onClick={() => setBukaId(bukaId === r.id ? null : r.id)} className="inline-flex items-center gap-1 text-[11px] font-bold text-[#7C3AED]">
                {bukaId === r.id ? <ChevronDown size={12} /> : <ChevronRight size={12} />} JSON
              </button> },
          ]}
          rows={rows.map((r) => ({ ...r, _row: r }))} />
      )}
      {bukaId && (() => {
        const r = rows.find((x) => x.id === bukaId);
        if (!r) return null;
        return (
          <div className="xy-card rounded-[16px] p-4">
            <div className="text-[11px] font-bold text-[#7C738F] uppercase tracking-wide mb-2">Muatan {r.jenis} — {r.id}</div>
            <pre className="text-[11px] bg-white border border-[#E9E3F5] rounded-xl p-3 overflow-x-auto font-mono text-[#1E1B2E]/80 whitespace-pre-wrap">{JSON.stringify(r.muatan_terurai ?? r.muatan, null, 2)}</pre>
          </div>
        );
      })()}
    </div>
  );
}
