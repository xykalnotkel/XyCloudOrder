"use client";
import { useState } from "react";
import { adminFetch } from "@/lib/api";
import { Copy, Cpu, Pencil, Plus, Trash2 } from "lucide-react";
import {
  Btn, Chip, EmptyBox, ErrBox, Field, Header, Input, jam, Load, MsgOk,
  useAdminList,
} from "@/components/ui/kit";

export default function UnitPage() {
  const { rows, loading, err, setErr, reload } = useAdminList("/api/admin/agen");
  const [ok, setOk] = useState("");
  const [busy, setBusy] = useState(false);
  const [form, setForm] = useState({ nama: "", plan_id: "", host: "" });
  const [baru, setBaru] = useState<{ id: string; kode: string } | null>(null);
  const [editId, setEditId] = useState<string | null>(null);
  const [editHost, setEditHost] = useState("");
  const [editNama, setEditNama] = useState("");

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
      setErr(e.message);
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

  function mulaiEdit(u: any) {
    setEditId(u.id);
    setEditHost(u.host || "");
    setEditNama(u.nama || "");
    setErr(""); setOk("");
  }

  async function simpanEdit() {
    if (!editId) return;
    setBusy(true); setErr(""); setOk("");
    try {
      await adminFetch(`/api/admin/agen/${editId}`, {
        method: "PATCH",
        body: { nama: editNama.trim(), host: editHost.trim() },
      });
      setOk("Unit diperbarui — host stream disinkron ke sesi aktif");
      setEditId(null);
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

  const hostAneh = (h?: string) => {
    if (!h) return true;
    const v = String(h).trim();
    if (/^\d{1,3}(\.\d{1,3}){3}$/.test(v)) return false;
    if (v.includes(".") && !/\s/.test(v)) return false;
    return true; // COMPUTERNAME dll
  };

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header
        icon={Cpu}
        title="Unit PC"
        sub="Daftarkan agen · set IP/host publik agar HP bisa Hubungkan PC"
        right={
          <div className="flex gap-2">
            <Btn tone="ghost" onClick={() => reload()}>Muat ulang</Btn>
            <span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium self-center">{rows.length} unit</span>
          </div>
        }
      />

      {ok && <MsgOk msg={ok} />}
      {err && <ErrBox msg={err} />}

      <div className="rounded-[16px] border border-amber-200 bg-amber-50 p-4 text-[12.5px] text-amber-900 leading-relaxed">
        <b>Penting streaming:</b> Host harus <b>IP publik</b> (contoh 103.x.x.x) atau domain yang resolve dari internet —
        <b> bukan</b> nama PC Windows (runnervm…, DESKTOP-…). Tanpa ini HP gagal DNS saat Hubungkan PC.
        Agen 1.3.3+ mengirim IP publik otomatis; tetap bisa override di sini.
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div className="xy-card rounded-[18px] p-5 space-y-3">
          <h3 className="font-semibold text-[#1E1B2E] flex items-center gap-2"><Plus size={16} className="text-[#7C3AED]" /> Daftarkan unit</h3>
          <Field label="Nama unit">
            <Input value={form.nama} onChange={(e) => setForm({ ...form, nama: e.target.value })} placeholder="Cloud RTX 4090 — Jakarta" />
          </Field>
          <Field label="Paket dilayani (opsional)">
            <Input value={form.plan_id} onChange={(e) => setForm({ ...form, plan_id: e.target.value })} placeholder="pc-gaming" />
          </Field>
          <Field label="Host / IP publik">
            <Input value={form.host} onChange={(e) => setForm({ ...form, host: e.target.value })} placeholder="103.x.x.x atau pc.domain.com" />
          </Field>
          <Btn className="w-full" disabled={busy} onClick={buat}>Simpan & buat kode</Btn>
          {baru && (
            <div className="rounded-xl border border-emerald-200 bg-emerald-50 p-3 space-y-2">
              <div className="text-[11px] font-semibold text-emerald-800 uppercase">Kode agen</div>
              <code className="block text-[12px] font-mono break-all text-[#1E1B2E]">{baru.kode}</code>
              <Btn tone="ghost" className="w-full" onClick={() => salin(baru.kode)}>
                <Copy size={13} /> Salin kode
              </Btn>
            </div>
          )}
        </div>

        <div className="lg:col-span-2 space-y-3">
          {loading ? <Load /> : rows.length === 0 ? (
            <EmptyBox msg="Belum ada unit." sub="Daftarkan unit lalu pasang agen di PC sewa." />
          ) : rows.map((u) => (
            <div key={u.id} className="xy-card rounded-[16px] p-4 space-y-3">
              <div className="flex flex-wrap items-start gap-3 justify-between">
                <div className="min-w-0">
                  <div className="flex items-center gap-2 flex-wrap">
                    <span className="font-semibold text-[#1E1B2E] text-[14px]">{u.nama}</span>
                    <Chip tone={hidup(u) ? "ok" : "netral"}>{hidup(u) ? "online" : (u.status || "offline")}</Chip>
                    {hostAneh(u.host) && <Chip tone="warn">host invalid</Chip>}
                  </div>
                  <div className="mt-1 text-[11px] text-[#7C738F] font-mono space-y-0.5">
                    <div>id: {u.id}</div>
                    {u.kode && <div className="flex items-center gap-2">kode: {u.kode}
                      <button type="button" className="text-[#7C3AED] font-semibold" onClick={() => salin(u.kode)}>salin</button>
                    </div>}
                    <div>host: {u.host || <span className="text-rose-600 font-sans font-semibold">belum diisi</span>}</div>
                    {u.plan_id && <div>plan: {u.plan_id}</div>}
                    <div>terakhir: {jam(u.terakhir || u.last_seen || u.dibuat)}</div>
                    {u.versi && <div>agen: {u.versi}</div>}
                  </div>
                </div>
                <div className="flex gap-1.5">
                  <Btn tone="ghost" className="!h-8" disabled={busy} onClick={() => mulaiEdit(u)}>
                    <Pencil size={13} /> Edit host
                  </Btn>
                  <Btn tone="bahaya" className="!h-8" disabled={busy} onClick={() => hapus(u.id, u.nama || u.id)}>
                    <Trash2 size={13} /> Hapus
                  </Btn>
                </div>
              </div>
              {editId === u.id && (
                <div className="rounded-xl border border-[#E9E3F5] bg-[#FBFAFF] p-3 space-y-2">
                  <Field label="Nama">
                    <Input value={editNama} onChange={(e) => setEditNama(e.target.value)} />
                  </Field>
                  <Field label="IP / host publik (wajib agar HP resolve)">
                    <Input value={editHost} onChange={(e) => setEditHost(e.target.value)} placeholder="103.xx.xx.xx" />
                  </Field>
                  <div className="flex gap-2">
                    <Btn disabled={busy} onClick={simpanEdit}>Simpan</Btn>
                    <Btn tone="ghost" disabled={busy} onClick={() => setEditId(null)}>Batal</Btn>
                  </div>
                </div>
              )}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
