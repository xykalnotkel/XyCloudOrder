"use client";
import { useState } from "react";
import { Layers } from "lucide-react";
import { Chip, ErrBox, Header, Load, SearchBox, Tabel, rupiah, useAdminList } from "@/components/ui/kit";

export default function StokPage() {
  const { rows, loading, err, reload } = useAdminList("/api/admin/stok");
  const [cari, setCari] = useState("");
  const q = cari.trim().toLowerCase();
  const daftar = rows.filter((r: any) => !q || `${r.nama} ${r.kategori}`.toLowerCase().includes(q));
  const totalTersedia = rows.reduce((n: number, r: any) => n + Number(r.tersedia || 0), 0);
  const kritis = rows.filter((r: any) => Number(r.tersedia || 0) === 0).length;

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header icon={Layers} title="Stok Akun" sub="Ketersediaan stok akun digital per produk — urut yang paling menipis"
        right={
          <div className="flex items-center gap-2">
            <Chip tone={kritis > 0 ? "bad" : "ok"}>{kritis} produk habis</Chip>
            <Chip tone="info">{totalTersedia} akun siap jual</Chip>
            <SearchBox value={cari} onChange={setCari} placeholder="Cari produk…" />
          </div>
        } />
      {loading ? <Load /> : err ? <ErrBox msg={err} onRetry={reload} /> : (
        <Tabel
          kolom={[
            { k: "nama", label: "Produk", render: (r) => <span className="font-semibold text-[#1E1B2E]">{r.nama}</span> },
            { k: "kategori", label: "Kategori", render: (r) => <Chip tone="netral">{r.kategori}</Chip> },
            { k: "harga", label: "Harga", render: (r) => <span className="font-semibold">{rupiah(r.harga)}</span> },
            { k: "tersedia", label: "Tersedia", render: (r) => (
              <Chip tone={Number(r.tersedia) === 0 ? "bad" : Number(r.tersedia) <= 3 ? "warn" : "ok"}>
                {r.tersedia} dari {r.total}
              </Chip>
            ) },
          ]}
          rows={daftar}
          kosong="Belum ada produk akun."
        />
      )}
    </div>
  );
}
