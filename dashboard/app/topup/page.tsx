"use client";
import { useEffect, useMemo, useState } from "react";
import { adminFetch } from "@/lib/api";
import { Check, CreditCard, ExternalLink, X, Zap } from "lucide-react";
import {
  Btn, Chip, ErrBox, Header, jam, Load, MsgOk, rupiah, runBatch, SelectBar,
  toneStatus, useAdminList, useSelection,
} from "@/components/ui/kit";
import { konfirm } from "@/components/ui/dialog";

export default function TopupPage() {
  const { rows, loading, err, setErr, reload } = useAdminList("/api/admin/topup");
  const [ok, setOk] = useState("");
  const [busy, setBusy] = useState(false);
  const [catatan, setCatatan] = useState("");
  const [filter, setFilter] = useState("pending");
  const [info, setInfo] = useState<any>(null);

  // status penyedia pembayaran (QRIS/DANA otomatis aktif atau masih manual?)
  useEffect(() => {
    adminFetch("/api/admin/bayar/info").then(setInfo).catch(() => setInfo(null));
  }, []);

  const list = useMemo(() => {
    if (filter === "semua") return rows;
    if (filter === "pending") return rows.filter((r) => ["menunggu", "diperiksa"].includes(String(r.status)));
    return rows.filter((r) => String(r.status) === filter);
  }, [rows, filter]);

  const ids = list.map((r) => r.id).filter(Boolean);
  const sel = useSelection(ids);

  const n = (s: string) => rows.filter((r) => r.status === s).length;

  async function aksi(id: string, status: string) {
    await adminFetch("/api/admin/topup/" + id, {
      method: "PATCH",
      body: { status, catatan: catatan || undefined },
    });
  }

  async function satu(id: string, status: string) {
    if (status === "ditolak" && !await konfirm({ pesan: "Tolak top up ini?" })) return;
    if (status === "disetujui" && !await konfirm({ pesan: "Setujui & tambahkan saldo?" })) return;
    setBusy(true); setErr(""); setOk("");
    try {
      await aksi(id, status);
      setCatatan("");
      setOk(status === "disetujui" ? "Saldo ditambahkan" : "Ditolak");
      await reload();
    } catch (e: any) { setErr(e.message); }
    finally { setBusy(false); }
  }

  async function verifikasi(id: string) {
    setBusy(true); setErr(""); setOk("");
    try {
      const r: any = await adminFetch("/api/admin/topup/" + id + "/verifikasi", { method: "POST" });
      setOk(r?.pesan || "Selesai diperiksa ke penyedia.");
      await reload();
    } catch (e: any) { setErr(e.message); }
    finally { setBusy(false); }
  }

  async function massal(status: string) {
    if (!sel.count) return;
    if (!await konfirm({ pesan: `${status === "disetujui" ? "Setujui" : "Tolak"} ${sel.count} permintaan?` })) return;
    setBusy(true); setErr(""); setOk("");
    try {
      const msg = await runBatch(sel.list, (id) => aksi(id, status), status === "disetujui" ? "disetujui" : "ditolak");
      setOk(msg); sel.clear(); await reload();
    } catch (e: any) { setErr(e.message); }
    finally { setBusy(false); }
  }

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header icon={CreditCard} title="TopUp" sub="Permintaan top up saldo + bukti transfer"
        right={
          <div className="flex gap-2 flex-wrap">
            <span className="text-xs px-3 py-1.5 rounded-full bg-amber-500/15 border border-amber-500/30 text-amber-700 font-semibold">{n("menunggu") + n("diperiksa")} pending</span>
            <span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{rows.length} total</span>
          </div>
        } />

      {info && (info.otomatis ? (
        <div className="text-[12px] px-3.5 py-2.5 rounded-2xl bg-emerald-500/10 border border-emerald-500/25 text-emerald-700 font-semibold flex items-center gap-2">
          <Zap size={14} className="shrink-0" /> Pembayaran otomatis aktif via {String(info.penyedia).toUpperCase()} — QRIS/DANA/e-wallet terdeteksi sendiri (webhook + pengecekan berkala + tombol ⚡ Verifikasi).
        </div>
      ) : (
        <div className="text-[12px] px-3.5 py-2.5 rounded-2xl bg-amber-500/10 border border-amber-500/25 text-amber-700 font-semibold flex items-center gap-2">
          <Zap size={14} className="shrink-0" /> Mode manual — deteksi bayar otomatis belum aktif. Setel secret Worker TRIPAY_API_KEY + TRIPAY_PRIVATE_KEY + TRIPAY_MERCHANT_CODE (atau MIDTRANS_SERVER_KEY) lalu deploy ulang; QRIS/DANA akan terdeteksi otomatis.
        </div>
      ))}

      <div className="flex flex-wrap gap-1.5">
        {["pending", "menunggu", "diperiksa", "disetujui", "ditolak", "semua"].map((f) => (
          <button key={f} type="button" onClick={() => setFilter(f)}
            className={`text-[11px] px-3 py-1.5 rounded-full border font-semibold ${filter === f ? "bg-[#7C3AED] text-white border-[#7C3AED]" : "bg-white border-[#E9E3F5] text-[#6B5A8A]"}`}>
            {f}
          </button>
        ))}
      </div>

      <input value={catatan} onChange={(e) => setCatatan(e.target.value)} placeholder="Catatan opsional (alasan tolak / catatan setuju)"
        className="xy-input w-full max-w-xl text-[12.5px]" />

      <SelectBar count={sel.count} onClear={sel.clear}>
        <Btn tone="ok" disabled={busy} onClick={() => massal("disetujui")}><Check size={13} /> Setujui massal</Btn>
        <Btn tone="bahaya" disabled={busy} onClick={() => massal("ditolak")}><X size={13} /> Tolak massal</Btn>
      </SelectBar>

      {ok && <MsgOk msg={ok} />}
      {err && <ErrBox msg={err} />}
      {loading ? <Load /> : (
        <div className="xy-card rounded-[20px] overflow-x-auto">
          <table className="w-full text-left text-[12.5px] min-w-[800px]">
            <thead>
              <tr className="border-b border-[#E9E3F5] bg-[#F5F3FF]">
                <th className="px-3 py-2.5 w-10"><input type="checkbox" checked={sel.allSelected} onChange={sel.toggleAll} /></th>
                {["ID / User", "Nominal", "Total", "Bukti", "Status", "Waktu", "Aksi"].map((h) => (
                  <th key={h} className="px-4 py-2.5 text-[10.5px] uppercase tracking-wider text-[#7C738F] font-semibold">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {list.length === 0 && (
                <tr><td colSpan={8} className="px-4 py-10 text-center text-[#7C738F]">Tidak ada data pada filter ini.</td></tr>
              )}
              {list.map((r) => (
                <tr key={r.id} className="border-b border-[#F0EDFB] last:border-0 hover:bg-[#FBFAFF]">
                  <td className="px-3 py-3"><input type="checkbox" checked={sel.selected.has(r.id)} onChange={() => sel.toggle(r.id)} /></td>
                  <td className="px-4 py-3">
                    <div className="font-mono text-[11px] text-[#7C738F]">{r.id}</div>
                    <div className="font-semibold">{r.nama || "—"}</div>
                    <div className="text-[10.5px] text-[#7C738F]">{r.email || r.phone || ""}</div>
                  </td>
                  <td className="px-4 py-3 font-semibold">{rupiah(r.nominal)}</td>
                  <td className="px-4 py-3">
                    <div className="font-semibold">{rupiah(r.total || Number(r.nominal || 0) + Number(r.kode_unik || 0))}</div>
                    <div className="text-[10.5px] text-[#7C738F]">{r.metode || "—"}</div>
                  </td>
                  <td className="px-4 py-3">
                    {r.bukti ? (
                      <a href={r.bukti} target="_blank" rel="noreferrer" className="inline-flex items-center gap-1 text-[#7C3AED] font-semibold text-[12px]">
                        <ExternalLink size={12} /> Bukti
                      </a>
                    ) : "—"}
                  </td>
                  <td className="px-4 py-3"><Chip tone={toneStatus(r.status)}>{r.status}</Chip></td>
                  <td className="px-4 py-3 text-[11px] font-mono text-[#7C738F]">{jam(r.dibuat || r.created_at)}</td>
                  <td className="px-4 py-3">
                    {["menunggu", "diperiksa"].includes(String(r.status)) ? (
                      <div className="flex gap-1">
                        <Btn tone="ghost" className="!h-8 !px-2.5" disabled={busy} title="Cek otomatis ke penyedia pembayaran (QRIS/DANA sudah benar-benar dibayar?)" onClick={() => verifikasi(r.id)}><Zap size={12} /></Btn>
                        <Btn tone="ok" className="!h-8 !px-2.5" disabled={busy} onClick={() => satu(r.id, "disetujui")}><Check size={12} /></Btn>
                        <Btn tone="bahaya" className="!h-8 !px-2.5" disabled={busy} onClick={() => satu(r.id, "ditolak")}><X size={12} /></Btn>
                      </div>
                    ) : <span className="text-[11px] text-[#9A8CBF]">—</span>}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
