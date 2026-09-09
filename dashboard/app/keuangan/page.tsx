"use client";
import { Wallet, TrendingUp, CreditCard, AlertCircle } from "lucide-react";

export default function KeuanganPage() {
  return (
    <div className="space-y-4 font-[Plus_Jakarta_Sans]">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl xy-btn grid place-items-center"><Wallet size={18} className="text-white" /></div>
        <div>
          <h1 className="text-xl font-black text-white tracking-tight">Keuangan <span className="ml-2 text-[10px] px-2 py-0.5 rounded-full bg-[#A855F7] font-bold">BARU</span></h1>
          <p className="text-sm text-violet-200/60 font-medium">Omzet, fee, saldo beredar, topup pending, export CSV</p>
        </div>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
        {[
          { l: "Omzet Hari Ini", v: "Rp 2.4jt", Icon: TrendingUp },
          { l: "Omzet Minggu", v: "Rp 18.7jt", Icon: TrendingUp },
          { l: "Saldo Beredar", v: "Rp 42jt", Icon: Wallet },
          { l: "Topup Pending", v: "3", Icon: AlertCircle },
        ].map((c) => (
          <div key={c.l} className="xy-card rounded-[14px] p-4 flex items-center gap-3">
            <div className="w-9 h-9 rounded-xl bg-[#7C3AED]/20 border border-[#7C3AED]/20 grid place-items-center"><c.Icon size={16} className="text-[#A78BFA]" /></div>
            <div><div className="text-[11px] text-white/50 font-medium tracking-wide uppercase">{c.l}</div><div className="text-lg font-bold text-white mt-0.5 tracking-tight">{c.v}</div></div>
          </div>
        ))}
      </div>
      <div className="xy-card rounded-xl p-4 text-[12px] text-white/40 font-medium">TODO: fetch /api/admin/statistik + keuangan endpoint. Export CSV via admin API. Icons Lucide, font Plus Jakarta Sans konsisten.</div>
    </div>
  );
}
