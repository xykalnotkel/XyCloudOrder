"use client";
import { useCallback, useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { Send } from "lucide-react";
import { Btn, Chip, ErrBox, Header, Load, Stat } from "@/components/ui/kit";

export default function PushStatPage() {
  // endpoint mengembalikan SATU objek {ok, app|alasan} — ambil langsung.
  const [d, setD] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");

  const reload = useCallback(() => {
    setLoading(true); setErr("");
    adminFetch("/api/admin/push/statistik")
      .then(setD)
      .catch((e: any) => setErr(e.message || String(e)))
      .finally(() => setLoading(false));
  }, []);
  useEffect(() => { reload(); }, [reload]);
  const app = d?.app || {};

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header icon={Send} title="Statistik Push (OneSignal)" sub="Kondisi app OneSignal XyCloudStore langsung dari API-nya — subscriber & kesiapan pengiriman"
        right={<Btn tone="ghost" onClick={reload}>Muat ulang</Btn>} />
      {loading ? <Load /> : err ? <ErrBox msg={err} onRetry={reload} /> : d?.ok === false ? (
        <div className="xy-card rounded-[20px] p-10 text-center text-[#7C738F] font-medium">{d?.alasan || "OneSignal belum dikonfigurasi."}</div>
      ) : (
        <>
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
            <Stat label="Nama app" value={app.name || "—"} />
            <Stat label="Total perangkat" value={String(app.players ?? "—")} sub="pernah terdaftar" />
            <Stat label="Bisa dikirimi" value={String(app.messageable_players ?? "—")} sub="subscriber aktif" tone={Number(app.messageable_players) > 0 ? "ok" : "warn"} />
            <Stat label="Dibuat" value={app.created_at ? String(app.created_at).slice(0, 10) : "—"} />
          </div>
          <div className="xy-card rounded-[20px] p-5 space-y-2">
            <div className="text-[14px] font-bold text-[#1E1B2E]">Platform terdaftar</div>
            <div className="flex flex-wrap gap-2">
              {Object.keys(app.platforms || {}).length === 0 && <Chip tone="warn">Belum ada platform (perlu pasang APK & izinkan notifikasi)</Chip>}
              {Object.entries(app.platforms || {}).map(([k, v]: any) => (
                <Chip key={k} tone="info">{k}: {v?.subscriptions ?? v?.subscribers ?? JSON.stringify(v)}</Chip>
              ))}
            </div>
            {Number(app.messageable_players ?? 0) === 0 && (
              <p className="text-[12px] text-[#7C738F] leading-relaxed pt-1">
                Belum ada subscriber aktif — push baru terkirim setelah ada perangkat yang memasang APK dan mengizinkan notifikasi.
                Uji cepat: menu <b>Email & Push</b> → kirim push tes.
              </p>
            )}
          </div>
          <div className="xy-card rounded-[20px] p-5">
            <div className="text-[13px] font-bold text-[#1E1B2E] mb-2">Data mentah</div>
            <pre className="text-[11px] font-mono bg-[#F5F3FF] border border-[#E9E3F5] rounded-xl p-3 overflow-auto max-h-64 text-[#4B445F]">{JSON.stringify(app, null, 2)}</pre>
          </div>
        </>
      )}
    </div>
  );
}
