"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { Save, ShieldCheck } from "lucide-react";
import {
  Btn, ErrBox, Field, Header, Input, Load, MsgOk, Stat,
} from "@/components/ui/kit";

const LABELS: Record<string, string> = {
  device_accounts: "Maks akun per perangkat",
  register_ip_hour: "Daftar / IP / jam",
  otp_email_hour: "OTP email / jam",
  otp_email_day: "OTP email / hari",
  email_daily: "Email sistem / hari",
};

export default function SecurityPage() {
  const [data, setData] = useState<any>(null);
  const [cfg, setCfg] = useState<Record<string, number>>({});
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");
  const [ok, setOk] = useState("");
  const [busy, setBusy] = useState(false);

  async function muat() {
    setLoading(true); setErr("");
    try {
      const d = await adminFetch("/api/admin/security");
      setData(d);
      setCfg({ ...(d?.config || {}) });
    } catch (e: any) { setErr(e.message); }
    finally { setLoading(false); }
  }
  useEffect(() => { muat(); }, []);

  async function simpan() {
    setBusy(true); setErr(""); setOk("");
    try {
      const d = await adminFetch("/api/admin/security", { method: "POST", body: cfg });
      setData((prev: any) => ({ ...prev, config: d.config || cfg }));
      setOk("Kebijakan keamanan disimpan");
    } catch (e: any) { setErr(e.message); }
    finally { setBusy(false); }
  }

  const stats = data?.stats || {};

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header
        icon={ShieldCheck}
        title="Security"
        sub="Kuota anti-abuse, OTP, email harian (pemilik)"
        right={<Btn tone="ghost" onClick={muat}>Muat ulang</Btn>}
      />

      {ok && <MsgOk msg={ok} />}
      {err && <ErrBox msg={err} />}
      {loading ? <Load /> : (
        <>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <Stat label="Devices" value={stats.devices ?? "—"} />
            <Stat label="Diblokir" value={stats.blocked ?? "—"} tone="bad" />
            <Stat label="Event 24 jam" value={stats.events ?? "—"} tone="warn" />
            <Stat label="Email hari ini" value={`${stats.emails ?? 0} / ${data?.email_max ?? "—"}`} />
          </div>

          <div className="xy-card rounded-[18px] p-5 space-y-4 max-w-2xl">
            <h3 className="font-bold text-[#1E1B2E]">Kebijakan</h3>
            <div className="grid sm:grid-cols-2 gap-3">
              {Object.keys(LABELS).map((k) => (
                <Field key={k} label={LABELS[k]}>
                  <Input
                    type="number"
                    min={1}
                    value={cfg[k] ?? ""}
                    onChange={(e) => setCfg({ ...cfg, [k]: Number(e.target.value) })}
                  />
                </Field>
              ))}
            </div>
            <Btn disabled={busy} onClick={simpan}><Save size={14} /> Simpan kebijakan</Btn>
            <p className="text-[11px] text-[#7C738F] leading-relaxed">
              Event detail ada di menu <b>Log Keamanan</b>. Perangkat & blokir di menu <b>Perangkat</b>.
            </p>
          </div>
        </>
      )}
    </div>
  );
}
