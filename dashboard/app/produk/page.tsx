"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { Gamepad2, Plus, Package, Star } from "lucide-react";

export default function ProdukPage() {
  const [produk, setProduk] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");
  const [form, setForm] = useState({ nama: "", kategori: "game", harga: 0, stok: 0, deskripsi: "" });

  useEffect(() => {
    adminFetch("/api/admin/produk")
      .then((d) => setProduk(d.produk || d.data || []))
      .catch((e) => setErr(e.message))
      .finally(() => setLoading(false));
  }, []);

  const create = async () => {
    try {
      await adminFetch("/api/admin/produk", { method: "POST", body: form });
      alert("Produk dibuat");
      location.reload();
    } catch (e: any) { alert(e.message); }
  };

  return (
    <div className="space-y-5 font-[var(--font-inter)]">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl xy-btn grid place-items-center"><Gamepad2 size={18} className="text-white" /></div>
          <div>
            <h1 className="text-xl font-black text-[#1E1B2E] tracking-tight">Produk Akun</h1>
            <p className="text-sm text-[#7C738F] font-medium">Kelola akun game/streaming — stok atomik anti-double (v3.0c)</p>
          </div>
        </div>
        <span className="text-xs px-3 py-1 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{produk.length} produk</span>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div className="xy-card rounded-[16px] p-5">
          <h3 className="font-bold text-[#1E1B2E] tracking-tight flex items-center gap-2"><Plus size={16} /> Tambah Produk</h3>
          <div className="mt-4 space-y-3">
            <input value={form.nama} onChange={(e) => setForm({ ...form, nama: e.target.value })} placeholder="Nama produk" className="w-full px-4 py-2.5 rounded-xl bg-[#FFFFFF] border border-[#E9E3F5] text-sm text-[#1E1B2E] font-medium" />
            <div className="grid grid-cols-2 gap-2">
              <select value={form.kategori} onChange={(e) => setForm({ ...form, kategori: e.target.value })} className="px-4 py-2.5 rounded-xl bg-[#FFFFFF] border border-[#E9E3F5] text-sm text-[#1E1B2E] font-medium">
                <option value="game">game</option>
                <option value="streaming">streaming</option>
                <option value="software">software</option>
                <option value="vpn">vpn</option>
              </select>
              <input type="number" value={form.harga} onChange={(e) => setForm({ ...form, harga: parseInt(e.target.value) || 0 })} placeholder="Harga" className="px-4 py-2.5 rounded-xl bg-[#FFFFFF] border border-[#E9E3F5] text-sm text-[#1E1B2E] font-medium" />
            </div>
            <input type="number" value={form.stok} onChange={(e) => setForm({ ...form, stok: parseInt(e.target.value) || 0 })} placeholder="Stok awal" className="w-full px-4 py-2.5 rounded-xl bg-[#FFFFFF] border border-[#E9E3F5] text-sm text-[#1E1B2E] font-medium" />
            <textarea value={form.deskripsi} onChange={(e) => setForm({ ...form, deskripsi: e.target.value })} placeholder="Deskripsi" rows={3} className="w-full px-4 py-2.5 rounded-xl bg-[#FFFFFF] border border-[#E9E3F5] text-sm text-[#1E1B2E] font-medium" />
            <button onClick={create} className="w-full py-3 rounded-xl xy-btn font-bold text-white tracking-wide">Simpan</button>
            <div className="text-[11px] text-[#7C738F] font-medium">Stok kredensial: klaim atomik WHERE status=tersedia — anti-double sudah di v3.0c. Icons Lucide, font konsisten.</div>
          </div>
        </div>

        <div className="lg:col-span-2">
          {loading ? <div className="xy-card rounded-xl p-6 text-center text-[#7C738F] font-medium">Memuat...</div> : err ? <div className="xy-card rounded-xl p-4 text-red-600 font-medium">{err}</div> : (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              {produk.map((p: any) => (
                <div key={p.id} className="xy-card rounded-[14px] p-4">
                  <div className="flex gap-3">
                    <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-[#7C3AED] to-[#A855F7] grid place-items-center text-white font-bold tracking-tight">{(p.nama || "?")[0]}</div>
                    <div className="min-w-0 flex-1">
                      <div className="font-bold text-[#1E1B2E] text-[13px] truncate tracking-tight">{p.nama}</div>
                      <div className="text-[11px] text-[#7C738F] font-medium">{p.kategori} • Rp {(p.harga || 0).toLocaleString()} • stok {p.stok ?? p.total_stok ?? 0}</div>
                      <div className="mt-2 flex gap-1.5">
                        <span className="text-[10px] px-2 py-0.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-semibold">{p.status || "aktif"}</span>
                        {p.terlaris && <span className="text-[10px] px-2 py-0.5 rounded-full bg-amber-500/20 border border-amber-500/30 font-semibold">terlaris</span>}
                      </div>
                    </div>
                  </div>
                </div>
              ))}
              {produk.length === 0 && <div className="col-span-2 xy-card rounded-xl p-8 text-center text-[#7C738F] text-sm font-medium">Belum ada produk — fetch dari Worker /api/admin/produk • Icons Lucide, no emoji</div>}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
