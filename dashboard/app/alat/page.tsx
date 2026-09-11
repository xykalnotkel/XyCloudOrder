"use client";
import { Wrench, Mail, Bell, Send } from "lucide-react";
import { useState } from "react";
import { adminFetch } from "@/lib/api";
import { Btn, ErrBox, Field, Header, Input, MsgOk, TextArea } from "@/components/ui/kit";

export default function AlatPage() {
  const [email, setEmail] = useState("");
  const [uid, setUid] = useState("");
  const [msg, setMsg] = useState("Halo dari XyCloudStore");
  const [out, setOut] = useState("");
  const [err, setErr] = useState("");
  const [ok, setOk] = useState("");
  const [busy, setBusy] = useState<"email" | "push" | "">("");

  async function testEmail() {
    setErr(""); setOk(""); setOut("");
    if (!email.trim()) { setErr("Email tujuan wajib diisi."); return; }
    setBusy("email");
    try {
      const r = await adminFetch("/api/admin/uji/email", { method: "POST", body: { to: email.trim() } });
      setOut(JSON.stringify(r, null, 2));
      setOk("Email uji dikirim (cek inbox / log provider).");
    } catch (e: any) {
      setErr(e.message || "Gagal kirim email uji");
    } finally { setBusy(""); }
  }

  async function testPush() {
    setErr(""); setOk(""); setOut("");
    if (!uid.trim()) { setErr("user_id wajib untuk push uji."); return; }
    if (!msg.trim()) { setErr("Pesan push wajib diisi."); return; }
    setBusy("push");
    try {
      const r = await adminFetch("/api/admin/uji/push", { method: "POST", body: { user_id: uid.trim(), pesan: msg } });
      setOut(JSON.stringify(r, null, 2));
      setOk("Push uji dikirim.");
    } catch (e: any) {
      setErr(e.message || "Gagal kirim push uji");
    } finally { setBusy(""); }
  }

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header icon={Wrench} title="Email & Push" sub="Alat uji kirim email Resend & push OneSignal" />
      {err && <ErrBox msg={err} />}
      {ok && <MsgOk msg={ok} />}
      <div className="grid md:grid-cols-2 gap-4">
        <div className="xy-card p-4 space-y-3">
          <div className="flex items-center gap-2"><Mail size={16} className="text-[#7C3AED]" /><span className="text-[12px] font-semibold text-[#1E1B2E]">Uji Email</span></div>
          <Field label="Tujuan">
            <Input value={email} onChange={(e) => setEmail(e.target.value)} placeholder="nama@email.com" type="email" />
          </Field>
          <Btn className="w-full" disabled={busy === "email"} onClick={testEmail}><Send size={14} /> {busy === "email" ? "Mengirim…" : "Kirim Test Email"}</Btn>
        </div>
        <div className="xy-card p-4 space-y-3">
          <div className="flex items-center gap-2"><Bell size={16} className="text-[#7C3AED]" /><span className="text-[12px] font-semibold text-[#1E1B2E]">Uji Push</span></div>
          <Field label="User ID">
            <Input value={uid} onChange={(e) => setUid(e.target.value)} placeholder="u_…" className="font-mono" />
          </Field>
          <Field label="Pesan">
            <Input value={msg} onChange={(e) => setMsg(e.target.value)} placeholder="pesan" />
          </Field>
          <Btn className="w-full" disabled={busy === "push"} onClick={testPush}><Send size={14} /> {busy === "push" ? "Mengirim…" : "Kirim Test Push"}</Btn>
        </div>
      </div>
      {out && (
        <div className="xy-card p-4">
          <div className="text-[11px] font-semibold text-[#1E1B2E] mb-2 uppercase tracking-wide">Respons API</div>
          <pre className="text-[11px] text-[#7C738F] whitespace-pre-wrap font-mono leading-relaxed">{out}</pre>
        </div>
      )}
    </div>
  );
}
