"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { ShieldCheck, ShieldAlert } from "lucide-react";

export default function SecurityPage() {
  const [data, setData] = useState<any>(null);
  const [err, setErr] = useState("");

  useEffect(() => {
    adminFetch("/api/admin/security").then(setData).catch((e) => setErr(e.message));
  }, []);

  return (
    <div className="space-y-4 font-[Plus_Jakarta_Sans]">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl xy-btn grid place-items-center"><ShieldCheck size={18} className="text-white" /></div>
        <div>
          <h1 className="text-xl font-black text-white tracking-tight">Security Full Audit</h1>
          <p className="text-sm text-[#9A8CBF] font-medium">Checklist semua lapisan — rate limit, device 2 akun, saldo anti-double, upload validasi, OTP atomik</p>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div className="xy-card rounded-[16px] p-5">
          <h3 className="font-bold text-white tracking-tight flex items-center gap-2"><ShieldCheck size={16} className="text-[#7C3AED]" /> Checklist (dari docs/rencana-3.3.md)</h3>
          <ul className="mt-3 space-y-2 text-[13px] text-[#9A8CBF] font-medium">
            <li>✓ Atomic claim kredensial (v3.0c) — WHERE status=tersedia</li>
            <li>✓ Saldo WHERE saldo {'>='} ? + check semua jalur</li>
            <li>✓ Device limit 2 akun per device + IP limit + global 180/60s</li>
            <li>✓ OTP digest + expiry 10m + max 3 percobaan</li>
            <li>✓ Upload max 5MB, whitelist image/png jpeg webp gif</li>
            <li>✓ esc() di innerHTML — audit ulang</li>
            <li>✓ Validasi URL update hanya xycloud.my.id</li>
            <li>✓ Rate limit middleware global di index.js (v3.3 done)</li>
            <li>✓ Icons Lucide, font Plus Jakarta Sans konsisten — no emoji</li>
          </ul>
        </div>
        <div className="xy-card rounded-[16px] p-5">
          <h3 className="font-bold text-white tracking-tight flex items-center gap-2"><ShieldAlert size={16} className="text-[#A855F7]" /> Data Security Terkini</h3>
          {err ? <div className="mt-3 text-red-300 text-sm font-medium">{err}</div> : !data ? <div className="mt-3 text-[#9A8CBF] text-sm">Memuat...</div> : (
            <pre className="mt-3 text-[11px] bg-[#100030] p-3 rounded-xl overflow-x-auto text-[#9A8CBF] font-mono">{JSON.stringify(data, null, 2).slice(0, 4000)}</pre>
          )}
          <div className="mt-4 p-3 rounded-xl bg-[#21114A] border border-[#2D1B5E] text-[11px] font-medium">File audit lengkap: <code className="font-mono">docs/keamanan-audit.md</code> + <code className="font-mono">docs/rencana-3.3.md</code></div>
        </div>
      </div>
    </div>
  );
}
