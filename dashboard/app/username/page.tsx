"use client";
import { useState } from "react";
import { AtSign } from "lucide-react";
import { Chip, ErrBox, Header, Load, SearchBox, Tabel, useAdminList } from "@/components/ui/kit";

export default function UsernamePage() {
  const { rows, loading, err, reload } = useAdminList("/api/admin/usernames");
  const [cari, setCari] = useState("");
  const q = cari.trim().toLowerCase();
  const daftar = rows.filter((u: any) =>
    !q || `${u.username} ${u.nama} ${u.email}`.toLowerCase().includes(q));

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header icon={AtSign} title="Username Pengguna" sub="Semua username publik yang sudah diklaim — cek bentrok atau penyalahgunaan"
        right={
          <div className="flex items-center gap-2">
            <Chip tone="info">{rows.length} terpakai</Chip>
            <SearchBox value={cari} onChange={setCari} placeholder="Cari @username / nama / email…" />
          </div>
        } />
      {loading ? <Load /> : err ? <ErrBox msg={err} onRetry={reload} /> : (
        <Tabel
          kolom={[
            { k: "username", label: "Username", render: (u) => <span className="font-mono font-bold text-[#7C3AED]">@{u.username}</span> },
            { k: "nama", label: "Nama", render: (u) => <span className="font-semibold text-[#1E1B2E]">{u.nama}</span> },
            { k: "email", label: "Email", render: (u) => <span className="font-mono text-[11px]">{u.email}</span> },
            { k: "tier", label: "Tier", render: (u) => <Chip tone="netral">{u.tier}</Chip> },
            { k: "diblokir", label: "Status", render: (u) => <Chip tone={u.diblokir ? "bad" : "ok"}>{u.diblokir ? "diblokir" : "aktif"}</Chip> },
          ]}
          rows={daftar}
          kosong="Belum ada pengguna yang mengklaim username."
        />
      )}
    </div>
  );
}
