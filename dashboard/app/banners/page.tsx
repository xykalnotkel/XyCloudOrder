"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { Image as ImageIcon, Power } from "lucide-react";
import { Chip, ErrBox, Header, Load } from "@/components/ui/kit";

export default function BannersPage() {
  const [rows, setRows] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");
  const [saving, setSaving] = useState<string | null>(null);

  async function muat() {
    setLoading(true); setErr("");
    try { setRows(await adminFetch("/api/admin/banners")); }
    catch (e: any) { setErr(e.message); }
    finally { setLoading(false); }
  }
  useEffect(() => { muat(); }, []);

  async function toggleAktif(b: any) {
    setSaving(b.id); setErr("");
    try {
      // endpoint POST bersifat upsert (INSERT OR REPLACE by id) — pakai utk toggle aktif.
      await adminFetch("/api/admin/banners", {
        method: "POST",
        body: {
          id: b.id, judul: b.judul, subjudul: b.subjudul, label: b.label, cta: b.cta,
          aksi: b.aksi, target: b.target, warna1: b.warna1, warna2: b.warna2,
          ikon: b.ikon, urutan: b.urutan, aktif: b.aktif ? 0 : 1, gambar: b.gambar || "",
        },
      });
      await muat();
    } catch (e: any) { setErr(e.message); }
    finally { setSaving(null); }
  }

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header icon={ImageIcon} title="Banner" sub="Carousel banner beranda aplikasi & web — tampilan & status aktif"
        right={<span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{rows.length} banner</span>} />
      {loading ? <Load /> : err ? <ErrBox msg={err} /> : rows.length === 0 ? (
        <div className="xy-card rounded-[20px] p-10 text-center text-[#7C738F] font-medium">Belum ada banner.</div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-3">
          {rows.map((b) => {
            const style = b.gambar
              ? undefined
              : { background: `linear-gradient(120deg, ${b.warna1 || "#7C3AED"}, ${b.warna2 || "#5B21B6"})` };
            return (
              <div key={b.id} className="xy-card rounded-[20px] overflow-hidden">
                <div className="h-28 flex items-center justify-center overflow-hidden" style={style}>
                  {b.gambar ? <img src={b.gambar} alt={b.judul} className="w-full h-full object-cover" /> : (
                    <span className="text-white font-black text-[16px] px-4 text-center">{b.judul}</span>
                  )}
                </div>
                <div className="p-4">
                  <div className="flex items-start justify-between gap-2">
                    <div className="min-w-0">
                      <div className="text-[13.5px] font-bold text-[#1E1B2E] truncate">{b.judul}</div>
                      {b.subjudul && <div className="text-[11px] text-[#7C738F] truncate">{b.subjudul}</div>}
                      <div className="mt-1.5 flex items-center gap-1.5 flex-wrap">
                        <Chip tone="netral">{b.label || "no label"}</Chip>
                        <Chip tone="info">aksi: {b.aksi || "-"}</Chip>
                        <Chip tone="netral">urutan {b.urutan}</Chip>
                      </div>
                    </div>
                    <button
                      onClick={() => toggleAktif(b)} disabled={saving === b.id}
                      title={b.aktif ? "Nonaktifkan" : "Aktifkan"}
                      className={`shrink-0 p-2 rounded-xl border transition ${b.aktif ? "bg-emerald-500/15 border-emerald-500/30 text-emerald-600" : "bg-[#F3F0FF] border-[#E9E3F5] text-[#B9AECF]"}`}>
                      <Power size={14} />
                    </button>
                  </div>
                  <div className="mt-2 text-[10.5px] text-[#7C738F] font-mono break-all">{b.target || "—"}</div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
