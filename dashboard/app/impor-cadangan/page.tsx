"use client";
import { useState } from "react";
import { adminFetch } from "@/lib/api";
import { DatabaseBackup, FileJson, UploadCloud } from "lucide-react";
import { ErrBox, Header } from "@/components/ui/kit";

export default function ImporCadanganPage() {
  const [namaFile, setNamaFile] = useState("");
  const [isi, setIsi] = useState("");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");
  const [hasil, setHasil] = useState<any>(null);

  async function pilihFile(e: any) {
    const f = e.target.files?.[0];
    if (!f) return;
    setNamaFile(f.name); setErr(""); setHasil(null);
    const teks = await f.text();
    setIsi(teks);
  }

  async function impor() {
    if (!isi.trim()) { setErr("Pilih file cadangan .json dulu."); return; }
    let obj: any;
    try { obj = JSON.parse(isi); }
    catch { setErr("File bukan JSON valid."); return; }
    setBusy(true); setErr(""); setHasil(null);
    try {
      const r = await adminFetch("/api/admin/cadangan/impor", { method: "POST", body: obj });
      setHasil(r);
      setIsi(""); setNamaFile("");
    } catch (e: any) { setErr(e.message); }
    finally { setBusy(false); }
  }

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header icon={UploadCloud} title="Impor Cadangan" sub="Tarik data DB lama ke D1 dari file .json cadangan (format ekspor Cadangan DB)"
        right={<span className="text-xs px-3 py-1.5 rounded-full bg-amber-500/15 border border-amber-500/30 text-amber-700 font-bold">Khusus pemilik</span>} />
      {err && <ErrBox msg={err} />}

      <div className="grid lg:grid-cols-2 gap-4">
        <div className="xy-card rounded-[20px] p-5 space-y-3">
          <div className="flex items-center gap-2"><FileJson size={16} className="text-[#7C3AED]" /><span className="text-[12px] font-bold text-[#1E1B2E]">1. Pilih file</span></div>
          <p className="text-[12.5px] text-[#7C738F] leading-relaxed">Format yang didukung: hasil <b>Cadangan DB</b> ({'{dibuat, isi:{nama_tabel:[...]}}'}) atau ekspor D1 raw ({'{isi:{"tabel":[...]}}'}). Baris yang sudah ada (ID sama) dilewati, tidak menimpa.</p>
          <label className={`flex flex-col items-center justify-center gap-2 rounded-2xl border-2 border-dashed px-6 py-8 cursor-pointer transition-colors ${namaFile ? "border-emerald-400 bg-emerald-500/5" : "border-[#C4B5FD] bg-[#F5F3FF] hover:bg-[#F3F0FF]"}`}>
            <UploadCloud size={22} className={namaFile ? "text-emerald-500" : "text-[#7C3AED]"} />
            <span className="text-[12.5px] font-bold text-[#1E1B2E]">{namaFile || "Klik untuk pilih file .json"}</span>
            <span className="text-[10.5px] text-[#7C738F]">maks {isi.length.toLocaleString("id-ID")} karakter terbaca</span>
            <input type="file" accept=".json,application/json" onChange={pilihFile} className="hidden" />
          </label>
          <button onClick={impor} disabled={busy || !isi.trim()} className="w-full h-11 rounded-xl xy-btn text-white font-bold text-[13px] flex items-center justify-center gap-2 disabled:opacity-50">
            <DatabaseBackup size={15} /> {busy ? "Mengimpor…" : "Impor ke Database"}
          </button>
        </div>

        <div className="xy-card rounded-[20px] p-5">
          <div className="flex items-center gap-2 mb-3"><DatabaseBackup size={16} className="text-[#7C3AED]" /><span className="text-[12px] font-bold text-[#1E1B2E]">2. Hasil impor</span></div>
          {hasil ? (
            <div className="space-y-2">
              <div className="grid grid-cols-3 gap-2">
                {[
                  ["Masuk", hasil.masuk, "text-emerald-600 bg-emerald-500/10"],
                  ["Dilewati", hasil.dilewati, "text-amber-600 bg-amber-500/10"],
                  ["Tabel", hasil.tabel, "text-[#7C3AED] bg-[#F3F0FF]"],
                ].map(([l, v, c]: any) => (
                  <div key={l} className={`rounded-xl p-3 text-center ${c}`}>
                    <div className="text-xl font-black">{Number(v).toLocaleString("id-ID")}</div>
                    <div className="text-[10.5px] font-bold uppercase tracking-wide">{l}</div>
                  </div>
                ))}
              </div>
              <p className="text-[12px] text-emerald-700 font-semibold">Impor selesai. Log Sistem mencatat ringkasannya.</p>
            </div>
          ) : (
            <div className="rounded-2xl bg-[#F5F3FF] border border-[#E9E3F5] p-8 text-center text-[#7C738F] text-[12.5px] font-medium leading-relaxed">
              Belum ada hasil.<br />Pilih file lalu ketuk Impor. Semua tindakan dicatat ke Audit Log.
            </div>
          )}
          <div className="mt-4 p-3 rounded-xl bg-[#F3F0FF] border border-[#E9E3F5] text-[11px] text-[#7C738F] font-medium leading-relaxed">
            Data sandi tidak pernah ikut diimpor. Halaman ini adalah cadangan/jembatan untuk <b>menarik DB lama</b> yang kamu simpan sebagai file.
          </div>
        </div>
      </div>
    </div>
  );
}
