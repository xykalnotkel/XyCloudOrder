"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { Cpu, Plus, Server } from "lucide-react";

export default function UnitPage() {
  const [units, setUnits] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");
  const [form, setForm] = useState({ nama: "", lokasi: "SG", cpu: "i7-12700", gpu: "RTX 4070", ram: "32GB", total: 1 });

  useEffect(() => {
    adminFetch("/api/admin/unit")
      .then((d) => setUnits(d.units || d.data || d.plans || []))
      .catch((e) => setErr(e.message))
      .finally(() => setLoading(false));
  }, []);

  const create = async () => {
    try {
      await adminFetch("/api/admin/unit", { method: "POST", body: form });
      alert("Unit dibuat");
      location.reload();
    } catch (e: any) { alert(e.message); }
  };

  return (
    <div className="space-y-5 font-[Plus_Jakarta_Sans]">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl xy-btn grid place-items-center"><Cpu size={18} className="text-white" /></div>
          <div>
            <h1 className="text-xl font-black text-[#1E1B2E] tracking-tight">Unit PC</h1>
            <p className="text-sm text-[#7C738F] font-medium">Kelola paket PC & unit fisik — dipakai live monitor</p>
          </div>
        </div>
        <span className="text-xs px-3 py-1 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{units.length} paket</span>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div className="xy-card rounded-[16px] p-5">
          <h3 className="font-bold text-[#1E1B2E] tracking-tight flex items-center gap-2"><Plus size={16} /> Tambah Paket</h3>
          <div className="mt-4 space-y-3">
            <input value={form.nama} onChange={(e) => setForm({ ...form, nama: e.target.value })} placeholder="Nama paket, ex: RTX 4070 SG" className="w-full px-4 py-2.5 rounded-xl bg-[#FFFFFF] border border-[#E9E3F5] text-sm text-[#1E1B2E] font-medium" />
            <div className="grid grid-cols-2 gap-2">
              <input value={form.lokasi} onChange={(e) => setForm({ ...form, lokasi: e.target.value })} placeholder="Lokasi" className="px-4 py-2.5 rounded-xl bg-[#FFFFFF] border border-[#E9E3F5] text-sm text-[#1E1B2E] font-medium" />
              <input type="number" value={form.total} onChange={(e) => setForm({ ...form, total: parseInt(e.target.value) || 1 })} placeholder="Jumlah unit" className="px-4 py-2.5 rounded-xl bg-[#FFFFFF] border border-[#E9E3F5] text-sm text-[#1E1B2E] font-medium" />
            </div>
            <input value={form.cpu} onChange={(e) => setForm({ ...form, cpu: e.target.value })} placeholder="CPU" className="w-full px-4 py-2.5 rounded-xl bg-[#FFFFFF] border border-[#E9E3F5] text-sm text-[#1E1B2E] font-medium" />
            <input value={form.gpu} onChange={(e) => setForm({ ...form, gpu: e.target.value })} placeholder="GPU" className="w-full px-4 py-2.5 rounded-xl bg-[#FFFFFF] border border-[#E9E3F5] text-sm text-[#1E1B2E] font-medium" />
            <input value={form.ram} onChange={(e) => setForm({ ...form, ram: e.target.value })} placeholder="RAM" className="w-full px-4 py-2.5 rounded-xl bg-[#FFFFFF] border border-[#E9E3F5] text-sm text-[#1E1B2E] font-medium" />
            <button onClick={create} className="w-full py-3 rounded-xl xy-btn font-bold text-white tracking-wide">Simpan Paket</button>
          </div>
        </div>

        <div className="lg:col-span-2">
          {loading ? <div className="xy-card rounded-xl p-6 text-center text-[#7C738F] font-medium">Memuat...</div> : err ? <div className="xy-card rounded-xl p-4 text-red-600 font-medium">{err}</div> : (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              {units.map((u: any, i: number) => (
                <div key={u.id || i} className="xy-card rounded-[14px] p-4">
                  <div className="flex items-center justify-between">
                    <span className="font-bold text-[#1E1B2E] text-[13px] tracking-tight flex items-center gap-2"><Server size={14} className="text-[#7C3AED]" /> {u.nama || u.name || `Paket ${i + 1}`}</span>
                    <span className="text-[10px] px-2 py-0.5 rounded-full bg-emerald-500/20 border border-emerald-500/30 font-bold">{u.unit_tersedia ?? u.tersedia ?? u.total_unit ?? "?"} ready</span>
                  </div>
                  <div className="mt-2 text-[11px] text-[#7C738F] font-medium">{u.cpu || "-"} • {u.gpu || "-"} • {u.ram || "-"}</div>
                  <div className="mt-2 text-[11px] text-[#7C738F] font-medium">Lokasi: {u.lokasi || u.region || "-"}</div>
                </div>
              ))}
              {units.length === 0 && <div className="col-span-2 xy-card rounded-xl p-8 text-center text-[#7C738F] text-sm font-medium">Belum ada unit — Worker /api/admin/unit • Icons Lucide, no emoji</div>}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
