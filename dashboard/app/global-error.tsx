"use client";
export default function GlobalError({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <html lang="id">
      <body className="bg-[#100030] text-white font-[Plus_Jakarta_Sans] min-h-screen grid place-items-center p-6">
        <div className="bg-[#1E123F] border border-[#2D1B5E] rounded-[16px] p-6 max-w-[600px] w-full">
          <h2 className="text-[16px] font-black">Global error</h2>
          <pre className="mt-3 p-3 rounded-xl bg-[#100030] border border-[#2D1B5E] text-[11px] text-[#F5B0C0] overflow-auto">{error.message}</pre>
          <button onClick={() => reset()} className="mt-4 px-4 py-2 rounded-xl bg-[#7C3AED] text-white">Coba lagi</button>
        </div>
      </body>
    </html>
  );
}
