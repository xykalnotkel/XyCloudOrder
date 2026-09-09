"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { FileText } from "lucide-react";
import { Chip, ErrBox, Header, jam, Load, Tabel } from "@/components/ui/kit";

export default function AuditPage() {
  const [rows, setRows] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");

  useEffect(() => {
    adminFetch("/api/admin/audit")
      .then((d) => setRows(Array.isArray(d) ? d : []))
      .catch((e) => setErr(e.message))
      .finally(() => setLoading(false));
  }, []);

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header icon={FileText} title="Audit Log" sub="Jejak tindakan admin dari log_admin (120 terakhir)"
        right={<span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{rows.length} catatan</span>} />
      {loading ? <Load /> : err ? <ErrBox msg={err} /> : (
        <Tabel kosong="Belum ada aktivitas admin tercatat."
          kolom={[
            { k: "waktu", label: "Waktu", render: (r) => <span className="text-[#7C738F] font-mono text-[11.5px]">{jam(r.waktu)}</span> },
            { k: "admin", label: "Admin", render: (r) => <span className="font-bold text-[#1E1B2E]">{r.admin || "—"}</span> },
            { k: "peran", label: "Peran", render: (r) => <Chip tone={r.peran === "pemilik" ? "info" : "netral"}>{r.peran || "-"}</Chip> },
            { k: "aksi", label: "Aksi", render: (r) => <span className="text-[#1E1B2E] font-medium">{r.aksi || "—"}</span> },
            { k: "target", label: "Target", render: (r) => <span className="font-mono text-[11px] text-[#6B5A8A] break-all">{r.target || "—"}</span> },
          ]}
          rows={rows} />
      )}
    </div>
  );
}
