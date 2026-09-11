"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { Rocket, Package } from "lucide-react";
import { Select, Check, ErrBox, Field } from "@/components/ui/kit";

export default function RilisPage() {
  const [rilis, setRilis] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [form, setForm] = useState({ versi: "", url_apk: "", catatan: "", gambar_tema: "default", wajib: false });

  useEffect(() => {
    adminFetch("/api/admin/rilis")
      .then((d) => setRilis(d.rilis || d.data || []))
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  const handleCreate = async () => {
    try {
      await adminFetch("/api/admin/rilis", { method: "POST", body: form });
      alert("Rilis dibuat");
      location.reload();
    } catch (e: any) { alert(e.message); }
  };

  return (
    <div className="space-y-6 font-[var(--font-inter)]">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl xy-btn grid place-items-center"><Rocket size={18} className="text-white" /></div>
        <div>
          <h1 className="text-xl font-semibold text-[#1E1B2E] tracking-tight">Manajemen Rilis App <span className="ml-2 text-[10px] px-2 py-0.5 rounded-full bg-[#F3F0FF] font-semibold">BARU</span></h1>
          <p className="text-sm text-[#7C738F] font-medium">Kelola versi APK, catatan, dan gambar tema popup (Ramadan, Lebaran, dll) — glossy violet-indigo #7C3AED</p>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div className="xy-card rounded-[18px] p-5">
          <h3 className="font-semibold text-[#1E1B2E] tracking-tight">Buat Rilis Baru</h3>
          <div className="mt-4 space-y-3">
            <input value={form.versi} onChange={(e) => setForm({ ...form, versi: e.target.value })} placeholder="Versi, mis: 3.3.0" className="w-full px-4 py-2.5 rounded-xl bg-[#FFFFFF] border border-[#E9E3F5] text-sm text-[#1E1B2E] font-medium" />
            <input value={form.url_apk} onChange={(e) => setForm({ ...form, url_apk: e.target.value })} placeholder="URL APK https://..." className="w-full px-4 py-2.5 rounded-xl bg-[#FFFFFF] border border-[#E9E3F5] text-sm text-[#1E1B2E] font-medium" />
            <textarea value={form.catatan} onChange={(e) => setForm({ ...form, catatan: e.target.value })} placeholder="Catatan rilis (apa yang baru)" rows={4} className="w-full px-4 py-2.5 rounded-xl bg-[#FFFFFF] border border-[#E9E3F5] text-sm text-[#1E1B2E] font-medium" />
            <Select value={form.gambar_tema} onChange={(v) => setForm({ ...form, gambar_tema: v })} options={[
              { value: "default", label: "default — violet-indigo" },
              { value: "ramadan", label: "ramadan — bulan + lampu" },
              { value: "lebaran", label: "lebaran — ketupat" },
              { value: "natal", label: "natal — salju" },
              { value: "tahunbaru", label: "tahunbaru — kembang api" },
              { value: "merdeka", label: "merdeka — merah putih" },
            ]} />
            <Check checked={!!form.wajib} onChange={(v) => setForm({ ...form, wajib: v })} label="Wajib update?" />
            <button onClick={handleCreate} className="w-full h-10 rounded-[10px] xy-btn font-semibold tracking-wide">Simpan Rilis</button>
            <div className="text-[11px] text-[#7C738F] font-medium">Gambar tema: file `rilis_popup_{"{tema}"}.png` 928x1152 — generate nanti pas waktunya. Icons Lucide, no emoji.</div>
          </div>
        </div>

        <div className="xy-card rounded-[18px] p-5">
          <h3 className="font-semibold text-[#1E1B2E] tracking-tight flex items-center gap-2"><Package size={16} className="text-[#7C3AED]" /> Rilis Terakhir</h3>
          {loading ? <div className="mt-4 text-[#7C738F] font-medium">Memuat...</div> : (
            <div className="mt-4 space-y-2">
              {rilis.length === 0 ? <div className="text-sm text-[#7C738F] font-medium">Belum ada rilis di DB. Release GitHub ada di <code className="font-mono">a1c267e</code> (v3.2)</div> : rilis.slice(0, 10).map((r: any) => (
                <div key={r.id || r.versi} className="p-3 rounded-xl bg-[#F3F0FF] border border-[#E9E3F5]">
                  <div className="flex items-center justify-between"><span className="font-semibold text-[#1E1B2E] tracking-tight">v{r.versi}</span><span className="text-[11px] px-2 py-0.5 rounded-full bg-[#F3F0FF] font-medium">{r.gambar_tema || "default"}</span></div>
                  <div className="text-[12px] text-[#7C738F] mt-1 line-clamp-2 font-medium">{r.catatan}</div>
                </div>
              ))}
            </div>
          )}
          <div className="mt-6 p-3 rounded-xl bg-[#F3F0FF] border border-[#E9E3F5] text-[12px] text-[#7C738F] font-medium">
            <b>Native:</b> APK baru otomatis inject updater via <code className="font-mono">tools/siapkan_pembaruan.py</code> — DownloadManager + notif progress tetap jalan walau app ditutup. Validasi URL hanya <code className="font-mono">xycloud.my.id</code>.
          </div>
        </div>
      </div>
    </div>
  );
}
