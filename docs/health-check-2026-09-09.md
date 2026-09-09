# Health Check & Perbaikan — XyCloudOrder
**Tanggal:** 2026-09-09 · Cabang: `main` (HEAD `v3.3k 3554801`)

## Status Terkini (setelah deploy)
- ✅ Perbaikan (endpoint push, halaman keuangan/live/push/statistik/analitik) di-commit & push ke `main`.
- ✅ Worker ter-deploy (`9862c7c5`) — `/api/admin/push` live, `/admin` launcher baru (tema terang).
- ✅ Dashboard **tema terang ala web xycloud.my.id** ter-deploy ke Cloudflare Pages (`xycloud-dashboard.pages.dev`) & Vercel (`dashboard-iota-ten-70`, alias `admin.xycloud.my.id` memakai Vercel).
- ✅ App Flutter: default tema **terang** (`Prefs.tema` default `terang`, `ThemeMode.light`). `XyTheme.light()` memakai token web yang sama. Push ke `main` memicu GitHub Actions `build-apk` → ambil APK dari **Artifacts** untuk tes visual per layar (SDK Flutter tidak tersedia di sandbox, jadi belum bisa di-build/analisa lokal).
- ⏳ Langkah berikut (fase B): tes APK di device; perbaiki layar yang masih memakai teks/permukaan gelap di luar aksen gradient ungu; audit `Colors.white` pada kartu terang; sinkron versi `pubspec` + `rilis` di D1 bila perlu.

## Ringkasan Status

| Lapisan | Status | Catatan |
|---|---|---|
| Backend Worker (live) | ✅ Hidup | `api.xycloud.my.id`, `xycloud.my.id`, `www.*`, `admin.*` semua HTTP 200 |
| Backend test suite | ✅ 9/9 lolos | 8 test lama + 1 test baru (`push_admin`) |
| Dashboard Next.js build | ✅ 38 halaman sukses | TS + lint + static generation bersih |
| App Flutter | ⚠️ Tidak diverifikasi | Flutter SDK tidak tersedia di sandbox |
| Endpoint `/api/admin/*` | ✅ Mayoritas ada | 3 halaman dashboard masih stub (sudah diperbaiki) |

---

## Yang Ditemukan "Ga Becus" & Status Perbaikan

### 1. Dashboard: 3 halaman masih stub TODO (DIPERBAIKI)
Commit sebelumnya membiarkan **Keuangan**, **Live Monitor**, dan **Push Notif** sebagai
placeholder ("TODO: fetch ...", "mock", tombol *"Kirim Sekarang (mock)"*).

**Perbaikan:**
- **`dashboard/app/keuangan/page.tsx`** — kini fetch asli `/api/admin/keuangan` +
  `/api/admin/stats` + `/api/admin/topup`. Kartu pendapatan/top-up/pending/pengguna,
  grafik tren pesanan 30 hari, daftar top-up tertunda, tombol **Export CSV**.
- **`dashboard/app/live/page.tsx`** — polling `/api/admin/unit` tiap 8 detik. Kartu agen
  dengan status ONLINE/OFFLINE (heartbeat < 90 dtk), bar CPU/RAM/GPU dari `spec` heartbeat
  `xy_agent.py`, RAM terpakai, umur heartbeat, badge sesi aktif.
- **`dashboard/app/push/page.tsx`** — builder push nyata: judul, pesan, kategori (tipe),
  target **semua user** (broadcast) atau **satu pengguna** (pilih dari daftar user),
  status hasil kirim.

### 2. Backend: endpoint `/api/admin/push` belum ada (DITAMBAHKAN)
`api/src/index.js` + `api/test/push_admin.test.mjs`:
- POST `/api/admin/push` → broadcast `siarkanPush` (segmen "Total Subscriptions")
  atau per-user `kirimPush` (validasi user ada di D1).
- Tipe notifikasi dipetakan ke channel Android (`promo/banner/order/sesi/wallet/akun/forum/...`).
- Audit: dicatat ke `log_admin`; hanya peran **pemilik** yang boleh (sesuai `HAK_PERAN`).
- Tanpa kredensial OneSignal → 502 dengan pesan jelas (bukan error tak dikenal).
- Test baru: tanpa kunci → 403, body kosong → 400, user tak dikenal → 404,
  tanpa kredensial → 502 (bukan 500).

### 3. Dashboard: halaman Statistik & Analitik tidak menampilkan data (DIPERBAIKI)
Keduanya memakai template "generic" yang menganggap respons berupa array lalu menampilkan
`Belum ada data` — padahal `/api/admin/statistik` dan `/api/admin/analitik` mengembalikan
**objek**. Kini dirender sungguhan:
- **Statistik** — 8 kartu ringkasan (pengguna, pesanan, omzet, saldo beredar, produk,
  unit PC, sesi aktif, forum) + tren pesanan & pengguna baru 30 hari + produk/paket terlaris.
