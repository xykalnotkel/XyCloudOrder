"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { Globe, CheckCircle2, XCircle, Loader2 } from "lucide-react";
import { Chip, Header } from "@/components/ui/kit";

const SITE = "https://xycloud.my.id";

type Hasil = { nama: string; ok: boolean | null; detail: string };

export default function SeoPage() {
  const [hasil, setHasil] = useState<Hasil[]>([]);
  const [jalan, setJalan] = useState(true);
  const [maint, setMaint] = useState<boolean | null>(null);

  async function periksa() {
    setJalan(true);
    const out: Hasil[] = [];

    // 1. berkas verifikasi Google Search Console
    try {
      const r = await fetch(`${SITE}/google8d6555ceced0c8e7.html`, { cache: "no-store" });
      const t = await r.text();
      const ok = r.status === 200 && t.includes("google-site-verification: google8d6555ceced0c8e7.html");
      out.push({ nama: "Berkas verifikasi Search Console", ok, detail: ok ? "Terverifikasi & dapat dibaca Google" : `HTTP ${r.status} — isi tidak cocok` });
    } catch (e: any) {
      out.push({ nama: "Berkas verifikasi Search Console", ok: false, detail: e.message });
    }

    // 2. robots.txt
    try {
      const r = await fetch(`${SITE}/robots.txt`, { cache: "no-store" });
      const t = await r.text();
      const ok = r.status === 200 && /user-agent/i.test(t);
      out.push({ nama: "robots.txt", ok, detail: ok ? t.trim().replace(/\n/g, " · ") : `HTTP ${r.status}` });
    } catch (e: any) {
      out.push({ nama: "robots.txt", ok: false, detail: e.message });
    }

    // 3. halaman utama
    try {
      const r = await fetch(`${SITE}/`, { cache: "no-store" });
      const t = await r.text();
      const perawatan = /perawatan|maintenance/i.test(t);
      out.push({
        nama: "Halaman utama", ok: r.status === 200,
        detail: r.status === 200
          ? (perawatan ? "Menampilkan halaman PEMELIHARAAN — konten asli belum terindeks" : "Menampilkan konten situs")
          : `HTTP ${r.status}`,
      });
      setMaint(perawatan);
    } catch (e: any) {
      out.push({ nama: "Halaman utama", ok: false, detail: e.message });
    }

    // 4. status maintenance dari admin API
    try {
      const x = await adminFetch("/api/admin/sistem");
      const pm = x?.pemeliharaan || {};
      out.push({ nama: "Mode pemeliharaan (server)", ok: !pm.aktif, detail: pm.aktif ? `AKTIF — cakupan ${pm.cakupan || "semua"}` : "Tidak aktif" });
    } catch (e: any) {
      out.push({ nama: "Mode pemeliharaan (server)", ok: null, detail: e.message });
    }

    setHasil(out);
    setJalan(false);
  }

  useEffect(() => { periksa(); }, []);

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header icon={Globe} title="SEO & Situs Publik" sub={`Pemeriksaan langsung ke ${SITE} — verifikasi Google, robots.txt, dan kesiapan indeks`} />
      {maint && (
        <div className="xy-card rounded-[16px] p-4 border-amber-200 bg-amber-50 text-[12.5px] text-amber-800 font-medium">
          ⚠️ Situs sedang dalam mode pemeliharaan. Google bisa mendaftar domainnya, tetapi konten asli baru terindeks setelah maintenance dimatikan (menu Mode Pemeliharaan).
        </div>
      )}
      <div className="xy-card rounded-[20px] divide-y divide-[#F0EDFB]">
        {jalan && <div className="p-6 flex items-center gap-2 text-[#7C738F] text-[12.5px] font-medium"><Loader2 className="animate-spin" size={15} /> Memeriksa…</div>}
        {hasil.map((h) => (
          <div key={h.nama} className="flex items-start justify-between gap-3 px-4 py-3">
            <div className="min-w-0">
              <div className="text-[13px] font-semibold text-[#1E1B2E]">{h.nama}</div>
              <div className="text-[11.5px] text-[#7C738F] break-all">{h.detail}</div>
            </div>
            {h.ok === null ? <Chip tone="netral">?</Chip>
              : h.ok ? <CheckCircle2 size={19} className="text-emerald-500 shrink-0" />
              : <XCircle size={19} className="text-rose-500 shrink-0" />}
          </div>
        ))}
      </div>
      <div className="xy-card rounded-[20px] p-5 space-y-2">
        <div className="text-[14px] font-bold text-[#1E1B2E]">Langkah di Google Search Console</div>
        <ol className="text-[12.5px] text-[#4B445F] list-decimal list-inside space-y-1.5 leading-relaxed">
          <li>Buka <span className="font-mono text-[11.5px]">search.google.com/search-console</span> → tambah properti → <b>Awalan URL</b> → masukkan <span className="font-mono text-[11.5px]">https://xycloud.my.id</span></li>
          <li>Pilih metode verifikasi <b>Tag HTML</b>… tidak perlu — berkas <span className="font-mono text-[11.5px]">google8d6555ceced0c8e7.html</span> sudah otomatis dilayani server (baris pertama di atas).</li>
          <li>Klik <b>Verifikasi</b>. Jika gagal, jalankan ulang pemeriksaan di halaman ini untuk melihat penyebabnya.</li>
          <li>Setelah situs keluar dari mode pemeliharaan: kirim sitemap dan minta pengindeksan URL utama.</li>
        </ol>
      </div>
    </div>
  );
}
