"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { Image as ImageIcon } from "lucide-react";
import { Chip, ErrBox, Header, jam, Load } from "@/components/ui/kit";

function formatBytes(n: number) {
  if (!n) return "—";
  if (n < 1024) return n + " B";
  if (n < 1024 * 1024) return (n / 1024).toFixed(1) + " KB";
  return (n / (1024 * 1024)).toFixed(1) + " MB";
}

export default function MediaPage() {
  const [rows, setRows] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");

  useEffect(() => {
    adminFetch("/api/admin/media")
      .then((d) => setRows(Array.isArray(d) ? d : []))
      .catch((e) => setErr(e.message))
      .finally(() => setLoading(false));
  }, []);

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header icon={ImageIcon} title="Media" sub="Aset unggahan Cloudinary (hanya pemilik) — 200 terakhir"
        right={<span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{rows.length} aset</span>} />
      {loading ? <Load /> : err ? <ErrBox msg={err} /> : rows.length === 0 ? (
        <div className="xy-card rounded-[20px] p-10 text-center text-[#7C738F] font-medium">Belum ada aset media.</div>
      ) : (
        <div className="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-4 gap-3">
          {rows.map((m) => (
            <div key={m.id} className="xy-card rounded-[18px] overflow-hidden">
              <div className="h-32 bg-[#F3F0FF] flex items-center justify-center overflow-hidden">
                {m.preview || m.url ? (
                  <img src={m.preview || m.url} alt={m.id} loading="lazy" className="w-full h-full object-cover" />
                ) : (
                  <ImageIcon size={20} className="text-[#C4B5FD]" />
                )}
              </div>
              <div className="p-3">
                <div className="flex items-center justify-between gap-2">
                  <span className="text-[12px] font-bold text-[#1E1B2E] font-mono truncate">{m.id.slice(0, 12)}</span>
                  <Chip tone="netral">{m.format || "-"}</Chip>
                </div>
                <div className="mt-1 text-[10.5px] text-[#7C738F] font-medium">
                  {m.width && m.height ? `${m.width}×${m.height}` : ""}{m.width ? " • " : ""}{formatBytes(m.bytes)}{m.animated ? " • GIF" : ""}
                </div>
                <div className="text-[10.5px] text-[#7C738F] mt-0.5">folder: {m.folder || "-"} • {jam(m.created_at)}</div>
                <button
                  onClick={() => navigator.clipboard?.writeText(m.url || "")}
                  className="mt-2 text-[11px] w-full py-1.5 rounded-full bg-[#F5F3FF] border border-[#E9E3F5] font-semibold text-[#6B5A8A] hover:text-[#7C3AED] hover:border-[#C4B5FD]">
                  Salin URL
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
