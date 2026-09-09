"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";

export default function SecurityPage() {
  const [data, setData] = useState<any>(null);
  const [err, setErr] = useState("");

  useEffect(() => {
    adminFetch("/api/admin/security").then(setData).catch((e) => setErr(e.message));
  }, []);

  return (
    <div className="space-y-4">
      <h1 className="text-xl font-black text-white">Security Full Audit 🛡️</h1>
      <p className="text-sm text-violet-200/60">Checklist semua lapisan — rate limit, device 2 akun, saldo anti-double, upload validasi, OTP atomik</p>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div className="xy-card rounded-[16px] p-5">
          <h3 className="font-bold text-white">Checklist (dari docs/rencana-3.3.md)</h3>
          <ul className="mt-3 space-y-2 text-[13px] text-violet-100/70">
            <li>✅ Atomic claim kredensial (v3.0c) — WHERE status=tersedia</li>
            <li>✅ Saldo WHERE saldo {'>='} ? + check semua jalur</li>
            <li>✅ Device limit 2 akun per device + IP limit</li>
            <li>✅ OTP digest + expiry 10m + max 3 percobaan</li>
            <li>✅ Upload max 5MB, whitelist image/png jpeg webp gif</li>
            <li>✅ esc() di innerHTML — audit ulang</li>
            <li>✅ Validasi URL update hanya xycloud.my.id</li>
            <li>⏳ Rate limit middleware tambahan di index.js (TODO v3.3)</li>
            <li>⏳ httpOnly cookie untuk admin key di Next.js (TODO)</li>
          </ul>
        </div>
        <div className="xy-card rounded-[16px] p-5">
          <h3 className="font-bold text-white">Data Security Terkini</h3>
          {err ? <div className="mt-3 text-red-300 text-sm">{err}</div> : !data ? <div className="mt-3 text-white/50 text-sm">Memuat...</div> : (
            <pre className="mt-3 text-[11px] bg-[#100030] p-3 rounded-xl overflow-x-auto text-violet-100/70">{JSON.stringify(data, null, 2).slice(0, 4000)}</pre>
          )}
          <div className="mt-4 p-3 rounded-xl bg-[#7C3AED]/10 border border-[#7C3AED]/20 text-[11px]">File audit lengkap: <code>docs/keamanan-audit.md</code> (akan dibuat) + <code>docs/rencana-3.3.md</code></div>
        </div>
      </div>
    </div>
  );
}
