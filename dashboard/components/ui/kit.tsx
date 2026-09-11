"use client";
import { type LucideIcon, Package, RefreshCw } from "lucide-react";
import { useCallback, useEffect, useMemo, useState, type ReactNode } from "react";
import { adminFetch } from "@/lib/api";

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

/** Normalisasi respons list dari Worker (array | {data}|{users}|{orders}|…). */
export function asList(d: any, keys: string[] = ["data", "users", "orders", "results", "items", "rows"]): any[] {
  if (Array.isArray(d)) return d;
  if (!d || typeof d !== "object") return [];
  for (const k of keys) {
    if (Array.isArray(d[k])) return d[k];
  }
  return [];
}

export function Header({ icon: Icon, title, sub, right }: {
  icon: LucideIcon; title: string; sub?: string; right?: ReactNode;
}) {
  return (
    <div className="flex items-start justify-between flex-wrap gap-2">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-[10px] bg-[#7C3AED] border border-[#6D28D9] grid place-items-center">
          <Icon size={18} className="text-white" />
        </div>
        <div>
          <h1 className="text-xl font-semibold text-[#1E1B2E] tracking-tight">{title}</h1>
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

export function ErrBox({ msg, title = "Terjadi kesalahan", onRetry }: { msg: string; title?: string; onRetry?: () => void }) {
  if (!msg) return null;
  return (
    <div role="alert" className="rounded-[12px] border border-rose-200 bg-rose-50 p-4 text-rose-800">
      <div className="flex items-start gap-3">
        <div className="w-8 h-8 rounded-[8px] bg-white border border-rose-200 grid place-items-center shrink-0 text-[14px] font-semibold text-rose-600">!</div>
        <div className="min-w-0 flex-1">
          <div className="text-[13px] font-semibold tracking-tight">{title}</div>
          <div className="mt-1 text-[12.5px] font-medium leading-relaxed text-rose-700/90 break-words">{msg}</div>
          {onRetry && (
            <button type="button" onClick={onRetry} className="mt-3 h-8 px-3 rounded-[8px] border border-rose-200 bg-white text-[12px] font-semibold text-rose-700 hover:bg-rose-100">
              Coba lagi
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

export function EmptyBox({ msg, sub }: { msg: string; sub?: string }) {
  return (
    <div className="xy-card rounded-[14px] p-8 text-center">
      <div className="w-12 h-12 mx-auto rounded-[10px] bg-[#F3F0FF] border border-[#E9E3F5] grid place-items-center">
        <Package size={20} className="text-[#7C3AED]" />
      </div>
      <div className="mt-3 text-sm text-[#6B5A8A] font-semibold tracking-tight">{msg}</div>
      {sub && <div className="text-[12px] text-[#7C738F] mt-1 font-medium">{sub}</div>}
    </div>
  );
}

export function Chip({ children, tone = "netral" }: { children: ReactNode; tone?: "ok" | "warn" | "bad" | "info" | "netral" }) {
  const map: Record<string, string> = {
    ok: "bg-emerald-500/15 border-emerald-500/30 text-emerald-700",
    warn: "bg-amber-500/15 border-amber-500/30 text-amber-700",
    bad: "bg-rose-500/15 border-rose-500/30 text-rose-700",
    info: "bg-violet-500/15 border-violet-500/25 text-violet-700",
    netral: "bg-[#F3F0FF] border-[#E9E3F5] text-[#6B5A8A]",
  };
  return (
    <span className={`text-[10px] px-2 py-0.5 rounded-full border font-semibold tracking-wide whitespace-nowrap ${map[tone]}`}>
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

export function Stat({ label, value, sub, tone }: { label: string; value: ReactNode; sub?: string; tone?: string }) {
  return (
    <div className="xy-card rounded-[14px] p-4">
      <div className="text-[11px] text-[#7C738F] font-semibold tracking-wide uppercase">{label}</div>
      <div className={`text-xl font-semibold tracking-tight mt-1 ${TONE_TEKS[tone || ""] || "text-[#1E1B2E]"}`}>{value}</div>
      {sub && <div className="text-[11px] text-[#7C738F] mt-0.5 font-medium">{sub}</div>}
    </div>
  );
}

export type Kolom = {
  k: string;
  label: string;
  render?: (r: any) => ReactNode;
  className?: string;
};

export function Tabel({ kolom, rows, kosong, leading }: {
  kolom: Kolom[]; rows: any[]; kosong?: string; leading?: (r: any) => ReactNode;
}) {
  if (rows.length === 0) {
    return <EmptyBox msg={kosong || "Belum ada data."} sub="Data akan muncul setelah ada aktivitas." />;
  }
  return (
    <div className="xy-card rounded-[14px] overflow-x-auto">
      <table className="w-full text-left text-[12.5px] min-w-[560px]">
        <thead>
          <tr className="border-b border-[#E9E3F5] bg-[#F5F3FF]">
            {leading && <th className="px-3 py-2.5 w-10" />}
            {kolom.map((c) => (
              <th key={c.k} className={`px-4 py-2.5 text-[10.5px] uppercase tracking-wider text-[#7C738F] font-semibold ${c.className || ""}`}>
                {c.label}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((r, i) => (
            <tr key={r.id || r.kunci || r.room || r.kode || i} className="border-b border-[#F0EDFB] last:border-0 hover:bg-[#FBFAFF]">
              {leading && <td className="px-3 py-3 align-middle">{leading(r)}</td>}
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

/* ---------- tombol & form kecil ---------- */

type BtnProps = {
  children: ReactNode;
  onClick?: () => void;
  disabled?: boolean;
  type?: "button" | "submit";
  className?: string;
  title?: string;
  tone?: "utama" | "ghost" | "bahaya" | "ok";
};

export function Btn({ children, onClick, disabled, type = "button", className = "", title, tone = "utama" }: BtnProps) {
  const base = "inline-flex items-center justify-center gap-1.5 px-3.5 h-9 rounded-[10px] text-[12.5px] font-semibold tracking-tight disabled:opacity-50 disabled:pointer-events-none transition border";
  const map: Record<string, string> = {
    utama: "xy-btn text-white border-[#6D28D9]",
    ghost: "bg-white border-[#E9E3F5] text-[#4B445F] hover:bg-[#F5F3FF]",
    bahaya: "bg-rose-50 border-rose-200 text-rose-700 hover:bg-rose-100",
    ok: "bg-emerald-50 border-emerald-200 text-emerald-700 hover:bg-emerald-100",
  };
  return (
    <button type={type} title={title} disabled={disabled} onClick={onClick} className={`${base} ${map[tone]} ${className}`}>
      {children}
    </button>
  );
}

export function SearchBox({ value, onChange, onSubmit, placeholder = "Cari…" }: {
  value: string; onChange: (v: string) => void; onSubmit?: () => void; placeholder?: string;
}) {
  return (
    <div className="relative max-w-[320px] flex-1">
      <input
        value={value}
        onChange={(e) => onChange(e.target.value)}
        onKeyDown={(e) => e.key === "Enter" && onSubmit?.()}
        placeholder={placeholder}
        className="w-full xy-input text-[12.5px] pl-3 pr-3"
      />
    </div>
  );
}

export function useSelection(ids: string[]) {
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const allSelected = ids.length > 0 && ids.every((id) => selected.has(id));
  const toggle = useCallback((id: string) => {
    setSelected((prev) => {
      const n = new Set(prev);
      if (n.has(id)) n.delete(id); else n.add(id);
      return n;
    });
  }, []);
  const toggleAll = useCallback(() => {
    setSelected((prev) => {
      if (ids.length && ids.every((id) => prev.has(id))) return new Set();
      return new Set(ids);
    });
  }, [ids]);
  const clear = useCallback(() => setSelected(new Set()), []);
  const list = useMemo(() => Array.from(selected), [selected]);
  return { selected, setSelected, toggle, toggleAll, clear, list, allSelected, count: selected.size };
}

export function SelectBar({ count, onClear, children }: { count: number; onClear: () => void; children: ReactNode }) {
  if (count === 0) return null;
  return (
    <div className="xy-card rounded-2xl px-4 py-2.5 flex items-center gap-2 flex-wrap sticky top-2 z-10 bg-white/95 backdrop-blur-sm">
      <span className="text-[12px] font-semibold text-[#7C3AED]">{count} dipilih</span>
      <button type="button" onClick={onClear} className="text-[11px] text-[#7C738F] hover:text-[#1E1B2E] font-semibold underline">
        kosongkan
      </button>
      <div className="flex-1" />
      <div className="flex gap-1.5 flex-wrap">{children}</div>
    </div>
  );
}

/** Hook muat list generik. */
export function useAdminList(path: string, deps: any[] = []) {
  const [rows, setRows] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");
  const [tick, setTick] = useState(0);

  const reload = useCallback(() => setTick((t) => t + 1), []);

  useEffect(() => {
    let hidup = true;
    setLoading(true); setErr("");
    adminFetch(path)
      .then((d) => { if (hidup) setRows(asList(d)); })
      .catch((e: any) => { if (hidup) setErr(e.message || String(e)); })
      .finally(() => { if (hidup) setLoading(false); });
    return () => { hidup = false; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [path, tick, ...deps]);

  return { rows, setRows, loading, err, setErr, reload };
}

export async function runBatch(
  ids: string[],
  fn: (id: string) => Promise<void>,
  labelOk: string,
): Promise<string> {
  let ok = 0, gagal = 0;
  for (const id of ids) {
    try { await fn(id); ok++; } catch { gagal++; }
  }
  return `${ok} ${labelOk}` + (gagal ? ` · ${gagal} gagal` : "");
}

export function toneStatus(s?: string): "ok" | "warn" | "bad" | "info" | "netral" {
  const v = String(s || "").toLowerCase();
  if (["selesai", "disetujui", "aktif", "ok", "online", "hidup", "siap", "berjalan"].includes(v)) return "ok";
  if (["menunggu", "diperiksa", "antre", "provisioning", "pairing", "pending"].includes(v)) return "warn";
  if (["batal", "ditolak", "gagal", "blocked", "diblokir", "error"].includes(v)) return "bad";
  if (["dibayar", "info", "baru"].includes(v)) return "info";
  return "netral";
}

/** Panel samping sederhana (detail user, device, dll). */
export function Panel({ open, title, onClose, children, width = "max-w-md" }: {
  open: boolean; title: string; onClose: () => void; children: ReactNode; width?: string;
}) {
  if (!open) return null;
  return (
    <div className="fixed inset-0 z-40 flex justify-end">
      <button type="button" aria-label="Tutup" className="absolute inset-0 bg-[#100030]/35" onClick={onClose} />
      <div className={`relative h-full w-full ${width} bg-white shadow-2xl border-l border-[#E9E3F5] overflow-y-auto p-5 space-y-4`}>
        <div className="flex items-start justify-between gap-3">
          <h2 className="text-lg font-semibold text-[#1E1B2E] tracking-tight">{title}</h2>
          <button type="button" onClick={onClose} className="text-[12px] font-semibold text-[#7C738F] hover:text-[#1E1B2E]">Tutup</button>
        </div>
        {children}
      </div>
    </div>
  );
}

export function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="block space-y-1.5">
      <span className="text-[11px] font-semibold uppercase tracking-wide text-[#7C738F]">{label}</span>
      {children}
    </label>
  );
}

export function Input(props: React.InputHTMLAttributes<HTMLInputElement>) {
  return <input {...props} className={`xy-input w-full text-[13px] ${props.className || ""}`} />;
}

export function TextArea(props: React.TextareaHTMLAttributes<HTMLTextAreaElement>) {
  return <textarea {...props} className={`w-full rounded-[14px] border border-[#E9E3F5] bg-white px-3 py-2.5 text-[13px] text-[#1E1B2E] outline-none focus:border-[#7C3AED] focus:shadow-[0_0_0_3px_rgba(124,58,237,0.14)] ${props.className || ""}`} />;
}

export function MsgOk({ msg }: { msg: string }) {
  if (!msg) return null;
  return <div className="xy-card rounded-xl p-3 text-emerald-700 text-[12.5px] font-semibold border border-emerald-200 bg-emerald-50">{msg}</div>;
}

export function FieldError({ msg }: { msg?: string }) {
  if (!msg) return null;
  return <p className="text-[11.5px] font-medium text-rose-600 mt-1 leading-snug">{msg}</p>;
}

export function Check({
  checked, onChange, disabled, label, className = "",
}: {
  checked: boolean;
  onChange?: (v: boolean) => void;
  disabled?: boolean;
  label?: ReactNode;
  className?: string;
}) {
  return (
    <button
      type="button"
      role="checkbox"
      aria-checked={checked}
      disabled={disabled}
      onClick={() => onChange?.(!checked)}
      className={`inline-flex items-center gap-2.5 text-left disabled:opacity-50 ${className}`}
    >
      <span className="xy-check" data-on={checked ? "1" : "0"} aria-hidden>
        {checked ? (
          <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"><polyline points="20 6 9 17 4 12" /></svg>
        ) : null}
      </span>
      {label != null && <span className="text-[13px] font-medium text-[#1E1B2E]">{label}</span>}
    </button>
  );
}

export type SelectOption = { value: string; label: string; disabled?: boolean };

export function Select({
  value, onChange, options, placeholder = "Pilih…", disabled, invalid, className = "", size,
}: {
  value: string;
  onChange: (v: string) => void;
  options: SelectOption[];
  placeholder?: string;
  disabled?: boolean;
  invalid?: boolean;
  className?: string;
  /** native multi-row list when size set (user picker) */
  size?: number;
}) {
  const [open, setOpen] = useState(false);
  const aktif = options.find((o) => o.value === value);
  // list mode (size): keep accessible native for long lists
  if (size && size > 1) {
    return (
      <select
        value={value}
        disabled={disabled}
        size={size}
        aria-invalid={invalid || undefined}
        onChange={(e) => onChange(e.target.value)}
        className={`w-full px-3 py-2 rounded-[10px] bg-white border border-[#E9E3F5] text-[13px] font-medium text-[#1E1B2E] outline-none focus:border-[#7C3AED] ${invalid ? "border-rose-300" : ""} ${className}`}
      >
        <option value="">{placeholder}</option>
        {options.map((o) => (
          <option key={o.value} value={o.value} disabled={o.disabled}>{o.label}</option>
        ))}
      </select>
    );
  }
  return (
    <div className={`relative ${className}`}>
      <button
        type="button"
        disabled={disabled}
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-invalid={invalid || undefined}
        className="xy-select-trigger disabled:opacity-50"
        onClick={() => setOpen((v) => !v)}
        onBlur={() => setTimeout(() => setOpen(false), 120)}
      >
        <span className={aktif ? "text-[#1E1B2E]" : "text-[#7C738F]"}>{aktif?.label || placeholder}</span>
      </button>
      {open && (
        <div className="xy-select-menu" role="listbox">
          {options.map((o) => (
            <button
              key={o.value}
              type="button"
              role="option"
              aria-selected={o.value === value}
              data-active={o.value === value ? "1" : "0"}
              disabled={o.disabled}
              className="xy-select-opt disabled:opacity-40"
              onMouseDown={(e) => e.preventDefault()}
              onClick={() => { onChange(o.value); setOpen(false); }}
            >
              {o.label}
            </button>
          ))}
          {options.length === 0 && (
            <div className="px-3 py-2 text-[12px] text-[#7C738F] font-medium">Tidak ada pilihan</div>
          )}
        </div>
      )}
    </div>
  );
}

export function PageShell({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <div className={`space-y-4 font-[var(--font-inter)] max-w-[1600px] ${className}`}>{children}</div>;
}
