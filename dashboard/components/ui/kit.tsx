"use client";
import { type LucideIcon, Package, RefreshCw } from "lucide-react";

/** Konversi & format kecil untuk konsisten di seluruh halaman admin. */

export function rupiah(n: number | string | null | undefined) {
  const v = Number(n || 0);
  return "Rp " + v.toLocaleString("id-ID");
}

/** Ubah nilai tanggal (ISO, atau format D1 "YYYY-MM-DD HH:MM:SS" UTC) ke objek Date yang valid. */
function parseWaktu(s: string | number | Date | null | undefined): Date | null {
  if (!s) return null;
  if (s instanceof Date) return isNaN(s.getTime()) ? null : s;
  const str = String(s).trim();
  if (/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}/.test(str)) return new Date(str.replace(" ", "T") + "Z");
  const d = new Date(str);
  return isNaN(d.getTime()) ? null : d;
}

export function tgl(s: string | number | Date | null | undefined) {
  const d = parseWaktu(s);
  if (!d) return String(s ?? "—");
  return d.toLocaleDateString("id-ID", { day: "2-digit", month: "short", year: "numeric" });
}

export function jam(s: string | number | Date | null | undefined) {
  const d = parseWaktu(s);
  if (!d) return String(s ?? "—");
  return d.toLocaleString("id-ID", {
    day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit",
  });
}

export function Header({ icon: Icon, title, sub, right }: {
  icon: LucideIcon; title: string; sub?: string; right?: React.ReactNode;
}) {
  return (
    <div className="flex items-start justify-between flex-wrap gap-2">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-[#7C3AED] to-[#5B21B6] grid place-items-center shadow-[0_8px_18px_rgba(124,58,237,.25)]">
          <Icon size={18} className="text-white" />
        </div>
        <div>
          <h1 className="text-xl font-black text-[#1E1B2E] tracking-tight">{title}</h1>
          {sub && <p className="text-sm text-[#7C738F] font-medium">{sub}</p>}
        </div>
      </div>
      {right}
    </div>
  );
}

export function Load() {
  return (
    <div className="xy-card rounded-xl p-12 text-center text-[#7C738F] font-medium">
      <RefreshCw size={20} className="mx-auto animate-spin text-[#7C3AED]" />
      <div className="mt-2">Memuat…</div>
    </div>
  );
}

export function ErrBox({ msg }: { msg: string }) {
  return (
    <div className="xy-card rounded-xl p-4 text-red-600 font-medium text-[13px] leading-relaxed">
      {msg}
    </div>
  );
}

export function EmptyBox({ msg, sub }: { msg: string; sub?: string }) {
  return (
    <div className="xy-card rounded-[20px] p-10 text-center">
      <div className="w-12 h-12 mx-auto rounded-xl bg-[#F3F0FF] border border-[#E9E3F5] grid place-items-center">
        <Package size={20} className="text-[#7C3AED]" />
      </div>
      <div className="mt-3 text-sm text-[#6B5A8A] font-bold tracking-tight">{msg}</div>
      {sub && <div className="text-[12px] text-[#7C738F] mt-1 font-medium">{sub}</div>}
    </div>
  );
}

export function Chip({ children, tone = "netral" }: { children: React.ReactNode; tone?: "ok" | "warn" | "bad" | "info" | "netral" }) {
  const map: Record<string, string> = {
    ok: "bg-emerald-500/15 border-emerald-500/30 text-emerald-700",
    warn: "bg-amber-500/15 border-amber-500/30 text-amber-700",
    bad: "bg-rose-500/15 border-rose-500/30 text-rose-700",
    info: "bg-violet-500/15 border-violet-500/25 text-violet-700",
    netral: "bg-[#F3F0FF] border-[#E9E3F5] text-[#6B5A8A]",
  };
  return (
    <span className={`text-[10px] px-2 py-0.5 rounded-full border font-bold tracking-wide whitespace-nowrap ${map[tone]}`}>
      {children}
    </span>
  );
}

const TONE_TEKS: Record<string, string> = {
  ok: "text-emerald-600",
  warn: "text-amber-600",
  bad: "text-rose-600",
  info: "text-[#7C3AED]",
};

export function Stat({ label, value, sub, tone }: { label: string; value: React.ReactNode; sub?: string; tone?: string }) {
  return (
    <div className="xy-card rounded-[14px] p-4">
      <div className="text-[11px] text-[#7C738F] font-semibold tracking-wide uppercase">{label}</div>
      <div className={`text-xl font-black tracking-tight mt-1 ${TONE_TEKS[tone || ""] || "text-[#1E1B2E]"}`}>{value}</div>
      {sub && <div className="text-[11px] text-[#7C738F] mt-0.5 font-medium">{sub}</div>}
    </div>
  );
}

export type Kolom = {
  k: string;
  label: string;
  render?: (r: any) => React.ReactNode;
  className?: string;
};

export function Tabel({ kolom, rows, kosong }: { kolom: Kolom[]; rows: any[]; kosong?: string }) {
  if (rows.length === 0) {
    return <EmptyBox msg={kosong || "Belum ada data."} sub="Data akan muncul setelah ada aktivitas." />;
  }
  return (
    <div className="xy-card rounded-[20px] overflow-x-auto">
      <table className="w-full text-left text-[12.5px] min-w-[640px]">
        <thead>
          <tr className="border-b border-[#E9E3F5] bg-[#F5F3FF]">
            {kolom.map((c) => (
              <th key={c.k} className={`px-4 py-2.5 text-[10.5px] uppercase tracking-wider text-[#7C738F] font-bold ${c.className || ""}`}>
                {c.label}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((r, i) => (
            <tr key={r.id || r.kunci || r.room || r.kode || i} className="border-b border-[#F0EDFB] last:border-0 hover:bg-[#FBFAFF]">
              {kolom.map((c) => (
                <td key={c.k} className={`px-4 py-3 align-top ${c.className || ""}`}>
                  {c.render ? c.render(r) : <span className="text-[#1E1B2E] font-medium">{r[c.k] ?? "—"}</span>}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
