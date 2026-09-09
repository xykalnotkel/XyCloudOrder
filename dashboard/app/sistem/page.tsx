"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import {
  Activity, CheckCircle2, Clock, Database, Globe, LayoutList, MonitorSmartphone,
  RefreshCw, Save, Server, Settings, Shield, Smartphone, Trash2, XCircle,
} from "lucide-react";
import { Chip, ErrBox, Header, Load, Stat } from "@/components/ui/kit";

const PRASET_HALAMAN: { label: string; path: string }[] = [
  { label: "Beranda", path: "/" },
  { label: "Halaman Unduh", path: "/unduh/" },
  { label: "Privasi", path: "/legal/privasi" },
  { label: "Syarat", path: "/legal/syarat" },
];
const LABEL_CAKUPAN: Record<string, string> = {
  semua: "Semua layanan",
  web: "Situs web saja",
  aplikasi: "Aplikasi Android saja",
  halaman: "Halaman web tertentu",
};

export default function SistemPage() {
  const [d, setD] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState("");
  const [msg, setMsg] = useState("");

  // formulir pemeliharaan
  const [cakupan, setCakupan] = useState("semua");
  const [halaman, setHalaman] = useState<string[]>([]);
  const [pesan, setPesan] = useState("");
  const [menit, setMenit] = useState("60");
  const [inputH, setInputH] = useState("");

  async function muat() {
    setLoading(true); setErr("");
    try {
      const x = await adminFetch("/api/admin/sistem");
      setD(x);
      const pm = x?.pemeliharaan || {};
      setCakupan(pm.cakupan || "semua");
      setHalaman(Array.isArray(pm.halaman) ? pm.halaman : []);
      setPesan(pm.pesan || "");
    } catch (e: any) { setErr(e.message); }
    finally { setLoading(false); }
  }
  useEffect(() => { muat(); }, []);

  async function simpanMaint(aktif: boolean) {
    if (!d) return;
    setSaving(true); setMsg(""); setErr("");
    try {
      const hasil = await adminFetch("/api/admin/sistem/pemeliharaan", {
        method: "POST",
        body: {
          aktif,
          cakupan,
          halaman,
          pesan,
          maks_menit: menit ? Number(menit) : 0,
        },
      });
      setMsg(hasil?.ok
        ? aktif ? `Pemeliharaan DINYALAKAN untuk ${LABEL_CAKUPAN[cakupan] || cakupan}.` : "Pemeliharaan dimatikan."
        : "Tidak berubah.");
      await muat();
    } catch (e: any) { setErr(e.message); }
    finally { setSaving(false); }
  }

  function toggleHalaman(path: string) {
    setHalaman((h) => h.includes(path) ? h.filter((x) => x !== path) : [...h, path]);
  }
  function tambahHalaman() {
    const p = inputH.trim().startsWith("/") ? inputH.trim() : "/" + inputH.trim();
    if (!p || p === "/") return;
    if (p.length > 3 && !halaman.includes(p)) setHalaman((h) => [...h, p]);
    setInputH("");
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
    <div className="space-y-4 font-[var(--font-inter)]">
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
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <Stat label="Database D1" tone={db.hidup ? "ok" : "bad"}
              value={db.hidup ? <span className="flex items-center gap-1.5"><CheckCircle2 size={16} /> Hidup</span> : <span className="flex items-center gap-1.5"><XCircle size={16} /> Gagal</span>}
              sub={`Latensi ${db.jedaMs ?? "?"} ms`} />
            <Stat label="Pemeliharaan" value={pm.aktif ? "AKTIF" : "Off"} tone={pm.aktif ? "warn" : undefined}
              sub={pm.aktif ? LABEL_CAKUPAN[pm.cakupan] || pm.cakupan : "Semua layanan normal"} />
            <Stat label="Baris Tabel" value={Object.values(baris as any).reduce((a: number, b: any) => a + Number(b || 0), 0).toLocaleString("id-ID")} sub="users+orders+cs+forum+log" />
            <Stat label="Pembayaran" value={String(d.pembayaran || "manual")} sub="Metode aktif" />
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-5 gap-4">
            {/* jumlah baris */}
            <div className="xy-card rounded-[20px] p-5 lg:col-span-2">
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
              {pm.versi_minimal && (
                <div className="mt-3 p-3 rounded-xl bg-amber-500/10 border border-amber-500/25 text-[12px] font-medium text-amber-800">
                  Versi minimal aplikasi: <code className="font-mono font-bold">{pm.versi_minimal}</code>
                </div>
              )}
            </div>

            {/* pengatur pemeliharaan */}
            <div className="xy-card rounded-[20px] p-5 lg:col-span-3">
              <div className="flex items-center justify-between flex-wrap gap-2">
                <h3 className="font-bold text-[#1E1B2E] tracking-tight flex items-center gap-2"><Activity size={15} className="text-[#7C3AED]" /> Mode Pemeliharaan</h3>
                <div className="flex items-center gap-2">
                  <Chip tone={pm.aktif ? "warn" : "ok"}>{pm.aktif ? "AKTIF" : "OFF"}</Chip>
                  {pm.aktif && pm.sampai && <Chip tone="info"><Clock size={9} className="inline mr-1" /> auto-mati {jamNow(pm.sampai)}</Chip>}
                </div>
              </div>

              <div className="mt-3 grid grid-cols-2 sm:grid-cols-4 gap-2">
                {Object.entries(LABEL_CAKUPAN).map(([k, label]) => (
                  <button key={k} onClick={() => setCakupan(k)}
                    className={`rounded-2xl border px-3 py-2.5 text-left transition ${cakupan === k ? "border-[#7C3AED] bg-[#F3F0FF] ring-2 ring-[#7C3AED]/20" : "border-[#E9E3F5] bg-white hover:bg-[#FAF8FF]"}`}>
                    <div className="text-[10.5px] font-black text-[#7C3AED] uppercase tracking-wide">{k}</div>
                    <div className={`text-[11.5px] font-bold mt-0.5 ${cakupan === k ? "text-[#1E1B2E]" : "text-[#6B5A8A]"}`}>{label}</div>
                  </button>
                ))}
              </div>

              {cakupan === "halaman" && (
                <div className="mt-3 rounded-2xl bg-[#F5F3FF] border border-[#E9E3F5] p-3">
                  <div className="flex items-center gap-1.5 text-[11px] font-bold text-[#6B5A8A] uppercase tracking-wide"><LayoutList size={12} /> Halaman web yang diblokir</div>
                  <div className="mt-2 flex flex-wrap gap-1.5">
                    {PRASET_HALAMAN.map((h) => (
                      <button key={h.path} onClick={() => toggleHalaman(h.path)}
                        className={`px-2.5 py-1 rounded-full text-[11px] font-bold border transition ${halaman.includes(h.path) ? "bg-[#7C3AED] text-white border-[#7C3AED]" : "bg-white border-[#E9E3F5] text-[#6B5A8A] hover:border-[#C4B5FD]"}`}>
                        {h.label} <span className="font-mono opacity-70">{h.path}</span>
                      </button>
                    ))}
                  </div>
                  {halaman.filter((h) => !PRASET_HALAMAN.some((p) => p.path === h)).length > 0 && (
                    <div className="mt-2 flex flex-wrap gap-1.5">
                      {halaman.filter((h) => !PRASET_HALAMAN.some((p) => p.path === h)).map((h) => (
                        <span key={h} className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-white border border-[#E9E3F5] text-[11px] font-bold text-[#1E1B2E] font-mono">
                          {h}
                          <button onClick={() => toggleHalaman(h)} className="text-[#9A8CBF] hover:text-rose-500"><Trash2 size={10} /></button>
                        </span>
                      ))}
                    </div>
                  )}
                  <div className="mt-2 flex gap-1.5">
                    <input value={inputH} onChange={(e) => setInputH(e.target.value)} onKeyDown={(e) => e.key === "Enter" && tambahHalaman()}
                      placeholder="/path-halaman" className="flex-1 px-3 py-1.5 rounded-xl bg-white border border-[#E9E3F5] text-[12px] font-mono focus:border-[#7C3AED] outline-none" />
                    <button onClick={tambahHalaman} className="px-3 py-1.5 rounded-xl bg-white border border-[#E9E3F5] hover:border-[#7C3AED] text-[12px] font-bold text-[#7C3AED]">Tambah</button>
                  </div>
                  <p className="mt-2 text-[10.5px] text-[#7C738F] font-medium">Mode ini hanya menutup halaman web publik yang dipilih — API & aplikasi Android tetap berjalan.</p>
                </div>
              )}

              <div className="mt-3 grid sm:grid-cols-[1fr_150px] gap-2">
                <textarea value={pesan} onChange={(e) => setPesan(e.target.value)} rows={2}
                  placeholder="Pesan yang tampil ke pengguna…" className="px-3.5 py-2.5 rounded-xl bg-white border border-[#E9E3F5] text-[12.5px] focus:border-[#7C3AED] outline-none resize-none" />
                <div>
                  <label className="text-[10px] font-bold text-[#7C738F] uppercase tracking-wide">Durasi (menit, 0=tak hingga)</label>
                  <input value={menit} onChange={(e) => setMenit(e.target.value.replace(/\D/g, ""))} type="text" inputMode="numeric"
                    className="mt-1 w-full px-3 py-2 rounded-xl bg-white border border-[#E9E3F5] text-[12.5px] font-mono focus:border-[#7C3AED] outline-none" />
                </div>
              </div>

              <div className="mt-3 flex flex-wrap gap-2">
                {pm.aktif ? (
                  <button onClick={() => simpanMaint(false)} disabled={saving}
                    className="inline-flex items-center gap-1.5 px-4 py-2.5 rounded-full bg-gradient-to-r from-[#16A34A] to-[#22C55E] text-white text-[12.5px] font-bold disabled:opacity-60">
                    <Save size={13} /> {saving ? "Menyimpan…" : "Matikan Pemeliharaan"}
                  </button>
                ) : (
                  <button onClick={() => simpanMaint(true)} disabled={saving}
                    className="inline-flex items-center gap-1.5 px-4 py-2.5 rounded-full bg-gradient-to-r from-[#7C3AED] to-[#5B21B6] text-white text-[12.5px] font-bold disabled:opacity-60 shadow-[0_8px_18px_rgba(124,58,237,.3)]">
                    <Shield size={13} /> {saving ? "Menyimpan…" : "Nyalakan Pemeliharaan"}
                  </button>
                )}
                {pm.aktif && pm.cakupan && (
                  <span className="inline-flex items-center gap-1.5 text-[11px] px-3 py-2 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-bold text-[#6B5A8A]">
                    {pm.cakupan === "web" ? <Globe size={12} /> : pm.cakupan === "aplikasi" ? <Smartphone size={12} /> : pm.cakupan === "halaman" ? <MonitorSmartphone size={12} /> : <Shield size={12} />}
                    sekarang: {LABEL_CAKUPAN[pm.cakupan] || pm.cakupan}
                  </span>
                )}
              </div>
              {msg && <div className="mt-2 text-[12px] font-semibold text-emerald-700 bg-emerald-500/10 border border-emerald-500/25 rounded-xl px-3 py-2">{msg}</div>}
              <p className="mt-3 text-[10.5px] text-[#7C738F] font-medium leading-relaxed">
                Otomatis mati bila lewat durasi (pengaman). Admin selalu bisa masuk untuk mematikan. Endpoint: <code className="font-mono">POST /api/admin/sistem/pemeliharaan</code>.
              </p>
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
            <div className="mt-3 text-[11px] text-[#7C738F] font-medium">Data asli dari GET /api/admin/sistem.</div>
          </div>
        </>
      ) : null}
    </div>
  );
}

function jamNow(s: string) {
  const d = new Date(s);
  return isNaN(d.getTime()) ? String(s) : d.toLocaleString("id-ID", { day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit" });
}
