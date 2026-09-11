"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { KeyRound, Sticker, Trash2 } from "lucide-react";
import {
  Btn, Chip, ErrBox, Field, Header, Input, Load, MsgOk,
} from "@/components/ui/kit";

export default function StikerPage() {
  const [data, setData] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");
  const [ok, setOk] = useState("");
  const [key, setKey] = useState("");
  const [busy, setBusy] = useState(false);

  async function muat() {
    setLoading(true); setErr("");
    try { setData(await adminFetch("/api/admin/integrasi/giphy")); }
    catch (e: any) { setErr(e.message); }
    finally { setLoading(false); }
  }
  useEffect(() => { muat(); }, []);

  async function simpan() {
    if (!key.trim()) { setErr("Tempel API key GIPHY dulu."); return; }
    setBusy(true); setErr(""); setOk("");
    try {
      await adminFetch("/api/admin/integrasi/giphy", { method: "POST", body: { api_key: key.trim() } });
      setKey("");
      setOk("GIPHY diaktifkan — key disimpan terenkripsi di server");
      await muat();
    } catch (e: any) { setErr(e.message); }
    finally { setBusy(false); }
  }

  async function nonaktif() {
    if (!confirm("Nonaktifkan GIPHY? Stiker yang sudah terkirim tetap ada.")) return;
    setBusy(true); setErr(""); setOk("");
    try {
      await adminFetch("/api/admin/integrasi/giphy", { method: "DELETE" });
      setOk("GIPHY dinonaktifkan");
      await muat();
    } catch (e: any) { setErr(e.message); }
    finally { setBusy(false); }
  }

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header
        icon={Sticker}
        title="Stiker & GIPHY"
        sub="API key GIPHY untuk pencarian stiker di chat & forum"
      />

      {ok && <MsgOk msg={ok} />}
      {err && <ErrBox msg={err} />}
      {loading ? <Load /> : (
        <>
          <div className="grid md:grid-cols-3 gap-3">
            <div className="xy-card rounded-[14px] p-4">
              <div className="text-[11px] uppercase text-[#7C738F] font-semibold">Status</div>
              <div className="mt-1">
                {data?.siap ? <Chip tone="ok">Terhubung</Chip> : <Chip tone="warn">Belum aktif</Chip>}
              </div>
            </div>
            <div className="xy-card rounded-[14px] p-4">
              <div className="text-[11px] uppercase text-[#7C738F] font-semibold">Sumber key</div>
              <div className="mt-1 font-semibold text-[#1E1B2E]">
                {data?.dari_env ? "Secret Worker (env)" : data?.siap ? "Disimpan di D1 (terenkripsi)" : "—"}
              </div>
            </div>
            <div className="xy-card rounded-[14px] p-4">
              <div className="text-[11px] uppercase text-[#7C738F] font-semibold">Endpoint</div>
              <div className="mt-1 font-mono text-[11px] text-[#7C738F]">/api/admin/integrasi/giphy</div>
            </div>
          </div>

          <div className="xy-card rounded-[18px] p-5 space-y-3 max-w-xl">
            <div className="flex items-center gap-2 font-semibold text-[#1E1B2E]">
              <KeyRound size={16} className="text-[#7C3AED]" /> Simpan / ganti API key
            </div>
            <p className="text-[12px] text-[#7C738F] leading-relaxed">
              Ambil key di developers.giphy.com. Server menguji key sebelum menyimpan.
              Key tidak pernah dikirim balik ke dashboard atau aplikasi.
            </p>
            {data?.dari_env ? (
              <div className="rounded-xl bg-amber-50 border border-amber-200 p-3 text-[12px] text-amber-800 font-medium">
                Key berasal dari secret Cloudflare Worker (`GIPHY_API_KEY`).
                Ubah/hapus lewat dashboard Cloudflare, bukan dari sini.
              </div>
            ) : (
              <>
                <Field label="API key GIPHY">
                  <Input
                    type="password"
                    value={key}
                    onChange={(e) => setKey(e.target.value)}
                    placeholder="giphy-xxxxxxxx"
                    autoComplete="off"
                  />
                </Field>
                <div className="flex flex-wrap gap-2">
                  <Btn disabled={busy} onClick={simpan}>Simpan & aktifkan</Btn>
                  {data?.siap && (
                    <Btn tone="bahaya" disabled={busy} onClick={nonaktif}>
                      <Trash2 size={13} /> Nonaktifkan
                    </Btn>
                  )}
                </div>
              </>
            )}
          </div>
        </>
      )}
    </div>
  );
}
