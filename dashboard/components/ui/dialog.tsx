"use client";
// Dialog & toast KUSTOM untuk dashboard admin.
//
// Sebelumnya halaman admin memakai `confirm()` / `alert()` bawaan browser yang
// tampilannya berbeda di tiap mesin dan tidak bisa diatur gayanya (audit UI
// 2026-09-13: 40 titik pemakaian). Modul ini menyediakan pengganti yang
// seragam dengan bahasa desain dashboard: sudut membulat, palet ungu, bayangan
// lembut, dan animasi masuk.
//
// Dipakai secara imperatif supaya panggilan di halaman tetap satu baris:
//   if (!(await konfirm({ pesan: "Hapus laporan ini?" }))) return;
//   toast("Berhasil disimpan", "ok");
import { useEffect, useState, type ReactElement } from "react";
import { createRoot } from "react-dom/client";
import { AlertTriangle, CheckCircle2, Info, X, XCircle } from "lucide-react";

let gayaTerpasang = false;
function pasangGaya() {
  if (gayaTerpasang || typeof document === "undefined") return;
  gayaTerpasang = true;
  const s = document.createElement("style");
  s.textContent = [
    "@keyframes xyDialogMasuk{from{opacity:0;transform:translateY(10px) scale(.96)}to{opacity:1;transform:none}}",
    "@keyframes xyLatarMasuk{from{opacity:0}to{opacity:1}}",
    "@keyframes xyToastMasuk{from{opacity:0;transform:translateX(14px)}to{opacity:1;transform:none}}",
  ].join("");
  document.head.appendChild(s);
}

function mount(el: ReactElement): () => void {
  pasangGaya();
  const wadah = document.createElement("div");
  document.body.appendChild(wadah);
  const root = createRoot(wadah);
  root.render(el);
  return () => {
    // Beri satu frame supaya animasi keluar tidak tabrakan dengan unmount.
    setTimeout(() => {
      root.unmount();
      wadah.remove();
    }, 0);
  };
}

// ---------------------------------------------------------------------------
// Modal konfirmasi
// ---------------------------------------------------------------------------

export type OpsiKonfirm = {
  pesan: string;
  judul?: string;
  okLabel?: string;
  batalLabel?: string;
  bahaya?: boolean;
};

function ModalKonfirmasi({
  opsi,
  selesai,
}: {
  opsi: OpsiKonfirm;
  selesai: (v: boolean) => void;
}) {
  const [tutup, setTutup] = useState(false);

  useEffect(() => {
    const padaTombol = (e: KeyboardEvent) => {
      if (e.key === "Escape") selesai(false);
    };
    window.addEventListener("keydown", padaTombol);
    return () => window.removeEventListener("keydown", padaTombol);
  }, [selesai]);

  const bahaya = !!opsi.bahaya;
  return (
    <div
      className="fixed inset-0 z-[95] grid place-items-center p-4"
      style={{ animation: "xyLatarMasuk .16s ease-out" }}
      role="dialog"
      aria-modal="true"
      aria-label={opsi.judul || "Konfirmasi"}
      onMouseDown={(e) => {
        if (e.target === e.currentTarget) selesai(false);
      }}
    >
      <div className="absolute inset-0 bg-[#14002E]/45 backdrop-blur-[2px]" />
      <div
        className="relative w-[min(92vw,430px)] rounded-[20px] bg-white border border-[#E9E3F5] shadow-[0_24px_60px_-18px_rgba(46,20,120,.35)] p-5"
        style={{ animation: "xyDialogMasuk .18s cubic-bezier(.2,.9,.3,1.2)", opacity: tutup ? 0 : 1 }}
      >
        <div className="flex items-start gap-3">
          <div
            className={`shrink-0 w-10 h-10 rounded-[14px] grid place-items-center ${
              bahaya ? "bg-[#FDE8EC] text-[#D3385B]" : "bg-[#F3F0FF] text-[#6D5AE0]"
            }`}
          >
            <AlertTriangle size={18} />
          </div>
          <div className="min-w-0 flex-1">
            <div className="font-semibold text-[15px] text-[#1E1B2E]">
              {opsi.judul || (bahaya ? "Tindakan berbahaya" : "Konfirmasi")}
            </div>
            <div className="text-[13px] text-[#5C5474] mt-1 whitespace-pre-wrap leading-relaxed">
              {opsi.pesan}
            </div>
          </div>
          <button
            className="shrink-0 w-8 h-8 rounded-[10px] grid place-items-center text-[#7C738F] hover:bg-[#F5F3FF] hover:text-[#1E1B2E] transition"
            onClick={() => selesai(false)}
            aria-label="Tutup"
          >
            <X size={15} />
          </button>
        </div>
        <div className="flex justify-end gap-2 mt-5">
          <button
            className="h-9 px-4 rounded-[12px] text-[13px] font-medium text-[#5C5474] bg-[#F5F3FF] border border-[#E9E3F5] hover:bg-[#EDE9FB] transition"
            onClick={() => selesai(false)}
          >
            {opsi.batalLabel || "Batal"}
          </button>
          <button
            className={`h-9 px-4 rounded-[12px] text-[13px] font-semibold text-white shadow-sm transition ${
              bahaya
                ? "bg-[#D3385B] hover:bg-[#B92E4E]"
                : "bg-[#6D5AE0] hover:bg-[#5B48CE]"
            }`}
            onClick={() => {
              setTutup(true);
              selesai(true);
            }}
          >
            {opsi.okLabel || (bahaya ? "Ya, lanjutkan" : "Ya")}
          </button>
        </div>
      </div>
    </div>
  );
}

