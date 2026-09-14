"use client";
import { useState } from "react";
import { HardDrive } from "lucide-react";
import { Chip, ErrBox, Header, Load, SearchBox, Stat, Tabel, useAdminList } from "@/components/ui/kit";

export default function DbPage() {
  const { rows, loading, err, reload } = useAdminList("/api/admin/dbinfo");
  const [cari, setCari] = useState("");
  const q = cari.trim().toLowerCase();
  const daftar = rows
    .filter((r: any) => !q || r.tabel.includes(q))
    .slice()
    .sort((a: any, b: any) => b.jumlah - a.jumlah);
  const total = rows.reduce((n: number, r: any) => n + Number(r.jumlah || 0), 0);
  const terbesar = daftar[0];

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header icon={HardDrive} title="Database" sub="Jumlah baris setiap tabel D1 produksi — pantau pertumbuhan & anomali"
        right={<SearchBox value={cari} onChange={setCari} placeholder="Cari tabel…" />} />
      {loading ? <Load /> : err ? <ErrBox msg={err} onRetry={reload} /> : (
        <>
          <div className="grid grid-cols-2 lg:grid-cols-3 gap-3">
            <Stat label="Total baris" value={total.toLocaleString("id-ID")} sub={`${rows.length} tabel dipantau`} />
            <Stat label="Tabel terbesar" value={terbesar?.tabel || "—"} sub={`${Number(terbesar?.jumlah || 0).toLocaleString("id-ID")} baris`} />
            <Stat label="Tabel kosong" value={String(rows.filter((r: any) => Number(r.jumlah) === 0).length)} sub="kandidat dibersihkan" />
          </div>
          <Tabel
            kolom={[
              { k: "tabel", label: "Tabel", render: (r) => <span className="font-mono text-[12px] font-semibold text-[#1E1B2E]">{r.tabel}</span> },
              { k: "jumlah", label: "Baris", render: (r) => (
                <Chip tone={Number(r.jumlah) === 0 ? "netral" : Number(r.jumlah) > 1000 ? "info" : "ok"}>
                  {Number(r.jumlah).toLocaleString("id-ID")}
                </Chip>
              ) },
            ]}
            rows={daftar}
            kosong="Tidak ada tabel cocok."
          />
        </>
      )}
    </div>
  );
}
