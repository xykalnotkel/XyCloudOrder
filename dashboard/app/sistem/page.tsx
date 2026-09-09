"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { Activity, CheckCircle2, Database, RefreshCw, Server, Settings, XCircle } from "lucide-react";
import { Chip, ErrBox, Header, Load, Stat } from "@/components/ui/kit";

export default function SistemPage() {
  const [d, setD] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState("");
  const [msg, setMsg] = useState("");

  async function muat() {
    setLoading(true); setErr("");
    try { setD(await adminFetch("/api/admin/sistem")); }
    catch (e: any) { setErr(e.message); }
    finally { setLoading(false); }
  }
  useEffect(() => { muat(); }, []);

  async function toggleMaint(aktif: boolean) {
    if (!d) return;
    setSaving(true); setMsg(""); setErr("");
    try {
      const hasil = await adminFetch("/api/admin/sistem/pemeliharaan", {
        method: "POST",
        body: { aktif, cakupan: d.pemeliharaan?.cakupan || "semua", pesan: d.pemeliharaan?.pesan || "" },
      });
      setMsg(hasil?.ok ? `Pemeliharaan ${aktif ? "DINYALAKAN" : "dimatikan"}.` : "Tidak berubah.");
      await muat();
    } catch (e: any) { setErr(e.message); }
    finally { setSaving(false); }
  }

  const db = d?.database || {};
  const pm = d?.pemeliharaan || {};
  const baris = db.baris || {};
  const waktu = d?.waktu;

  const integrasi = [
    { l: "Email (Resend)", ok: !!d?.email },
    { l: "Push (OneSignal)", ok: !!d?.push },
    { l: "Gambar (Cloudinary)", ok: !!d?.gambar },
  ];

  return (
    <div className="space-y-4 font-[Plus_Jakarta_Sans]">
      <Header icon={Settings} title="Sistem" sub="Kesehatan server, mode pemeliharaan & status integrasi"
        right={
          <div className="flex items-center gap-2">
            <span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-mono text-[#6B5A8A]">
              {waktu ? jamNow(waktu) : "…"}
            </span>
            <button onClick={muat} className="text-xs px-3 py-1.5 rounded-full xy-btn text-white flex items-center gap-1.5">
              <RefreshCw size={12} /> Muat Ulang
            </button>
          </div>
        } />

      {loading && !d ? <Load /> : err ? <ErrBox msg={err} /> : d ? (
        <>
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
            <Stat label="Database D1" value={db.hidup ? <span className="text-emerald-600 flex items-center gap-1.5"><CheckCircle2 size={16} /> Hidup</span> : <span className="text-rose-600 flex items-center gap-1.5"><XCircle size={16} /> Gagal</span>}
              sub={`Latensi ${db.jedaMs ?? "?"} ms`} />
            <Stat label="Pemeliharaan" value={pm.aktif ? "AKTIF" : "Off"} tone={pm.aktif ? "text-amber-600" : "text-[#1E1B2E]"}
              sub={pm.aktif ? `Cakupan ${pm.cakupan || "semua"}` : "Semua layanan normal"} />
            <Stat label="Baris Tabel" value={Object.values(baris as any).reduce((a: number, b: any) => a + Number(b || 0), 0)} sub="users+orders+cs+forum+log" />
            <Stat label="Pembayaran" value={String(d.pembayaran || "manual")} sub="Metode aktif" />
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
            <div className="xy-card rounded-[20px] p-5">
              <div className="flex items-center justify-between">
                <h3 className="font-bold text-[#1E1B2E] tracking-tight flex items-center gap-2"><Server size={15} className="text-[#7C3AED]" /> Jumlah Baris per Tabel</h3>
                <Chip tone="info">D1</Chip>
              </div>
              <div className="mt-3 grid grid-cols-2 gap-2">
                {Object.entries(baris as any).map(([k, v]) => (
                  <div key={k} className="flex items-center justify-between p-2.5 rounded-xl bg-[#F5F3FF] border border-[#E9E3F5]">
                    <span className="text-[12px] text-[#6B5A8A] font-semibold">{k}</span>
                    <span className="font-mono font-bold text-[#1E1B2E]">{Number(v || 0).toLocaleString("id-ID")}</span>
                  </div>
                ))}
              </div>
            </div>

            <div className="xy-card rounded-[20px] p-5">
              <h3 className="font-bold text-[#1E1B2E] tracking-tight flex items-center gap-2"><Activity size={15} className="text-[#7C3AED]" /> Mode Pemeliharaan</h3>
              <div className="mt-3 space-y-2 text-[12.5px]">
                <div className="flex justify-between"><span className="text-[#7C738F] font-medium">Status</span> {pm.aktif ? <Chip tone="warn">AKTIF</Chip> : <Chip tone="ok">Off</Chip>}</div>
                <div className="flex justify-between"><span className="text-[#7C738F] font-medium">Cakupan</span><span className="font-bold text-[#1E1B2E]">{pm.cakupan || "semua"}</span></div>
                <div className="flex justify-between"><span className="text-[#7C738F] font-medium">Pesan</span><span className="font-medium text-[#1E1B2E] max-w-[60%] text-right">{pm.pesan || "—"}</span></div>
                <div className="flex justify-between"><span className="text-[#7C738F] font-medium">Versi minimal</span><span className="font-mono font-bold text-[#1E1B2E]">{pm.versi_minimal || "—"}</span></div>
              </div>
              <button
                onClick={() => toggleMaint(!pm.aktif)} disabled={saving}
                className={`mt-4 w-full py-3 rounded-full font-bold text-white text-[13px] transition disabled:opacity-60 ${pm.aktif ? "bg-gradient-to-r from-[#16A34A] to-[#22C55E]" : "bg-gradient-to-r from-[#7C3AED] to-[#5B21B6]"}`}>
                {saving ? "Menyimpan…" : pm.aktif ? "Matikan Pemeliharaan" : "Nyalakan Pemeliharaan"}
              </button>
              {msg && <div className="mt-2 text-[12px] font-semibold text-emerald-700 bg-emerald-500/10 border border-emerald-500/25 rounded-xl px-3 py-2">{msg}</div>}
            </div>
          </div>

          <div className="xy-card rounded-[20px] p-5">
            <h3 className="font-bold text-[#1E1B2E] tracking-tight flex items-center gap-2"><Database size={15} className="text-[#7C3AED]" /> Integrasi Layanan</h3>
            <div className="mt-3 flex flex-wrap gap-3">
              {integrasi.map((x) => (
                <div key={x.l} className="flex items-center gap-2 p-3 rounded-xl bg-[#F5F3FF] border border-[#E9E3F5]">
                  {x.ok ? <CheckCircle2 size={15} className="text-emerald-600" /> : <XCircle size={15} className="text-rose-500" />}
                  <span className="text-[12.5px] font-semibold text-[#1E1B2E]">{x.l}</span>
                </div>
              ))}
              <div className="flex items-center gap-2 p-3 rounded-xl bg-[#F5F3FF] border border-[#E9E3F5]">
                <CheckCircle2 size={15} className="text-emerald-600" />
                <span className="text-[12.5px] font-semibold text-[#1E1B2E]">Pembayaran: {String(d.pembayaran || "manual")}</span>
              </div>
            </div>
            <div className="mt-3 text-[11px] text-[#7C738F] font-medium">Data asli dari GET /api/admin/sistem. Tombol pemeliharaan = POST /api/admin/sistem/pemeliharaan (hanya pemilik).</div>
          </div>
        </>
      ) : null}
    </div>
  );
}

function jamNow(s: string) {
  const d = new Date(s);
  return isNaN(d.getTime()) ? String(s) : d.toLocaleString("id-ID");
}
