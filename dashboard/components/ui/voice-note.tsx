"use client";
// Pemutar pesan suara custom (tanpa <audio controls> bawaan browser):
// tombol putar/jeda bulat, bilah progres yang bisa diklik, dan durasi.
// Dibuat karena kontrol native Chrome terpotong di dalam gelembung chat
// (tinggi 36px) sehingga voice note "tidak bisa diputar" di dashboard.
import { useEffect, useRef, useState } from "react";
import { AlertCircle, Pause, Play } from "lucide-react";

export default function VoiceNote({
  src,
  durasi,
  gelap = false,
}: {
  src: string;
  durasi?: number | null;
  gelap?: boolean;
}) {
  const ref = useRef<HTMLAudioElement | null>(null);
  const [main, setMain] = useState(false);
  const [posisi, setPosisi] = useState(0);
  const [lama, setLama] = useState(durasi && durasi > 0 ? durasi : 0);
  const [rusak, setRusak] = useState(false);

  // berhenti memutar kalau pindah kamar percakapan / unmount
  useEffect(() => {
    return () => {
      ref.current?.pause();
    };
  }, []);
  useEffect(() => {
    ref.current?.pause();
    setMain(false);
    setPosisi(0);
    setRusak(false);
  }, [src]);

  function fmt(d: number) {
    if (!isFinite(d) || d < 0) d = 0;
    const m = Math.floor(d / 60);
    const s = Math.floor(d % 60);
    return `${m}:${String(s).padStart(2, "0")}`;
  }

  function toggle() {
    const a = ref.current;
    if (!a || rusak) return;
    if (main) {
      a.pause();
      setMain(false);
    } else {
      a.play().then(() => setMain(true)).catch(() => setRusak(true));
    }
  }

  function loncat(e: React.MouseEvent<HTMLDivElement>) {
    const a = ref.current;
    if (!a || !lama || rusak) return;
    const r = e.currentTarget.getBoundingClientRect();
    const p = Math.min(1, Math.max(0, (e.clientX - r.left) / r.width));
    a.currentTime = p * lama;
    setPosisi(p * lama);
  }

  return (
    <div className={`flex items-center gap-2.5 py-0.5 min-w-[210px] max-w-[250px] ${gelap ? "text-white" : "text-[#1E1B2E]"}`}>
      {/* preload="metadata" supaya durasi muncul tanpa mengunduh penuh */}
      <audio
        ref={ref}
        preload="metadata"
        src={src}
        onTimeUpdate={(e) => setPosisi(e.currentTarget.currentTime)}
        onLoadedMetadata={(e) => {
          const d = e.currentTarget.duration;
          if (isFinite(d) && d > 0) setLama(d);
        }}
        onEnded={() => {
          setMain(false);
          setPosisi(0);
        }}
        onError={() => setRusak(true)}
      />
      <button
        type="button"
        onClick={toggle}
        title={rusak ? "Audio tidak bisa diputar" : main ? "Jeda" : "Putar pesan suara"}
        className={`shrink-0 w-9 h-9 rounded-full grid place-items-center transition ${
          gelap ? "bg-white/20 hover:bg-white/30" : "bg-[#F3EDFF] hover:bg-[#E7DBFF] text-[#7C3AED]"
        } ${rusak ? "opacity-60" : ""}`}
      >
        {rusak ? <AlertCircle size={15} /> : main ? <Pause size={15} /> : <Play size={15} className="translate-x-[1px]" />}
      </button>
      <div className="flex-1 flex flex-col gap-1 min-w-[110px]">
        <div
          onClick={loncat}
          className={`h-1.5 rounded-full overflow-hidden cursor-pointer ${gelap ? "bg-white/25" : "bg-[#E9E3F5]"}`}
        >
          <div
            className={`h-full rounded-full ${gelap ? "bg-white" : "bg-[#7C3AED]"}`}
            style={{ width: `${lama ? Math.min(100, (posisi / lama) * 100) : 0}%` }}
          />
        </div>
        <div className={`text-[10px] font-medium ${gelap ? "text-white/75" : "text-[#9A8CBF]"}`}>
          {rusak ? "Audio tidak dapat diputar" : `${fmt(posisi)} / ${fmt(lama)}`}
        </div>
      </div>
    </div>
  );
}
