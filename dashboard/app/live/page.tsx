"use client";
import { useEffect, useRef, useState } from "react";
import { adminFetch } from "@/lib/api";
import { Activity, Cpu, Gauge, Radio, Server, Wifi } from "lucide-react";

type Agen = any;

const HIDUP_MS = 90000; // sesuai Worker: terakhir < 90 detik = hidup

function hidup(terakhir?: string) {
  if (!terakhir) return false;
  return Date.now() - new Date(terakhir).getTime() < HIDUP_MS;
}

function Bar({ label, persen, warn }: { label: string; persen?: number | null; warn?: boolean }) {
  const p = Math.max(0, Math.min(100, Math.round(Number(persen ?? 0))));
  const warna = warn ? "bg-amber-400" : "bg-gradient-to-r from-[#7C3AED] to-[#A855F7]";
  return (
    <div className="flex items-center gap-2">
      <span className="w-14 text-[10px] text-[#7C738F] font-semibold uppercase tracking-wide">{label}</span>
      <div className="flex-1 h-1.5 rounded-full bg-[#F3F0FF] overflow-hidden">
        <div className={`h-full ${warna}`} style={{ width: `${p}%` }} />
      </div>
      <span className="w-9 text-right text-[11px] font-mono text-[#1E1B2E]">{p}%</span>
    </div>
  );
}

function specAman(raw: any) {
  if (!raw || typeof raw !== "object") return {};
  return raw;
}

