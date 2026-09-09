"use client";
import { Database, Download, Clock } from "lucide-react";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
export default function CadanganPage(){
  const [list,setList]=useState<any[]>([]);
  useEffect(()=>{ adminFetch('/api/admin/cadangan').then((r:any)=>setList(Array.isArray(r)?r:r.data??[])).catch(()=>{}); },[]);
  return (
    <div className="space-y-4 font-[Plus_Jakarta_Sans]">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl bg-[#7C3AED] grid place-items-center"><Database size={18} className="text-white"/></div>
        <div><h1 className="text-xl font-black text-white tracking-tight">Cadangan</h1><p className="text-sm text-[#9A8CBF]">Backup otomatis DB, download JSON</p></div>
      </div>
      <div className="xy-card p-4">
        <div className="flex items-center gap-2 mb-3"><Clock size={14} className="text-[#A78BFA]"/><span className="text-[12px] font-bold text-white">{list.length} cadangan</span></div>
        <div className="space-y-2 max-h-[560px] overflow-auto">
          {list.slice(0,50).map((c:any)=>(
            <div key={c.id} className="flex items-center justify-between py-2 border-b border-[#2D1B5E] text-[12px]">
              <div><div className="font-bold text-white">{c.id} • {c.jumlah_baris} baris</div><div className="text-[#6B5A8A] text-[11px]">{c.dibuat} • {c.ukuran} bytes</div></div>
              <a href={`/api/admin/cadangan/${c.id}`} className="text-[11px] px-3 py-1 rounded-full bg-[#21114A] text-[#A78BFA] font-bold flex items-center gap-1"><Download size={12}/> Unduh</a>
            </div>
          ))}
          {list.length===0 && <div className="text-[12px] text-[#6B5A8A]">Belum ada — endpoint /api/admin/cadangan</div>}
        </div>
      </div>
    </div>
  );
}
