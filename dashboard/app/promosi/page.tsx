"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { Gift, Plus, Trash2 } from "lucide-react";
import { Chip, ErrBox, Header, jam, Load } from "@/components/ui/kit";

const kosong = { nama: "", jenis: "floating", gambar: "", aksi: "url", target: "", posisi: "kanan", platform: "semua", aktif: 1, urutan: 0 };

export default function PromosiPage() {
  const [rows, setRows] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");
  const [form, setForm] = useState({ ...kosong });
  const [saving, setSaving] = useState(false);
  const [buka, setBuka] = useState(false);

  async function muat() {
    setLoading(true); setErr("");
    try { setRows(await adminFetch("/api/admin/promosi")); }
    catch (e: any) { setErr(e.message); }
    finally { setLoading(false); }
  }
  useEffect(() => { muat(); }, []);

  async function simpan() {
    if (!form.gambar.trim() || !form.nama.trim()) { setErr("Nama & URL/gambar wajib diisi."); return; }
    setSaving(true); setErr("");
    try {
      await adminFetch("/api/admin/promosi", { method: "POST", body: form });
      setForm({ ...kosong }); setBuka(false);
      await muat();
    } catch (e: any) { setErr(e.message); }
    finally { setSaving(false); }
  }

  async function hapus(id: string) {
    if (!confirm("Hapus promo " + id + "?")) return;
    try {
      await adminFetch("/api/admin/promosi/" + id, { method: "DELETE" });
      await muat();
    } catch (e: any) { setErr(e.message); }
  }

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header icon={Gift} title="Promosi" sub="Pop-up & floating promo lintas platform (promo_overlay)"
        right={
          <button onClick={() => setBuka(!buka)} className="text-xs px-3.5 py-2 rounded-full xy-btn text-white font-semibold flex items-center gap-1.5">
            <Plus size={13} /> Tambah Promo
          </button>
        } />

      {buka && (
        <div className="xy-card rounded-[20px] p-5">
          <h3 className="font-semibold text-[#1E1B2E] tracking-tight">Promo Baru</h3>
          <div className="mt-3 grid grid-cols-1 md:grid-cols-2 gap-2.5">
            <input value={form.nama} onChange={(e) => setForm({ ...form, nama: e.target.value })} placeholder="Nama promo" className="px-3.5 py-2 rounded-xl bg-white border border-[#E9E3F5] text-[13px] focus:border-[#7C3AED] outline-none" />
            <input value={form.gambar} onChange={(e) => setForm({ ...form, gambar: e.target.value })} placeholder="URL gambar (https://)" className="px-3.5 py-2 rounded-xl bg-white border border-[#E9E3F5] text-[13px] focus:border-[#7C3AED] outline-none" />
            <select value={form.jenis} onChange={(e) => setForm({ ...form, jenis: e.target.value })} className="px-3.5 py-2 rounded-xl bg-white border border-[#E9E3F5] text-[13px] focus:border-[#7C3AED] outline-none">
              <option value="floating">floating</option><option value="popup">popup</option>
            </select>
            <select value={form.posisi} onChange={(e) => setForm({ ...form, posisi: e.target.value })} className="px-3.5 py-2 rounded-xl bg-white border border-[#E9E3F5] text-[13px] focus:border-[#7C3AED] outline-none">
              <option value="kanan">kanan</option><option value="kiri">kiri</option><option value="bawah">bawah</option>
            </select>
            <input value={form.target} onChange={(e) => setForm({ ...form, target: e.target.value })} placeholder="Target (URL https://)" className="px-3.5 py-2 rounded-xl bg-white border border-[#E9E3F5] text-[13px] focus:border-[#7C3AED] outline-none" />
            <select value={form.platform} onChange={(e) => setForm({ ...form, platform: e.target.value })} className="px-3.5 py-2 rounded-xl bg-white border border-[#E9E3F5] text-[13px] focus:border-[#7C3AED] outline-none">
              <option value="semua">semua</option><option value="aplikasi">aplikasi</option><option value="web">web</option>
            </select>
          </div>
          {err && <div className="mt-2 text-[12px] text-red-600 font-semibold">{err}</div>}
          <button onClick={simpan} disabled={saving} className="mt-3 px-5 py-2.5 rounded-full xy-btn text-white font-semibold text-[13px] disabled:opacity-50">
            {saving ? "Menyimpan…" : "Simpan Promo"}
          </button>
        </div>
      )}

      {loading ? <Load /> : err && rows.length === 0 ? <ErrBox msg={err} /> : rows.length === 0 ? (
        <div className="xy-card rounded-[20px] p-10 text-center text-[#7C738F] font-medium">Belum ada promosi.</div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-3">
          {rows.map((p) => (
            <div key={p.id} className="xy-card rounded-[20px] overflow-hidden">
              <div className="h-28 bg-[#F3F0FF] overflow-hidden flex items-center justify-center">
                {p.gambar ? <img src={p.gambar} alt={p.nama} className="w-full h-full object-cover" loading="lazy" /> : <Gift size={18} className="text-[#C4B5FD]" />}
              </div>
              <div className="p-4">
                <div className="flex items-start justify-between gap-2">
                  <div className="min-w-0">
                    <div className="text-[13.5px] font-semibold text-[#1E1B2E] truncate">{p.nama}</div>
                    <div className="text-[10.5px] text-[#7C738F] font-mono mt-0.5">{p.id}</div>
                  </div>
                  <div className="flex flex-col items-end gap-1">
                    <Chip tone={p.aktif ? "ok" : "bad"}>{p.aktif ? "aktif" : "nonaktif"}</Chip>
                    <Chip tone="info">{p.jenis} • {p.platform}</Chip>
                  </div>
                </div>
                <div className="mt-2 flex items-center gap-1.5 flex-wrap text-[10.5px] text-[#7C738F] font-medium">
                  <Chip tone="netral">aksi {p.aksi || "-"}</Chip>
                  <Chip tone="netral">{p.posisi}</Chip>
                  <span>revisi {p.revisi || 1} • {jam(p.dibuat)}</span>
                </div>
                <div className="mt-2 flex items-center gap-2">
                  <button onClick={() => hapus(p.id)} className="text-[11px] px-3 py-1.5 rounded-full bg-rose-500/10 border border-rose-500/25 text-rose-600 font-semibold flex items-center gap-1"><Trash2 size={11} /> Hapus</button>
                  {p.target && <span className="text-[10px] text-[#7C738F] font-mono truncate flex-1">{p.target}</span>}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
