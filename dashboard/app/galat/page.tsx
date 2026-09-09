"use client";
import { Bug, AlertTriangle, CheckCircle2 } from "lucide-react";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
export default function GalatPage(){
  const [list,setList]=useState<any[]>([]);
  useEffect(()=>{ adminFetch('/api/admin/galat').then((r:any)=>setList(Array.isArray(r)?r:r.data??[])).catch(()=>{}); },[]);
  return (
    <div className="space-y-4 font-[Plus_Jakarta_Sans]">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl xy-btn grid place-items-center"><Bug size={18} className="text-white"/></div>
        <div>
          <h1 className="text-xl font-black text-white tracking-tight">Galat Aplikasi <span className="ml-2 text-[10px] px-2 py-0.5 rounded-full bg-[#A855F7] font-bold">BARU</span></h1>
          <p className="text-sm text-violet-200/60 font-medium">Crash log dari Android, dikelompokkan by hash, status baru/selesai</p>
        </div>
      </div>
      <div className="xy-card rounded-xl p-4">
        <div className="flex items-center gap-2 mb-3">
          <AlertTriangle size={14} className="text-[#A78BFA]"/><span className="text-[12px] font-bold text-white tracking-wide">{list.length} Laporan</span>
        </div>
        <div className="space-y-2 max-h-[560px] overflow-auto">
          {list.slice(0,50).map((g:any)=>(
            <div key={g.id} className="py-2.5 px-3 rounded-xl bg-white/[0.03] border border-white/5 flex items-start justify-between gap-3">
              <div className="flex-1">
                <div className="text-[12px] font-bold text-white">{g.pesan?.slice(0,120)}</div>
                <div className="text-[11px] text-white/40 mt-1">{g.perangkat} • {g.versi} • {g.layar} • {g.jumlah}x • {g.terakhir?.slice(0,19)}</div>
              </div>
              <span className={`text-[10px] px-2 py-1 rounded-full font-bold ${g.status==='baru'?'bg-red-500/20 text-red-300':'bg-green-500/20 text-green-300'}`}>{g.status}</span>
            </div>
          ))}
          {list.length===0 && <div className="text-[12px] text-white/30">Belum ada laporan — user Android kirim via /api/galat</div>}
        </div>
      </div>
    </div>
  );
}
