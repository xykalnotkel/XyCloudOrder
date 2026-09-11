"use client";
import { useState } from "react";
import { Copy, Package } from "lucide-react";
import {
  Btn, EmptyBox, ErrBox, Header, jam, Load, MsgOk, useAdminList,
} from "@/components/ui/kit";

function formatBytes(n?: number) {
  const v = Number(n || 0);
  if (v < 1024) return `${v} B`;
  if (v < 1024 * 1024) return `${(v / 1024).toFixed(1)} KB`;
  return `${(v / 1024 / 1024).toFixed(2)} MB`;
}

export default function MediaPage() {
  const { rows, loading, err } = useAdminList("/api/admin/media");
  const [ok, setOk] = useState("");

  function salin(url: string) {
    navigator.clipboard?.writeText(url).then(() => setOk("URL disalin")).catch(() => setOk(url));
  }

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header
        icon={Package}
        title="Media"
        sub="File terunggah (R2 / storage) — pemilik"
        right={<span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{rows.length} file</span>}
      />
      {ok && <MsgOk msg={ok} />}
      {err && <ErrBox msg={err} />}
      {loading ? <Load /> : rows.length === 0 ? (
        <EmptyBox msg="Belum ada media tercatat." sub="Upload banner/produk/CS akan muncul di sini bila diindeks." />
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
          {rows.map((m: any, i: number) => (
            <div key={m.id || m.key || m.url || i} className="xy-card rounded-[16px] p-4 space-y-2">
              {m.url && /\.(png|jpe?g|gif|webp)(\?|$)/i.test(m.url) ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={m.url} alt="" className="w-full h-36 object-cover rounded-xl border border-[#E9E3F5] bg-[#F5F3FF]" />
              ) : (
                <div className="h-36 rounded-xl bg-[#F5F3FF] border border-[#E9E3F5] grid place-items-center text-[#7C738F] text-[12px] font-medium">
                  {m.content_type || m.tipe || "file"}
                </div>
              )}
              <div className="font-semibold text-[13px] text-[#1E1B2E] truncate">{m.nama || m.key || m.id || "media"}</div>
              <div className="text-[11px] text-[#7C738F] font-mono">
                {formatBytes(m.ukuran || m.size)} · {jam(m.dibuat || m.uploaded_at)}
              </div>
              {m.url && (
                <Btn tone="ghost" className="w-full !h-8" onClick={() => salin(m.url)}>
                  <Copy size={12} /> Salin URL
                </Btn>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
