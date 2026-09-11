"use client";
import { useState } from "react";
import { adminFetch } from "@/lib/api";
import { RotateCcw, Trash2 } from "lucide-react";
import {
  Btn, EmptyBox, ErrBox, Header, jam, Load, MsgOk, runBatch, SelectBar,
  useAdminList, useSelection,
} from "@/components/ui/kit";

export default function SampahPage() {
  const { rows, loading, err, setErr, reload } = useAdminList("/api/admin/users?trash=1");
  const [ok, setOk] = useState("");
  const [busy, setBusy] = useState(false);
  const sel = useSelection(rows.map((u) => u.id).filter(Boolean));

  async function restore(id: string) {
    await adminFetch(`/api/admin/users/${id}/restore`, { method: "POST", body: {} });
  }

  async function permanent(id: string, email?: string) {
    await adminFetch(`/api/admin/users/${id}/permanent`, {
      method: "DELETE",
      body: { email: email || undefined, konfirmasi: "HAPUS PERMANEN" },
    });
  }

  async function aksiRestore(id: string) {
    if (!confirm("Pulihkan akun ini? Login ulang diperlukan.")) return;
    setBusy(true); setErr(""); setOk("");
    try {
      await restore(id);
      setOk("Akun dipulihkan");
      await reload();
    } catch (e: any) { setErr(e.message); }
    finally { setBusy(false); }
  }

  async function aksiPermanent(u: any) {
    if (u.owner_protected) { setErr("Akun pemilik dilindungi."); return; }
    const email = prompt(`Hapus permanen. Ketik email akun (${u.email}) untuk konfirmasi:`, "");
    if (email === null) return;
    if (String(email).trim().toLowerCase() !== String(u.email || "").toLowerCase()) {
      setErr("Email tidak cocok — dibatalkan.");
      return;
    }
    if (!confirm(`Hapus permanen ${u.email}? Tidak bisa dibatalkan.`)) return;
    setBusy(true); setErr(""); setOk("");
    try {
      await permanent(u.id, u.email);
      setOk("Penghapusan permanen selesai");
      await reload();
    } catch (e: any) { setErr(e.message); }
    finally { setBusy(false); }
  }

  async function massalRestore() {
    if (!sel.count) return;
    if (!confirm(`Pulihkan ${sel.count} akun?`)) return;
    setBusy(true); setErr(""); setOk("");
    try {
      const msg = await runBatch(sel.list, restore, "dipulihkan");
      setOk(msg); sel.clear(); await reload();
    } catch (e: any) { setErr(e.message); }
    finally { setBusy(false); }
  }

  async function massalPermanent() {
    const target = sel.list.filter((id) => !rows.find((u) => u.id === id)?.owner_protected);
    if (!target.length) { setErr("Tidak ada akun non-pemilik di pilihan."); return; }
    const kunci = prompt(`Ketik HAPUS untuk menghapus permanen ${target.length} akun:`);
    if (kunci !== "HAPUS") return;
    if (!confirm("Yakin? Seluruh data akun terpilih hilang permanen.")) return;
    setBusy(true); setErr(""); setOk("");
    try {
      const msg = await runBatch(target, async (id) => {
        const u = rows.find((x) => x.id === id);
        await permanent(id, u?.email);
      }, "dihapus permanen");
      setOk(msg); sel.clear(); await reload();
    } catch (e: any) { setErr(e.message); }
    finally { setBusy(false); }
  }

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header
        icon={Trash2}
        title="Sampah Pengguna"
        sub="Soft-delete — pulihkan atau hapus permanen (hanya pemilik)"
        right={<span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{rows.length} akun</span>}
      />

      <SelectBar count={sel.count} onClear={sel.clear}>
        <Btn tone="ok" disabled={busy} onClick={massalRestore}><RotateCcw size={13} /> Pulihkan</Btn>
        <Btn tone="bahaya" disabled={busy} onClick={massalPermanent}><Trash2 size={13} /> Hapus permanen</Btn>
      </SelectBar>

      {ok && <MsgOk msg={ok} />}
      {err && <ErrBox msg={err} />}
      {loading ? <Load /> : rows.length === 0 ? (
        <EmptyBox msg="Sampah kosong." sub="Akun soft-delete dari menu Pengguna muncul di sini." />
      ) : (
        <div className="xy-card rounded-[20px] overflow-x-auto">
          <table className="w-full text-left text-[12.5px] min-w-[640px]">
            <thead>
              <tr className="border-b border-[#E9E3F5] bg-[#F5F3FF]">
                <th className="px-3 py-2.5 w-10">
                  <input type="checkbox" checked={sel.allSelected} onChange={sel.toggleAll} />
                </th>
                {["Akun", "Saldo", "Dihapus", "Aksi"].map((h) => (
                  <th key={h} className="px-4 py-2.5 text-[10.5px] uppercase tracking-wider text-[#7C738F] font-semibold">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.map((u) => (
                <tr key={u.id} className="border-b border-[#F0EDFB] last:border-0 hover:bg-[#FBFAFF]">
                  <td className="px-3 py-3">
                    <input type="checkbox" checked={sel.selected.has(u.id)} onChange={() => sel.toggle(u.id)} disabled={!!u.owner_protected} />
                  </td>
                  <td className="px-4 py-3">
                    <div className="font-semibold text-[#1E1B2E]">{u.nama || "—"}</div>
                    <div className="text-[11px] text-[#7C738F]">{u.email}</div>
                    <div className="font-mono text-[10px] text-[#9A8CBF]">{u.id}</div>
                  </td>
                  <td className="px-4 py-3 font-medium">Rp {Number(u.saldo || 0).toLocaleString("id-ID")}</td>
                  <td className="px-4 py-3 text-[11px] font-mono text-[#7C738F]">{jam(u.deleted_at)}</td>
                  <td className="px-4 py-3">
                    <div className="flex gap-1.5 flex-wrap">
                      <Btn tone="ok" className="!h-8" disabled={busy} onClick={() => aksiRestore(u.id)}>
                        <RotateCcw size={12} /> Pulihkan
                      </Btn>
                      <Btn tone="bahaya" className="!h-8" disabled={busy || u.owner_protected} onClick={() => aksiPermanent(u)}>
                        <Trash2 size={12} /> Permanen
                      </Btn>
                    </div>
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
