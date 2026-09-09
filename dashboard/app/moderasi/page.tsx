"use client";
import { ShieldAlert, Flag, Eye } from "lucide-react";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
export default function ModerasiPage(){
  const [laporan,setLaporan]=useState<any[]>([]);
  useEffect(()=>{ adminFetch('/api/admin/laporan').then((r:any)=>setLaporan(Array.isArray(r)?r:r.data??[])).catch(()=>{}); },[]);
  return (
    <div className="space-y-4 font-[Plus_Jakarta_Sans]">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl bg-[#7C3AED] grid place-items-center"><ShieldAlert size={18} className="text-white"/></div>
        <div><h1 className="text-xl font-black text-white tracking-tight">Moderasi</h1><p className="text-sm text-[#9A8CBF]">Laporan konten, sensitif, spam forum</p></div>
      </div>
      <div className="xy-card p-4">
        <div className="text-[12px] font-bold text-white mb-3">{laporan.length} laporan</div>
        <div className="space-y-2 max-h-[560px] overflow-auto">
          {laporan.slice(0,50).map((l:any)=>(
            <div key={l.id} className="flex items-center justify-between py-2 border-b border-[#2D1B5E] text-[12px]">
              <div><div className="font-bold text-white">{l.jenis} • {l.ref_id}</div><div className="text-[#6B5A8A] text-[11px]">{l.alasan} • {l.status} • {l.dibuat}</div></div>
              <span className="text-[10px] px-2 py-1 rounded-full bg-[#21114A] text-[#A78BFA] font-bold">{l.status}</span>
            </div>
          ))}
          {laporan.length===0 && <div className="text-[12px] text-[#6B5A8A]">Belum ada laporan — endpoint /api/admin/laporan</div>}
        </div>
      </div>
    </div>
  );
}
