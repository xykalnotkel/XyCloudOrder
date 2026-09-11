"use client";
import { useState } from "react";
import { adminFetch } from "@/lib/api";
import { Ban, RefreshCcw, Smartphone } from "lucide-react";
import {
  Btn, Chip, EmptyBox, ErrBox, Header, jam, Load, MsgOk, Panel, useAdminList,
} from "@/components/ui/kit";

export default function PerangkatPage() {
  const { rows, loading, err, setErr, reload } = useAdminList("/api/admin/devices");
  const [ok, setOk] = useState("");
  const [busy, setBusy] = useState(false);
  const [detail, setDetail] = useState<any | null>(null);
  const [akun, setAkun] = useState<any[]>([]);

  async function buka(d: any) {
    setDetail(d); setAkun([]); setErr("");
    try {
      const r = await adminFetch(`/api/admin/devices/${d.id}`);
      setAkun(Array.isArray(r) ? r : []);
    } catch (e: any) { setErr(e.message); }
  }

  async function block(id: string, blocked: boolean) {
    if (!confirm(blocked ? "Blokir perangkat ini?" : "Buka blokir perangkat?")) return;
    setBusy(true); setErr(""); setOk("");
    try {
      await adminFetch(`/api/admin/devices/${id}/block`, {
        method: "POST",
        body: { blocked, reason: blocked ? "Ditinjau oleh pemilik" : "Dibuka admin" },
      });
      setOk(blocked ? "Perangkat diblokir" : "Blokir dibuka");
      await reload();
      if (detail?.id === id) setDetail({ ...detail, blocked: blocked ? 1 : 0 });
    } catch (e: any) { setErr(e.message); }
    finally { setBusy(false); }
  }

  async function reset(id: string) {
    if (!confirm("Reset jatah pendaftaran perangkat? Akun yang sudah ada tetap.")) return;
    setBusy(true); setErr(""); setOk("");
    try {
      await adminFetch(`/api/admin/devices/${id}/reset`, {
        method: "POST", body: { konfirmasi: "RESET" },
      });
      setOk("Jatah pendaftaran direset");
      await reload();
    } catch (e: any) { setErr(e.message); }
    finally { setBusy(false); }
  }

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header
        icon={Smartphone}
        title="Perangkat"
        sub="Fingerprint device, kuota daftar akun, blokir / reset"
        right={<span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{rows.length} device</span>}
      />

      {ok && <MsgOk msg={ok} />}
      {err && <ErrBox msg={err} />}
      {loading ? <Load /> : rows.length === 0 ? (
        <EmptyBox msg="Belum ada perangkat tercatat." sub="Muncul saat user login/daftar dari app." />
      ) : (
        <div className="xy-card rounded-[20px] overflow-x-auto">
          <table className="w-full text-left text-[12.5px] min-w-[720px]">
            <thead>
              <tr className="border-b border-[#E9E3F5] bg-[#F5F3FF]">
                {["Device", "Model", "Akun", "Daftar", "Terakhir", "Status", "Aksi"].map((h) => (
                  <th key={h} className="px-4 py-2.5 text-[10.5px] uppercase tracking-wider text-[#7C738F] font-bold">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.map((d) => (
                <tr key={d.id} className="border-b border-[#F0EDFB] last:border-0 hover:bg-[#FBFAFF]">
                  <td className="px-4 py-3">
                    <button type="button" className="font-mono text-[11px] text-[#7C3AED] font-bold" onClick={() => buka(d)}>
                      {String(d.id).slice(0, 12)}…
                    </button>
                    <div className="text-[10px] text-[#9A8CBF]">{d.kind || "—"}</div>
                  </td>
                  <td className="px-4 py-3 font-medium">{d.model || "—"}</td>
                  <td className="px-4 py-3 font-bold">{d.linked_accounts ?? "—"}</td>
                  <td className="px-4 py-3">{d.registrations ?? 0}</td>
                  <td className="px-4 py-3 text-[11px] font-mono text-[#7C738F]">{jam(d.last_seen)}</td>
                  <td className="px-4 py-3">
                    {d.blocked ? <Chip tone="bad">blocked</Chip> : <Chip tone="ok">ok</Chip>}
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex gap-1 flex-wrap">
                      {d.blocked ? (
                        <Btn tone="ok" className="!h-8" disabled={busy} onClick={() => block(d.id, false)}>Buka</Btn>
                      ) : (
                        <Btn tone="bahaya" className="!h-8" disabled={busy} onClick={() => block(d.id, true)}>
                          <Ban size={12} /> Blokir
                        </Btn>
                      )}
                      <Btn tone="ghost" className="!h-8" disabled={busy} onClick={() => reset(d.id)}>
                        <RefreshCcw size={12} /> Reset
                      </Btn>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <Panel open={!!detail} title="Detail perangkat" onClose={() => setDetail(null)} width="max-w-lg">
        {detail && (
          <>
            <div className="font-mono text-[11px] break-all text-[#7C738F]">{detail.id}</div>
            <div className="grid grid-cols-2 gap-2 text-[12px]">
              <div className="xy-card rounded-xl p-3"><div className="text-[10px] uppercase text-[#7C738F] font-bold">Kind</div>{detail.kind || "—"}</div>
              <div className="xy-card rounded-xl p-3"><div className="text-[10px] uppercase text-[#7C738F] font-bold">Model</div>{detail.model || "—"}</div>
              <div className="xy-card rounded-xl p-3"><div className="text-[10px] uppercase text-[#7C738F] font-bold">Registrations</div>{detail.registrations ?? 0}</div>
              <div className="xy-card rounded-xl p-3"><div className="text-[10px] uppercase text-[#7C738F] font-bold">Reason</div>{detail.reason || "—"}</div>
            </div>
            <div className="text-[12px] font-bold text-[#1E1B2E]">Akun tertaut ({akun.length})</div>
            <div className="space-y-2">
              {akun.length === 0 && <div className="text-[12px] text-[#7C738F]">Tidak ada / gagal dimuat.</div>}
              {akun.map((u) => (
                <div key={u.id} className="flex justify-between gap-2 py-2 border-b border-[#E9E3F5] text-[12px]">
                  <div>
                    <div className="font-bold">{u.nama}</div>
                    <div className="text-[#7C738F]">{u.email}</div>
                  </div>
                  <div className="text-right text-[11px] text-[#7C738F]">
                    {u.deleted_at ? <Chip tone="bad">sampah</Chip> : <Chip tone="ok">aktif</Chip>}
                    <div className="mt-1 font-mono">{jam(u.last_seen)}</div>
                  </div>
                </div>
              ))}
            </div>
          </>
        )}
      </Panel>
    </div>
  );
}
