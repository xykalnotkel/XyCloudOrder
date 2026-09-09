"use client";
import { Heart, Star, TrendingUp } from "lucide-react";
export default function FavoritPage(){
  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl xy-btn grid place-items-center"><Heart size={18} className="text-white"/></div>
        <div>
          <h1 className="text-xl font-black text-[#1E1B2E] tracking-tight">Favorit <span className="ml-2 text-[10px] px-2 py-0.5 rounded-full bg-[#F3F0FF] font-bold">BARU</span></h1>
          <p className="text-sm text-[#7C738F] font-medium">Produk paling banyak difavoritkan user, insight wishlist</p>
        </div>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
        {[
          {l:"Total Wishlist Item", v:"-", Icon: Heart},
          {l:"Produk Top Favorit", v:"-", Icon: Star},
          {l:"Konversi Fav→Beli", v:"-", Icon: TrendingUp},
        ].map(c=>(
          <div key={c.l} className="xy-card rounded-[14px] p-4 flex items-center gap-3">
            <div className="w-9 h-9 rounded-xl bg-[#F3F0FF] border border-[#E9E3F5] grid place-items-center"><c.Icon size={16} className="text-[#7C3AED]"/></div>
            <div><div className="text-[11px] text-[#7C738F] font-medium uppercase">{c.l}</div><div className="text-lg font-bold text-[#1E1B2E] mt-0.5">{c.v}</div></div>
          </div>
        ))}
      </div>
      <div className="xy-card rounded-xl p-4 text-[12px] text-[#7C738F]">TODO: endpoint /api/admin/favorit (agregasi favorit table). Saat ini belum ada endpoint, placeholder untuk v3.4.</div>
    </div>
  );
}
