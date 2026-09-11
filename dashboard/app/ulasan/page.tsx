"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { MessageSquareReply, ShieldAlert, Star, Trash2 } from "lucide-react";
import { Chip, ErrBox, Header, jam, Load } from "@/components/ui/kit";

export default function UlasanPage() {
  const [rows, setRows] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");
  const [bukaId, setBukaId] = useState<string | null>(null);
  const [teks, setTeks] = useState("");
  const [proses, setProses] = useState<string | null>(null);

  async function muat() {
    setLoading(true); setErr("");
    try { setRows(await adminFetch("/api/admin/ulasan")); }
    catch (e: any) { setErr(e.message); }
    finally { setLoading(false); }
  }
  useEffect(() => { muat(); }, []);

  function mulaiBalas(r: any) {
    setBukaId(r.id); setTeks(r.balasan || "");
  }

  async function simpanBalas(id: string) {
    setProses("b_" + id);
    try {
      await adminFetch("/api/admin/ulasan/" + id, { method: "PATCH", body: { balasan: teks.trim() || null } });
      setBukaId(null); setTeks("");
      await muat();
    } catch (e: any) { setErr(e.message); }
    finally { setProses(null); }
  }

  async function hapus(id: string) {
    if (!confirm("Hapus ulasan ini?")) return;
    setProses("h_" + id);
    try {
      await adminFetch("/api/admin/ulasan/" + id, { method: "DELETE" });
      await muat();
    } catch (e: any) { setErr(e.message); }
    finally { setProses(null); }
  }

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header icon={Star} title="Ulasan" sub="Ulasan produk akun digital — balas & moderasi"
        right={<span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{rows.length} ulasan</span>} />
      {loading ? <Load /> : err ? <ErrBox msg={err} /> : rows.length === 0 ? (
        <div className="xy-card rounded-[20px] p-10 text-center text-[#7C738F] font-medium">Belum ada ulasan.</div>
      ) : (
        <div className="space-y-3">
          {rows.map((r) => (
            <div key={r.id} className="xy-card rounded-[20px] p-5">
              <div className="flex items-start justify-between gap-3">
                <div className="flex items-center gap-3 min-w-0">
                  <div className="w-9 h-9 shrink-0 rounded-xl bg-gradient-to-br from-[#7C3AED] to-[#5B21B6] grid place-items-center text-white font-semibold text-[13px]">
                    {(r.nama || "?")[0].toUpperCase()}
                  </div>
                  <div className="min-w-0">
                    <div className="text-[13px] font-semibold text-[#1E1B2E] truncate">{r.nama}</div>
                    <div className="text-[11px] text-[#7C738F]">untuk <b className="text-[#1E1B2E]">{r.produk || r.produk_id}</b> • {jam(r.waktu)}</div>
                  </div>
                </div>
                <div className="flex items-center gap-1.5 shrink-0">
                  {r.sensitif ? <Chip tone="bad"><ShieldAlert size={9} className="inline mr-0.5" /> sensitif</Chip> : null}
                  <span className="flex items-center gap-0.5 text-[12px] font-semibold text-amber-600">
                    {Array.from({ length: Math.min(5, Number(r.rating) || 0) }).map((_, i) => <Star key={i} size={11} className="fill-amber-400 text-amber-400" />)}
                    {Number(r.rating || 0)}
                  </span>
                </div>
              </div>

              <p className="mt-3 text-[13px] text-[#1E1B2E]/85 leading-relaxed whitespace-pre-line">{r.komentar}</p>

              {r.balasan && (
                <div className="mt-3 p-3 rounded-xl bg-[#F5F3FF] border border-[#E9E3F5]">
                  <div className="text-[10.5px] font-semibold text-[#7C3AED] uppercase tracking-wide">Balasan admin</div>
                  <p className="text-[12.5px] text-[#1E1B2E]/85 mt-1 whitespace-pre-line">{r.balasan}</p>
                </div>
              )}

              <div className="mt-3 flex items-center gap-2">
                <button onClick={() => mulaiBalas(r)} className="inline-flex items-center gap-1 text-[11px] px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-semibold text-[#6B5A8A] hover:text-[#7C3AED] hover:border-[#C4B5FD]">
                  <MessageSquareReply size={11} /> {r.balasan ? "Ubah Balasan" : "Balas"}
                </button>
                <button onClick={() => hapus(r.id)} disabled={proses === "h_" + r.id} className="inline-flex items-center gap-1 text-[11px] px-3 py-1.5 rounded-full bg-rose-500/10 border border-rose-500/25 font-semibold text-rose-600 disabled:opacity-50">
                  <Trash2 size={11} /> Hapus
                </button>
              </div>

              {bukaId === r.id && (
                <div className="mt-3 flex gap-2">
                  <textarea value={teks} onChange={(e) => setTeks(e.target.value)} rows={2} placeholder="Balasan admin…"
                    className="flex-1 px-3.5 py-2.5 rounded-xl bg-white border border-[#E9E3F5] text-[13px] focus:border-[#7C3AED] outline-none" />
                  <button onClick={() => simpanBalas(r.id)} disabled={proses === "b_" + r.id} className="px-4 py-2 rounded-full xy-btn text-white font-semibold text-[13px] h-fit disabled:opacity-50">
                    {proses === "b_" + r.id ? "…" : "Simpan"}
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
