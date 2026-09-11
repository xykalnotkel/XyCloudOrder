"use client";
import { useMemo, useState } from "react";
import { adminFetch } from "@/lib/api";
import { CheckCircle2, Receipt, XCircle } from "lucide-react";
import {
  Btn, Chip, ErrBox, Header, jam, Load, MsgOk, rupiah, runBatch, SelectBar,
  toneStatus, useAdminList, useSelection,
} from "@/components/ui/kit";

export default function OrdersPage() {
  const { rows, loading, err, setErr, reload } = useAdminList("/api/admin/orders");
  const [filter, setFilter] = useState("semua");
  const [ok, setOk] = useState("");
  const [busy, setBusy] = useState(false);

  const list = useMemo(() => {
    if (filter === "semua") return rows;
    return rows.filter((o) => String(o.status || "").toLowerCase() === filter);
  }, [rows, filter]);

  const ids = list.map((o) => o.id).filter(Boolean);
  const sel = useSelection(ids);

  const counts = useMemo(() => {
    const m: Record<string, number> = {};
    for (const o of rows) {
      const s = String(o.status || "—");
      m[s] = (m[s] || 0) + 1;
    }
    return m;
  }, [rows]);

  async function setStatus(id: string, status: "selesai" | "batal") {
    await adminFetch(`/api/admin/orders/${id}`, { method: "PATCH", body: { status } });
  }

  async function aksiSatu(id: string, status: "selesai" | "batal") {
    const label = status === "selesai" ? "tandai selesai" : "batalkan";
    if (!confirm(`${label[0].toUpperCase() + label.slice(1)} pesanan ${id}?`)) return;
    setBusy(true); setErr(""); setOk("");
    try {
      await setStatus(id, status);
      setOk(`Pesanan ${status}`);
      await reload();
    } catch (e: any) { setErr(e.message); }
    finally { setBusy(false); }
  }

  async function massal(status: "selesai" | "batal") {
    if (!sel.count) return;
    if (!confirm(`${status === "selesai" ? "Selesaikan" : "Batalkan"} ${sel.count} pesanan terpilih?`)) return;
    setBusy(true); setErr(""); setOk("");
    try {
      const msg = await runBatch(sel.list, (id) => setStatus(id, status), status === "selesai" ? "diselesaikan" : "dibatalkan");
      setOk(msg);
      sel.clear();
      await reload();
    } catch (e: any) { setErr(e.message); }
    finally { setBusy(false); }
  }

  const filters = ["semua", ...Object.keys(counts)];

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header
        icon={Receipt}
        title="Pesanan"
        sub="Sewa PC & pembelian — aksi selesai/batal (status siap/aktif dari agen)"
        right={<span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{rows.length} pesanan</span>}
      />

      <div className="flex flex-wrap gap-1.5">
        {filters.map((f) => (
          <button
            key={f}
            type="button"
            onClick={() => setFilter(f)}
            className={`text-[11px] px-3 py-1.5 rounded-full border font-semibold ${
              filter === f
                ? "bg-[#7C3AED] text-white border-[#7C3AED]"
                : "bg-white text-[#6B5A8A] border-[#E9E3F5] hover:bg-[#F5F3FF]"
            }`}
          >
            {f}{f !== "semua" ? ` (${counts[f]})` : ` (${rows.length})`}
          </button>
        ))}
      </div>

      <SelectBar count={sel.count} onClear={sel.clear}>
        <Btn tone="ok" disabled={busy} onClick={() => massal("selesai")}>
          <CheckCircle2 size={13} /> Selesai massal
        </Btn>
        <Btn tone="bahaya" disabled={busy} onClick={() => massal("batal")}>
          <XCircle size={13} /> Batal massal
        </Btn>
      </SelectBar>

      {ok && <MsgOk msg={ok} />}
      {err && <ErrBox msg={err} />}
      {loading ? <Load /> : (
        <div className="xy-card rounded-[20px] overflow-x-auto">
          <table className="w-full text-left text-[12.5px] min-w-[760px]">
            <thead>
              <tr className="border-b border-[#E9E3F5] bg-[#F5F3FF]">
                <th className="px-3 py-2.5 w-10">
                  <input type="checkbox" checked={sel.allSelected} onChange={sel.toggleAll} />
                </th>
                {["ID", "Pengguna", "Paket / Produk", "Total", "Status", "Waktu", "Aksi"].map((h) => (
                  <th key={h} className="px-4 py-2.5 text-[10.5px] uppercase tracking-wider text-[#7C738F] font-semibold">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {list.length === 0 && (
                <tr><td colSpan={8} className="px-4 py-10 text-center text-[#7C738F] font-medium">Belum ada pesanan pada filter ini.</td></tr>
              )}
              {list.map((o) => (
                <tr key={o.id} className="border-b border-[#F0EDFB] last:border-0 hover:bg-[#FBFAFF]">
                  <td className="px-3 py-3">
                    <input type="checkbox" checked={sel.selected.has(o.id)} onChange={() => sel.toggle(o.id)} />
                  </td>
                  <td className="px-4 py-3 font-mono text-[11px] text-[#7C738F]">{String(o.id).slice(0, 14)}</td>
                  <td className="px-4 py-3">
                    <div className="font-semibold text-[#1E1B2E]">{o.user_nama || o.nama || "—"}</div>
                    <div className="text-[11px] text-[#7C738F]">{o.user_email || o.email || o.user_id}</div>
                  </td>
                  <td className="px-4 py-3 font-medium">
                    {o.plan_name || o.paket || o.produk_nama || o.plan_id || o.produk_id || "—"}
                    {o.durasi ? <div className="text-[10.5px] text-[#7C738F]">{o.durasi} menit</div> : null}
                  </td>
                  <td className="px-4 py-3 font-semibold">{rupiah(o.total ?? o.harga ?? o.nominal)}</td>
                  <td className="px-4 py-3"><Chip tone={toneStatus(o.status)}>{o.status}</Chip></td>
                  <td className="px-4 py-3 text-[11px] font-mono text-[#7C738F]">{jam(o.created_at || o.dibuat)}</td>
                  <td className="px-4 py-3">
                    <div className="flex gap-1 flex-wrap">
                      <Btn tone="ok" className="!h-8 !px-2.5" disabled={busy || o.status === "selesai"} onClick={() => aksiSatu(o.id, "selesai")}>
                        Selesai
                      </Btn>
                      <Btn tone="bahaya" className="!h-8 !px-2.5" disabled={busy || o.status === "batal"} onClick={() => aksiSatu(o.id, "batal")}>
                        Batal
                      </Btn>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      <p className="text-[11px] text-[#7C738F] font-medium">
        Catatan API: status <code className="px-1 rounded bg-[#F3F0FF]">siap/aktif</code> hanya dari agen.
        Admin hanya boleh <b>selesai</b> atau <b>batal</b>.
      </p>
    </div>
  );
}
