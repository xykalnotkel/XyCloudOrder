"use client";
import { FileText } from "lucide-react";
import {
  EmptyBox, ErrBox, Header, jam, Load, useAdminList,
} from "@/components/ui/kit";

export default function AuditPage() {
  const { rows, loading, err } = useAdminList("/api/admin/audit");

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header
        icon={FileText}
        title="Audit Log"
        sub="Jejak aksi admin (200 terakhir)"
        right={<span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{rows.length} entri</span>}
      />
      {err && <ErrBox msg={err} />}
      {loading ? <Load /> : rows.length === 0 ? (
        <EmptyBox msg="Belum ada audit." sub="Aksi non-GET admin tercatat otomatis." />
      ) : (
        <div className="xy-card rounded-[20px] overflow-x-auto">
          <table className="w-full text-left text-[12.5px] min-w-[640px]">
            <thead>
              <tr className="border-b border-[#E9E3F5] bg-[#F5F3FF]">
                {["Waktu", "Admin", "Peran", "Aksi", "Target"].map((h) => (
                  <th key={h} className="px-4 py-2.5 text-[10.5px] uppercase tracking-wider text-[#7C738F] font-bold">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.map((r, i) => (
                <tr key={r.id || i} className="border-b border-[#F0EDFB] last:border-0 hover:bg-[#FBFAFF]">
                  <td className="px-4 py-3 font-mono text-[11px] text-[#7C738F]">{jam(r.waktu)}</td>
                  <td className="px-4 py-3 font-bold">{r.admin || r.nama || "—"}</td>
                  <td className="px-4 py-3 text-[#6B5A8A]">{r.peran || "—"}</td>
                  <td className="px-4 py-3 font-medium">{r.aksi}</td>
                  <td className="px-4 py-3 font-mono text-[11px] text-[#7C738F] max-w-[220px] truncate">{r.target || "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
