"use client";
import { useState } from "react";
import { adminFetch } from "@/lib/api";
import { CheckCheck, Flag, Trash2 } from "lucide-react";
import {
  Btn, Chip, EmptyBox, ErrBox, Header, jam, Load, MsgOk, toneStatus, useAdminList,
} from "@/components/ui/kit";

export default function ModerasiPage() {
  const { rows, loading, err, setErr, reload } = useAdminList("/api/admin/laporan");
  const [ok, setOk] = useState("");
  const [busy, setBusy] = useState(false);

  async function selesai(id: string) {
    setBusy(true); setErr(""); setOk("");
    try {
      await adminFetch(`/api/admin/laporan/${id}`, { method: "PATCH", body: { status: "selesai" } });
      setOk("Laporan ditutup");
      await reload();
    } catch (e: any) { setErr(e.message); }
    finally { setBusy(false); }
  }

  async function hapusKonten(l: any) {
    if (!confirm("Hapus konten terkait laporan ini? Permanen.")) return;
    setBusy(true); setErr(""); setOk("");
    try {
      const jenis = String(l.jenis || l.tipe || "");
      const ref = l.ref_id || l.target_id;
      if (jenis.includes("balasan")) {
        await adminFetch(`/api/admin/forum/balasan/${ref}`, { method: "DELETE" });
      } else if (jenis.includes("forum") || jenis.includes("post")) {
        await adminFetch(`/api/admin/forum/${ref}`, { method: "DELETE" });
      } else if (l.konten_path) {
        await adminFetch(`/api/admin/konten/${l.konten_path}`, { method: "DELETE" });
      }
      await adminFetch(`/api/admin/laporan/${l.id}`, { method: "PATCH", body: { status: "selesai" } });
      setOk("Konten dihapus & laporan ditutup");
      await reload();
    } catch (e: any) { setErr(e.message); }
    finally { setBusy(false); }
  }

  const open = rows.filter((r) => !["selesai", "ditutup", "closed"].includes(String(r.status || "").toLowerCase()));

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header
        icon={Flag}
        title="Moderasi"
        sub="Laporan konten forum / spam / sensitif"
        right={
          <div className="flex gap-2">
            <span className="text-xs px-3 py-1.5 rounded-full bg-amber-500/15 border border-amber-500/30 text-amber-700 font-semibold">{open.length} terbuka</span>
            <span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{rows.length} total</span>
          </div>
        }
      />

      {ok && <MsgOk msg={ok} />}
      {err && <ErrBox msg={err} />}
      {loading ? <Load /> : rows.length === 0 ? (
        <EmptyBox msg="Belum ada laporan." sub="User melapor dari app → masuk ke sini." />
      ) : (
        <div className="space-y-3">
          {rows.map((l) => (
            <div key={l.id} className="xy-card rounded-[16px] p-4 flex flex-wrap gap-3 justify-between">
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-2 flex-wrap">
                  <span className="font-semibold text-[#1E1B2E]">{l.jenis || l.tipe || "laporan"}</span>
                  <Chip tone={toneStatus(l.status)}>{l.status || "baru"}</Chip>
                  {l.ref_id && <span className="font-mono text-[10.5px] text-[#7C738F]">ref {l.ref_id}</span>}
                </div>
                <p className="mt-1 text-[13px] text-[#4B445F] leading-relaxed">{l.alasan || l.pesan || "—"}</p>
                <div className="mt-1 text-[11px] text-[#7C738F]">
                  pelapor: {l.pelapor_nama || l.user_id || "—"} · {jam(l.dibuat || l.created_at)}
                </div>
              </div>
              <div className="flex gap-1.5 items-start">
                <Btn tone="ok" className="!h-8" disabled={busy || String(l.status) === "selesai"} onClick={() => selesai(l.id)}>
                  <CheckCheck size={13} /> Selesai
                </Btn>
                <Btn tone="bahaya" className="!h-8" disabled={busy} onClick={() => hapusKonten(l)}>
                  <Trash2 size={13} /> Hapus konten
                </Btn>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
