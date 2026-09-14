"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { Image as ImageIcon, Power, Pencil, Trash2, Plus, X } from "lucide-react";
import { Btn, Chip, ErrBox, Field, Header, Input, Load, Panel, TextArea, Toggle, Check, FileField } from "@/components/ui/kit";
import { konfirm, toast } from "@/components/ui/dialog";

/** Formulir banner kosong untuk membuat baru. */
function kosongForm() {
  return {
    id: "",
    judul: "",
    subjudul: "",
    label: "",
    cta: "Lihat",
    aksi: "sewa",
    target: "",
    warna1: "#7C3AED",
    warna2: "#5B21B6",
    ikon: "bolt",
    urutan: "0",
    aktif: true,
    gambar: "",       // URL yang sudah tersimpan
    gambarBaru: "",   // data URI hasil unggah (mengalahkan gambar lama)
    kirimPush: false,
  };
}
type Form = ReturnType<typeof kosongForm>;

export default function BannersPage() {
  const [rows, setRows] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");
  const [saving, setSaving] = useState<string | null>(null);

  // panel editor
  const [form, setForm] = useState<Form | null>(null);
  const [busy, setBusy] = useState(false);

  async function muat() {
    setLoading(true); setErr("");
    try { setRows(await adminFetch("/api/admin/banners")); }
    catch (e: any) { setErr(e.message); }
    finally { setLoading(false); }
  }
  useEffect(() => { muat(); }, []);

  function set<K extends keyof Form>(k: K, v: Form[K]) {
    setForm((f) => (f ? { ...f, [k]: v } : f));
  }

  function mulaiEdit(b?: any) {
    setForm(b ? {
      id: b.id, judul: b.judul || "", subjudul: b.subjudul || "", label: b.label || "",
      cta: b.cta || "Lihat", aksi: b.aksi || "sewa", target: b.target || "",
      warna1: b.warna1 || "#7C3AED", warna2: b.warna2 || "#5B21B6",
      ikon: b.ikon || "bolt", urutan: String(b.urutan ?? 0), aktif: !!b.aktif,
      gambar: b.gambar || "", gambarBaru: "", kirimPush: false,
    } : kosongForm());
  }

  async function pilihGambar(f: File | null) {
    if (!f) { set("gambarBaru", ""); return; }
    if (f.size > 4 * 1024 * 1024) { toast("Gambar maksimal 4 MB.", "err"); return; }
    const reader = new FileReader();
    reader.onload = () => set("gambarBaru", String(reader.result || ""));
    reader.readAsDataURL(f);
  }

  async function simpan() {
    if (!form) return;
    if (form.judul.trim().length < 3) { toast("Judul minimal 3 karakter.", "err"); return; }
    setBusy(true);
    try {
      await adminFetch("/api/admin/banners", {
        method: "POST",
        body: {
          ...(form.id ? { id: form.id } : {}),
          judul: form.judul.trim(), subjudul: form.subjudul, label: form.label, cta: form.cta,
          aksi: form.aksi, target: form.target, warna1: form.warna1, warna2: form.warna2,
          ikon: form.ikon, urutan: Number(form.urutan) || 0, aktif: form.aktif ? 1 : 0,
          gambar: form.gambarBaru || form.gambar || "",
          ...(form.kirimPush ? { kirimPush: true } : {}),
        },
      });
      toast(form.id ? "Banner diperbarui." : "Banner dibuat.");
      setForm(null);
      await muat();
    } catch (e: any) { toast(e.message || "Gagal menyimpan banner.", "err"); }
    finally { setBusy(false); }
  }

  async function hapus(b: any) {
    const yakin = await konfirm({
      judul: "Hapus banner?",
      pesan: `Banner "${b.judul}" akan dihapus permanen dari carousel aplikasi & web.`,
      okLabel: "Hapus", bahaya: true,
    });
    if (!yakin) return;
    setSaving(b.id);
    try {
      await adminFetch(`/api/admin/banners/${b.id}`, { method: "DELETE" });
      toast("Banner dihapus.");
      await muat();
    } catch (e: any) { toast(e.message || "Gagal menghapus.", "err"); }
    finally { setSaving(null); }
  }

  async function toggleAktif(b: any) {
    setSaving(b.id); setErr("");
    try {
      // endpoint POST bersifat upsert (INSERT OR REPLACE by id) — pakai utk toggle aktif.
      await adminFetch("/api/admin/banners", {
        method: "POST",
        body: {
          id: b.id, judul: b.judul, subjudul: b.subjudul, label: b.label, cta: b.cta,
          aksi: b.aksi, target: b.target, warna1: b.warna1, warna2: b.warna2,
          ikon: b.ikon, urutan: b.urutan, aktif: b.aktif ? 0 : 1, gambar: b.gambar || "",
        },
      });
      await muat();
    } catch (e: any) { setErr(e.message); }
    finally { setSaving(null); }
  }

  const pratinjau = form
    ? (form.gambarBaru || form.gambar
      ? { backgroundImage: `url(${form.gambarBaru || form.gambar})`, backgroundSize: "cover", backgroundPosition: "center" }
      : { background: `linear-gradient(120deg, ${form.warna1}, ${form.warna2})` })
    : undefined;

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header icon={ImageIcon} title="Banner" sub="Carousel banner beranda aplikasi & web — buat, ubah, urutkan, dan aktifkan"
        right={
          <div className="flex items-center gap-2">
            <span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{rows.length} banner</span>
            <Btn onClick={() => mulaiEdit()}><Plus size={14} /> Tambah Banner</Btn>
          </div>
        } />
      {loading ? <Load /> : err ? <ErrBox msg={err} onRetry={muat} /> : rows.length === 0 ? (
        <div className="xy-card rounded-[20px] p-10 text-center text-[#7C738F] font-medium">
          Belum ada banner. <button className="text-[#7C3AED] font-semibold underline" onClick={() => mulaiEdit()}>Buat yang pertama</button>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-3">
          {rows.map((b) => {
            const style = b.gambar
              ? undefined
              : { background: `linear-gradient(120deg, ${b.warna1 || "#7C3AED"}, ${b.warna2 || "#5B21B6"})` };
            return (
              <div key={b.id} className="xy-card rounded-[20px] overflow-hidden">
                <div className="h-28 flex items-center justify-center overflow-hidden relative" style={style}>
                  {b.gambar ? <img src={b.gambar} alt={b.judul} className="w-full h-full object-cover" /> : (
                    <span className="text-white font-semibold text-[16px] px-4 text-center">{b.judul}</span>
                  )}
                  <span className="absolute top-2 right-2 text-[10px] font-bold px-2 py-0.5 rounded-full bg-black/35 text-white">#{b.urutan}</span>
                </div>
                <div className="p-4">
                  <div className="flex items-start justify-between gap-2">
                    <div className="min-w-0">
                      <div className="text-[13.5px] font-semibold text-[#1E1B2E] truncate">{b.judul}</div>
                      {b.subjudul && <div className="text-[11px] text-[#7C738F] truncate">{b.subjudul}</div>}
                      <div className="mt-1.5 flex items-center gap-1.5 flex-wrap">
                        <Chip tone="netral">{b.label || "no label"}</Chip>
                        <Chip tone="info">aksi: {b.aksi || "-"}</Chip>
                        <Chip tone={b.aktif ? "ok" : "netral"}>{b.aktif ? "aktif" : "nonaktif"}</Chip>
                      </div>
                    </div>
                    <div className="flex flex-col gap-1.5 shrink-0">
                      <button
                        onClick={() => toggleAktif(b)} disabled={saving === b.id}
                        title={b.aktif ? "Nonaktifkan" : "Aktifkan"}
                        className={`p-2 rounded-xl border transition ${b.aktif ? "bg-emerald-500/15 border-emerald-500/30 text-emerald-600" : "bg-[#F3F0FF] border-[#E9E3F5] text-[#B9AECF]"}`}>
                        <Power size={14} />
                      </button>
                      <button
                        onClick={() => mulaiEdit(b)}
                        title="Ubah banner"
                        className="p-2 rounded-xl border bg-[#F3F0FF] border-[#E9E3F5] text-[#7C3AED] transition hover:border-[#C4B5FD]">
                        <Pencil size={14} />
                      </button>
                      <button
                        onClick={() => hapus(b)} disabled={saving === b.id}
                        title="Hapus banner"
                        className="p-2 rounded-xl border bg-rose-500/10 border-rose-500/25 text-rose-600 transition hover:border-rose-400">
                        <Trash2 size={14} />
                      </button>
                    </div>
                  </div>
                  <div className="mt-2 text-[10.5px] text-[#7C738F] font-mono break-all">{b.target || "—"}</div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      <Panel open={!!form} title={form?.id ? "Ubah Banner" : "Banner Baru"} onClose={() => setForm(null)} width="max-w-lg">
        {form && (
          <div className="space-y-4">
            {/* pratinjau langsung */}
            <div className="h-28 rounded-[16px] flex items-center justify-center overflow-hidden relative border border-[#E9E3F5]" style={pratinjau}>
              {!form.gambarBaru && !form.gambar && (
                <span className="text-white font-semibold text-[15px] px-4 text-center">{form.judul || "Judul banner"}</span>
              )}
              {(form.gambarBaru || form.gambar) && (
                <button
                  className="absolute top-2 right-2 p-1.5 rounded-full bg-black/50 text-white"
                  title="Hapus gambar"
                  onClick={() => { set("gambarBaru", ""); set("gambar", ""); }}>
                  <X size={12} />
                </button>
              )}
              <span className="absolute bottom-2 left-3 text-[10px] font-bold text-white/90 bg-black/30 rounded-full px-2 py-0.5">Pratinjau</span>
            </div>

            <Field label="Judul"><Input value={form.judul} onChange={(e) => set("judul", e.target.value)} placeholder="Contoh: Promo Merdeka 50%" /></Field>
            <Field label="Subjudul"><Input value={form.subjudul} onChange={(e) => set("subjudul", e.target.value)} placeholder="Deskripsi singkat (opsional)" /></Field>
            <div className="grid grid-cols-2 gap-3">
              <Field label="Label chip"><Input value={form.label} onChange={(e) => set("label", e.target.value)} placeholder="PROMO" /></Field>
              <Field label="Teks tombol (CTA)"><Input value={form.cta} onChange={(e) => set("cta", e.target.value)} placeholder="Lihat" /></Field>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <Field label="Aksi saat diklik">
                <Input value={form.aksi} onChange={(e) => set("aksi", e.target.value)} placeholder="sewa | produk | akun | forum | voucher | url" />
              </Field>
              <Field label="Target (id / URL)"><Input value={form.target} onChange={(e) => set("target", e.target.value)} placeholder="kosongkan bila tidak perlu" /></Field>
            </div>
            <div className="grid grid-cols-3 gap-3">
              <Field label="Warna 1">
                <div className="flex items-center gap-2">
                  <input type="color" value={form.warna1} onChange={(e) => set("warna1", e.target.value)} className="h-9 w-10 rounded-lg border border-[#E9E3F5] cursor-pointer bg-white p-1" />
                  <span className="text-[11px] font-mono text-[#7C738F]">{form.warna1}</span>
                </div>
              </Field>
              <Field label="Warna 2">
                <div className="flex items-center gap-2">
                  <input type="color" value={form.warna2} onChange={(e) => set("warna2", e.target.value)} className="h-9 w-10 rounded-lg border border-[#E9E3F5] cursor-pointer bg-white p-1" />
                  <span className="text-[11px] font-mono text-[#7C738F]">{form.warna2}</span>
                </div>
              </Field>
              <Field label="Urutan"><Input type="number" value={form.urutan} onChange={(e) => set("urutan", e.target.value)} /></Field>
            </div>
            <Field label="Ikon"><Input value={form.ikon} onChange={(e) => set("ikon", e.target.value)} placeholder="bolt | gift | gamepad | cpu" /></Field>
            <FileField
              label="Gambar latar (opsional — otomatis dikompresi ke WebP)"
              accept="image/png,image/jpeg,image/webp"
              onFile={pilihGambar}
              hint="PNG/JPEG/WebP maks 4 MB. Kosongkan untuk memakai gradasi warna."
            />
            <div className="flex items-center justify-between gap-4 pt-1">
              <Toggle checked={form.aktif} onChange={(v) => set("aktif", v)} label="Banner aktif" />
              {!form.id && <Check checked={form.kirimPush} onChange={(v) => set("kirimPush", v)} label="Kirim push promo saat dibuat" />}
            </div>
            <div className="flex gap-2 pt-2">
              <Btn onClick={simpan} disabled={busy} className="flex-1">{busy ? "Menyimpan…" : form.id ? "Simpan Perubahan" : "Buat Banner"}</Btn>
              <Btn tone="ghost" onClick={() => setForm(null)} disabled={busy}>Batal</Btn>
            </div>
          </div>
        )}
      </Panel>
    </div>
  );
}
