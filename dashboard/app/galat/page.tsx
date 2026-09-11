"use client";
import { useState } from "react";
import { adminFetch } from "@/lib/api";
import { Bug, CheckCheck, Trash2 } from "lucide-react";
import {
  Btn, Chip, EmptyBox, ErrBox, Header, jam, Load, MsgOk, toneStatus, useAdminList,
} from "@/components/ui/kit";

export default function GalatPage() {
  const { rows, loading, err, setErr, reload } = useAdminList("/api/admin/galat");
  const [ok, setOk] = useState("");
  const [busy, setBusy] = useState(false);
  const [buka, setBuka] = useState<string | null>(null);

  async function tandai(id: string) {
    setBusy(true); setErr(""); setOk("");
    try {
      await adminFetch(`/api/admin/galat/${id}`, { method: "PATCH", body: { status: "selesai" } });
      setOk("Ditandai selesai");
      await reload();
    } catch (e: any) { setErr(e.message); }
    finally { setBusy(false); }
  }

  async function hapus(id: string) {
    if (!confirm("Hapus laporan galat ini?")) return;
    setBusy(true); setErr(""); setOk("");
    try {
      await adminFetch(`/api/admin/galat/${id}`, { method: "DELETE" });
      setOk("Dihapus");
      await reload();
    } catch (e: any) { setErr(e.message); }
    finally { setBusy(false); }
  }

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header
        icon={Bug}
        title="Galat App"
        sub="Crash / error report dari aplikasi"
        right={<span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{rows.length} laporan</span>}
      />

      {ok && <MsgOk msg={ok} />}
      {err && <ErrBox msg={err} />}
      {loading ? <Load /> : rows.length === 0 ? (
        <EmptyBox msg="Belum ada laporan galat." />
      ) : (
        <div className="space-y-3">
          {rows.map((g) => (
            <div key={g.id} className="xy-card rounded-[16px] p-4 space-y-2">
              <div className="flex flex-wrap items-start justify-between gap-2">
                <div>
                  <div className="flex items-center gap-2 flex-wrap">
                    <span className="font-bold text-[#1E1B2E]">{g.judul || g.pesan?.slice?.(0, 60) || g.id}</span>
                    <Chip tone={toneStatus(g.status)}>{g.status || "baru"}</Chip>
                  </div>
                  <div className="text-[11px] text-[#7C738F] mt-0.5">
                    {g.nama_pengguna || g.user_id || "anon"} · {g.platform || g.versi || ""} · {jam(g.dibuat || g.created_at)}
                  </div>
                </div>
                <div className="flex gap-1.5">
                  <Btn tone="ok" className="!h-8" disabled={busy} onClick={() => tandai(g.id)}>
                    <CheckCheck size={12} /> Selesai
                  </Btn>
                  <Btn tone="bahaya" className="!h-8" disabled={busy} onClick={() => hapus(g.id)}>
                    <Trash2 size={12} />
                  </Btn>
                  <Btn tone="ghost" className="!h-8" onClick={() => setBuka(buka === g.id ? null : g.id)}>
                    {buka === g.id ? "Tutup" : "Detail"}
                  </Btn>
                </div>
              </div>
              {buka === g.id && (
                <pre className="text-[11px] bg-[#F5F3FF] border border-[#E9E3F5] rounded-xl p-3 overflow-x-auto whitespace-pre-wrap font-mono text-[#4B445F]">
                  {g.stack || g.detail || g.pesan || JSON.stringify(g, null, 2)}
                </pre>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