- **Analitik** — total kunjungan 30 hari, tren harian, halaman terpopuler, perangkat, negara.

---

## Item Lain yang Masih Perlu Dikerjakan (ditemukan saat audit)

1. **`unit` page** — tombol *Tambah Paket* mem-POST ke `/api/admin/unit` yang tidak punya
   handler POST di Worker (balas "Endpoint admin tidak dikenal"). Unit fisik (tabel `agen`)
   sebaiknya halaman read-only; CRUD paket sudah ada di halaman `plans`.
2. **Halaman "generic" lain** (orders, users, banners, promosi, forum, cs, dll) masih
   merender JSON mentah dalam kartu. Berfungsi, tapi belum berupa UI terstruktur.
3. **Versi app tertinggal** — `app/pubspec.yaml` masih `2.6.0+20` padahal repo sudah v3.3j.
   Bila versi di D1 (`rilis`) di atas 2.6.0, popup pembaruan akan selalu muncul. Sinkronkan
   saat build APK berikutnya.
4. **Keamanan (docs/keamanan-audit.md) masih TODO:**
   - Admin key masih `localStorage` di dashboard (rentan XSS) — belum httpOnly cookie.
   - Tidak ada proxy `/api/admin` same-origin di Next.js (`dashboard/app/api/` kosong).
5. **Dep:** `next@14.2.5` punya celah keamanan (deprecated); upgrade disarankan.
6. **Docs ganda:** `PopupUpdate.md` vs `popupupdate.md` identik; README bagian atas
   "Pembaruan v2.6.0" sudah usang.
7. **Flutter** tidak bisa dianalisa di sandbox (SDK tak tersedia).

---

## Verifikasi Teknis
- `npm test` (api): **9/9 pass** — termasuk auth, sewa atomik, media, keamanan, push admin.
- `npm run build` (dashboard): **sukses, 38 rute statis**, tanpa error TypeScript.
- Endpoint live dicek: `/`, `/admin`, `/brand/logo.png`, `xycloud.my.id` storefront 200.

## Perubahan File
```
M api/src/index.js                     (+ endpoint POST /api/admin/push)
M dashboard/app/analitik/page.tsx      (render nyata data kunjungan)
M dashboard/app/keuangan/page.tsx      (dari stub → fetch + CSV)
M dashboard/app/live/page.tsx          (dari mock → polling agen)
M dashboard/app/push/page.tsx          (dari mock → builder push nyata)
M dashboard/app/statistik/page.tsx     (dari dump → ringkasan terstruktur)
A api/test/push_admin.test.mjs         (test endpoint baru)
```

## Hotfix lanjutan: "Global error — Node.removeChild"
- **Gejala:** halaman *Global error* `Node.removeChild: The node to be removed is not a child of this node` setelah login/navigasi.
- **Akar:** `app/login/layout.tsx` membuat `<html><body>` **kedua** yang bersarang di dalam `<body>` root layout (`body > html > body`). Saat React berpindah rute (login → `/`), pembongkaran node tidak valid → DOMException.
- **Fix:** hapus `app/login/layout.tsx` (Sidebar & AuthGuard di root sudah menangani `/login`). Terverifikasi: `out/login.html` kini 1 `<html>` + 1 `<body>`; sudah di-deploy ke Pages & Vercel.

## Fase B App (tema terang) — catatan audit
- `_MiniBtn` (translucent-putih, gaya dark) tidak terpakai — grid & hero app sudah token-aware (`XyTheme.of(context)`), sehingga default terang aman untuk sebagian besar layar.
- Aksen **dark-gradient** (header/hero `0xFF100030→0xFF7C3AED`) dibiarkan sebagai aksen brand (konsisten dgn kartu gradient violet di dashboard light).
- **Yang perlu dicek saat tes APK** (beri tahu layar yg bermasalah): `Colors.white` pada kartu terang, bilah status/teks pada `welcome`, `splash`, `shell` (bottom nav), `wallet`, `akun`, `cs`, `forum`; prioritas lihat tangkapan layar dari HP.
- Versi app dinaikkan `2.6.0+20 → 3.3.0+21` (artefak APK berikutnya terbaca versi baru; tidak ada tag release).

## Sudah Dieksekusi (persetujuan user)
- ✅ Git commit + push ke `main` (`v3.3k`)
- ✅ Deploy Worker (`wrangler deploy`) → `/api/admin/push` live di produksi
- ✅ Deploy dashboard ke Cloudflare Pages + Vercel (`dashboard-iota-ten-70` aliased) — `admin.xycloud.my.id` menampilkan tema terang baru
- ⏳ Deploy/finalisasi **app Flutter**: butuh build APK via GitHub Actions + tes device oleh user (lihat catatan fase B di atas)
