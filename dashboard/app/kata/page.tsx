"use client";
import { useCallback, useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { Filter, Search } from "lucide-react";
import { Btn, Chip, ErrBox, Header, Load, TextArea } from "@/components/ui/kit";
import { toast } from "@/components/ui/dialog";

const JUDUL: Record<string, string> = {
  kasar: "Kata kasar / makian",
  sara: "SARA / ujaran kebencian",
  porno: "Pornografi",
};

export default function KataPage() {
  // respons berupa objek {kasar:[], sara:[], porno:[]} — ambil langsung.
  const [peta, setPeta] = useState<any>({});
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");

  const reload = useCallback(() => {
    setLoading(true); setErr("");
    adminFetch("/api/admin/kata")
      .then((x) => setPeta(x || {}))
      .catch((e: any) => setErr(e.message || String(e)))
      .finally(() => setLoading(false));
  }, []);
  useEffect(() => { reload(); }, [reload]);
  const [teks, setTeks] = useState("");
  const [hasil, setHasil] = useState<any>(null);
  const [busy, setBusy] = useState(false);

  async function uji() {
    if (!teks.trim()) return;
    setBusy(true); setHasil(null);
    try {
      const r = await adminFetch("/api/admin/uji-kata", { method: "POST", body: { teks } });
      setHasil(r);
    } catch (e: any) { toast(e.message || "Gagal menguji.", "err"); }
    finally { setBusy(false); }
  }

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header icon={Filter} title="Filter Kata Terlarang" sub="Daftar kata yang ditolak otomatis untuk nama, username, bio, dan konten komunitas — plus penguji teks" />
      {loading ? <Load /> : err ? <ErrBox msg={err} onRetry={reload} /> : (
        <>
          <div className="xy-card rounded-[20px] p-5 space-y-3">
            <div className="text-[14px] font-bold text-[#1E1B2E]">Penguji teks</div>
            <TextArea rows={2} value={teks} onChange={(e) => setTeks(e.target.value)}
              placeholder="Ketik nama / username / kalimat untuk diuji…" />
            <div className="flex items-center gap-3">
              <Btn onClick={uji} disabled={busy}><Search size={14} /> {busy ? "Menguji…" : "Uji sekarang"}</Btn>
              {hasil && (
                hasil.terlarang
                  ? <Chip tone="bad">DITOLAK — kata "{hasil.kata}" ({hasil.jenis})</Chip>
                  : <Chip tone="ok">Bersih — teks diterima</Chip>
              )}
            </div>
            <p className="text-[11.5px] text-[#7C738F] leading-relaxed">
              Filter menormalisasi leetspeak (0→o, 1→i, 3→e, 4→a, @→a, $→s) dan membuang pemisah,
              jadi varian seperti “a.n.j.i.n.g” tetap terjaring. Kata pendek (≤3 huruf) hanya dicocokkan
              sebagai kata utuh supaya nama sah seperti “Nasution” tidak ikut terkena.
            </p>
          </div>
          {Object.entries(peta).map(([jenis, daftar]: any) => (
            <div key={jenis} className="xy-card rounded-[20px] p-5 space-y-2.5">
              <div className="flex items-center justify-between">
                <div className="text-[14px] font-bold text-[#1E1B2E]">{JUDUL[jenis] || jenis}</div>
                <Chip tone="netral">{(daftar || []).length} kata</Chip>
              </div>
              <div className="flex flex-wrap gap-1.5">
                {(daftar || []).map((k: string) => (
                  <span key={k} className="text-[11px] font-mono px-2 py-1 rounded-lg bg-[#F5F3FF] border border-[#E9E3F5] text-[#4B445F]">{k}</span>
                ))}
              </div>
            </div>
          ))}
        </>
      )}
    </div>
  );
}
