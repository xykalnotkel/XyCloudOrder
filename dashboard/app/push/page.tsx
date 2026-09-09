"use client";
import { useState } from "react";
import { Bell } from "lucide-react";

export default function PushPage() {
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  return (
    <div className="space-y-4 max-w-[640px] font-[Plus_Jakarta_Sans]">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl xy-btn grid place-items-center"><Bell size={18} className="text-white" /></div>
        <div>
          <h1 className="text-xl font-black text-white tracking-tight">Push Notif Builder <span className="ml-2 text-[10px] px-2 py-0.5 rounded-full bg-[#21114A] font-bold">BARU</span></h1>
          <p className="text-sm text-[#9A8CBF] font-medium">Compose push dengan targeting + schedule — OneSignal</p>
        </div>
      </div>
      <div className="xy-card rounded-[16px] p-5 space-y-3">
        <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Judul notif" className="w-full px-4 py-2.5 rounded-xl bg-[#100030] border border-[#2D1B5E] text-sm text-white font-medium" />
        <textarea value={body} onChange={(e) => setBody(e.target.value)} placeholder="Isi pesan" rows={4} className="w-full px-4 py-2.5 rounded-xl bg-[#100030] border border-[#2D1B5E] text-sm text-white font-medium" />
        <select className="w-full px-4 py-2.5 rounded-xl bg-[#100030] border border-[#2D1B5E] text-sm text-white font-medium">
          <option>Semua user</option>
          <option>Tier aktif sewa</option>
          <option>User tertentu (by email)</option>
        </select>
        <button className="w-full py-3 rounded-xl xy-btn font-bold tracking-wide">Kirim Sekarang (mock)</button>
        <div className="text-[11px] text-[#6B5A8A] font-medium">TODO: POST /api/admin/push dengan x-admin-key, integrasi OneSignal REST API sudah ada di Worker. Icons Lucide, no emoji.</div>
      </div>
    </div>
  );
}
