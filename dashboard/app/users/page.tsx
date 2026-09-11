"use client";
import { useEffect, useMemo, useState } from "react";
import { adminFetch } from "@/lib/api";
import {
  Ban, CheckCircle2, Search, ShieldAlert, Trash2, UserCog, Users, Wallet,
} from "lucide-react";
import {
  asList, Btn, Chip, EmptyBox, ErrBox, Field, Header, Input, jam, Load, MsgOk,
  Panel, rupiah, runBatch, SelectBar, TextArea, useSelection,
} from "@/components/ui/kit";

type User = any;

export default function UsersPage() {
  const [rows, setRows] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");
  const [ok, setOk] = useState("");
  const [q, setQ] = useState("");
  const [cari, setCari] = useState("");
  const [aktif, setAktif] = useState<User | null>(null);
  const [busy, setBusy] = useState(false);

  // panel form state
  const [saldoDelta, setSaldoDelta] = useState("");
  const [saldoCatatan, setSaldoCatatan] = useState("Penyesuaian saldo admin");
  const [tier, setTier] = useState("");
  const [badge, setBadge] = useState("");
  const [alasanBlokir, setAlasanBlokir] = useState("");
  const [peringatan, setPeringatan] = useState("Mohon jaga bahasa dan hormati sesama pengguna di komunitas.");

  async function muat(query = cari) {
    setLoading(true); setErr("");
    try {
      const path = "/api/admin/users" + (query ? `?q=${encodeURIComponent(query)}` : "");
      const d = await adminFetch(path);
      setRows(asList(d, ["users", "data"]));
    } catch (e: any) {
      setErr(e.message);
    } finally {
      setLoading(false);
    }
  }
  useEffect(() => { muat(); }, [cari]);

  const filtered = useMemo(() => {
    if (!q || q === cari) return rows;
    const s = q.toLowerCase();
    return rows.filter((u) =>
      [u.email, u.nama, u.phone, u.id].some((x) => String(x || "").toLowerCase().includes(s)),
    );
  }, [rows, q, cari]);

  const ids = filtered.map((u) => u.id).filter(Boolean);
  const sel = useSelection(ids);

  function buka(u: User) {
    setAktif(u);
    setTier(u.tier || "basic");
    setBadge(u.badge || "");
    setAlasanBlokir(u.alasan_blokir || "");
    setSaldoDelta("");
    setOk("");
  }

  async function aksi(fn: () => Promise<void>, sukses: string) {
    setBusy(true); setErr(""); setOk("");
    try {
      await fn();
      setOk(sukses);
      await muat();
      if (aktif) {
        const d = await adminFetch("/api/admin/users" + (cari ? `?q=${encodeURIComponent(cari)}` : ""));
        const list = asList(d, ["users", "data"]);
        const baru = list.find((x) => x.id === aktif.id);
        if (baru) setAktif(baru);
      }
    } catch (e: any) {
      setErr(e.message);
    } finally {
      setBusy(false);
    }
  }

  async function simpanKelola(patch: Record<string, any>, msg: string) {
    if (!aktif) return;
    await aksi(
      () => adminFetch(`/api/admin/users/${aktif.id}/kelola`, { method: "PATCH", body: patch }),
      msg,
    );
  }

  async function ubahSaldo() {
    if (!aktif) return;
    const nominal = Number(saldoDelta);
    if (!Number.isFinite(nominal) || nominal === 0) {
      setErr("Nominal saldo harus angka selain 0 (boleh negatif untuk potong).");
      return;
    }
    if (!confirm(`Sesuaikan saldo ${aktif.email} sebesar ${rupiah(nominal)}?`)) return;
    await aksi(
      () => adminFetch("/api/admin/users/saldo", {
        method: "POST",
        body: { user_id: aktif.id, nominal, catatan: saldoCatatan || "Penyesuaian saldo admin" },
      }),
      "Saldo diperbarui",
    );
    setSaldoDelta("");
  }

  async function kirimPeringatan() {
    if (!aktif || !peringatan.trim()) return;
    await aksi(
      () => adminFetch(`/api/admin/users/${aktif.id}/peringatan`, {
        method: "POST", body: { pesan: peringatan.trim() },
      }),
      "Peringatan terkirim",
    );
  }

  async function keSampah() {
    if (!aktif || aktif.owner_protected) return;
    const kunci = prompt("Ketik HAPUS untuk memindahkan akun ke Sampah (soft-delete):");
    if (kunci !== "HAPUS") return;
    await aksi(
      () => adminFetch(`/api/admin/users/${aktif.id}/trash`, {
        method: "POST", body: { konfirmasi: "HAPUS" },
      }),
      "Akun dipindah ke Sampah",
    );
    setAktif(null);
  }

  async function massalBlokir(blokir: boolean) {
    const target = sel.list.filter((id) => {
      const u = rows.find((x) => x.id === id);
      return u && !u.owner_protected && Boolean(u.diblokir) !== blokir;
    });
    if (!target.length) { setErr("Tidak ada akun cocok (pemilik dilindungi / status sama)."); return; }
    if (!confirm(`${blokir ? "Blokir" : "Buka blokir"} ${target.length} akun?`)) return;
    setBusy(true); setErr("");
    try {
      const msg = await runBatch(target, (id) =>
        adminFetch(`/api/admin/users/${id}/kelola`, {
          method: "PATCH",
          body: blokir
            ? { diblokir: true, alasan: "Diblokir massal oleh admin" }
            : { diblokir: false },
        }), blokir ? "diblokir" : "dibuka");
      setOk(msg);
      sel.clear();
      await muat();
    } catch (e: any) { setErr(e.message); }
    finally { setBusy(false); }
  }

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header
        icon={Users}
        title="Pengguna"
        sub="Kelola akun, saldo, blokir, peringatan, dan sampah"
        right={
          <span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">
            {filtered.length} user
          </span>
        }
      />

      <div className="flex flex-wrap gap-2 items-center">
        <div className="relative max-w-[340px] flex-1">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-[#9A8CBF]" />
          <input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && setCari(q.trim())}
            placeholder="Cari email / nama / id…"
            className="w-full pl-9 pr-3 h-10 rounded-xl bg-white border border-[#E9E3F5] text-[13px] outline-none focus:border-[#7C3AED]"
          />
        </div>
        <Btn onClick={() => setCari(q.trim())}>Cari</Btn>
        <Btn tone="ghost" onClick={() => muat()} disabled={loading}>
          Muat ulang
        </Btn>
      </div>

      <SelectBar count={sel.count} onClear={sel.clear}>
        <Btn tone="bahaya" disabled={busy} onClick={() => massalBlokir(true)}>
          <Ban size={13} /> Blokir
        </Btn>
        <Btn tone="ok" disabled={busy} onClick={() => massalBlokir(false)}>
          <CheckCircle2 size={13} /> Buka blokir
        </Btn>
      </SelectBar>

      {ok && <MsgOk msg={ok} />}
      {err && <ErrBox msg={err} />}
      {loading ? <Load /> : filtered.length === 0 ? (
        <EmptyBox msg="Tidak ada pengguna." sub="Coba ubah kata kunci pencarian." />
      ) : (
        <div className="xy-card rounded-[20px] overflow-x-auto">
          <table className="w-full text-left text-[12.5px] min-w-[720px]">
            <thead>
              <tr className="border-b border-[#E9E3F5] bg-[#F5F3FF]">
                <th className="px-3 py-2.5 w-10">
                  <input type="checkbox" checked={sel.allSelected} onChange={sel.toggleAll} />
                </th>
                {["Pengguna", "Saldo", "Tier", "Status", "Daftar", ""].map((h) => (
                  <th key={h || "a"} className="px-4 py-2.5 text-[10.5px] uppercase tracking-wider text-[#7C738F] font-bold">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {filtered.map((u) => (
                <tr key={u.id} className="border-b border-[#F0EDFB] last:border-0 hover:bg-[#FBFAFF]">
                  <td className="px-3 py-3">
                    <input type="checkbox" checked={sel.selected.has(u.id)} onChange={() => sel.toggle(u.id)} disabled={!!u.owner_protected} />
                  </td>
                  <td className="px-4 py-3">
                    <div className="font-bold text-[#1E1B2E]">{u.nama || "—"}</div>
                    <div className="text-[11px] text-[#7C738F] truncate max-w-[220px]">{u.email}</div>
                    <div className="font-mono text-[10px] text-[#9A8CBF]">{u.id}</div>
                  </td>
                  <td className="px-4 py-3 font-bold">{rupiah(u.saldo)}</td>
                  <td className="px-4 py-3">
                    <Chip tone="info">{u.tier || "basic"}</Chip>
                    {u.badge ? <div className="mt-1"><Chip>{u.badge}</Chip></div> : null}
                  </td>
                  <td className="px-4 py-3">
                    {u.owner_protected ? <Chip tone="info">pemilik</Chip>
                      : u.diblokir ? <Chip tone="bad">diblokir</Chip>
                        : <Chip tone="ok">aktif</Chip>}
                    {Number(u.peringatan) > 0 && (
                      <div className="mt-1 text-[10px] text-amber-700 font-semibold">{u.peringatan} peringatan</div>
                    )}
                  </td>
                  <td className="px-4 py-3 text-[11px] text-[#7C738F] font-mono">{jam(u.created_at || u.dibuat)}</td>
                  <td className="px-4 py-3">
                    <Btn tone="ghost" className="!h-8 !px-2.5" onClick={() => buka(u)}>
                      <UserCog size={13} /> Kelola
                    </Btn>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <Panel open={!!aktif} title={aktif ? `Kelola · ${aktif.nama || aktif.email}` : ""} onClose={() => setAktif(null)}>
        {aktif && (
          <>
            <div className="grid grid-cols-2 gap-2 text-[12px]">
              <div className="xy-card rounded-xl p-3">
                <div className="text-[10px] uppercase text-[#7C738F] font-bold">Email</div>
                <div className="font-semibold break-all">{aktif.email}</div>
              </div>
              <div className="xy-card rounded-xl p-3">
                <div className="text-[10px] uppercase text-[#7C738F] font-bold">Saldo</div>
                <div className="font-black text-[#7C3AED]">{rupiah(aktif.saldo)}</div>
              </div>
              <div className="xy-card rounded-xl p-3">
                <div className="text-[10px] uppercase text-[#7C738F] font-bold">Status</div>
                <div className="font-semibold">
                  {aktif.owner_protected ? "Pemilik dilindungi" : aktif.diblokir ? "Diblokir" : "Aktif"}
                </div>
              </div>
              <div className="xy-card rounded-xl p-3">
                <div className="text-[10px] uppercase text-[#7C738F] font-bold">Peringatan</div>
                <div className="font-semibold">{aktif.peringatan || 0}</div>
              </div>
            </div>

            <div className="space-y-2">
              <div className="text-[11px] font-bold uppercase tracking-wide text-[#7C738F]">Saldo</div>
              <Field label="Nominal (+ tambah / − potong)">
                <Input type="number" value={saldoDelta} onChange={(e) => setSaldoDelta(e.target.value)} placeholder="50000 atau -10000" />
              </Field>
              <Field label="Catatan transaksi">
                <Input value={saldoCatatan} onChange={(e) => setSaldoCatatan(e.target.value)} />
              </Field>
              <Btn disabled={busy} onClick={ubahSaldo}><Wallet size={13} /> Sesuaikan saldo</Btn>
            </div>

            <div className="space-y-2">
              <div className="text-[11px] font-bold uppercase tracking-wide text-[#7C738F]">Lencana & tier</div>
              <div className="grid grid-cols-2 gap-2">
                <Field label="Tier">
                  <Input value={tier} onChange={(e) => setTier(e.target.value)} placeholder="basic / pro / elite" />
                </Field>
                <Field label="Badge">
                  <Input value={badge} onChange={(e) => setBadge(e.target.value)} placeholder="VIP / Creator" />
                </Field>
              </div>
              <Btn tone="ghost" disabled={busy} onClick={() => simpanKelola({ tier, badge }, "Tier/badge disimpan")}>
                Simpan tier & badge
              </Btn>
            </div>

            <div className="space-y-2">
              <div className="text-[11px] font-bold uppercase tracking-wide text-[#7C738F]">Keamanan akun</div>
              {aktif.diblokir ? (
                <Btn tone="ok" disabled={busy || aktif.owner_protected} onClick={() => simpanKelola({ diblokir: false }, "Blokir dibuka")}>
                  <CheckCircle2 size={13} /> Buka blokir
                </Btn>
              ) : (
                <div className="space-y-2">
                  <Field label="Alasan blokir">
                    <Input value={alasanBlokir} onChange={(e) => setAlasanBlokir(e.target.value)} placeholder="Melanggar ketentuan" />
                  </Field>
                  <Btn
                    tone="bahaya"
                    disabled={busy || aktif.owner_protected}
                    onClick={() => simpanKelola({ diblokir: true, alasan: alasanBlokir || "Diblokir admin", badge, tier }, "Akun diblokir")}
                  >
                    <Ban size={13} /> Blokir akun
                  </Btn>
                </div>
              )}
            </div>

            <div className="space-y-2">
              <div className="text-[11px] font-bold uppercase tracking-wide text-[#7C738F]">Peringatan</div>
              <TextArea rows={3} value={peringatan} onChange={(e) => setPeringatan(e.target.value)} />
              <Btn tone="ghost" disabled={busy} onClick={kirimPeringatan}>
                <ShieldAlert size={13} /> Kirim peringatan
              </Btn>
            </div>

            {!aktif.owner_protected && (
              <div className="rounded-2xl border border-rose-200 bg-rose-50 p-4 space-y-2">
                <div className="text-[12px] font-bold text-rose-800">Zona berbahaya</div>
                <p className="text-[11.5px] text-rose-700/90 leading-relaxed">
                  Pindah ke Sampah menonaktifkan login. Hapus permanen hanya dari menu Sampah setelah soft-delete.
                </p>
                <Btn tone="bahaya" disabled={busy} onClick={keSampah}>
                  <Trash2 size={13} /> Pindah ke Sampah
                </Btn>
              </div>
            )}
          </>
        )}
      </Panel>
    </div>
  );
}