export default function LivePage() {
  const [agen, setAgen] = useState<Agen[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");
  const [jam, setJam] = useState(new Date());
  const ref = useRef(false);

  useEffect(() => {
    const muat = async () => {
      try {
        // /api/admin/unit sudah menghitung 'hidup' dari terakhir; /api/admin/live memakai kolom status agen.
        const d = await adminFetch("/api/admin/unit");
        const arr = Array.isArray(d) ? d : Array.isArray(d?.units) ? d.units : Array.isArray(d?.data) ? d.data : [];
        setAgen(arr);
        setErr("");
      } catch (e: any) {
        setErr(e.message);
      } finally {
        setLoading(false);
      }
    };
    if (!ref.current) {
      ref.current = true;
      muat();
      const id = setInterval(muat, 8000);
      const t = setInterval(() => setJam(new Date()), 1000);
      return () => {
        clearInterval(id);
        clearInterval(t);
      };
    }
  }, []);

  const online = agen.filter((a) => hidup(a.terakhir)).length;
  const sesi = agen.filter((a) => a.sesi_aktif).length;

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <div className="flex items-center justify-between flex-wrap gap-2">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl xy-btn grid place-items-center"><Activity size={18} className="text-white" /></div>
          <div>
            <h1 className="text-xl font-semibold text-[#1E1B2E] tracking-tight">Live Monitor <span className="ml-2 text-[10px] px-2 py-0.5 rounded-full bg-[#F3F0FF] font-semibold">BARU</span></h1>
            <p className="text-sm text-[#7C738F] font-medium">Status agen PC realtime — CPU/RAM/GPU dari heartbeat agen, refresh tiap 8 detik</p>
          </div>
        </div>
        <span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-mono text-[#7C3AED] flex items-center gap-1.5">
          <span className={`w-2 h-2 rounded-full ${online > 0 ? "bg-emerald-400" : "bg-rose-400"} animate-pulse`} />
          {jam.toLocaleTimeString("id-ID")}
        </span>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
        {[
          { l: "Unit Terdaftar", v: agen.length, Icon: Server, t: "text-[#7C3AED]" },
          { l: "Online Sekarang", v: online, Icon: Wifi, t: "text-emerald-600" },
          { l: "Sesi Aktif", v: sesi, Icon: Radio, t: "text-amber-600" },
        ].map((c) => (
          <div key={c.l} className="xy-card rounded-[14px] p-4 flex items-center gap-3">
            <div className="w-9 h-9 rounded-xl bg-[#F3F0FF] border border-[#E9E3F5] grid place-items-center"><c.Icon size={16} className={c.t} /></div>
            <div>
              <div className="text-[11px] text-[#7C738F] font-medium tracking-wide uppercase">{c.l}</div>
              <div className="text-lg font-semibold text-[#1E1B2E] mt-0.5 tracking-tight">{c.v}</div>
            </div>
          </div>
        ))}
      </div>

      {loading ? (
        <div className="xy-card rounded-xl p-10 text-center text-[#7C738F] font-medium">Menghubungi Worker…</div>
      ) : err ? (
        <div className="xy-card rounded-xl p-4 text-red-600 font-medium">{err} — pastikan /api/admin/unit tersedia di Worker.</div>
      ) : agen.length === 0 ? (
        <div className="xy-card rounded-xl p-10 text-center">
          <div className="w-12 h-12 mx-auto rounded-xl bg-[#F3F0FF] grid place-items-center"><Gauge size={20} className="text-[#7C3AED]" /></div>
          <div className="mt-3 text-sm text-[#7C738F] font-semibold tracking-tight">Belum ada agen terdaftar</div>
          <div className="text-[11px] text-[#7C738F] mt-1 font-medium">Daftarkan unit lewat menu Unit PC & jalankan xy_agent.py di host.</div>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-3">
          {agen.map((a) => {
            const s = specAman(a.spec);
            const hidupFlag = hidup(a.terakhir);
            const ramGb = Number(s.ram_total_gb) || 0;
            return (
              <div key={a.id} className={`xy-card rounded-[14px] p-4 border ${hidupFlag ? "border-[#E9E3F5]" : "border-[#3A1A3A]"}`}>
                <div className="flex items-center justify-between gap-2">
                  <span className="font-semibold text-[#1E1B2E] text-[13px] tracking-tight flex items-center gap-2 truncate">
                    <Server size={14} className="text-[#7C3AED] shrink-0" /> {a.nama || a.kode || a.id}
                  </span>
                  <span className={`shrink-0 text-[10px] px-2 py-0.5 rounded-full font-semibold tracking-wide ${hidupFlag ? "bg-emerald-500/20 border border-emerald-500/30 text-emerald-600" : "bg-rose-500/15 border border-rose-500/30 text-rose-600"}`}>
                    {hidupFlag ? "ONLINE" : "OFFLINE"}
                  </span>
                </div>
                <div className="mt-1 text-[11px] text-[#7C738F] font-mono truncate">{a.host || a.plan_id || "—"}{a.versi ? ` • agen ${a.versi}` : ""}</div>

                {a.sesi_aktif && (
                  <div className="mt-2 inline-flex items-center gap-1.5 text-[10px] px-2 py-0.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-semibold text-amber-600">
                    <Radio size={10} /> Sesi aktif
                  </div>
                )}

                <div className="mt-3 space-y-2">
                  {s.gpu ? (
                    <>
                      <div className="text-[12px] text-[#1E1B2E]/90 font-semibold truncate flex items-center gap-1.5">
                        <Cpu size={12} className="text-[#7C3AED]" /> {s.gpu}{s.vram_mb ? ` • ${Math.round(Number(s.vram_mb) / 1024)}GB` : ""}
                      </div>
                      <Bar label="GPU" persen={s.gpu_persen} />
                    </>
                  ) : (
                    <div className="text-[12px] text-[#1E1B2E]/80 font-medium truncate">{s.cpu || "Spesifikasi belum dilaporkan agen"}</div>
                  )}
                  {s.ram_total_gb ? <Bar label="RAM" persen={s.ram_persen} warn={Number(s.ram_persen) > 85} /> : null}
                  {s.cpu_persen != null ? <Bar label="CPU" persen={s.cpu_persen} /> : null}
                </div>

                <div className="mt-3 pt-2 border-t border-[#E9E3F5] flex items-center justify-between text-[10px] text-[#7C738F] font-medium">
                  <span>{ramGb ? `RAM ${Math.round((ramGb * (Number(s.ram_persen) || 0)) / 100)}/${ramGb} GB` : ""}</span>
                  <span className="font-mono">{a.terakhir ? `${Math.max(0, Math.round((Date.now() - new Date(a.terakhir).getTime()) / 1000))}s lalu` : "belum pernah"}</span>
                </div>
              </div>
            );
          })}
        </div>
      )}
      <div className="xy-card rounded-xl p-3 text-[11px] text-[#7C738F] font-medium flex items-center gap-1.5">
        <Activity size={12} /> Sumber: GET /api/admin/unit (agen + spec heartbeat dari xy_agent.py). "Hidup" = heartbeat terakhir &lt; 90 detik. Icons Lucide, no emoji.
      </div>
    </div>
  );
}
