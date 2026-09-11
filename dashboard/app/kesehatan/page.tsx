"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { Activity, Cloud, Database, Eraser, HeartPulse, RefreshCw } from "lucide-react";
import { Chip, ErrBox, Header, Load, Stat } from "@/components/ui/kit";

export default function KesehatanPage() {
  const [d, setD] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");
  const [busy, setBusy] = useState(false);
  const [info, setInfo] = useState("");

  async function muat() {
    setLoading(true); setErr("");
    try { setD(await adminFetch("/api/admin/sistem/kesehatan")); }
    catch (e: any) { setErr(e.message); }
    finally { setLoading(false); }
  }
  useEffect(() => { muat(); }, []);

  async function bersihCache() {
    if (!confirm("Kosongkan singgahan (cache) rilis & halaman publik?")) return;
    setBusy(true); setErr(""); setInfo("");
    try { const r = await adminFetch("/api/admin/sistem/cache", { method: "DELETE" }); setInfo("Cache dibuang: " + (r.dibuang?.join(", ") || "tidak ada")); }
    catch (e: any) { setErr(e.message); }
    finally { setBusy(false); }
  }

  const baris = d?.database?.baris;

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header icon={HeartPulse} title="Kesehatan & Cache" sub="Status layanan realtime dari Worker — DB, integrasi, singgahan"
        right={
          <button onClick={muat} className="inline-flex items-center gap-1.5 px-4 h-9 rounded-xl xy-btn text-white text-[12px] font-semibold"><RefreshCw size={13} /> Segarkan</button>
        } />
      {info && <div className="px-4 py-2.5 rounded-xl bg-emerald-500/10 border border-emerald-500/25 text-emerald-700 text-[12.5px] font-semibold">{info}</div>}
      {loading ? <Load /> : err ? <ErrBox msg={err} /> : !d ? null : (
        <>
          <div className="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-6 gap-3">
            <Stat label="Database" tone={d.database?.hidup ? "ok" : "bad"} value={d.database?.hidup ? "Hidup" : "Mati"} sub={(d.database?.jedaMs ?? "-") + " ms respons"} />
            <Stat label="Baris tersimpan" value={(baris?.users ?? 0).toLocaleString("id-ID") + " user"} sub={(baris?.orders ?? 0).toLocaleString("id-ID") + " pesanan • " + (baris?.pesan ?? 0).toLocaleString("id-ID") + " chat"} />
            <Stat label="Email (Resend)" tone={d.email ? "ok" : "warn"} value={d.email ? "Siap" : "Tidak aktif"} sub="RESEND_API_KEY" />
            <Stat label="Push (OneSignal)" tone={d.push ? "ok" : "warn"} value={d.push ? "Siap" : "Tidak aktif"} sub="ONESIGNAL_API_KEY" />
            <Stat label="Gambar (Cloudinary)" tone={d.gambar ? "ok" : "warn"} value={d.gambar ? "Siap" : "Tidak aktif"} sub="CLOUDINARY_KEY" />
            <Stat label="Pembayaran" value={String(d.pembayaran || "manual")} sub={d.loginGoogle ? "Login Google aktif" : "Login Google nonaktif"} />
          </div>

          <div className="grid md:grid-cols-2 gap-4">
            <div className="xy-card rounded-[20px] p-5 space-y-3">
              <div className="flex items-center gap-2"><Activity size={15} className="text-[#7C3AED]" /><span className="text-[12px] font-semibold text-[#1E1B2E]">Respons layanan</span></div>
              <div className="grid grid-cols-2 gap-3 text-[12px]">
                <div className="rounded-xl bg-[#F5F3FF] border border-[#E9E3F5] p-3"><div className="text-[10.5px] font-semibold text-[#7C738F] uppercase">Wilayah Cloudflare</div><div className="font-semibold text-[#1E1B2E] mt-0.5 font-mono">{d.wilayah || "-"}</div></div>
                <div className="rounded-xl bg-[#F5F3FF] border border-[#E9E3F5] p-3"><div className="text-[10.5px] font-semibold text-[#7C738F] uppercase">Waktu server</div><div className="font-semibold text-[#1E1B2E] mt-0.5">{d.waktu ? new Date(d.waktu).toLocaleString("id-ID") : "-"}</div></div>
              </div>
            </div>
            <div className="xy-card rounded-[20px] p-5 space-y-3">
              <div className="flex items-center gap-2"><Cloud size={15} className="text-[#7C3AED]" /><span className="text-[12px] font-semibold text-[#1E1B2E]">Singgahan (cache)</span></div>
              <p className="text-[12px] text-[#7C738F] leading-relaxed">Singgahan rilis &amp; halaman publik di Cloudflare bisa dikosongkan jika ada pembaruan yang belum tampil (mis. versi APK baru).</p>
              <button onClick={bersihCache} disabled={busy} className="inline-flex items-center gap-1.5 px-4 py-2 rounded-xl bg-white border border-[#E9E3F5] hover:border-rose-300 text-[12px] font-semibold text-rose-600 disabled:opacity-50">
                <Eraser size={13} /> Kosongkan cache
              </button>
              {d.gambar && <Chip tone="ok"><Database size={10} className="inline mr-1" /> DB &amp; integrasi sehat</Chip>}
            </div>
          </div>
        </>
      )}
    </div>
  );
}
