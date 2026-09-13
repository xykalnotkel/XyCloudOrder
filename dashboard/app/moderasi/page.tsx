"use client";
import { useState } from "react";
import { adminFetch } from "@/lib/api";
import { CheckCheck, Flag, Gavel, Inbox, Trash2, XCircle } from "lucide-react";
import {
  Btn, Chip, EmptyBox, ErrBox, Header, jam, Load, MsgOk, toneStatus, useAdminList,
} from "@/components/ui/kit";
import { konfirm, mintaTeks } from "@/components/ui/dialog";

export default function ModerasiPage() {
  const [tab, setTab] = useState<"laporan" | "banding">("laporan");
  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header
        icon={Flag}
        title="Moderasi"
        sub="Laporan konten forum / spam / sensitif, serta banding pengguna yang dibekukan"
        right={
          <div className="flex rounded-full border border-[#E9E3F5] bg-white p-1">
            {([["laporan", "Laporan", Flag], ["banding", "Banding", Gavel]] as const).map(([k, label, Icon]) => (
              <button
                key={k}
                onClick={() => setTab(k)}
                className={`inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-full text-[12px] font-semibold transition ${
                  tab === k ? "bg-[#6D5AE0] text-white shadow-sm" : "text-[#6B5A8A] hover:bg-[#F5F3FF]"
                }`}
              >
                <Icon size={12} /> {label}
              </button>
            ))}
          </div>
        }
      />
      {tab === "laporan" ? <TabLaporan /> : <TabBanding />}
    </div>
  );
}

