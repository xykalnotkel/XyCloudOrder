"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { Heart, Star } from "lucide-react";
import {
  Chip, EmptyBox, ErrBox, Header, Load, Stat,
} from "@/components/ui/kit";

export default function FavoritPage() {
  const [data, setData] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");

  useEffect(() => {
    adminFetch("/api/admin/favorit")
      .then(setData)
      .catch((e) => setErr(e.message))
      .finally(() => setLoading(false));
  }, []);

  const top: any[] = data?.top || [];

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header
        icon={Heart}
        title="Favorit"
        sub="Agregasi wishlist pengguna (produk / paket)"
      />

      {err && <ErrBox msg={err} />}
      {loading ? <Load /> : (
        <>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
            <Stat label="Total wishlist item" value={data?.total ?? 0} tone="info" />
            <Stat label="Produk top favorit" value={data?.produk_top || top[0]?.nama || "—"} />
            <Stat label="Varian unik" value={top.length} sub="ref di top 50" />
          </div>

          {top.length === 0 ? (
            <EmptyBox msg="Belum ada data favorit." sub="Muncul saat user menandai favorit di app." />
          ) : (
            <div className="xy-card rounded-[20px] overflow-x-auto">
              <table className="w-full text-left text-[12.5px] min-w-[520px]">
                <thead>
                  <tr className="border-b border-[#E9E3F5] bg-[#F5F3FF]">
                    {["#", "Nama", "Jenis", "Ref", "Jumlah"].map((h) => (
                      <th key={h} className="px-4 py-2.5 text-[10.5px] uppercase tracking-wider text-[#7C738F] font-bold">{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {top.map((r, i) => (
                    <tr key={`${r.jenis}-${r.ref_id}-${i}`} className="border-b border-[#F0EDFB] last:border-0">
                      <td className="px-4 py-3 font-bold text-[#7C738F]">{i + 1}</td>
                      <td className="px-4 py-3 font-bold text-[#1E1B2E] flex items-center gap-2">
                        {i === 0 && <Star size={13} className="text-amber-500" />}
                        {r.nama || r.ref_id}
                      </td>
                      <td className="px-4 py-3"><Chip tone="netral">{r.jenis || "item"}</Chip></td>
                      <td className="px-4 py-3 font-mono text-[11px] text-[#7C738F]">{r.ref_id}</td>
                      <td className="px-4 py-3 font-black text-[#7C3AED]">{r.jumlah}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </>
      )}
    </div>
  );
}
