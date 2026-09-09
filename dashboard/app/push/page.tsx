"use client";
import { useEffect, useMemo, useState } from "react";
import { adminFetch } from "@/lib/api";
import { Bell, CheckCircle2, Search, Send, XCircle } from "lucide-react";

const TIPE = [
  { v: "sistem", l: "Umum / Sistem" },
  { v: "promo", l: "Promo / Banner" },
  { v: "order", l: "Order / Sewa PC" },
  { v: "wallet", l: "Dompet / Top up" },
  { v: "akun", l: "Akun Digital" },
  { v: "forum", l: "Komunitas / Forum" },
];

export default function PushPage() {
  const [judul, setJudul] = useState("");
  const [pesan, setPesan] = useState("");
  const [tipe, setTipe] = useState("sistem");
  const [mode, setMode] = useState<"semua" | "user">("semua");
  const [userId, setUserId] = useState("");
  const [q, setQ] = useState("");
  const [users, setUsers] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [hasil, setHasil] = useState<{ ok: boolean; pesan: string } | null>(null);

  // daftar user untuk sasaran per-user
  useEffect(() => {
    if (mode === "user" && users.length === 0) {
      adminFetch("/api/admin/users")
        .then((d) => {
          const arr = Array.isArray(d) ? d : Array.isArray(d?.users) ? d.users : [];
          setUsers(arr);
        })
        .catch(() => {});
    }
  }, [mode, users.length]);

  const pilihan = useMemo(() => {
    const k = q.trim().toLowerCase();
    return users.filter((u) => !k || (u.nama || "").toLowerCase().includes(k) || (u.email || "").toLowerCase().includes(k));
  }, [users, q]);

  const kirim = async () => {
    setHasil(null);
    if (!judul.trim() || !pesan.trim()) {
      setHasil({ ok: false, pesan: "Judul dan isi pesan wajib diisi." });
      return;
    }
    if (mode === "user" && !userId) {
      setHasil({ ok: false, pesan: "Pilih pengguna sasaran atau ganti target ke 'Semua user'." });
      return;
    }
    setLoading(true);
    try {
      const body: any = { judul, pesan, tipe, mode };
      if (mode === "user") body.user_id = userId;
      const r = await adminFetch("/api/admin/push", { method: "POST", body });
      setHasil({ ok: true, pesan: `Terkirim (ID ${r.id || "-"})${r.sasaran === "semua" ? " ke semua pelanggan terdaftar di OneSignal" : ""}.` });
      if (mode === "semua") setPesan("");
    } catch (e: any) {
      setHasil({ ok: false, pesan: e.message || "Push gagal dikirim." });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="space-y-4 max-w-[700px] font-[Plus_Jakarta_Sans]">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl xy-btn grid place-items-center"><Bell size={18} className="text-white" /></div>
        <div>
          <h1 className="text-xl font-black text-[#1E1B2E] tracking-tight">Push Notif Builder <span className="ml-2 text-[10px] px-2 py-0.5 rounded-full bg-[#F3F0FF] font-bold">BARU</span></h1>
          <p className="text-sm text-[#7C738F] font-medium">Compose & kirim push OneSignal — semua user atau per pengguna (hanya pemilik)</p>
        </div>
      </div>

      <div className="xy-card rounded-[16px] p-5 space-y-3">
        <input value={judul} onChange={(e) => setJudul(e.target.value)} placeholder="Judul notifikasi" maxLength={120}
          className="w-full px-4 py-2.5 rounded-xl bg-[#FFFFFF] border border-[#E9E3F5] text-sm text-[#1E1B2E] font-medium" />
        <textarea value={pesan} onChange={(e) => setPesan(e.target.value)} placeholder="Isi pesan notifikasi" rows={4} maxLength={400}
          className="w-full px-4 py-2.5 rounded-xl bg-[#FFFFFF] border border-[#E9E3F5] text-sm text-[#1E1B2E] font-medium" />

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <label className="block">
            <span className="text-[11px] text-[#7C738F] font-semibold uppercase tracking-wide">Kategori</span>
            <select value={tipe} onChange={(e) => setTipe(e.target.value)}
              className="mt-1 w-full px-4 py-2.5 rounded-xl bg-[#FFFFFF] border border-[#E9E3F5] text-sm text-[#1E1B2E] font-medium">
              {TIPE.map((t) => <option key={t.v} value={t.v}>{t.l}</option>)}
            </select>
          </label>
          <label className="block">
            <span className="text-[11px] text-[#7C738F] font-semibold uppercase tracking-wide">Target</span>
            <select value={mode} onChange={(e) => setMode(e.target.value as any)}
              className="mt-1 w-full px-4 py-2.5 rounded-xl bg-[#FFFFFF] border border-[#E9E3F5] text-sm text-[#1E1B2E] font-medium">
              <option value="semua">Semua user (broadcast)</option>
              <option value="user">Satu pengguna</option>
            </select>
          </label>
        </div>

        {mode === "user" && (
          <div className="space-y-2 p-3 rounded-xl bg-[#F3F0FF] border border-[#E9E3F5]">
            <div className="relative">
              <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-[#7C738F]" />
              <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Cari nama atau email…"
                className="w-full pl-9 pr-4 py-2 rounded-lg bg-[#FFFFFF] border border-[#E9E3F5] text-sm text-[#1E1B2E] font-medium" />
            </div>
            <select value={userId} onChange={(e) => setUserId(e.target.value)} size={Math.min(6, Math.max(2, pilihan.length))}
              className="w-full px-3 py-2 rounded-lg bg-[#FFFFFF] border border-[#E9E3F5] text-sm text-[#1E1B2E] font-medium">
              <option value="">— pilih pengguna —</option>
              {pilihan.map((u) => (
                <option key={u.id} value={u.id}>{u.email || u.id}{u.nama ? ` (${u.nama})` : ""}{u.diblokir ? " • diblokir" : ""}</option>
              ))}
            </select>
            <div className="text-[11px] text-[#7C738F] font-medium">{pilihan.length} dari {users.length} pengguna.</div>
          </div>
        )}

        <button onClick={kirim} disabled={loading}
          className="w-full py-3 rounded-xl xy-btn font-bold tracking-wide text-white disabled:opacity-50 flex items-center justify-center gap-2">
          {loading ? <span className="w-4 h-4 rounded-full border-2 border-white/40 border-t-white animate-spin" /> : <Send size={15} />}
          {loading ? "Mengirim…" : "Kirim Sekarang"}
        </button>

        {hasil && (
          <div className={`flex items-start gap-2 text-[13px] font-semibold px-4 py-3 rounded-xl ${hasil.ok ? "bg-emerald-500/10 border border-emerald-500/25 text-emerald-600" : "bg-rose-500/10 border border-rose-500/25 text-rose-600"}`}>
            {hasil.ok ? <CheckCircle2 size={15} className="mt-0.5 shrink-0" /> : <XCircle size={15} className="mt-0.5 shrink-0" />}
            <span>{hasil.pesan}</span>
          </div>
        )}

        <div className="text-[11px] text-[#7C738F] font-medium leading-relaxed">
          Endpoint: POST /api/admin/push (x-admin-key) • broadcast via segmen "Total Subscriptions" OneSignal, per-user via external_id.
          Pastikan REST API key & App ID terpasang di secret Worker — bila belum, tampil pesan dari penyedia. Icons Lucide, no emoji.
        </div>
      </div>
    </div>
  );
}
