"use client";
import { useState } from "react";
import { adminFetch } from "@/lib/api";
import { Flag } from "lucide-react";
import { Btn, Chip, ErrBox, Header, Load, SearchBox, jam, toneStatus, useAdminList } from "@/components/ui/kit";
import { konfirm, toast } from "@/components/ui/dialog";

export default function LaporanPage() {
  const { rows, loading, err, reload } = useAdminList("/api/admin/laporan");
  const [busy, setBusy] = useState<string | null>(null);
  const [cari, setCari] = useState("");
  const [status, setStatus] = useState("semua");

  async function selesai(id: string) {
    setBusy(id);
    try {
      await adminFetch(`/api/admin/laporan/${id}`, { method: "PATCH", body: { status: "selesai" } });
      toast("Laporan ditandai selesai.");
      reload();
    } catch (e: any) { toast(e.message || "Gagal.", "err"); }
    finally { setBusy(null); }
  }

  async function hapusKonten(l: any) {
    const jenis = String(l.jenis || l.tipe || "");
    const ref = l.ref_id || l.target_id;
    const yakin = await konfirm({
      judul: "Hapus konten terlapor?",
      pesan: jenis === "pengguna"
        ? `Laporan ini tentang PENGGUNA (id: ${ref}). Tandai selesai lalu tindak lewat menu Pengguna (peringatan/blokir).`
        : `Konten ${jenis} (id: ${ref}) akan dihapus permanen dan laporan ditandai selesai.`,
      okLabel: "Hapus & selesaikan", bahaya: true,
    });
    if (!yakin) return;
    setBusy(l.id);
    try {
      if (jenis === "balasan") await adminFetch(`/api/admin/forum/balasan/${ref}`, { method: "DELETE" });
      else if (jenis === "forum" || jenis === "posting") await adminFetch(`/api/admin/forum/${ref}`, { method: "DELETE" });
      else if (jenis === "ulasan") await adminFetch(`/api/admin/ulasan/${ref}`, { method: "DELETE" });
      else if (l.konten_path) await adminFetch(`/api/admin/konten/${l.konten_path}`, { method: "DELETE" });
      await adminFetch(`/api/admin/laporan/${l.id}`, { method: "PATCH", body: { status: "selesai" } });
      toast("Konten dihapus & laporan selesai.");
      reload();
    } catch (e: any) { toast(e.message || "Gagal menghapus konten.", "err"); }
    finally { setBusy(null); }
  }

  const q = cari.trim().toLowerCase();
  const daftar = rows.filter((l: any) =>
    (status === "semua" || (l.status || "baru") === status) &&
    (!q || `${l.jenis} ${l.alasan || ""} ${l.pelapor || ""} ${l.ref_id || ""}`.toLowerCase().includes(q)));

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header icon={Flag} title="Laporan Pengguna & Konten" sub="Semua laporan dari aplikasi: konten forum, ulasan, hingga laporan antar-pengguna"
        right={
          <div className="flex items-center gap-2">
            <SearchBox value={cari} onChange={setCari} placeholder="Cari alasan / pelapor…" />
            <select value={status} onChange={(e) => setStatus(e.target.value)}
              className="xy-select-trigger !w-auto !min-h-9 text-[12.5px]">
              <option value="semua">Semua status</option>
              <option value="baru">Baru</option>
              <option value="selesai">Selesai</option>
            </select>
          </div>
        } />
      {loading ? <Load /> : err ? <ErrBox msg={err} onRetry={reload} /> : daftar.length === 0 ? (
        <div className="xy-card rounded-[20px] p-10 text-center text-[#7C738F] font-medium">Tidak ada laporan pada filter ini. Komunitas aman 🎉</div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-3">
          {daftar.map((l: any) => (
            <div key={l.id} className="xy-card rounded-[16px] p-4 space-y-2">
              <div className="flex items-start justify-between gap-2">
                <div className="min-w-0">
                  <span className="font-semibold text-[#1E1B2E]">{l.judul || l.jenis || l.id}</span>
                  {l.jenis === "pengguna" && <Chip tone="info">antar-pengguna</Chip>}
                </div>
                <Chip tone={toneStatus(l.status)}>{l.status || "baru"}</Chip>
              </div>
              <div className="text-[11px] text-[#7C738F]">
                {l.pelapor || l.nama_pelapor || "anon"} · {l.jenis} · {jam(l.dibuat || l.created_at)}
              </div>
              {l.alasan && <div className="text-[12px] text-[#4B445F] bg-[#F5F3FF] border border-[#E9E3F5] rounded-xl px-3 py-2">{l.alasan}</div>}
              <div className="text-[10.5px] text-[#7C738F] font-mono break-all">ref: {l.ref_id || l.target_id || "—"}</div>
              {(l.status || "baru") !== "selesai" && (
                <div className="flex gap-2 pt-1">
                  <Btn tone="ok" className="!h-8" disabled={busy === l.id} onClick={() => selesai(l.id)}>Tandai selesai</Btn>
                  {l.jenis !== "pengguna" && (
                    <Btn tone="bahaya" className="!h-8" disabled={busy === l.id} onClick={() => hapusKonten(l)}>Hapus konten</Btn>
                  )}
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
