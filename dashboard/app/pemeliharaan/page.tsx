"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { Power, UserRound, X } from "lucide-react";
import { Btn, Chip, ErrBox, Field, Header, Input, Load, Select, TextArea, Toggle, asList } from "@/components/ui/kit";
import { toast } from "@/components/ui/dialog";

const LABEL_CAKUPAN: Record<string, string> = {
  semua: "Semua layanan",
  web: "Situs web saja",
  aplikasi: "Aplikasi Android saja",
  halaman: "Halaman web tertentu",
};

export default function PemeliharaanPage() {
  const [d, setD] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");
  const [saving, setSaving] = useState(false);

  const [aktif, setAktif] = useState(false);
  const [cakupan, setCakupan] = useState("semua");
  const [pesan, setPesan] = useState("");
  const [menit, setMenit] = useState("60");
  const [bebas, setBebas] = useState<{ id: string; email: string; nama: string }[]>([]);
  const [q, setQ] = useState("");
  const [hasilCari, setHasilCari] = useState<any[]>([]);
  const [cariBusy, setCariBusy] = useState(false);

  async function muat() {
    setLoading(true); setErr("");
    try {
      const x = await adminFetch("/api/admin/sistem");
      setD(x);
      const pm = x?.pemeliharaan || {};
      setAktif(!!pm.aktif);
      setCakupan(pm.cakupan || "semua");
      setPesan(pm.pesan || "");
      setMenit(String(pm.maks_menit ?? 60));
      const b = x?.bebas || pm.bebas || [];
      setBebas(Array.isArray(b) ? b : []);
    } catch (e: any) { setErr(e.message); }
    finally { setLoading(false); }
  }
  useEffect(() => { muat(); }, []);

  async function simpan(nextAktif: boolean) {
    setSaving(true);
    try {
      await adminFetch("/api/admin/sistem/pemeliharaan", {
        method: "POST",
        body: {
          aktif: nextAktif, cakupan, halaman: [], pesan, bebas,
          maks_menit: menit ? Number(menit) : 0,
        },
      });
      toast(nextAktif ? `Pemeliharaan DINYALAKAN (${LABEL_CAKUPAN[cakupan] || cakupan}).` : "Pemeliharaan dimatikan.");
      await muat();
    } catch (e: any) { toast(e.message || "Gagal menyimpan.", "err"); }
    finally { setSaving(false); }
  }

  async function simpanBebas() {
    setSaving(true);
    try {
      await adminFetch("/api/admin/sistem/pemeliharaan", {
        method: "POST",
        body: { hanya_bebas: true, bebas },
      });
      toast(`Pengecualian tersimpan (${bebas.length} pengguna).`);
      await muat();
    } catch (e: any) { toast(e.message || "Gagal menyimpan pengecualian.", "err"); }
    finally { setSaving(false); }
  }

  async function cariUser() {
    if (!q.trim()) return;
    setCariBusy(true);
    try {
      const d2 = await adminFetch(`/api/admin/users?q=${encodeURIComponent(q.trim())}`);
      setHasilCari(asList(d2).slice(0, 8));
    } catch (e: any) { toast(e.message || "Pencarian gagal.", "err"); }
    finally { setCariBusy(false); }
  }

  if (loading) return <div className="p-6"><Load /></div>;

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header icon={Power} title="Mode Pemeliharaan" sub="Kendali penuh maintenance situs & aplikasi — termasuk daftar pengguna yang kebal (tester internal)"
        right={<Chip tone={aktif ? "warn" : "ok"}>{aktif ? `AKTIF — ${LABEL_CAKUPAN[cakupan] || cakupan}` : "NORMAL"}</Chip>} />
      {err && <ErrBox msg={err} onRetry={muat} />}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div className="xy-card rounded-[20px] p-5 space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <div className="text-[14px] font-bold text-[#1E1B2E]">Status pemeliharaan</div>
              <div className="text-[11.5px] text-[#7C738F]">Saat aktif, semua pengunjung melihat halaman perawatan kecuali daftar pengecualian.</div>
            </div>
            <Toggle checked={aktif} onChange={(v) => simpan(v)} disabled={saving} />
          </div>
          <Field label="Cakupan">
            <Select
              value={cakupan}
              onChange={setCakupan}
              options={Object.entries(LABEL_CAKUPAN).map(([value, label]) => ({ value, label }))}
            />
          </Field>
          <Field label="Pesan untuk pengunjung">
            <TextArea rows={3} value={pesan} onChange={(e) => setPesan(e.target.value)}
              placeholder="Kami sedang meningkatkan layanan. Kembali lagi sebentar ya!" />
          </Field>
          <Field label="Batas otomatis mati (menit, 0 = tanpa batas)">
            <Input type="number" value={menit} onChange={(e) => setMenit(e.target.value)} />
          </Field>
          <div className="flex gap-2">
            <Btn onClick={() => simpan(aktif)} disabled={saving}>{saving ? "Menyimpan…" : "Simpan pengaturan"}</Btn>
            <Btn tone={aktif ? "ok" : "bahaya"} onClick={() => simpan(!aktif)} disabled={saving}>
              {aktif ? "Matikan sekarang" : "Nyalakan sekarang"}
            </Btn>
          </div>
        </div>

        <div className="xy-card rounded-[20px] p-5 space-y-3">
          <div className="flex items-center gap-2">
            <UserRound size={16} className="text-[#7C3AED]" />
            <div className="text-[14px] font-bold text-[#1E1B2E]">Pengecualian — tetap bisa masuk saat pemeliharaan</div>
          </div>
          <div className="flex gap-2">
            <Input value={q} onChange={(e) => setQ(e.target.value)} onKeyDown={(e) => e.key === "Enter" && cariUser()}
              placeholder="Cari nama / email / id pengguna…" />
            <Btn tone="ghost" onClick={cariUser} disabled={cariBusy}>{cariBusy ? "…" : "Cari"}</Btn>
          </div>
          {hasilCari.length > 0 && (
            <div className="xy-card rounded-[14px] divide-y divide-[#F0EDFB]">
              {hasilCari.map((u) => (
                <button key={u.id} disabled={bebas.some((b) => b.id === u.id)}
                  className="w-full flex items-center justify-between px-3 py-2 text-left hover:bg-[#FBFAFF] disabled:opacity-40"
                  onClick={() => setBebas((l) => [...l, { id: u.id, email: u.email, nama: u.nama }])}>
                  <span className="text-[12.5px] font-semibold text-[#1E1B2E]">{u.nama} <span className="text-[#7C738F] font-normal">· {u.email}</span></span>
                  <span className="text-[11px] font-bold text-[#7C3AED]">+ tambah</span>
                </button>
              ))}
            </div>
          )}
          <div className="space-y-1.5">
            {bebas.length === 0 && <div className="text-[12px] text-[#7C738F] font-medium">Belum ada pengecualian.</div>}
            {bebas.map((b) => (
              <div key={b.id} className="flex items-center justify-between bg-[#F5F3FF] border border-[#E9E3F5] rounded-xl px-3 py-2">
                <span className="text-[12px] font-semibold text-[#1E1B2E]">{b.nama} <span className="text-[#7C738F] font-normal">· {b.email}</span></span>
                <button className="p-1 rounded-full hover:bg-white text-[#B54450]" title="Keluarkan"
                  onClick={() => setBebas((l) => l.filter((x) => x.id !== b.id))}>
                  <X size={13} />
                </button>
              </div>
            ))}
          </div>
          <Btn onClick={simpanBebas} disabled={saving}>Simpan pengecualian ({bebas.length})</Btn>
        </div>
      </div>
    </div>
  );
}
