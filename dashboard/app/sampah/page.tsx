"use client";
import { Trash2, Users, AlertTriangle } from "lucide-react";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
export default function SampahPage(){
  const [list,setList]=useState<any[]>([]);
  useEffect(()=>{ adminFetch('/api/admin/users?trash=1').then((r:any)=>setList(Array.isArray(r)?r:r.data??[])).catch(()=>{}); },[]);
  return (
    <div className="space-y-4 font-[Plus_Jakarta_Sans]">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl bg-[#7C3AED] grid place-items-center"><Trash2 size={18} className="text-white"/></div>
        <div><h1 className="text-xl font-black text-white tracking-tight">Sampah Pengguna</h1><p className="text-sm text-[#9A8CBF]">Akun dihapus soft-delete, bisa restore/permanent</p></div>
      </div>
      <div className="xy-card p-4">
        <div className="text-[12px] font-bold text-white mb-3">{list.length} akun di sampah</div>
        <div className="space-y-2 max-h-[560px] overflow-auto">
          {list.slice(0,50).map((u:any)=>(
            <div key={u.id} className="flex items-center justify-between py-2 border-b border-[#2D1B5E] text-[12px]">
              <div><div className="font-bold text-white">{u.nama} • {u.email}</div><div className="text-[#6B5A8A] text-[11px]">{u.id} • {u.deleted_at}</div></div>
            </div>
          ))}
          {list.length===0 && <div className="text-[12px] text-[#6B5A8A]">Kosong — endpoint /api/admin/users?trash=1</div>}
        </div>
      </div>
    </div>
  );
}