/** Pengganti `confirm()` bawaan browser. Resolve true bila pengguna setuju. */
export function konfirm(opsi: OpsiKonfirm): Promise<boolean> {
  return new Promise((resolve) => {
    const lepas = mount(
      <ModalKonfirmasi
        opsi={opsi}
        selesai={(v) => {
          lepas();
          resolve(v);
        }}
      />,
    );
  });
}

// ---------------------------------------------------------------------------
// Toast
// ---------------------------------------------------------------------------

type ToneToast = "ok" | "err" | "info";

function Toast({ pesan, tone }: { pesan: string; tone: ToneToast }) {
  const ikon =
    tone === "ok" ? (
      <CheckCircle2 size={16} className="text-[#2E9E6B]" />
    ) : tone === "err" ? (
      <XCircle size={16} className="text-[#D3385B]" />
    ) : (
      <Info size={16} className="text-[#6D5AE0]" />
    );
  return (
    <div
      className="pointer-events-auto flex items-start gap-2.5 max-w-[min(92vw,380px)] rounded-[14px] bg-white/95 backdrop-blur border border-[#E9E3F5] shadow-[0_14px_38px_-14px_rgba(46,20,120,.35)] px-4 py-3"
      style={{ animation: "xyToastMasuk .18s ease-out" }}
      role="status"
    >
      <span className="mt-0.5 shrink-0">{ikon}</span>
      <span className="text-[13px] leading-relaxed text-[#332D47] whitespace-pre-wrap">{pesan}</span>
    </div>
  );
}

let wadahToast: HTMLDivElement | null = null;
function wadahStack(): HTMLDivElement {
  if (wadahToast && document.body.contains(wadahToast)) return wadahToast;
  wadahToast = document.createElement("div");
  wadahToast.className =
    "fixed bottom-4 right-4 z-[96] flex flex-col gap-2 items-end pointer-events-none";
  document.body.appendChild(wadahToast);
  return wadahToast;
}

/** Pengganti `alert()` bawaan browser. Hilang sendiri setelah ~3,6 detik. */
export function toast(pesan: string, tone: ToneToast = "info") {
  pasangGaya();
  const slot = document.createElement("div");
  wadahStack().appendChild(slot);
  const root = createRoot(slot);
  root.render(<Toast pesan={pesan} tone={tone} />);
  setTimeout(() => {
    root.unmount();
    slot.remove();
  }, 3600);
}

// ---------------------------------------------------------------------------
// Modal input teks (pengganti prompt() bawaan)
// ---------------------------------------------------------------------------

export type OpsiTeks = {
  judul: string;
  pesan?: string;
  placeholder?: string;
  okLabel?: string;
  bahaya?: boolean;
  /** Kembalikan pesan galat bila isian belum benar; null bila benar. */
  wajib?: (v: string) => string | null;
};

