"use client";
import { Sticker, Search, Trash2 } from "lucide-react";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
export default function StikerPage(){
  const [data,setData]=useState<any>(null);
  useEffect(()=>{ adminFetch('/api/admin/integrasi/giphy').then(setData).catch(()=>{}); },[]);
  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl bg-[#7C3AED] grid place-items-center"><Sticker size={18} className="text-white"/></div>
        <div><h1 className="text-xl font-black text-[#1E1B2E] tracking-tight">Stiker & GIPHY</h1><p className="text-sm text-[#7C738F] font-medium">Kelola integrasi GIPHY, koleksi stiker lokal</p></div>
      </div>
      <div className="xy-card p-4">
        <div className="text-[12px] font-bold text-[#1E1B2E] mb-2">Status GIPHY</div>
        <div className="text-[12px] text-[#7C738F]">{data ? (data.siap ? "Terhubung" : "Belum terhubung") : "Memuat..."}</div>
        <div className="text-[11px] text-[#7C738F] mt-2">Key dari env: {data?.dari_env ? "Ya" : "Tidak"} — kelola via /api/admin/integrasi/giphy</div>
      </div>
      <div className="xy-card p-4 text-[12px] text-[#7C738F]">Halaman ini terpisah per menu — no glassmorphism, solid #1E123F</div>
    </div>
  );
}
