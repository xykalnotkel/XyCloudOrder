"use client";
export default function GlobalError({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <html lang="id">
      <body className="bg-[#FFFFFF] text-[#1E1B2E] font-[var(--font-inter)] min-h-screen grid place-items-center p-6">
        <div className="bg-[#FFFFFF] border border-[#E9E3F5] rounded-[16px] p-6 max-w-[600px] w-full">
          <h2 className="text-[16px] font-semibold">Global error</h2>
          <pre className="mt-3 p-3 rounded-xl bg-[#FFFFFF] border border-[#E9E3F5] text-[11px] text-[#BE123C] overflow-auto">{error.message}</pre>
          <button onClick={() => reset()} className="mt-4 px-4 py-2 rounded-xl bg-[#7C3AED] text-white">Coba lagi</button>
        </div>
      </body>
    </html>
  );
}