// ---------------------------------------------------------------------------
//  Tab laporan konten (perilaku lama)
// ---------------------------------------------------------------------------
function TabLaporan() {
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
    if (!await konfirm({ pesan: "Hapus konten terkait laporan ini? Permanen.", bahaya: true })) return;
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
    <div className="space-y-4">
      <div className="flex gap-2">
        <span className="text-xs px-3 py-1.5 rounded-full bg-amber-500/15 border border-amber-500/30 text-amber-700 font-semibold">{open.length} terbuka</span>
        <span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{rows.length} total</span>
      </div>
      {ok && <MsgOk msg={ok} />}
      {err && <ErrBox msg={err} />}
      {loading ? <Load /> : rows.length === 0 ? <EmptyBox msg="Belum ada laporan konten." /> : (
        <div className="space-y-3">
          {rows.map((l) => (
            <div key={l.id} className="xy-card rounded-[16px] p-4 space-y-2">
              <div className="flex flex-wrap items-start justify-between gap-2">
                <div>
                  <div className="flex items-center gap-2 flex-wrap">
                    <span className="font-semibold text-[#1E1B2E]">{l.judul || l.jenis || l.id}</span>
                    <Chip tone={toneStatus(l.status)}>{l.status || "baru"}</Chip>
                  </div>
                  <div className="text-[11px] text-[#7C738F] mt-0.5">
                    {l.pelapor || l.nama_pelapor || "anon"} · {l.jenis} · {jam(l.dibuat || l.created_at)}
                  </div>
                </div>
                <div className="flex gap-1.5">
                  <Btn tone="ok" className="!h-8" disabled={busy} onClick={() => selesai(l.id)}>
                    <CheckCheck size={12} /> Tutup
                  </Btn>
                  <Btn tone="bahaya" className="!h-8" disabled={busy} onClick={() => hapusKonten(l.id)}>
                    <Trash2 size={12} /> Hapus konten
                  </Btn>
                </div>
              </div>
              {l.alasan && <div className="text-[12px] text-[#4B445F] bg-[#F5F3FF] border border-[#E9E3F5] rounded-xl px-3 py-2">{l.alasan}</div>}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------
//  Tab banding pengguna yang dibekukan
// ---------------------------------------------------------------------------
function TabBanding() {
  const [status, setStatus] = useState("baru");
  const { rows, loading, err, setErr, reload } = useAdminList(
    `/api/admin/moderasi/banding${status ? `?status=${status}` : ""}`, [status]);
  const [busy, setBusy] = useState<string | null>(null);
  const [ok, setOk] = useState("");

  async function tanggapi(b: any, terima: boolean) {
    const t = await mintaTeks({
      judul: terima ? "Terima banding" : "Tolak banding",
      pesan: terima
        ? `Akun ${b.nama || b.email || b.user_id} akan AKTIF kembali. Tuliskan catatan untuk pengguna (opsional):`
        : `Tuliskan alasan penolakan untuk ${b.nama || b.email || b.user_id} (opsional):`,
      okLabel: terima ? "Terima & aktifkan" : "Tolak",
      bahaya: !terima,
      placeholder: "Catatan untuk pengguna…",
    });
    if (t === null) return;
    setBusy(b.id); setErr(""); setOk("");
    try {
      await adminFetch(`/api/admin/moderasi/banding/${b.id}`, {
        method: "POST",
        body: { status: terima ? "diterima" : "ditolak", tanggapan: t || "" },
      });
      setOk(terima ? "Banding diterima — akun aktif kembali." : "Banding ditolak.");
      await reload();
    } catch (e: any) { setErr(e.message); }
    finally { setBusy(null); }
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap gap-1.5">
        {[["baru", "Baru"], ["diterima", "Diterima"], ["ditolak", "Ditolak"], ["", "Semua"]].map(([v, label]) => (
          <button
            key={v || "semua"}
            onClick={() => setStatus(v)}
            className={`px-3 py-1.5 rounded-full text-[11.5px] font-semibold border transition ${
              status === v ? "bg-[#6D5AE0] text-white border-[#6D5AE0]" : "bg-white border-[#E9E3F5] text-[#6B5A8A] hover:border-[#C4B5FD]"
            }`}
          >
            {label}
          </button>
        ))}
      </div>
      {ok && <MsgOk msg={ok} />}
      {err && <ErrBox msg={err} />}
      {loading ? <Load /> : rows.length === 0 ? (
        <EmptyBox msg="Tidak ada banding pada saringan ini." sub="Banding masuk dari layar Akun Dibekukan di aplikasi." />
      ) : (
        <div className="space-y-3">
          {rows.map((b: any) => (
            <div key={b.id} className="xy-card rounded-[16px] p-4 space-y-2">
              <div className="flex flex-wrap items-start justify-between gap-2">
                <div className="min-w-0">
                  <div className="flex items-center gap-2 flex-wrap">
                    <span className="font-semibold text-[#1E1B2E]">{b.nama || "(akun terhapus)"}</span>
                    <span className="text-[11px] text-[#7C738F] font-mono">{b.email}</span>
                    <Chip tone={b.status === "baru" ? "warn" : b.status === "diterima" ? "ok" : "bad"}>{b.status}</Chip>
                  </div>
                  <div className="text-[11px] text-[#7C738F] mt-0.5">diajukan {jam(b.waktu)}</div>
                </div>
                {b.status === "baru" && (
                  <div className="flex gap-1.5">
                    <Btn tone="ok" className="!h-8" disabled={busy === b.id} onClick={() => tanggapi(b, true)}>
                      <CheckCheck size={12} /> Terima
                    </Btn>
                    <Btn tone="bahaya" className="!h-8" disabled={busy === b.id} onClick={() => tanggapi(b, false)}>
                      <XCircle size={12} /> Tolak
                    </Btn>
                  </div>
                )}
              </div>
              <div className="text-[12.5px] text-[#332D47] bg-[#F5F3FF] border border-[#E9E3F5] rounded-xl px-3 py-2 whitespace-pre-wrap leading-relaxed">
                {b.pesan}
              </div>
              {b.tanggapan && (
                <div className="text-[11.5px] text-[#4B445F] flex items-start gap-1.5">
                  <Inbox size={12} className="mt-0.5 shrink-0" />
                  <span>Tanggapan admin: {b.tanggapan} · {jam(b.waktu_tanggapan)}</span>
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
