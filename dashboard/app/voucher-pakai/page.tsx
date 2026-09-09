"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { ReceiptText } from "lucide-react";
import { Chip, ErrBox, Header, jam, Load, rupiah, Tabel } from "@/components/ui/kit";

export default function VoucherPakaiPage() {
  const [rows, setRows] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");

  useEffect(() => {
    adminFetch("/api/admin/voucher-pakai")
      .then((d) => setRows(Array.isArray(d) ? d : []))
      .catch((e) => setErr(e.message))
      .finally(() => setLoading(false));
  }, []);

  const potongan = rows.reduce((a, r) => a + Number(r.potongan || 0), 0);

  return (
    <div className="space-y-4 font-[Plus_Jakarta_Sans]">
      <Header icon={ReceiptText} title="Voucher Terpakai" sub="Riwayat pemakaian kode voucher di pesanan"
        right={
          <div className="flex gap-2">
            <span className="text-xs px-3 py-1.5 rounded-full bg-emerald-500/15 border border-emerald-500/30 text-emerald-700 font-bold">{rupiah(potongan)} dipotong</span>
            <span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{rows.length} pemakaian</span>
          </div>
        } />
      {loading ? <Load /> : err ? <ErrBox msg={err} /> : (
        <Tabel kosong="Belum ada pemakaian voucher."
          kolom={[
            { k: "kode", label: "Kode", render: (r) => <span className="font-mono font-bold text-[#1E1B2E]">{r.kode}</span> },
            { k: "user", label: "Pengguna", render: (r) => <div><div className="font-bold text-[#1E1B2E]">{r.user_nama || "—"}</div><div className="text-[10.5px] font-mono text-[#7C738F]">{r.user_email || r.user_id}</div></div> },
            { k: "potongan", label: "Potongan", render: (r) => <span className="font-bold text-emerald-600">-{rupiah(r.potongan)}</span> },
            { k: "ref", label: "Ref pesanan", render: (r) => <span className="font-mono text-[11px] text-[#7C738F]">{r.ref_id || "—"}</span> },
            { k: "waktu", label: "Waktu", render: (r) => <span className="text-[11px] font-mono text-[#7C738F]">{jam(r.waktu)}</span> },
            { k: "id", label: "Id", render: (r) => <Chip tone="netral">{String(r.id).slice(0, 14)}</Chip> },
          ]}
          rows={rows} />
      )}
    </div>
  );
}
