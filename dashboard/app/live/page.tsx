"use client";
import { Activity, Cpu, Server } from "lucide-react";

export default function LivePage() {
  return (
    <div className="space-y-4 font-[Plus_Jakarta_Sans]">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-[#7C3AED] to-[#A855F7] grid place-items-center"><Activity size={18} className="text-white" /></div>
        <div>
          <h1 className="text-xl font-black text-white tracking-tight">Live Monitor <span className="ml-2 text-[10px] px-2 py-0.5 rounded-full bg-[#A855F7] font-bold">BARU</span></h1>
          <p className="text-sm text-violet-200/60 font-medium">Realtime status semua agen PC — CPU/RAM/GPU, ping, load, restart remote</p>
        </div>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
        {[1,2,3,4,5,6].map((i) => (
          <div key={i} className="xy-card rounded-[14px] p-4">
            <div className="flex justify-between items-center"><span className="font-bold text-white text-[13px] tracking-tight flex items-center gap-2"><Server size={14} className="text-[#A78BFA]" /> PC-{String(i).padStart(3,"0")} RTX 4090</span><span className="text-[10px] px-2 py-0.5 rounded-full bg-emerald-500/20 border border-emerald-500/30 font-bold tracking-wide">ONLINE</span></div>
            <div className="mt-3 space-y-1 text-[12px] text-white/60 font-medium">
              <div>CPU 32% • RAM 12/64GB • GPU 78°C</div>
              <div>Ping 12ms • Load 2 user • Region SG</div>
            </div>
            <div className="mt-3 flex gap-2"><button className="text-[11px] px-2 py-1 rounded-lg bg-white/5 border border-white/10 font-medium">Restart</button><button className="text-[11px] px-2 py-1 rounded-lg xy-btn font-semibold">Detail</button></div>
          </div>
        ))}
      </div>
      <div className="xy-card rounded-xl p-3 text-[11px] text-white/40 font-medium">TODO: sambung ke WS /api/admin/unit + agent heartbeat. Saat ini mockup UI saja. Icons Lucide, no emoji.</div>
    </div>
  );
}
