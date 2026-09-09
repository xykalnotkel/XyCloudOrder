"use client";
import { useState } from "react";

export default function PushPage() {
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  return (
    <div className="space-y-4 max-w-[640px]">
      <h1 className="text-xl font-black text-white">Push Notif Builder 🔔 BARU</h1>
      <p className="text-sm text-violet-200/60">Compose push dengan targeting + schedule — OneSignal</p>
      <div className="xy-card rounded-[16px] p-5 space-y-3">
        <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Judul notif" className="w-full px-4 py-2.5 rounded-xl bg-[#100030] border border-white/10 text-sm" />
        <textarea value={body} onChange={(e) => setBody(e.target.value)} placeholder="Isi pesan" rows={4} className="w-full px-4 py-2.5 rounded-xl bg-[#100030] border border-white/10 text-sm" />
        <select className="w-full px-4 py-2.5 rounded-xl bg-[#100030] border border-white/10 text-sm">
          <option>Semua user</option>
          <option>Tier aktif sewa</option>
          <option>User tertentu (by email)</option>
        </select>
        <button className="w-full py-3 rounded-xl xy-btn font-bold">Kirim Sekarang (mock)</button>
        <div className="text-[11px] text-white/30">TODO: POST /api/admin/push dengan x-admin-key, integrasi OneSignal REST API sudah ada di Worker.</div>
      </div>
    </div>
  );
}
