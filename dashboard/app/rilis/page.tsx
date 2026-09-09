"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";

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
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-black text-white">Manajemen Rilis App 🚀 BARU</h1>
        <p className="text-sm text-violet-200/60">Kelola versi APK, catatan, dan gambar tema popup (Ramadan, Lebaran, dll) — glossy violet-indigo #7C3AED</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div className="xy-card rounded-[18px] p-5">
          <h3 className="font-bold text-white">Buat Rilis Baru</h3>
          <div className="mt-4 space-y-3">
            <input value={form.versi} onChange={(e) => setForm({ ...form, versi: e.target.value })} placeholder="Versi, mis: 3.3.0" className="w-full px-4 py-2.5 rounded-xl bg-[#100030] border border-white/10 text-sm" />
            <input value={form.url_apk} onChange={(e) => setForm({ ...form, url_apk: e.target.value })} placeholder="URL APK https://..." className="w-full px-4 py-2.5 rounded-xl bg-[#100030] border border-white/10 text-sm" />
            <textarea value={form.catatan} onChange={(e) => setForm({ ...form, catatan: e.target.value })} placeholder="Catatan rilis (apa yang baru)" rows={4} className="w-full px-4 py-2.5 rounded-xl bg-[#100030] border border-white/10 text-sm" />
            <select value={form.gambar_tema} onChange={(e) => setForm({ ...form, gambar_tema: e.target.value })} className="w-full px-4 py-2.5 rounded-xl bg-[#100030] border border-white/10 text-sm">
              <option value="default">default — violet-indigo</option>
              <option value="ramadan">ramadan — bulan + lampu</option>
              <option value="lebaran">lebaran — ketupat</option>
              <option value="natal">natal — salju</option>
              <option value="tahunbaru">tahunbaru — kembang api</option>
              <option value="merdeka">merdeka — merah putih</option>
            </select>
            <label className="flex items-center gap-2 text-sm text-white/70"><input type="checkbox" checked={form.wajib} onChange={(e) => setForm({ ...form, wajib: e.target.checked })} /> Wajib update?</label>
            <button onClick={handleCreate} className="w-full py-3 rounded-xl xy-btn font-bold">Simpan Rilis</button>
            <div className="text-[11px] text-white/40">Gambar tema: file `rilis_popup_{"{tema}"}.png` 928x1152 — generate nanti pas waktunya (sesuai request user). Saat ini pakai default.</div>
          </div>
        </div>

        <div className="xy-card rounded-[18px] p-5">
          <h3 className="font-bold text-white">Rilis Terakhir</h3>
          {loading ? <div className="mt-4 text-white/50">Memuat...</div> : (
            <div className="mt-4 space-y-2">
              {rilis.length === 0 ? <div className="text-sm text-white/40">Belum ada rilis di DB. Release GitHub ada di <code>a1c267e</code> (v3.2)</div> : rilis.slice(0, 10).map((r: any) => (
                <div key={r.id || r.versi} className="p-3 rounded-xl bg-white/[0.04] border border-white/5">
                  <div className="flex items-center justify-between"><span className="font-bold text-white">v{r.versi}</span><span className="text-[11px] px-2 py-0.5 rounded-full bg-[#7C3AED]/20">{r.gambar_tema || "default"}</span></div>
                  <div className="text-[12px] text-white/60 mt-1 line-clamp-2">{r.catatan}</div>
                </div>
              ))}
            </div>
          )}
          <div className="mt-6 p-3 rounded-xl bg-[#7C3AED]/10 border border-[#7C3AED]/20 text-[12px] text-violet-100/80">
            <b>Native:</b> APK baru otomatis inject updater via <code>tools/siapkan_pembaruan.py</code> — DownloadManager + notif progress tetap jalan walau app ditutup. Validasi URL hanya <code>xycloud.my.id</code>.
          </div>
        </div>
      </div>
    </div>
  );
}
