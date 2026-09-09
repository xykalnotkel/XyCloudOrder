"use client";
import { MonitorSmartphone, Activity, Timer, Cpu } from "lucide-react";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
export default function SesiPage(){
  const [sesi,setSesi]=useState<any[]>([]);
  useEffect(()=>{ adminFetch('/api/admin/sesi').then((r:any)=>setSesi(Array.isArray(r)?r:r.data??[])).catch(()=>{}); },[]);
  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl xy-btn grid place-items-center"><MonitorSmartphone size={18} className="text-white"/></div>
        <div>
          <h1 className="text-xl font-black text-[#1E1B2E] tracking-tight">Sesi PC <span className="ml-2 text-[10px] px-2 py-0.5 rounded-full bg-[#F3F0FF] font-bold">BARU</span></h1>
          <p className="text-sm text-[#7C738F] font-medium">Monitoring sesi aktif, agen, durasi, status siap/berjalan/selesai</p>
        </div>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
        {[
          {l:"Aktif", v: sesi.filter((s:any)=>['siap','berjalan','pairing'].includes(s.status)).length, Icon: Activity},
          {l:"Provisioning", v: sesi.filter((s:any)=>s.status==='provisioning').length, Icon: Timer},
          {l:"Selesai Hari Ini", v: sesi.filter((s:any)=>s.status==='selesai').length, Icon: Cpu},
          {l:"Total", v: sesi.length, Icon: MonitorSmartphone},
        ].map(c=>(
          <div key={c.l} className="xy-card rounded-[14px] p-4 flex items-center gap-3">
            <div className="w-9 h-9 rounded-xl bg-[#F3F0FF] border border-[#E9E3F5] grid place-items-center"><c.Icon size={16} className="text-[#7C3AED]"/></div>
            <div><div className="text-[11px] text-[#7C738F] font-medium uppercase">{c.l}</div><div className="text-lg font-bold text-[#1E1B2E] mt-0.5">{c.v}</div></div>
          </div>
        ))}
      </div>
      <div className="xy-card rounded-xl p-4">
        <div className="space-y-2 max-h-[560px] overflow-auto">
          {sesi.slice(0,50).map((s:any)=>(
            <div key={s.id} className="flex items-center justify-between py-2 border-b border-[#E9E3F5] text-[12px]">
              <div><div className="font-bold text-[#1E1B2E]">{s.id} • {s.nama} ({s.email})</div><div className="text-[#7C738F] text-[11px]">{s.unit} • {s.status} • {s.dibuat?.slice(0,19)}</div></div>
              <span className="text-[10px] px-2 py-1 rounded-full bg-[#F3F0FF] text-[#7C3AED] font-bold">{s.status}</span>
            </div>
          ))}
          {sesi.length===0 && <div className="text-[12px] text-[#7C738F]">Belum ada sesi — endpoint /api/admin/sesi</div>}
        </div>
      </div>
    </div>
  );
}
