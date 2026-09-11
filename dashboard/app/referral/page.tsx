"use client";
import { Share2 } from "lucide-react";
import {
  EmptyBox, ErrBox, Header, jam, Load, rupiah, useAdminList,
} from "@/components/ui/kit";

export default function ReferralPage() {
  const { rows, loading, err } = useAdminList("/api/admin/referral");

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header
        icon={Share2}
        title="Referral"
        sub="Riwayat undangan & hadiah referral"
        right={<span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{rows.length} entri</span>}
      />
      {err && <ErrBox msg={err} />}
      {loading ? <Load /> : rows.length === 0 ? (
        <EmptyBox msg="Belum ada referral." />
      ) : (
        <div className="xy-card rounded-[20px] overflow-x-auto">
          <table className="w-full text-left text-[12.5px] min-w-[640px]">
            <thead>
              <tr className="border-b border-[#E9E3F5] bg-[#F5F3FF]">
                {["Pengundang", "Diundang", "Kode / Hadiah", "Waktu"].map((h) => (
                  <th key={h} className="px-4 py-2.5 text-[10.5px] uppercase tracking-wider text-[#7C738F] font-bold">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.map((r: any, i: number) => (
                <tr key={r.id || i} className="border-b border-[#F0EDFB] last:border-0">
                  <td className="px-4 py-3">
                    <div className="font-bold">{r.nama_pengundang || r.pengundang || "—"}</div>
                    <div className="text-[11px] text-[#7C738F]">{r.pengundang_id || r.user_id}</div>
                  </td>
                  <td className="px-4 py-3">
                    <div className="font-bold">{r.nama_diundang || r.diundang || r.nama || "—"}</div>
                    <div className="text-[11px] text-[#7C738F]">{r.diundang_id || r.email}</div>
                  </td>
                  <td className="px-4 py-3">
                    <div className="font-mono text-[11px]">{r.kode || "—"}</div>
                    <div className="font-bold text-[#7C3AED]">{r.hadiah != null ? rupiah(r.hadiah) : (r.bonus != null ? rupiah(r.bonus) : "—")}</div>
                  </td>
                  <td className="px-4 py-3 text-[11px] font-mono text-[#7C738F]">{jam(r.dibuat || r.created_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
