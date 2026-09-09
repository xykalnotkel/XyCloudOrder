"use client";
import { Smartphone, ShieldCheck, Ban } from "lucide-react";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
export default function PerangkatPage(){
  const [list,setList]=useState<any[]>([]);
  useEffect(()=>{ adminFetch('/api/admin/devices').then((r:any)=>setList(Array.isArray(r)?r:r.data??[])).catch(()=>{}); },[]);
  return (
    <div className="space-y-4 font-[Plus_Jakarta_Sans]">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl bg-[#7C3AED] grid place-items-center"><Smartphone size={18} className="text-white"/></div>
        <div><h1 className="text-xl font-black text-white tracking-tight">Perangkat</h1><p className="text-sm text-[#9A8CBF]">Device fingerprint, batas 2 akun per device, blokir</p></div>
      </div>
      <div className="xy-card p-4">
        <div className="text-[12px] font-bold text-white mb-3">{list.length} perangkat tercatat</div>
        <div className="space-y-2 max-h-[560px] overflow-auto">
          {list.slice(0,50).map((d:any)=>(
            <div key={d.id} className="flex items-center justify-between py-2 border-b border-[#2D1B5E] text-[12px]">
              <div><div className="font-bold text-white">{d.id.slice(0,16)}... • {d.blocked ? "Diblokir" : "Aktif"}</div><div className="text-[#6B5A8A] text-[11px]">{d.user_id} • {d.last_seen}</div></div>
              <span className={`text-[10px] px-2 py-1 rounded-full font-bold ${d.blocked?'bg-red-500/20 text-red-300':'bg-green-500/20 text-green-300'}`}>{d.blocked?'blocked':'ok'}</span>
            </div>
          ))}
          {list.length===0 && <div className="text-[12px] text-[#6B5A8A]">Belum ada — endpoint /api/admin/devices</div>}
        </div>
      </div>
    </div>
  );
}
