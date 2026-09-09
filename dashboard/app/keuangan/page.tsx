"use client";
export default function KeuanganPage() {
  return (
    <div className="space-y-4">
      <h1 className="text-xl font-black text-white">Keuangan 💰 BARU</h1>
      <p className="text-sm text-violet-200/60">Omzet, fee, saldo beredar, topup pending, export CSV</p>
      <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
        {[
          { l: "Omzet Hari Ini", v: "Rp 2.4jt" },
          { l: "Omzet Minggu", v: "Rp 18.7jt" },
          { l: "Saldo Beredar", v: "Rp 42jt" },
          { l: "Topup Pending", v: "3" },
        ].map((c) => (
          <div key={c.l} className="xy-card rounded-[14px] p-4"><div className="text-[11px] text-white/50">{c.l}</div><div className="text-lg font-bold text-white mt-1">{c.v}</div></div>
        ))}
      </div>
      <div className="xy-card rounded-xl p-4 text-[12px] text-white/40">TODO: fetch /api/admin/statistik + keuangan endpoint. Export CSV via admin API.</div>
    </div>
  );
}