function ModalTeks({ opsi, selesai }: { opsi: OpsiTeks; selesai: (v: string | null) => void }) {
  const [nilai, setNilai] = useState("");
  const [galat, setGalat] = useState("");

  useEffect(() => {
    const padaTombol = (e: KeyboardEvent) => {
      if (e.key === "Escape") selesai(null);
    };
    window.addEventListener("keydown", padaTombol);
    return () => window.removeEventListener("keydown", padaTombol);
  }, [selesai]);

  const kirim = () => {
    const g = opsi.wajib ? opsi.wajib(nilai) : null;
    if (g) { setGalat(g); return; }
    selesai(nilai);
  };

  return (
    <div
      className="fixed inset-0 z-[95] grid place-items-center p-4"
      style={{ animation: "xyLatarMasuk .16s ease-out" }}
      role="dialog"
      aria-modal="true"
      aria-label={opsi.judul}
      onMouseDown={(e) => { if (e.target === e.currentTarget) selesai(null); }}
    >
      <div className="absolute inset-0 bg-[#14002E]/45 backdrop-blur-[2px]" />
      <div
        className="relative w-[min(92vw,430px)] rounded-[20px] bg-white border border-[#E9E3F5] shadow-[0_24px_60px_-18px_rgba(46,20,120,.35)] p-5"
        style={{ animation: "xyDialogMasuk .18s cubic-bezier(.2,.9,.3,1.2)" }}
      >
        <div className="flex items-start gap-3">
          <div className={`shrink-0 w-10 h-10 rounded-[14px] grid place-items-center ${opsi.bahaya ? "bg-[#FDE8EC] text-[#D3385B]" : "bg-[#F3F0FF] text-[#6D5AE0]"}`}>
            <AlertTriangle size={18} />
          </div>
          <div className="min-w-0 flex-1">
            <div className="font-semibold text-[15px] text-[#1E1B2E]">{opsi.judul}</div>
            {opsi.pesan && (
              <div className="text-[13px] text-[#5C5474] mt-1 leading-relaxed whitespace-pre-wrap">{opsi.pesan}</div>
            )}
          </div>
          <button className="shrink-0 w-8 h-8 rounded-[10px] grid place-items-center text-[#7C738F] hover:bg-[#F5F3FF] hover:text-[#1E1B2E] transition"
            onClick={() => selesai(null)} aria-label="Tutup">
            <X size={15} />
          </button>
        </div>
        <input
          autoFocus
          value={nilai}
          onChange={(e) => { setNilai(e.target.value); setGalat(""); }}
          onKeyDown={(e) => { if (e.key === "Enter") kirim(); }}
          placeholder={opsi.placeholder || ""}
          className="mt-4 w-full px-3.5 py-2.5 rounded-[12px] bg-[#FAF8FF] border border-[#E9E3F5] text-[13px] text-[#1E1B2E] outline-none focus:border-[#6D5AE0] focus:bg-white transition"
        />
        {galat && <div className="mt-1.5 text-[11.5px] font-semibold text-[#D3385B]">{galat}</div>}
        <div className="flex justify-end gap-2 mt-4">
          <button className="h-9 px-4 rounded-[12px] text-[13px] font-medium text-[#5C5474] bg-[#F5F3FF] border border-[#E9E3F5] hover:bg-[#EDE9FB] transition"
            onClick={() => selesai(null)}>
            Batal
          </button>
          <button
            className={`h-9 px-4 rounded-[12px] text-[13px] font-semibold text-white shadow-sm transition ${opsi.bahaya ? "bg-[#D3385B] hover:bg-[#B92E4E]" : "bg-[#6D5AE0] hover:bg-[#5B48CE]"}`}
            onClick={kirim}>
            {opsi.okLabel || "Simpan"}
          </button>
        </div>
      </div>
    </div>
  );
}

/** Pengganti `prompt()` bawaan browser. Resolve null bila dibatalkan. */
export function mintaTeks(opsi: OpsiTeks): Promise<string | null> {
  return new Promise((resolve) => {
    const lepas = mount(
      <ModalTeks opsi={opsi} selesai={(v) => { lepas(); resolve(v); }} />,
    );
  });
}

export default konfirm;
