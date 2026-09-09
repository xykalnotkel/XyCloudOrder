"use client";
import { Share2, Users, Gift, TrendingUp } from "lucide-react";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";

export default function ReferralPage(){
  const [data,setData]=useState<any>(null);
  useEffect(()=>{ adminFetch('/api/admin/referral').then((r:any)=>setData(r)).catch(()=>{}); },[]);
  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl xy-btn grid place-items-center"><Share2 size={18} className="text-white"/></div>
        <div>
          <h1 className="text-xl font-black text-[#1E1B2E] tracking-tight">Referral <span className="ml-2 text-[10px] px-2 py-0.5 rounded-full bg-[#F3F0FF] font-bold">BARU</span></h1>
          <p className="text-sm text-[#7C738F] font-medium">Top referrer, bonus tracking, kode referral user</p>
        </div>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
        {[
          {l:"Total Referral", v: data?.daftar?.length ?? "-", Icon: Users},
          {l:"Bonus Terbagikan", v: data?.teratas?.reduce((a:number,b:any)=>a+(b.bonus||0),0) ? `Rp ${(data.teratas.reduce((a:number,b:any)=>a+(b.bonus||0),0)).toLocaleString('id-ID')}` : "-", Icon: Gift},
          {l:"Top Pengundang", v: data?.teratas?.[0]?.nama ?? "-", Icon: TrendingUp},
        ].map(c=>(
          <div key={c.l} className="xy-card rounded-[14px] p-4 flex items-center gap-3">
            <div className="w-9 h-9 rounded-xl bg-[#F3F0FF] border border-[#E9E3F5] grid place-items-center"><c.Icon size={16} className="text-[#7C3AED]"/></div>
            <div><div className="text-[11px] text-[#7C738F] font-medium uppercase">{c.l}</div><div className="text-lg font-bold text-[#1E1B2E] mt-0.5">{c.v}</div></div>
          </div>
        ))}
      </div>
      <div className="xy-card rounded-xl p-4">
        <div className="text-[12px] font-bold text-[#1E1B2E] mb-2 tracking-wide">Daftar Referral Terbaru</div>
        <div className="space-y-2 max-h-[420px] overflow-auto">
          {(data?.daftar ?? []).slice(0,30).map((r:any)=>(
            <div key={r.id} className="flex items-center justify-between py-2 border-b border-[#E9E3F5] text-[12px]">
              <span className="text-[#1E1B2E]/80 font-medium">{r.nama_pengundang} → {r.nama_diundang}</span>
              <span className="text-[#7C738F]">{r.status} • Rp {r.bonus_pengundang}</span>
            </div>
          ))}
          {(!data?.daftar || data.daftar.length===0) && <div className="text-[12px] text-[#7C738F]">Belum ada data — endpoint /api/admin/referral</div>}
        </div>
      </div>
    </div>
  );
}
