"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { Ticket, Plus } from "lucide-react";

export default function VoucherPage() {
  const [vouchers, setVouchers] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");
  const [form, setForm] = useState({ kode: "", persen: 10, min_belanja: 0, kuota: 100, jenis: "all" });

  useEffect(() => {
    adminFetch("/api/admin/voucher")
      .then((d) => setVouchers(d.vouchers || d.data || []))
      .catch((e) => setErr(e.message))
      .finally(() => setLoading(false));
  }, []);

  const create = async () => {
    try {
      await adminFetch("/api/admin/voucher", { method: "POST", body: form });
      alert("Voucher dibuat");
      location.reload();
    } catch (e: any) { alert(e.message); }
  };

  return (
    <div className="space-y-5 font-[var(--font-inter)]">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl xy-btn grid place-items-center"><Ticket size={18} className="text-white" /></div>
          <div>
            <h1 className="text-xl font-black text-[#1E1B2E] tracking-tight">Voucher</h1>
            <p className="text-sm text-[#7C738F] font-medium">Kelola kode diskon — validasi anti-double + min belanja</p>
          </div>
        </div>
        <span className="text-xs px-3 py-1 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{vouchers.length} voucher</span>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div className="xy-card rounded-[16px] p-5">
          <h3 className="font-bold text-[#1E1B2E] tracking-tight flex items-center gap-2"><Plus size={16} /> Buat Voucher</h3>
          <div className="mt-4 space-y-3">
            <input value={form.kode} onChange={(e) => setForm({ ...form, kode: e.target.value.toUpperCase() })} placeholder="KODE, ex: HEMAT20" className="w-full px-4 py-2.5 rounded-xl bg-[#FFFFFF] border border-[#E9E3F5] text-sm text-[#1E1B2E] font-mono" />
            <div className="grid grid-cols-2 gap-2">
              <input type="number" value={form.persen} onChange={(e) => setForm({ ...form, persen: parseInt(e.target.value) || 0 })} placeholder="Persen" className="px-4 py-2.5 rounded-xl bg-[#FFFFFF] border border-[#E9E3F5] text-sm text-[#1E1B2E] font-medium" />
              <input type="number" value={form.min_belanja} onChange={(e) => setForm({ ...form, min_belanja: parseInt(e.target.value) || 0 })} placeholder="Min belanja" className="px-4 py-2.5 rounded-xl bg-[#FFFFFF] border border-[#E9E3F5] text-sm text-[#1E1B2E] font-medium" />
            </div>
            <input type="number" value={form.kuota} onChange={(e) => setForm({ ...form, kuota: parseInt(e.target.value) || 0 })} placeholder="Kuota" className="w-full px-4 py-2.5 rounded-xl bg-[#FFFFFF] border border-[#E9E3F5] text-sm text-[#1E1B2E] font-medium" />
            <select value={form.jenis} onChange={(e) => setForm({ ...form, jenis: e.target.value })} className="w-full px-4 py-2.5 rounded-xl bg-[#FFFFFF] border border-[#E9E3F5] text-sm text-[#1E1B2E] font-medium">
              <option value="all">all</option>
              <option value="sewa">sewa</option>
              <option value="akun">akun</option>
            </select>
            <button onClick={create} className="w-full py-3 rounded-xl xy-btn font-bold text-white tracking-wide">Simpan Voucher</button>
            <div className="text-[11px] text-[#7C738F] font-medium">Security: claim atomik — rollback jika transaksi gagal (v3.0c). Icons Lucide, no emoji.</div>
          </div>
        </div>

        <div className="lg:col-span-2">
          {loading ? <div className="xy-card rounded-xl p-6 text-center text-[#7C738F] font-medium">Memuat...</div> : err ? <div className="xy-card rounded-xl p-4 text-red-600 font-medium">{err}</div> : (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              {vouchers.map((v: any) => (
                <div key={v.id || v.kode} className="xy-card rounded-[14px] p-4">
                  <div className="flex items-center justify-between">
                    <span className="font-mono font-bold text-[#1E1B2E] text-[14px] tracking-widest">{v.kode}</span>
                    <span className="text-[11px] px-2 py-0.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] text-[#1E1B2E] font-semibold">{v.persen}% OFF</span>
                  </div>
                  <div className="mt-2 text-[11px] text-[#7C738F] font-medium">Min Rp {(v.min_belanja || 0).toLocaleString()} • Kuota {v.kuota ?? v.sisa_kuota ?? "-"} • {v.jenis || "all"}</div>
                  <div className="mt-2 text-[11px] text-[#7C738F] font-medium">Dipakai: {v.terpakai || 0}x</div>
                </div>
              ))}
              {vouchers.length === 0 && <div className="col-span-2 xy-card rounded-xl p-8 text-center text-[#7C738F] text-sm font-medium">Belum ada voucher — Worker /api/admin/voucher • Icons Lucide, no emoji</div>}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
