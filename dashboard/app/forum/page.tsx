"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { MessagesSquare, Pin, Reply, ShieldAlert, ThumbsUp, Trash2 } from "lucide-react";
import { Btn, Chip, ErrBox, Header, jam, Load, MsgOk } from "@/components/ui/kit";

export default function ForumPage() {
  const [rows, setRows] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");
  const [ok, setOk] = useState("");
  const [bukaId, setBukaId] = useState<string | null>(null);
  const [balasan, setBalasan] = useState("");
  const [proses, setProses] = useState<string | null>(null);
  const [bukaForm, setBukaForm] = useState(false);
  const [judul, setJudul] = useState("");
  const [isiBaru, setIsiBaru] = useState("");

  async function muat() {
    setLoading(true); setErr("");
    try { setRows(await adminFetch("/api/admin/forum")); }
    catch (e: any) { setErr(e.message); }
    finally { setLoading(false); }
  }
  useEffect(() => { muat(); }, []);

  async function kirimBalas(id: string) {
    if (!balasan.trim()) return;
    setProses("b_" + id);
    try {
      await adminFetch(`/api/admin/forum/${id}/balas`, { method: "POST", body: { isi: balasan.trim() } });
      setBalasan(""); setBukaId(null); setOk("Balasan terkirim");
      await muat();
    } catch (e: any) { setErr(e.message); }
    finally { setProses(null); }
  }

  async function hapus(id: string) {
    if (!confirm("Hapus posting forum ini? (termasuk balasan)")) return;
    setProses("h_" + id);
    try {
      await adminFetch("/api/admin/forum/" + id, { method: "DELETE" });
      setOk("Posting dihapus");
      await muat();
    } catch (e: any) { setErr(e.message); }
    finally { setProses(null); }
  }

  async function semat(id: string, v: boolean) {
    setProses("s_" + id);
    try {
      await adminFetch(`/api/admin/forum/${id}/sematkan`, { method: "PATCH", body: { disematkan: v } });
      setOk(v ? "Disematkan" : "Sematan dilepas");
      await muat();
    } catch (e: any) { setErr(e.message); }
    finally { setProses(null); }
  }

  async function buatPengumuman() {
    if (judul.trim().length < 5 || isiBaru.trim().length < 10) {
      setErr("Judul min 5 & isi min 10 karakter.");
      return;
    }
    setProses("baru"); setErr(""); setOk("");
    try {
      await adminFetch("/api/admin/forum", {
        method: "POST",
        body: { judul: judul.trim(), isi: isiBaru.trim(), kategori: "Pengumuman", sematkan: true },
      });
      setJudul(""); setIsiBaru(""); setBukaForm(false);
      setOk("Pengumuman dipublikasikan");
      await muat();
    } catch (e: any) { setErr(e.message); }
    finally { setProses(null); }
  }

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header icon={MessagesSquare} title="Forum" sub="Moderasi diskusi komunitas — 200 terakhir"
        right={
          <div className="flex gap-2 items-center">
            <Btn tone="ghost" onClick={() => setBukaForm(!bukaForm)}>{bukaForm ? "Tutup form" : "Pengumuman baru"}</Btn>
            <span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{rows.length} posting</span>
          </div>
        } />

      {bukaForm && (
        <div className="xy-card rounded-[18px] p-4 space-y-3 max-w-xl">
          <input value={judul} onChange={(e) => setJudul(e.target.value)} placeholder="Judul pengumuman"
            className="xy-input w-full text-[13px]" />
          <textarea value={isiBaru} onChange={(e) => setIsiBaru(e.target.value)} rows={4} placeholder="Isi pengumuman…"
            className="w-full rounded-[14px] border border-[#E9E3F5] p-3 text-[13px] outline-none focus:border-[#7C3AED]" />
          <Btn disabled={proses === "baru"} onClick={buatPengumuman}>Kirim pengumuman</Btn>
        </div>
      )}

      {ok && <MsgOk msg={ok} />}
      {err && <ErrBox msg={err} />}
      {loading ? <Load /> : rows.length === 0 ? (
        <div className="xy-card rounded-[20px] p-10 text-center text-[#7C738F] font-medium">Belum ada posting forum.</div>
      ) : (
        <div className="space-y-3">
          {rows.map((p) => (
            <div key={p.id} className="xy-card rounded-[20px] p-5">
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0">
                  <div className="flex items-center gap-2 flex-wrap">
                    <h3 className="font-semibold text-[#1E1B2E] tracking-tight text-[15px]">{p.judul}</h3>
                    {p.disematkan ? <Chip tone="info"><Pin size={9} className="inline mr-0.5" /> semat</Chip> : null}
                    {p.sensitif ? <Chip tone="bad"><ShieldAlert size={9} className="inline mr-0.5" /> sensitif</Chip> : null}
                  </div>
                  <div className="text-[11px] text-[#7C738F] font-medium mt-0.5">
                    {p.nama || p.user_id} • <Chip tone="netral">{p.kategori || "Umum"}</Chip> • {jam(p.dibuat)}
                  </div>
                </div>
                <div className="flex gap-1 shrink-0">
                  <button type="button" onClick={() => semat(p.id, !p.disematkan)} disabled={proses === "s_" + p.id}
                    title={p.disematkan ? "Lepas sematan" : "Sematkan"}
                    className="p-2 rounded-lg bg-white border border-[#E9E3F5] hover:border-[#7C3AED] disabled:opacity-50">
                    <Pin size={13} className={p.disematkan ? "text-[#7C3AED]" : "text-[#9A8CBF]"} />
                  </button>
                  <button type="button" onClick={() => hapus(p.id)} disabled={proses === "h_" + p.id}
                    className="p-2 rounded-lg bg-white border border-[#E9E3F5] hover:border-rose-300 disabled:opacity-50">
                    <Trash2 size={13} className="text-rose-500" />
                  </button>
                </div>
              </div>
              <p className="mt-2 text-[13px] text-[#1E1B2E]/85 leading-relaxed whitespace-pre-line line-clamp-3">{p.isi}</p>
              <div className="mt-3 flex items-center gap-2 text-[11px] text-[#7C738F] font-semibold">
                <span className="inline-flex items-center gap-1 px-2 py-1 rounded-full bg-[#F5F3FF] border border-[#E9E3F5]">
                  <ThumbsUp size={11} className="text-[#7C3AED]" /> {p.suka || 0}
                </span>
                <span className="inline-flex items-center gap-1 px-2 py-1 rounded-full bg-[#F5F3FF] border border-[#E9E3F5]">
                  <MessagesSquare size={11} className="text-[#7C3AED]" /> {p.balasan || 0} balasan
                </span>
                <button type="button" onClick={() => setBukaId(bukaId === p.id ? null : p.id)}
                  className="inline-flex items-center gap-1 px-3 py-1 rounded-full xy-btn text-white font-semibold ml-auto">
                  <Reply size={11} /> Balas
                </button>
              </div>
              {bukaId === p.id && (
                <div className="mt-3 flex gap-2">
                  <textarea value={balasan} onChange={(e) => setBalasan(e.target.value)} rows={2}
                    placeholder="Balas sebagai Kirana - XyCloudStore…"
                    className="flex-1 px-3.5 py-2.5 rounded-xl bg-white border border-[#E9E3F5] text-[13px] focus:border-[#7C3AED] outline-none" />
                  <button type="button" onClick={() => kirimBalas(p.id)} disabled={proses === "b_" + p.id}
                    className="px-4 py-2 rounded-full xy-btn text-white font-semibold text-[13px] h-fit disabled:opacity-50">
                    {proses === "b_" + p.id ? "…" : "Kirim"}
                  </button>
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
