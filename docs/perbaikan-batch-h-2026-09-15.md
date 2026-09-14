# Batch H — 2026-09-15

Rangkuman perbaikan Batch H (11 butir permintaan pemilik). Semua perubahan
sudah di-push ke `main` dan worker sudah di-deploy.

## Commit

| Commit | Isi |
| --- | --- |
| `f658b04` | Worker: akun diblokir → token terbatas + layar Blokir; deteksi negara di `/api/config`; halaman maintenance web baru (aurora). |
| `b1b6318` | App: onboarding Lengkapi Profil; consent login + negara; profil dirapikan; tinggi tombol; promo floating snap tepi & hingga 4. |
| `252cd0f` | App fix: pakai `LegalScreen` publik dari `legal_screen.dart` (hapus duplikat privat di `tentang_screen.dart`). |
| `c347ddb` | Worker: `/api/legal/*` lolos gate pemeliharaan (tautan persetujuan login harus terbaca tanpa token). Deploy wrangler Version `316417d1`. |

## Butir permintaan → penyelesaian

1. **Cek backend normal** — `/health` ok; D1 sehat; 22/22 unit test worker lolos
   (lokal + CI). Banner dashboard "invalid signed" diperbaiki lebih dulu dengan
   menulis ulang secret `CLOUDINARY_KEY`/`CLOUDINARY_SECRET` di worker
   (upload tes terbukti sukses, gambar tes dihapus lagi).
2. **Blokir/pelanggaran → halaman khusus, bukan redirect login** — login (email
   maupun Google) untuk akun diblokir kini menghasilkan *token terbatas*;
   semua endpoint lain balas 403 kecuali `cs/*`, `notifikasi*`, `me`,
   `me/blokir`, `me/banding`. Gate root `main.dart`:
   `!masuk → FlowGate; diblokir → BlokirScreen; username kosong →
   LengkapiProfilScreen; selain itu → XyShell`. Tidak ada lagi jatuh ke
   onboarding/login atau sekadar toast "AKUN DIBLOKIR".
3. **Tinggi tombol** — default `GradientButton` 56 → 48; tombol dialog
   konfirmasi/beritahu (`lembar.dart`) 50 → 46 (5 titik); tombol sosial login
   52 → 48; CTA `order_detail` 52 → 48; CTA welcome 54 → 48.
4. **Profil dirapikan + pensil edit** — header profil: ikon pensil di pojok
   kanan atas (melingkar, glass) → `UbahProfilScreen`; `@username` tampil di
   bawah email. Menu profil dikelompokkan jadi 4 seksi: **Akun** (ubah profil,
   profil publik, keamanan, aktivitas), **Komunitas** (mengikuti & pesan,
   leaderboard, tier), **Transaksi** (dompet, pesanan, voucher, favorit,
   statistik, undang teman, unit live), **Aplikasi** (pengaturan, tema,
   pembaruan, tentang, bantuan, hapus akun). Pengaturan utama sudah berseksi
   rapi (Akun/Tampilan/Aplikasi/Sesi/Legal/Lainnya) — dipertahankan.
5. **Promo floating** — lepas geser → snap ke tepi terdekat (kiri 8px atau
   kanan max) dengan `AnimatedPositioned` 240 ms; posisi tersimpan per promo;
   jumlah floating naik dari 2 → 4.
6. **Consent login + negara** — `/api/config` kini membalas
   `negara: {kode, nama}` (deteksi `CF-IPCountry`, peta `NAMA_NEGARA`,
   fallback Indonesia). Layar login menampilkan: "Dengan masuk atau
   mendaftar, kamu menyetujui **Ketentuan Layanan** dan **Kebijakan
   Privasi**. Akun kamu berasal dari 🇮🇩 Indonesia (terdeteksi otomatis dari
   jaringan)." Tautan membuka `LegalScreen` publik; bendera dirakit dari kode
   ISO-2 (fallback 🌐).
7. **Onboarding setelah daftar/login (termasuk Google)** — layar baru
   `LengkapiProfilScreen` (gate root saat `username` kosong): foto profil
   (galeri, kompres 700px q80), nama, username publik (validasi 3–20,
   `[a-z0-9_.]`, cek unik via `PATCH /me` server), nomor WhatsApp opsional.
   `PopScope(canPop: false)` — tidak bisa dilewati; setelah simpan,
   `perbaruiProfil` memuat ulang user dan gate otomatis lanjut ke aplikasi.
8. **Maintenance menutup semua app** — gate root penuh di `main.dart`
   (FlowGate menangani cakupan pemeliharaan untuk app); `pemeliharaan_bebas`
   produksi = `[]`.
9. **Maintenance web** — template baru: latar aurora 4 blob + bintang
   berkedip, kartu glass, tombol shimmer, meter progres, **footer tetap**
   (© 2026 + tautan `/legal/syarat`, `/legal/privasi`, `/legal/refund`),
   dukungan `prefers-reduced-motion`. robots.txt & sitemap.xml tetap 200.
10. **`/api/legal/*` lolos gate** — dokumen legal adalah konten publik yang
    dibutuhkan layar persetujuan login (anonim); sebelumnya kena 503 saat
    mode pemeliharaan.
11. **CI** — `flutter analyze` + `flutter test` hijau pada `252cd0f`; build
    APK (universal + 3 ABI) berjalan pada run `c347ddb`.

## Verifikasi produksi (pasca-deploy `316417d1`)

- `GET https://api.xycloud.my.id/api/config` → `negara` ada (dari IP US:
  `{"kode":"US","nama":"Amerika Serikat"}`).
- `GET /api/legal/syarat` & `/api/legal/privasi` → 200 dengan dokumen penuh
  (tanpa token, saat maintenance aktif).
- `GET /health` → ok. `https://xycloud.my.id/` → halaman maintenance baru,
  tautan footer legal 200. robots.txt/sitemap.xml 200.

## Catatan rilis

Batch B tetap ditahan: tidak ada tag `apk-android`/`agent-windows`, tidak ada
`simpanRilis` — menunggu pengujian APK oleh pemilik dan instruksi rilis
eksplisit.
