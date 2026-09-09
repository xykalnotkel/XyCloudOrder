"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { Eraser, ScrollText } from "lucide-react";
import { Chip, EmptyBox, ErrBox, Header, jam, Load } from "@/components/ui/kit";

export default function LogSistemPage() {
  const [rows, setRows] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");
  const [busy, setBusy] = useState(false);
  const [hasil, setHasil] = useState("");

  async function muat() {
    setLoading(true); setErr("");
    try { setRows(await adminFetch("/api/admin/log-sistem")); }
    catch (e: any) { setErr(e.message); }
    finally { setLoading(false); }
  }
  useEffect(() => { muat(); }, []);

  async function bersihkan() {
    if (!confirm("Hapus log sistem yang berumur lebih dari 24 jam?")) return;
    setBusy(true); setErr(""); setHasil("");
    try { await adminFetch("/api/admin/log-sistem/bersihkan", { method: "DELETE" }); setHasil("Log lama dibersihkan."); await muat(); }
    catch (e: any) { setErr(e.message); }
    finally { setBusy(false); }
  }

  const jenis = Array.from(new Set(rows.map((r) => r.jenis)));

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header icon={ScrollText} title="Log Sistem" sub="Catatan internal Worker — pemeliharaan, cache, cadangan, impor"
        right={
          <div className="flex items-center gap-2">
            <span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{rows.length} entri • {jenis.length} jenis</span>
            <button onClick={bersihkan} disabled={busy} className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-full bg-white border border-[#E9E3F5] hover:border-rose-300 text-[12px] font-bold text-rose-600 disabled:opacity-50">
              <Eraser size={13} /> Bersihkan &gt;24 jam
            </button>
          </div>
        } />
      {hasil && <div className="px-4 py-2.5 rounded-xl bg-emerald-500/10 border border-emerald-500/25 text-emerald-700 text-[12.5px] font-semibold">{hasil}</div>}
      {loading ? <Load /> : err ? <ErrBox msg={err} /> : rows.length === 0 ? (
        <EmptyBox msg="Belum ada log sistem." sub="Log tercatat saat Worker menjalankan tugas otomatis." />
      ) : (
        <div className="space-y-2">
          {rows.map((l) => (
            <div key={l.id} className="xy-card rounded-[14px] px-4 py-3 flex items-start gap-3">
              <Chip tone={l.jenis === "galat" || l.jenis === "error" ? "bad" : l.jenis === "pemeliharaan" ? "warn" : l.jenis === "cadangan" || l.jenis === "impor" ? "ok" : "info"}>{l.jenis}</Chip>
              <div className="min-w-0 flex-1">
                <div className="text-[13px] text-[#1E1B2E]/90 font-medium leading-relaxed break-words">{l.pesan || "—"}</div>
                <div className="text-[10.5px] text-[#7C738F] font-mono mt-0.5">{l.id} • {jam(l.waktu)}</div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
