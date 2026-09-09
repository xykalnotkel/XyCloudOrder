"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { AlertTriangle, Fingerprint, Globe, ListChecks, Smartphone } from "lucide-react";
import { Chip, ErrBox, Header, jam, Load, Stat } from "@/components/ui/kit";

const ICON: Record<string, any> = {
  signup: Smartphone, login: Fingerprint, otp: Fingerprint,
  blocked: AlertTriangle, rate: AlertTriangle, policy: Globe, device: Smartphone,
};

export default function KeamananPage() {
  const [rows, setRows] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");

  useEffect(() => {
    adminFetch("/api/admin/security/events")
      .then((d) => setRows(Array.isArray(d) ? d : []))
      .catch((e) => setErr(e.message))
      .finally(() => setLoading(false));
  }, []);

  const totalCount = rows.reduce((a, r) => a + Number(r.count || 0), 0);
  const perRute = Array.from(new Set(rows.map((r) => r.route).filter(Boolean))).map((rt) => ({ rt, n: rows.filter((r) => r.route === rt).reduce((a, r) => a + Number(r.count || 0), 0) })).sort((a, b) => b.n - a.n);
  const perJenis = Array.from(new Set(rows.map((r) => r.kind))).map((k) => ({
    kind: k,
    n: rows.filter((r) => r.kind === k).reduce((a, r) => a + Number(r.count || 0), 0),
  }));

  return (
    <div className="space-y-4 font-[Plus_Jakarta_Sans]">
      <Header icon={ListChecks} title="Log Keamanan" sub="Peristiwa keamanan terbaru dari modul security (150 terakhir, 30 hari)"
        right={<span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{totalCount.toLocaleString("id-ID")} peristiwa</span>} />
      <div className="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-5 gap-3">
        <Stat label="Jenis tercatat" value={perJenis.length} sub="kind berbeda" />
        <Stat label="Event terbanyak" value={perJenis[0]?.kind || "—"} sub={perJenis[0] ? perJenis[0].n.toLocaleString("id-ID") + " kali" : "belum ada"} />
        <Stat label="Subjek aktif" value={new Set(rows.filter((r) => r.subject).map((r) => r.subject)).size} sub="user/device berbeda" />
        <Stat label="Rute terbanyak" value={perRute[0]?.rt || "—"} sub={perRute[0] ? perRute[0].n.toLocaleString("id-ID") + " kali" : "belum ada"} />
        <Stat label="Masa simpan" value="30 hari" sub="otomatis dipangkas" />
      </div>
      {perJenis.length > 0 && (
        <div className="flex flex-wrap gap-1.5">
          {perJenis.map((p) => (
            <span key={p.kind} className="text-[11px] px-2.5 py-1 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-bold text-[#6B5A8A]">{p.kind} <span className="text-[#7C3AED]">{p.n}</span></span>
          ))}
        </div>
      )}
      {loading ? <Load /> : err ? <ErrBox msg={err} /> : rows.length === 0 ? (
        <div className="xy-card rounded-[20px] p-10 text-center text-[#7C738F] font-medium">Belum ada peristiwa keamanan. Halaman ini menampilkan kejadian dari tabel security_events.</div>
      ) : (
        <div className="space-y-2">
          {rows.map((e) => {
            const Ico = ICON[e.kind] || ListChecks;
            const warn = e.kind === "blocked" || e.kind === "rate" || /blokir|tolak|gagal/i.test(e.note || "") || /blocked/i.test(e.kind);
            return (
              <div key={e.id} className="xy-card rounded-[14px] px-4 py-3 flex items-start gap-3">
                <div className={`w-8 h-8 shrink-0 rounded-lg grid place-items-center ${warn ? "bg-rose-500/10 text-rose-600" : "bg-[#F3F0FF] text-[#7C3AED]"}`}><Ico size={14} /></div>
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2 flex-wrap">
                    <span className="text-[12.5px] font-bold text-[#1E1B2E]">{e.kind}</span>
                    <Chip tone={warn ? "bad" : "info"}>{Number(e.count || 0)}x</Chip>
                    {e.subject && <span className="font-mono text-[10.5px] text-[#7C738F]">{e.subject}</span>}
                    {e.route && <span className="font-mono text-[10.5px] text-[#9A8CBF]">{e.route}</span>}
                  </div>
                  {e.note && <p className="text-[12px] text-[#6B5A8A]/85 mt-0.5 leading-relaxed">{e.note}</p>}
                  <div className="text-[10.5px] text-[#7C738F] mt-1 font-mono">{e.id} • pertama {jam(e.created_at)} • terakhir {jam(e.last_seen)}</div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
