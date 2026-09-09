"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";

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
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-black text-white">Produk Akun 🎮</h1>
          <p className="text-sm text-violet-200/60">Kelola akun game/streaming — stok atomik anti-double (v3.0c)</p>
        </div>
        <span className="text-xs px-3 py-1 rounded-full bg-white/5 border border-white/10">{produk.length} produk</span>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div className="xy-card rounded-[16px] p-5">
          <h3 className="font-bold text-white">Tambah Produk</h3>
          <div className="mt-4 space-y-3">
            <input value={form.nama} onChange={(e) => setForm({ ...form, nama: e.target.value })} placeholder="Nama produk" className="w-full px-4 py-2.5 rounded-xl bg-[#100030] border border-white/10 text-sm text-white" />
            <div className="grid grid-cols-2 gap-2">
              <select value={form.kategori} onChange={(e) => setForm({ ...form, kategori: e.target.value })} className="px-4 py-2.5 rounded-xl bg-[#100030] border border-white/10 text-sm text-white">
                <option value="game">game</option>
                <option value="streaming">streaming</option>
                <option value="software">software</option>
                <option value="vpn">vpn</option>
              </select>
              <input type="number" value={form.harga} onChange={(e) => setForm({ ...form, harga: parseInt(e.target.value) || 0 })} placeholder="Harga" className="px-4 py-2.5 rounded-xl bg-[#100030] border border-white/10 text-sm text-white" />
            </div>
            <input type="number" value={form.stok} onChange={(e) => setForm({ ...form, stok: parseInt(e.target.value) || 0 })} placeholder="Stok awal" className="w-full px-4 py-2.5 rounded-xl bg-[#100030] border border-white/10 text-sm text-white" />
            <textarea value={form.deskripsi} onChange={(e) => setForm({ ...form, deskripsi: e.target.value })} placeholder="Deskripsi" rows={3} className="w-full px-4 py-2.5 rounded-xl bg-[#100030] border border-white/10 text-sm text-white" />
            <button onClick={create} className="w-full py-3 rounded-xl xy-btn font-bold text-white">Simpan</button>
            <div className="text-[11px] text-white/30">Stok kredensial: klaim atomik WHERE status=tersedia — anti-double sudah di v3.0c.</div>
          </div>
        </div>

        <div className="lg:col-span-2">
          {loading ? <div className="xy-card rounded-xl p-6 text-center text-white/60">Memuat...</div> : err ? <div className="xy-card rounded-xl p-4 text-red-300">{err}</div> : (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              {produk.map((p: any) => (
                <div key={p.id} className="xy-card rounded-[14px] p-4">
                  <div className="flex gap-3">
                    <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-[#7C3AED] to-[#A855F7] grid place-items-center text-white font-bold">{(p.nama || "?")[0]}</div>
                    <div className="min-w-0 flex-1">
                      <div className="font-bold text-white text-[13px] truncate">{p.nama}</div>
                      <div className="text-[11px] text-violet-200/50">{p.kategori} • Rp {(p.harga || 0).toLocaleString()} • stok {p.stok ?? p.total_stok ?? 0}</div>
                      <div className="mt-2 flex gap-1.5">
                        <span className="text-[10px] px-2 py-0.5 rounded-full bg-[#7C3AED]/20 border border-[#7C3AED]/30">{p.status || "aktif"}</span>
                        {p.terlaris && <span className="text-[10px] px-2 py-0.5 rounded-full bg-amber-500/20 border border-amber-500/30">terlaris</span>}
                      </div>
                    </div>
                  </div>
                </div>
              ))}
              {produk.length === 0 && <div className="col-span-2 xy-card rounded-xl p-8 text-center text-white/40 text-sm">Belum ada produk — fetch dari Worker /api/admin/produk</div>}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
