"use client";
import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { ShieldCheck, Eye, EyeOff, LogIn, ExternalLink } from "lucide-react";
import { loginAdmin, setAdminKey, getAdminKey } from "@/lib/api";

export default function LoginPage() {
  const [key, setKey] = useState("");
  const [show, setShow] = useState(false);
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState("");
  const router = useRouter();

  useEffect(() => {
    const saved = getAdminKey();
    if (saved) setKey(saved);
  }, []);

  async function handleLogin() {
    const k = key.trim();
    if (!k) { setErr("Admin key wajib diisi"); return; }
    setLoading(true); setErr("");
    try {
      await loginAdmin(k);
      setAdminKey(k);
      router.push("/");
    } catch (e:any) {
      setErr(e.message || "Gagal masuk");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center p-6 bg-[#100030]">
      <div className="w-full max-w-[420px]">
        <div className="xy-card p-7">
          <div className="flex items-center gap-3 mb-6">
            <img src="/brand/logo.png" alt="XyCloud" className="w-16 h-16 object-contain" />
            <div>
              <div className="font-black text-white text-[18px] tracking-tight leading-tight">XyCloud Admin</div>
              <div className="text-[11px] text-[#9A8CBF] font-semibold tracking-wide mt-0.5">ADMIN.XYCLOUD.MY.ID • CONSOLE</div>
            </div>
          </div>

          <h1 className="text-[20px] font-black text-white tracking-tight">Masuk Dashboard</h1>
          <p className="text-[13px] text-[#9A8CBF] font-medium leading-[1.5] mt-1.5">Masukkan Admin Key. Key disimpan lokal di browser, tidak dikirim ke pihak ketiga.</p>

          <div className="mt-5 space-y-4">
            <div>
              <label className="block text-[11px] font-bold tracking-wide uppercase text-[#9A8CBF] mb-2">Admin Key</label>
              <div className="relative">
                <input
                  type={show ? "text" : "password"}
                  value={key}
                  onChange={e=>setKey(e.target.value)}
                  onKeyDown={e=>{ if(e.key==='Enter') handleLogin(); }}
                  placeholder="xya_xxx atau key utama"
                  className="xy-input w-full pr-10"
                />
                <button type="button" onClick={()=>setShow(!show)} className="absolute right-2 top-1/2 -translate-y-1/2 w-8 h-8 grid place-items-center rounded-lg bg-[#21114A] hover:bg-[#2D1B5E]">
                  {show ? <EyeOff size={16} className="text-[#9A8CBF]"/> : <Eye size={16} className="text-[#9A8CBF]"/>}
                </button>
              </div>
            </div>

            {err && (
              <div className="p-3 rounded-xl bg-[#2A1230] border border-[#4A2040] text-[#F5B0C0] text-[12px] font-semibold leading-[1.4]">{err}</div>
            )}

            <button onClick={handleLogin} disabled={loading} className="xy-btn w-full h-[46px] flex items-center justify-center gap-2 text-[14px]">
              {loading ? "Memeriksa..." : <><LogIn size={16}/> Masuk</>}
            </button>

            <div className="h-px bg-[#2D1B5E] my-1" />

            <div className="space-y-2">
              <div className="text-[11px] font-bold uppercase tracking-wide text-[#9A8CBF]">Tautan Cepat</div>
              <a href="https://www.xycloud.my.id" className="flex items-center gap-3 p-3 rounded-xl border border-[#2D1B5E] bg-[#21114A] hover:border-[#7C3AED] hover:bg-[#251553]">
                <div className="w-9 h-9 rounded-lg bg-[#2A1A5E] grid place-items-center"><ExternalLink size={16} className="text-[#A78BFA]"/></div>
                <div className="flex-1"><div className="text-[13px] font-bold text-white">www.xycloud.my.id</div><div className="text-[11px] text-[#9A8CBF]">Situs utama</div></div>
              </a>
              <a href="https://api.xycloud.my.id/admin?legacy=1" className="flex items-center gap-3 p-3 rounded-xl border border-[#2D1B5E] bg-[#21114A] hover:border-[#7C3AED]">
                <div className="w-9 h-9 rounded-lg bg-[#2A1A5E] grid place-items-center"><ShieldCheck size={16} className="text-[#A78BFA]"/></div>
                <div className="flex-1"><div className="text-[13px] font-bold text-white">Console Lama (Legacy)</div><div className="text-[11px] text-[#9A8CBF]">Fallback darurat 1826 baris</div></div>
              </a>
            </div>

            <div className="text-center text-[11px] text-[#6B5A8A] font-medium pt-2">
              v3.3d • Plus Jakarta Sans • Lucide • No Emoji • No Glassmorphism • Solid
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
