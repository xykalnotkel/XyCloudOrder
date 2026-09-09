"use client";
import { Bug, AlertTriangle, CheckCircle2 } from "lucide-react";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
export default function GalatPage(){
  const [list,setList]=useState<any[]>([]);
  useEffect(()=>{ adminFetch('/api/admin/galat').then((r:any)=>setList(Array.isArray(r)?r:r.data??[])).catch(()=>{}); },[]);
  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl xy-btn grid place-items-center"><Bug size={18} className="text-white"/></div>
        <div>
          <h1 className="text-xl font-black text-[#1E1B2E] tracking-tight">Galat Aplikasi <span className="ml-2 text-[10px] px-2 py-0.5 rounded-full bg-[#F3F0FF] font-bold">BARU</span></h1>
          <p className="text-sm text-[#7C738F] font-medium">Crash log dari Android, dikelompokkan by hash, status baru/selesai</p>
        </div>
      </div>
      <div className="xy-card rounded-xl p-4">
        <div className="flex items-center gap-2 mb-3">
          <AlertTriangle size={14} className="text-[#7C3AED]"/><span className="text-[12px] font-bold text-[#1E1B2E] tracking-wide">{list.length} Laporan</span>
        </div>
        <div className="space-y-2 max-h-[560px] overflow-auto">
          {list.slice(0,50).map((g:any)=>(
            <div key={g.id} className="py-2.5 px-3 rounded-xl bg-[#F3F0FF] border border-[#E9E3F5] flex items-start justify-between gap-3">
              <div className="flex-1">
                <div className="text-[12px] font-bold text-[#1E1B2E]">{g.pesan?.slice(0,120)}</div>
                <div className="text-[11px] text-[#7C738F] mt-1">{g.perangkat} • {g.versi} • {g.layar} • {g.jumlah}x • {g.terakhir?.slice(0,19)}</div>
              </div>
              <span className={`text-[10px] px-2 py-1 rounded-full font-bold ${g.status==='baru'?'bg-red-500/20 text-red-600':'bg-green-500/20 text-green-700'}`}>{g.status}</span>
            </div>
          ))}
          {list.length===0 && <div className="text-[12px] text-[#7C738F]">Belum ada laporan — user Android kirim via /api/galat</div>}
        </div>
      </div>
    </div>
  );
}
