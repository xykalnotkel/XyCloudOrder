"use client";
import { useState } from "react";
import { adminFetch } from "@/lib/api";
import { Gavel } from "lucide-react";
import { Btn, Chip, ErrBox, Header, Load, jam, useAdminList } from "@/components/ui/kit";
import { mintaTeks } from "@/components/ui/dialog";

export default function BandingPage() {
  const { rows, loading, err, reload } = useAdminList("/api/admin/moderasi/banding");
  const [busy, setBusy] = useState<string | null>(null);
  const [filter, setFilter] = useState<"baru" | "semua">("baru");

  async function tanggapi(b: any, terima: boolean) {
    const t = await mintaTeks({
      judul: terima ? "Terima banding" : "Tolak banding",
      pesan: terima
        ? `Akun ${b.nama || b.email || b.user_id} akan AKTIF kembali. Tuliskan catatan untuk pengguna (opsional):`
        : `Tuliskan alasan penolakan untuk ${b.nama || b.email || b.user_id} (opsional):`,
      okLabel: terima ? "Terima & aktifkan" : "Tolak",
      bahaya: !terima,
      placeholder: "Catatan untuk pengguna…",
    });
    if (t === null) return;
    setBusy(b.id);
    try {
      await adminFetch(`/api/admin/moderasi/banding/${b.id}`, {
        method: "POST",
        body: { status: terima ? "diterima" : "ditolak", tanggapan: t || "" },
      });
      reload();
    } catch { /* galat muncul lewat reload */ }
    finally { setBusy(null); }
  }

  const daftar = filter === "baru" ? rows.filter((b: any) => b.status === "baru") : rows;

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header icon={Gavel} title="Banding Akun" sub="Pengajuan banding pengguna yang diblokir — terima atau tolak beserta catatannya"
        right={
          <div className="flex gap-2">
            <Btn tone={filter === "baru" ? "utama" : "ghost"} onClick={() => setFilter("baru")}>Menunggu ({rows.filter((b: any) => b.status === "baru").length})</Btn>
            <Btn tone={filter === "semua" ? "utama" : "ghost"} onClick={() => setFilter("semua")}>Semua</Btn>
          </div>
        } />
      {loading ? <Load /> : err ? <ErrBox msg={err} onRetry={reload} /> : daftar.length === 0 ? (
        <div className="xy-card rounded-[20px] p-10 text-center text-[#7C738F] font-medium">Tidak ada banding pada filter ini.</div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-3">
          {daftar.map((b: any) => (
            <div key={b.id} className="xy-card rounded-[16px] p-4 space-y-2">
              <div className="flex items-start justify-between gap-2">
                <div className="min-w-0">
                  <span className="font-semibold text-[#1E1B2E]">{b.nama || "(akun terhapus)"}</span>
                  <div className="text-[11px] text-[#7C738F] font-mono truncate">{b.email}</div>
                </div>
                <Chip tone={b.status === "baru" ? "warn" : b.status === "diterima" ? "ok" : "bad"}>{b.status}</Chip>
              </div>
              <div className="text-[11px] text-[#7C738F]">diajukan {jam(b.waktu)}</div>
              {b.pesan && <div className="text-[12px] text-[#4B445F] bg-[#F5F3FF] border border-[#E9E3F5] rounded-xl px-3 py-2">{b.pesan}</div>}
              {b.status === "baru" && (
                <div className="flex gap-2 pt-1">
                  <Btn tone="ok" className="!h-8" disabled={busy === b.id} onClick={() => tanggapi(b, true)}>Terima</Btn>
                  <Btn tone="bahaya" className="!h-8" disabled={busy === b.id} onClick={() => tanggapi(b, false)}>Tolak</Btn>
                </div>
              )}
              {b.tanggapan && (
                <div className="text-[11.5px] text-[#7C738F] border-t border-[#F0EDFB] pt-2">
                  <span className="font-semibold">Tanggapan admin:</span> {b.tanggapan} · {jam(b.waktu_tanggapan)}
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
