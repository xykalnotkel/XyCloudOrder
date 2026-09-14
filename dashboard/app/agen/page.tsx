"use client";
import { useState } from "react";
import { Bot } from "lucide-react";
import { Chip, ErrBox, Header, Load, SearchBox, Tabel, jam, toneStatus, useAdminList } from "@/components/ui/kit";

export default function AgenPage() {
  const { rows, loading, err, reload } = useAdminList("/api/admin/agen");
  const [cari, setCari] = useState("");
  const q = cari.trim().toLowerCase();
  const daftar = rows.filter((a: any) =>
    !q || `${a.nama} ${a.kode} ${a.host || ""} ${a.status} ${a.versi || ""}`.toLowerCase().includes(q));

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header icon={Bot} title="Agen Windows" sub="Semua agen streaming XyDesk yang terdaftar — status, host, dan versinya"
        right={<SearchBox value={cari} onChange={setCari} placeholder="Cari agen / kode / host…" />} />
      {loading ? <Load /> : err ? <ErrBox msg={err} onRetry={reload} /> : (
        <Tabel
          kolom={[
            { k: "nama", label: "Nama", render: (a) => <span className="font-semibold text-[#1E1B2E]">{a.nama}</span> },
            { k: "kode", label: "Kode", render: (a) => <span className="font-mono text-[11.5px]">{a.kode}</span> },
            { k: "status", label: "Status", render: (a) => <Chip tone={toneStatus(a.status)}>{a.status}</Chip> },
            { k: "host", label: "Host", render: (a) => <span className="font-mono text-[11.5px]">{a.host || "—"}</span> },
            { k: "versi", label: "Versi", render: (a) => <span className="font-mono text-[11.5px]">{a.versi || "—"}</span> },
            { k: "sesi_aktif", label: "Sesi aktif", render: (a) => <span className="font-mono text-[11px]">{a.sesi_aktif || "—"}</span> },
            { k: "terakhir", label: "Terakhir terlihat", render: (a) => <span className="text-[#7C738F]">{a.terakhir ? jam(a.terakhir) : "—"}</span> },
          ]}
          rows={daftar}
          kosong="Belum ada agen terdaftar."
        />
      )}
    </div>
  );
}
