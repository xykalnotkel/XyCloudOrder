"use client";
import { useState } from "react";
import { adminFetch } from "@/lib/api";
import { Copy, Cpu, Plus, Trash2 } from "lucide-react";
import {
  Btn, Chip, EmptyBox, ErrBox, Field, Header, Input, jam, Load, MsgOk,
  useAdminList,
} from "@/components/ui/kit";

export default function UnitPage() {
  const { rows, loading, err, setErr, reload } = useAdminList("/api/admin/agen");
  // fallback alias unit
  const [viaUnit, setViaUnit] = useState(false);
  const [ok, setOk] = useState("");
  const [busy, setBusy] = useState(false);
  const [form, setForm] = useState({ nama: "", plan_id: "", host: "" });
  const [baru, setBaru] = useState<{ id: string; kode: string } | null>(null);

  async function muatAman() {
    setErr("");
    try {
      await reload();
    } catch {
      /* useAdminList handles */
    }
    // if empty try /unit alias
    if (!viaUnit) {
      try {
        const d = await adminFetch("/api/admin/unit");
        const list = Array.isArray(d) ? d : d?.units || d?.data || [];
        if (list.length && rows.length === 0) {
          // force path switch by reloading agen is enough usually
        }
      } catch { /* ignore */ }
      setViaUnit(true);
    }
  }

  async function buat() {
    if (!form.nama.trim()) { setErr("Nama unit wajib."); return; }
    setBusy(true); setErr(""); setOk(""); setBaru(null);
    try {
      const d = await adminFetch("/api/admin/agen", {
        method: "POST",
        body: {
          nama: form.nama.trim(),
          plan_id: form.plan_id.trim() || null,
          host: form.host.trim() || null,
        },
      });
      setBaru({ id: d.id, kode: d.kode });
      setOk("Unit terdaftar — salin kode agen ke PC");
      setForm({ nama: "", plan_id: "", host: "" });
      await reload();
    } catch (e: any) {
      // coba alias
      try {
        const d = await adminFetch("/api/admin/unit", {
          method: "POST",
          body: { nama: form.nama.trim(), plan_id: form.plan_id.trim() || null, host: form.host.trim() || null },
        });
        setBaru({ id: d.id, kode: d.kode || d.kode_agen });
        setOk("Unit terdaftar");
        await reload();
      } catch (e2: any) { setErr(e2.message || e.message); }
    } finally { setBusy(false); }
  }

  async function hapus(id: string, nama: string) {
    if (!confirm(`Hapus unit "${nama}"? Agen di PC tidak bisa terhubung lagi.`)) return;
    setBusy(true); setErr(""); setOk("");
    try {
      await adminFetch(`/api/admin/agen/${id}`, { method: "DELETE" });
      setOk("Unit dihapus");
      if (baru?.id === id) setBaru(null);
      await reload();
    } catch (e: any) { setErr(e.message); }
    finally { setBusy(false); }
  }

  function salin(teks: string) {
    navigator.clipboard?.writeText(teks).then(() => setOk("Kode disalin")).catch(() => setOk(teks));
  }

  const hidup = (u: any) => {
    if (!u.terakhir && !u.last_seen) return false;
    const t = new Date(u.terakhir || u.last_seen).getTime();
    return Date.now() - t < 90_000;
  };

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header
        icon={Cpu}
        title="Unit PC"
        sub="Daftarkan unit → salin kode → tempel di Agent v1.3 (auto Sunshine, tanpa login web UI)"
        right={
          <div className="flex gap-2">
            <Btn tone="ghost" onClick={() => muatAman()}>Muat ulang</Btn>
            <span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium self-center">{rows.length} unit</span>
          </div>
        }
      />

      {ok && <MsgOk msg={ok} />}
      {err && <ErrBox msg={err} />}

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div className="xy-card rounded-[18px] p-5 space-y-3">
          <h3 className="font-semibold text-[#1E1B2E] flex items-center gap-2"><Plus size={16} className="text-[#7C3AED]" /> Daftarkan unit</h3>
          <Field label="Nama unit">
            <Input value={form.nama} onChange={(e) => setForm({ ...form, nama: e.target.value })} placeholder="Cloud RTX 4090 — Jakarta" />
          </Field>
          <Field label="Paket dilayani (opsional)">
            <Input value={form.plan_id} onChange={(e) => setForm({ ...form, plan_id: e.target.value })} placeholder="pc-gaming" />
          </Field>
          <Field label="Host / IP publik (opsional)">
            <Input value={form.host} onChange={(e) => setForm({ ...form, host: e.target.value })} placeholder="103.x.x.x" />
          </Field>
          <Btn className="w-full" disabled={busy} onClick={buat}>Simpan & buat kode</Btn>
          {baru && (
            <div className="rounded-xl border border-emerald-200 bg-emerald-50 p-3 space-y-2">
              <div className="text-[11px] font-semibold text-emerald-800 uppercase">Kode agen</div>
              <code className="block text-[12px] font-mono break-all text-[#1E1B2E]">{baru.kode}</code>
              <Btn tone="ghost" className="w-full" onClick={() => salin(baru.kode)}>
                <Copy size={13} /> Salin kode
              </Btn>
              <p className="text-[11px] text-emerald-800/80 leading-relaxed">
                Di PC: buka <b>XyCloudStore-Agent</b> → tempel kode → <b>Pasang &amp; kunci otomatis</b> → Jalankan Agen.
                Sunshine di-set sendiri (tidak perlu buka web UI / login manual).
              </p>
            </div>
          )}
        </div>

        <div className="lg:col-span-2 space-y-3">
          {loading ? <Load /> : rows.length === 0 ? (
            <EmptyBox msg="Belum ada unit." sub="Daftarkan unit lalu pasang agen di PC sewa." />
          ) : rows.map((u) => (
            <div key={u.id} className="xy-card rounded-[16px] p-4 flex flex-wrap items-start gap-3 justify-between">
              <div className="min-w-0">
                <div className="flex items-center gap-2 flex-wrap">
                  <span className="font-semibold text-[#1E1B2E] text-[14px]">{u.nama}</span>
                  <Chip tone={hidup(u) ? "ok" : "netral"}>{hidup(u) ? "online" : (u.status || "offline")}</Chip>
                </div>
                <div className="mt-1 text-[11px] text-[#7C738F] font-mono space-y-0.5">
                  <div>id: {u.id}</div>
                  {u.kode && <div className="flex items-center gap-2">kode: {u.kode}
                    <button type="button" className="text-[#7C3AED] font-semibold" onClick={() => salin(u.kode)}>salin</button>
                  </div>}
                  {u.host && <div>host: {u.host}</div>}
                  {u.plan_id && <div>plan: {u.plan_id}</div>}
                  <div>terakhir: {jam(u.terakhir || u.last_seen || u.dibuat)}</div>
                </div>
              </div>
              <Btn tone="bahaya" className="!h-8" disabled={busy} onClick={() => hapus(u.id, u.nama || u.id)}>
                <Trash2 size={13} /> Hapus
              </Btn>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
