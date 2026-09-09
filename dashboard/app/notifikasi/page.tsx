"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { BellRing, Search } from "lucide-react";
import { Chip, EmptyBox, ErrBox, Header, jam, Load } from "@/components/ui/kit";

export default function NotifikasiPage() {
  const [rows, setRows] = useState<any[]>([]);
  const [q, setQ] = useState("");
  const [cari, setCari] = useState("");
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");

  useEffect(() => {
    setLoading(true); setErr("");
    adminFetch("/api/admin/notifikasi" + (cari ? "?q=" + encodeURIComponent(cari) : ""))
      .then((d) => setRows(Array.isArray(d) ? d : []))
      .catch((e) => setErr(e.message))
      .finally(() => setLoading(false));
  }, [cari]);

  const belum = rows.filter((r) => !Number(r.dibaca)).length;

  return (
    <div className="space-y-4 font-[Plus_Jakarta_Sans]">
      <Header icon={BellRing} title="Notifikasi" sub="Notifikasi yang dikirim ke semua pengguna (300 terakhir)"
        right={
          <div className="flex items-center gap-2 flex-wrap">
            {!loading && <>
              <span className="text-xs px-3 py-1.5 rounded-full bg-violet-500/15 border border-violet-500/25 text-violet-700 font-bold">{belum} belum dibaca</span>
              <span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{rows.length} total</span>
            </>}
          </div>
        } />
      <div className="flex items-center gap-2">
        <div className="relative max-w-[340px] flex-1">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-[#9A8CBF]" />
          <input value={q} onChange={(e) => setQ(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && setCari(q)}
            placeholder="Cari user / judul / isi…" className="w-full pl-9 pr-3 py-2 rounded-xl bg-white border border-[#E9E3F5] text-[12.5px] focus:border-[#7C3AED] outline-none" />
        </div>
        <button onClick={() => setCari(q)} className="px-4 h-9 rounded-xl xy-btn text-white text-[12px] font-bold">Cari</button>
      </div>
      {loading ? <Load /> : err ? <ErrBox msg={err} /> : rows.length === 0 ? (
        <EmptyBox msg="Belum ada notifikasi." sub="Notifikasi muncul saat pengguna menerima info dari Worker." />
      ) : (
        <div className="space-y-2.5">
          {rows.map((n) => (
            <div key={n.id} className={`xy-card rounded-[16px] p-4 ${Number(n.dibaca) ? "opacity-70" : ""}`}>
              <div className="flex items-start gap-3">
                <div className={`w-8 h-8 shrink-0 rounded-lg grid place-items-center ${Number(n.dibaca) ? "bg-[#F3F0FF] text-[#9A8CBF]" : "bg-gradient-to-br from-[#7C3AED] to-[#5B21B6] text-white"}`}>
                  <BellRing size={14} />
                </div>
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2 flex-wrap">
                    <span className="text-[13px] font-bold text-[#1E1B2E]">{n.judul}</span>
                    <Chip tone="netral">{n.jenis}</Chip>
                    {!Number(n.dibaca) && <Chip tone="info">baru</Chip>}
                  </div>
                  {n.pesan && <p className="text-[12.5px] text-[#6B5A8A]/85 mt-1 leading-relaxed">{n.pesan}</p>}
                  <div className="mt-1.5 text-[10.5px] text-[#7C738F] font-medium font-mono truncate">
                    {n.user_id} {n.aktor ? "• dari " + n.aktor : ""} {n.ref_jenis ? "• " + n.ref_jenis + "/" + (n.ref_id || "-") : ""} • {jam(n.dibuat)}
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
