"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { Database, DatabaseBackup, Download, HardDrive, Link2, RefreshCw } from "lucide-react";
import { Chip, EmptyBox, ErrBox, Header, jam, Load, Stat } from "@/components/ui/kit";

export default function CadanganPage() {
  const [list, setList] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");
  const [busy, setBusy] = useState(false);
  const [info, setInfo] = useState("");

  async function muat() {
    setLoading(true); setErr("");
    try { const d = await adminFetch("/api/admin/cadangan"); setList(Array.isArray(d) ? d : []); }
    catch (e: any) { setErr(e.message); }
    finally { setLoading(false); }
  }
  useEffect(() => { muat(); }, []);

  async function buat() {
    if (!confirm("Buat cadangan database sekarang?")) return;
    setBusy(true); setErr(""); setInfo("");
    try { const r = await adminFetch("/api/admin/cadangan", { method: "POST" }); setInfo("Cadangan " + r.id + " dibuat: " + r.baris + " baris."); await muat(); }
    catch (e: any) { setErr(e.message); }
    finally { setBusy(false); }
  }

  async function unduh(id: string) {
    setBusy(true); setErr(""); setInfo("");
    try {
      const obj = await adminFetch("/api/admin/cadangan/" + id);
      const blob = new Blob([JSON.stringify(obj, null, 2)], { type: "application/json" });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url; a.download = "xycloudstore-" + id + ".json";
      document.body.appendChild(a); a.click(); a.remove();
      URL.revokeObjectURL(url);
      setInfo("Cadangan " + id + " diunduh.");
    } catch (e: any) { setErr(e.message); }
    finally { setBusy(false); }
  }

  const totalBaris = list.reduce((a, c) => a + Number(c.jumlah_baris || 0), 0);
  const ukuran = list[0] ? Number(list[0].ukuran || 0) : 0;

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header icon={Database} title="Cadangan DB" sub="Snapshot database D1 (otomatis tiap hari 19 UTC) — unduh atau impor kembali"
        right={
          <div className="flex gap-2">
            <a href="/impor-cadangan" className="inline-flex items-center gap-1.5 px-4 h-9 rounded-xl bg-white border border-[#E9E3F5] hover:border-[#C4B5FD] text-[12px] font-semibold text-[#7C3AED]">
              <Link2 size={13} /> Tarik DB lama
            </a>
            <button onClick={buat} disabled={busy} className="inline-flex items-center gap-1.5 px-4 h-9 rounded-xl xy-btn text-white text-[12px] font-semibold disabled:opacity-50">
              <RefreshCw size={13} className={busy ? "animate-spin" : ""} /> Buat sekarang
            </button>
          </div>
        } />
      {info && <div className="px-4 py-2.5 rounded-xl bg-emerald-500/10 border border-emerald-500/25 text-emerald-700 text-[12.5px] font-semibold">{info}</div>}
      <div className="grid grid-cols-3 gap-3">
        <Stat label="Tersimpan" value={list.length} sub="cadangan terakhir (maks 7)" />
        <Stat label="Baris total" value={totalBaris.toLocaleString("id-ID")} sub="baris di snapshot" />
        <Stat label="Snapshot terbaru" value={ukuran >= 1024 ? (ukuran / 1024).toFixed(1) + " KB" : ukuran + " B"} sub={list[0] ? jam(list[0].dibuat) : "belum ada"} />
      </div>
      {loading ? <Load /> : err ? <ErrBox msg={err} /> : list.length === 0 ? (
        <EmptyBox msg="Belum ada cadangan." sub="Cadangan otomatis dibuat tiap hari; atau ketuk “Buat sekarang”." />
      ) : (
        <div className="xy-card rounded-[20px] p-2">
          {list.map((c) => (
            <div key={c.id} className="flex items-center justify-between gap-3 px-3 py-3 border-b border-[#F0EDFB] last:border-0">
              <div className="flex items-center gap-3 min-w-0">
                <div className="w-9 h-9 shrink-0 rounded-xl bg-[#F3F0FF] border border-[#E9E3F5] grid place-items-center"><HardDrive size={15} className="text-[#7C3AED]" /></div>
                <div className="min-w-0">
                  <div className="font-semibold text-[#1E1B2E] text-[12.5px] font-mono truncate">{c.id}</div>
                  <div className="text-[11px] text-[#7C738F] font-medium">{c.jumlah_baris.toLocaleString("id-ID")} baris • {(Number(c.ukuran) / 1024).toFixed(1)} KB • {jam(c.dibuat)}</div>
                </div>
              </div>
              <div className="flex items-center gap-2 shrink-0">
                <Chip tone="ok">terbaru ke-{list.indexOf(c) + 1}</Chip>
                <button onClick={() => unduh(c.id)} disabled={busy} className="inline-flex items-center gap-1 text-[11px] px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] text-[#7C3AED] font-semibold disabled:opacity-50">
                  <Download size={12} /> Unduh JSON
                </button>
              </div>
            </div>
          ))}
          <div className="px-3 py-2 text-[11px] text-[#7C738F] font-medium flex items-center gap-1.5">
            <DatabaseBackup size={12} className="text-[#7C3AED]" /> File unduhan bisa diimpor lewat menu “Tarik DB lama”.
          </div>
        </div>
      )}
    </div>
  );
}
