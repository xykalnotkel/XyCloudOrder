"use client";
import { useEffect } from "react";

export default function Error({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  useEffect(() => {
    console.error("Dashboard error:", error);
  }, [error]);

  return (
    <div className="min-h-[60vh] grid place-items-center p-6">
      <div className="xy-card rounded-[16px] p-6 max-w-[600px] w-full">
        <h2 className="text-[16px] font-semibold text-[#1E1B2E] tracking-tight">Terjadi kesalahan di halaman ini</h2>
        <p className="text-[13px] text-[#7C738F] mt-2 font-medium">Buka console browser (F12) untuk detail. Pesan error:</p>
        <pre className="mt-3 p-3 rounded-xl bg-[#FFFFFF] border border-[#E9E3F5] text-[11px] text-[#BE123C] overflow-auto whitespace-pre-wrap break-all">
          {error.message}
          {"\n"}
          {error.stack?.slice(0, 2000)}
        </pre>
        <div className="mt-4 flex gap-2">
          <button onClick={() => reset()} className="xy-btn px-4 py-2 text-[13px]">Coba lagi</button>
          <button onClick={() => location.href = '/'} className="px-4 py-2 rounded-xl bg-[#F3F0FF] border border-[#E9E3F5] text-[13px] font-semibold">Ke Dashboard</button>
        </div>
        <div className="mt-4 text-[11px] text-[#7C738F]">v3.3i solid no glass • {error.digest || "no-digest"}</div>
      </div>
    </div>
  );
}
