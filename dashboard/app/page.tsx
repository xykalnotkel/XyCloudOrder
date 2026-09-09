"use client";
import { useEffect, useState } from "react";
import { adminFetch, getAdminKey, setAdminKey, loginAdmin } from "@/lib/api";
import { Users, Receipt, Wallet, Cpu, ShieldCheck, Rocket, Bell, Activity } from "lucide-react";

type Stats = {
  total_users: number;
  total_orders: number;
  pendapatan: number;
  unit_online: number;
};

export default function DashboardPage() {
  const [keyInput, setKeyInput] = useState("");
  const [logged, setLogged] = useState(false);
  const [stats, setStats] = useState<Stats | null>(null);
  const [err, setErr] = useState("");

  useEffect(() => {
    const k = getAdminKey();
    if (k) {
      setKeyInput(k);
      loginAdmin(k)
        .then((d) => {
          setLogged(true);
          setStats({
            total_users: d?.total_users ?? d?.users ?? 0,
            total_orders: d?.total_orders ?? d?.orders ?? 0,
            pendapatan: d?.pendapatan ?? 0,
            unit_online: d?.unit_online ?? 0,
          });
        })
        .catch(() => setLogged(false));
    }
  }, []);

  const handleLogin = async () => {
    setErr("");
    try {
      const d = await loginAdmin(keyInput);
      setAdminKey(keyInput);
      setLogged(true);
      setStats({
        total_users: d?.total_users ?? 0,
        total_orders: d?.total_orders ?? 0,
        pendapatan: d?.pendapatan ?? 0,
        unit_online: d?.unit_online ?? 0,
      });
    } catch (e: any) {
      setErr(e.message || "Gagal login");
    }
  };

  if (!logged) {
    return (
      <div className="min-h-[80vh] grid place-items-center font-[Plus_Jakarta_Sans]">
        <div className="xy-card rounded-[20px] p-8 w-full max-w-[420px]">
          <div className="w-12 h-12 rounded-xl xy-btn grid place-items-center font-black mb-4 text-white tracking-tight">XY</div>
          <h1 className="text-xl font-bold text-white tracking-tight">Login Console v3.3</h1>
          <p className="text-sm text-violet-200/70 mt-1 font-medium">Pakai x-admin-key. Palette violet-indigo #7C3AED + #100030</p>
          <input
            value={keyInput}
            onChange={(e) => setKeyInput(e.target.value)}
            placeholder="x-admin-key"
            className="mt-5 w-full px-4 py-3 rounded-xl bg-[#100030] border border-white/10 text-white outline-none focus:border-[#7C3AED] font-mono text-sm"
          />
          {err && <div className="mt-3 text-sm text-red-300 bg-red-500/10 border border-red-500/20 rounded-xl p-2">{err}</div>}
          <button onClick={handleLogin} className="mt-4 w-full py-3 rounded-xl xy-btn text-white font-bold tracking-wide">
            Masuk
          </button>
          <div className="mt-4 text-[11px] text-white/30 text-center font-medium">Next.js 14 • API tetap Cloudflare Worker • Font Plus Jakarta Sans • Icons Lucide</div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6 font-[Plus_Jakarta_Sans]">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-black text-white tracking-tight">Dashboard</h1>
          <p className="text-sm text-violet-200/60 font-medium">Ringkasan v3.3 — Next.js full rewrite, glossy violet-indigo, no emoji</p>
        </div>
        <div className="flex gap-2">
          <span className="px-3 py-1 rounded-full bg-[#7C3AED]/20 border border-[#7C3AED]/30 text-xs text-violet-100 font-semibold flex items-center gap-1"><Activity size={12} /> Live</span>
          <span className="px-3 py-1 rounded-full bg-white/5 border border-white/10 text-xs text-white/60 font-medium">{new Date().toLocaleDateString("id-ID")}</span>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        {[
          { label: "Total Pengguna", value: stats?.total_users ?? "—", Icon: Users, grad: "from-[#7C3AED] to-[#A855F7]" },
          { label: "Total Pesanan", value: stats?.total_orders ?? "—", Icon: Receipt, grad: "from-[#200050] to-[#7C3AED]" },
          { label: "Pendapatan", value: stats?.pendapatan ? `Rp ${stats.pendapatan.toLocaleString()}` : "—", Icon: Wallet, grad: "from-[#7C3AED] to-[#8B5CF6]" },
          { label: "Unit Online", value: stats?.unit_online ?? "—", Icon: Cpu, grad: "from-[#100030] to-[#7C3AED]" },
        ].map((c) => (
          <div key={c.label} className="xy-card rounded-[18px] p-5">
            <div className="flex items-center justify-between">
              <div className={`w-10 h-10 rounded-xl bg-gradient-to-br ${c.grad} grid place-items-center`}><c.Icon size={18} className="text-white" /></div>
              <div className="text-[11px] px-2 py-0.5 rounded-full bg-white/5 border border-white/10 font-medium">v3.3</div>
            </div>
            <div className="mt-4 text-[12px] text-violet-200/60 font-medium tracking-wide uppercase">{c.label}</div>
            <div className="text-xl font-bold text-white mt-1 tracking-tight">{c.value}</div>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div className="lg:col-span-2 xy-card rounded-[18px] p-5">
          <h3 className="font-bold text-white tracking-tight flex items-center gap-2"><Rocket size={16} className="text-[#A855F7]" /> Apa yang baru di v3.3?</h3>
          <ul className="mt-3 space-y-2 text-sm text-violet-100/80 list-disc pl-5 font-medium">
            <li>Next.js 14 App Router — admin.html lama 1800 baris dipecah jadi komponen, no emoji, Lucide icons konsisten</li>
            <li>Native updater fix: <code className="px-1.5 py-0.5 rounded bg-white/10 font-mono text-xs">siapkan_pembaruan.py</code> auto-inject DownloadManager + notif progress tetap jalan walau app ditutup</li>
            <li>Security full audit: global IP rate-limit 180/60s, device 2 akun, saldo anti-double, upload validasi</li>
            <li>Menu baru: Live Monitor, Keuangan, Rilis App (tema popup Ramadan dll), Push Notif Builder — semua pakai Lucide</li>
            <li>Font konsisten: Plus Jakarta Sans di semua platform, icons Lucide (bukan emoji)</li>
          </ul>
        </div>
        <div className="xy-card rounded-[18px] p-5">
          <h3 className="font-bold text-white tracking-tight flex items-center gap-2"><ShieldCheck size={16} className="text-[#7C3AED]" /> Next Steps</h3>
          <div className="mt-3 space-y-2">
            {[
              "Port Orders + Users (multi-select v3.0b) — done",
              "Port Rilis App (kelola versi + gambar tema) — done",
              "Tambah Flutter: Favorit, Statistik, Tier, Aktivitas — done",
              "Security: global rate-limit middleware — done",
              "Deploy dashboard ke Cloudflare Pages — next",
            ].map((t, i) => (
              <div key={i} className="flex gap-2 text-[13px] text-violet-100/70 font-medium">
                <span className="w-5 h-5 rounded-full bg-[#7C3AED]/20 border border-[#7C3AED]/30 grid place-items-center text-[10px] font-bold">{i + 1}</span>
                <span>{t}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="xy-card rounded-[18px] p-4 flex items-center justify-between">
        <div className="text-[12px] text-white/50 font-medium">Fallback: admin lama masih jalan di <a href="/api/admin" className="text-[#8B5CF6] underline">/api/admin</a> sampai migrasi 100% • Icons Lucide, no emoji</div>
        <button
          onClick={() => {
            localStorage.removeItem("xy_admin_key");
            location.reload();
          }}
          className="text-xs px-3 py-1.5 rounded-lg bg-white/5 hover:bg-white/10 border border-white/10 font-medium"
        >
          Logout
        </button>
      </div>
    </div>
  );
}
