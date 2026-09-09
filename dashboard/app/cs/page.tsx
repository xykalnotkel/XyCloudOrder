"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { MessageCircle } from "lucide-react";
import { Chip, EmptyBox, ErrBox, Header, jam, Load } from "@/components/ui/kit";

export default function CsPage() {
  const [rooms, setRooms] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");

  useEffect(() => {
    adminFetch("/api/admin/cs")
      .then((d) => setRooms(Array.isArray(d) ? d : []))
      .catch((e) => setErr(e.message))
      .finally(() => setLoading(false));
  }, []);

  const total = rooms.reduce((a, r) => a + Number(r.total || 0), 0);

  return (
    <div className="space-y-4 font-[Plus_Jakarta_Sans]">
      <Header icon={MessageCircle} title="CS Realtime" sub="Room percakapan pengguna 7 hari terakhir (log cs_messages)"
        right={<span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{rooms.length} room • {total} pesan</span>} />
      {loading ? <Load /> : err ? <ErrBox msg={err} /> : rooms.length === 0 ? (
        <EmptyBox msg="Belum ada percakapan CS." sub="Room muncul saat pengguna membuka chat dukungan." />
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-3">
          {rooms.map((r) => (
            <div key={r.room} className="xy-card rounded-[18px] p-4">
              <div className="flex items-start justify-between gap-2">
                <div className="min-w-0">
                  <div className="text-[13px] font-bold text-[#1E1B2E] truncate">{r.nama || r.email || r.room}</div>
                  <div className="text-[11px] text-[#7C738F] font-mono truncate">{r.email || r.room}</div>
                </div>
                <Chip tone="info">{r.total} pesan</Chip>
              </div>
              {r.preview && (
                <div className="mt-3 p-3 rounded-xl bg-[#F5F3FF] border border-[#E9E3F5] text-[12px] text-[#1E1B2E]/80 font-medium leading-relaxed">
                  {r.preview}
                </div>
              )}
              <div className="mt-3 pt-2 border-t border-[#E9E3F5] text-[10.5px] text-[#7C738F] font-medium flex items-center justify-between">
                <span>Terakhir: {jam(r.terakhir)}</span>
                {r.phone && <span className="font-mono">{r.phone}</span>}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
