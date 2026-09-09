"use client";
import { Wrench, Mail, Bell, Send } from "lucide-react";
import { useState } from "react";
import { adminFetch } from "@/lib/api";
export default function AlatPage(){
  const [email,setEmail]=useState(""); const [uid,setUid]=useState(""); const [msg,setMsg]=useState("Halo dari XyCloudStore"); const [out,setOut]=useState("");
  async function testEmail(){
    try{ const r=await adminFetch('/api/admin/uji/email',{method:'POST',body:{to:email}}); setOut(JSON.stringify(r)); }catch(e:any){ setOut(e.message); }
  }
  async function testPush(){
    try{ const r=await adminFetch('/api/admin/uji/push',{method:'POST',body:{user_id:uid,pesan:msg}}); setOut(JSON.stringify(r)); }catch(e:any){ setOut(e.message); }
  }
  return (
    <div className="space-y-4 font-[Plus_Jakarta_Sans]">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl bg-[#7C3AED] grid place-items-center"><Wrench size={18} className="text-white"/></div>
        <div><h1 className="text-xl font-black text-white tracking-tight">Email & Push</h1><p className="text-sm text-[#9A8CBF]">Alat uji kirim email & push notifikasi</p></div>
      </div>
      <div className="grid md:grid-cols-2 gap-4">
        <div className="xy-card p-4 space-y-3">
          <div className="flex items-center gap-2"><Mail size={16} className="text-[#A78BFA]"/><span className="text-[12px] font-bold text-white">Uji Email</span></div>
          <input value={email} onChange={e=>setEmail(e.target.value)} placeholder="nama@email.com" className="xy-input w-full"/>
          <button onClick={testEmail} className="xy-btn w-full h-10 text-[13px] flex items-center justify-center gap-2"><Send size={14}/> Kirim Test Email</button>
        </div>
        <div className="xy-card p-4 space-y-3">
          <div className="flex items-center gap-2"><Bell size={16} className="text-[#A78BFA]"/><span className="text-[12px] font-bold text-white">Uji Push</span></div>
          <input value={uid} onChange={e=>setUid(e.target.value)} placeholder="user_id" className="xy-input w-full"/>
          <input value={msg} onChange={e=>setMsg(e.target.value)} placeholder="pesan" className="xy-input w-full"/>
          <button onClick={testPush} className="xy-btn w-full h-10 text-[13px] flex items-center justify-center gap-2"><Send size={14}/> Kirim Test Push</button>
        </div>
      </div>
      {out && <div className="xy-card p-4"><div className="text-[11px] font-bold text-white mb-2">Hasil</div><pre className="text-[11px] text-[#9A8CBF] whitespace-pre-wrap">{out}</pre></div>}
    </div>
  );
}
