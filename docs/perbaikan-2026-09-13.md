# Perbaikan Batch A — 2026-09-13

Lanjutan audit menyeluruh (`/home/user/audit/AUDIT-XyCloudOrder-2026-09-13.md`).
Semua yang tercatat di sini **sudah dieksekusi**, bukan rencana.

Head setelah push: `b2d978e` (7 commit di atas `18e883c`).

---

## 1. Basis data produksi (D1)

| Tindakan | Hasil |
|---|---|
| Apply `migrations/0004_rilis_gambar_pembaruan.sql` (`ALTER TABLE rilis ADD COLUMN gambar TEXT`) | ✅ kolom ada, `simpanRilis()` tidak lagi gagal |
| Catat `0004` (hari ini) dan `0005` (tanggal commit aslinya) di `d1_migrations` | ✅ buku migrasi lengkap 0001–0005 |
| Uji bentuk INSERT `simpanRilis` (id=1, ON CONFLICT DO NOTHING) | ✅ lolos, data rilis lama utuh |
| Tutup sesi zombie `s_72252a148d7f` (status `siap`, `berakhir` NULL, 6 hari) | ✅ `selesai` |
| Lepas kunci unit `agen ag_01657b59d506` | ✅ `sesi_aktif` NULL |
| Tutup order kedaluwarsa `XY-7229` (`aktif` sejak 7 Sep, `berakhir` 8 Sep) | ✅ `selesai`; metode `legacy` jadi trigger refund tidak tersentuh (memang tidak boleh refund) |
| Buang host `runnervmvmocb` (COMPUTERNAME runner CI) dari agen `buat tes` | ✅ host NULL |
| Verifikasi ulang seluruh skema vs repository | ✅ **0 selisih** (42 tabel prod vs 41 repo; selisihnya hanya `d1_migrations`) |

Mode pemeliharaan **dibiarkan menyala** sesuai keputusan pemilik (produk belum rilis).

## 2. Kode — penyebab masalah diperbaiki, bukan gejalanya

### `api/src/sewa.js`
- `rawatSewa()` kini menutup empat keadaan macet yang dulu mengunci unit permanen:
  1. sesi tanpa `berakhir` padahal sudah ≥10 menit (kasus produksi 6 hari);
  2. sesi `mengakhiri` yang tidak pernah di-ACK agen (≥10 menit setelah waktunya) — dipaksa `tutupSewa()` dengan catatan;
  3. order `aktif`/`provisioning` yang sudah lewat `berakhir` → `selesai` + sesi ditutup + kunci `order:` dilepas;
  4. kunci unit yatim (menunjuk sesi/order yang sudah tidak ada).
- Reservasi order yang **masih terbuka** sengaja tidak dilepas, supaya unit tidak bisa direbut order lain (trigger `order_saldo_baru` memakai bentuk `order:<id>` sebelum sesi ada).
- `normalisasiHostStream()` menerima `host:port` dan `[ipv6]:port`. Lapisan native
  (`NativeStreaming.java#address`) memang mengurai `host:port` dan memakai port
  bawaan Sunshine bila kosong, tetapi validator lama menolak apa pun yang
  mengandung `:` sekaligus `.`, sehingga isian admin yang sah seperti
  `103.10.20.30:47989` dilaporkan “bukan IP/DNS publik”. Nama mesin lokal
  (`COMPUTERNAME`) tetap ditolak.

### `api/src/index.js`
- `/health` dipindah ke sebelum pemilihan rute berdasar host. Sebelumnya hanya
  hidup di `api.*`; di host cadangan dan di situs publik dibalas HTML 200 sehingga
  pemantau kesehatan selalu tampak hijau.

### `api/test/harness.mjs` + `api/test/skema_kode.test.mjs` (baru)
- Harness kini menerapkan `schema.sql` **lalu seluruh `migrations/*.sql`**
  berurutan (toleran kolom ganda). Sebelumnya migrasi tidak pernah dieksekusi CI.
- Uji baru: (a) tabel inti + kolom bekas-bekas terlewat + trigger keuangan harus ada;
  (b) setiap kolom `INSERT INTO … (…)` dan `UPDATE … SET …` di `api/src/*.js` harus
  ada di skema hasil migrasi (532 kolom diperiksa); (c) penomoran migrasi tidak melompat.

### `api/test/sewa_perawatan.test.mjs` (baru)
- Uji validator host (14 kasus) dan empat keadaan macet pembersih, dijalankan lewat
  heartbeat agen seperti jalur produksi, termasuk memastikan reservasi order
  terbuka tidak ikut dilepas.

### `tools/cek_skema_d1.py` (baru)
- Membandingkan tabel/kolom/trigger/index D1 **produksi** dengan `schema.sql`+migrasi,
  exit 1 bila ada selisih, `--fix` mencetak SQL perbaikan sambil menunjuk berkas
  migrasinya, `--fix --apply` menjalankannya. Sudah diverifikasi menangkap persis
  bug 0004 bila diulang. Skrip npm: `npm run db:check`.

### `tools/daftar_rilis.py`
- Kegagalan pendaftaran rilis kini `exit 1` (CI merah). Sebelumnya ditelan
  (`return 0`) sehingga lima hari CI hijau sementara server menyajikan rilis lama.

### `.github/workflows/build-apk.yml`
- Nama bundle sumber GPLv3 dibaca dari `app/pubspec.yaml` (`VERSI_APLIKASI`),
  bukan angka mati `2.6.0`.

### Aplikasi Flutter
- Aset baru `favorit.png`, `pc.png`, `order.png` (gaya 3D glosi ungu, latar
  transparan) untuk tiga layar v3.3 yang sebelumnya melempar
  “Unable to load asset” di perangkat pengguna.
- `XyIlustrasi` diberi `errorBuilder` → aset hilang jatuh ke ilustrasi `kosong`,
  dan bila `kosong` pun hilang jatuh ke ikon polos. Satu kelas bug tertutup permanen.
- `app/test/ilustrasi_asset_test.dart` memindai semua nama ilustrasi yang dirujuk
  kode dan memastikan berkasnya ada + folder terdaftar di `pubspec.yaml`.
- `XyConfig.waCs` placeholder `6281234567890` → `6283116632566` (sama dengan `WA_ADMIN`).

### Lain-lain
- `api/wrangler.toml`: `migrations_dir = "migrations"`; skrip npm
  `db:migrate`, `db:migrate:local`, `db:check`.
- `docs/popupupdate.md` (duplikat identik `PopupUpdate.md`) dihapus.
- Branch basi `native-integration-check` dihapus dari remote.

## 3. Hasil verifikasi

| Cek | Hasil |
|---|---|
| `npm test` di `api/` | **19/19 lolos** (sebelumnya 14) |
| YAML workflow, `package.json`, `wrangler.toml` | valid |
| Simulasi test ilustrasi (regex sama dengan test Dart) | 0 nama hilang |
| Skema produksi vs repo | 0 selisih |
| Push `main` | `18e883c..b2d978e`, CI `build-apk` + `deploy-dashboard` jalan |

## 4. Yang TIDAK bisa gw lakukan dengan token yang ada

- **Observability Worker**: `PUT …/workers/scripts/xycloud-api/settings` ditolak
  (`10405 Method not allowed for this authentication scheme`). Binding & secret
  diverifikasi tetap utuh (27 binding, 8 secret). Perlu dinyalakan dari dashboard
  Cloudflare → Worker `xycloud-api` → Settings → Observability, atau dengan token
  ber-izin *Workers Scripts: Edit*.
- Verifikasi nilai secret (`GOOGLE_CLIENT_SECRET`, `ONESIGNAL_API_KEY`) tidak
  terbaca lewat API — lihat bagian OneSignal di bawah.

## 5. OneSignal — hasil pengecekan (SELESAI penuh per 2026-09-13)

Ada **dua** app di akun OneSignal dan REST key-nya tidak saling tukar:

| App ID | Nama | REST key | FCM/Google | Dipakai proyek? |
|---|---|---|---|---|
| `f4843c35-…` | XyCloudStore | key baru (berlabel di berkas kredensial) | ✅ **FCM v1 terpasang** (service account project `xycloud-c19f1`) | ✅ ya (wrangler.toml, workflow, Flutter) |
| `e3d5adea-…` | XyDesk | key lama (berlabel di berkas kredensial) | ❌ belum | ❌ tidak |

Akar masalahnya: secret Worker `ONESIGNAL_API_KEY` berisi key milik **XyDesk**,
sehingga setiap kiriman push gagal autentikasi diam-diam sementara semua
konfigurasi lain (app ID di wrangler/workflow/Flutter, FCM) sudah benar.
Perbaikan yang sudah dijalankan:

1. Berkas kredensial dirapikan: blok `#ONESIGNAL` kini berlabel per-app
   (`App Id/Api Key XyCloudStore` dan `App Id/Api Key XyDesk`) + catatan.
2. Secret Worker `ONESIGNAL_API_KEY` **diset ulang lewat API**
   (`PUT /accounts/…/workers/scripts/xycloud-api/secrets`, berhasil) ke key
   XyCloudStore. Catatan: endpoint `PUT …/settings` ditolak token ini (kode
   10405), tetapi endpoint `/secrets` boleh — jadi set secret bisa otomatis,
   tidak perlu dashboard.
3. README dikoreksi soal keberadaan app kedua dan sifat key per-app.

Catatan verifikasi: field legacy `gcm_key`/`android_sender_id` memang kosong di
app XyCloudStore dan sempat disalahartikan sebagai “FCM belum dipasang”;
konfigurasi FCM v1 sebenarnya ada di field `fcm_v1_service_account_json` +
`fcm_sender_id`. Uji kirim ke segment `Subscribed Users` membalas
“All included players are not subscribed” karena saat ini **tidak ada perangkat
yang berlangganan** (36 player sisa tes lama sudah tidak aktif) — bukti
pengiriman akhir baru bisa dilakukan begitu ada perangkat nyata memasang APK.

## 6. Masih menunggu (Batch B, ditahan sampai APK dites)

- Build APK dari head baru → artifact Actions (bukan Release), sesuai alur
  “push build boleh, release jangan”.
- Pindahkan tag `apk-android` ke head + unggah 4 ABI + betulkan body rilis
  (body sekarang mengklaim `18e883c` padahal tag menunjuk `f626c87`).
- Gerakkan tag `agent-windows` ke head (agen 1.3.3) supaya link unduhan permanen
  tidak lagi menyajikan 1.3.2.
- Daftarkan rilis baru ke D1 (kini sudah mungkin karena kolom `gambar` ada).

## Batch D — Sosial, push kaya aksi, dan perbaikan build (malam)

### Backend (worker live via CI, migrasi 0007 sudah di D1 produksi)
- Endpoint baru: `GET /api/users/:id/profil`, `POST /api/users/:id/ikuti`,
  `GET /api/me/follows?arah=mengikuti|pengikut`, `GET/POST /api/dm/:id`,
  `POST /api/dm/:id/dibaca`, `POST /api/forum/:id/simpan` (toggle bookmark),
  `GET /api/me/simpan`, `POST /api/me/bisukan`.
- DM mendukung teks, gambar, dan pesan suara (m4a → Cloudinary `xycloudstore/dm`),
  realtime lewat DO `user:<id>` event `dm.baru`, rate limit 20 pesan/menit.
- `PATCH /api/me` kini menerima `bio` (maks 240) dan `banner`
  (whitelist: ungu, senja, midnight, permen, anggrek).
- Push balasan forum & DM kini membawa: `large_icon` foto profil pengirim,
  `android_accent_color` ungu, dan tombol aksi **Tandai dibaca / Balas /
  Bisukan 1 jam**. Bisukan disimpan server (`users.bisu_notif`) dan dihormati
  `threadBisu()` sebelum push DM/forum dikirim.
- `api/schema.sql` disinkronkan (kontrak harness); test baru `sosial.test.mjs`.
  Suite penuh 22/22 hijau.

### Flutter
- Layar baru: `ProfilPublikScreen` (banner tema gradien, bio, statistik,
  ikuti/kirim pesan), `DmChatScreen` (voice note tekan-tahan mic + geser batal
  ala CS, gambar, tanda dibaca ✓✓), `FollowsScreen` (Mengikuti/Pengikut +
  pintu DM per orang).
- `UbahProfilScreen`: bio (160 char) + pemilih tema banner visual.
- Forum: tap avatar/nama penulis → profil publik; tombol Simpan (bookmark)
  di kartu posting; state bookmark di AppState (optimis + rollback).
- `shell._tanganiNotif`: aksi push `baca` (tandai DM dibaca), `balas`
  (buka DM/CS), `bisukan` (POST /me/bisukan 60 menit), tipe `dm` → DmChat.
- Profil: menu baru "Profil Publik" dan "Mengikuti & Pesan".

### Perbaikan build yang sempat merah sejak Batch C
- `XyRadius.pill` terdefinisi dua kali (99 & 100) → error `duplicate_definition`
  (regresi normalisasi radius C5). Dihapus duplikatnya.
- `padStart` (istilah JS) di `blokir_screen.dart` → `padLeft`.
- `stiker_storage_test` masih mencari `index.xys`/`<id>.xys` padahal Batch C
  menyamarkan jadi `index.byscrt`/`<sha>.webp.byscrt` → test diselaraskan.
- Hasil: Analyze ✅ Test ✅ Build ✅ — artifact APK: universal, arm64-v8a,
  **armeabi-v7a**, x86_64, + Sumber GPL (run 34785495619, head 5d9187b).
- Release/tag (`apk-android`, `agent-windows`) DITAHAN sampai pemilik tes APK,
  sesuai kesepakatan.

## Batch D lanjutan — menutup sisa antrian (release tetap ditahan)

### Backend (migrasi 0008 sudah live di D1 produksi)
- Kolom `users.notif_dm` (default 1): toggle push DM per pengguna;
  `PATCH /api/me` menerima `notif_dm`; push DM melewati penerima yang
  mematikannya (selain hormati `threadBisu`).
- `GET /api/me/bisukan`: daftar thread yang sedang dibisukan (untuk
  manajemen di Settings); `POST menit=0` = nyalakan lagi.
- Test sosial diperluas (notif_dm + bisukan). Suite 22/22 hijau.

### Flutter
- Forum: tombol bookmark di app bar → filter "Hanya yang disimpan"
  (menutup celah: simpan ada tapi tidak bisa dilihat).
- Profil sendiri: header kini memakai **tema banner pilihan pengguna**
  (gradien XyBannerTema) + bio tampil di bawah email.
- Settings → Notifikasi: kartu toggle **Pesan Langsung** + kartu
  **Sedang dibisukan** (daftar thread, sisa waktu, tombol nyalakan lagi).
- Settings → Data: "Bersihkan Sekarang" kini juga mengosongkan cache
  gambar (flutter_cache_manager + imageCache memori).
- Model/repo/AppState: `notifDm`, `bisukanDaftar()`, `BisukanItem`.

### Optimasi (butir 7 Batch D) — ringkasan yang sudah terpasang
- DM: LIMIT 50 + index `idx_dm_dari/ke`, polling 6 detik hanya saat layar
  terbuka, gambar di-encode max 1200px q82, audio m4a 32kbps mono.
- Gambar jaringan lewat `AppImage` dengan `memCacheWidth` (decode seukuran
  tampilan, hemat RAM).
- Push: penerima yang bisu/mematikan notif DM tidak dikirimi (hemat kuota
  OneSignal + tidak mengganggu).
- Cache offline bisa dibersihkan penuh dari Settings → Data.

### Status antrian
- Batch D butir 1–9: **selesai semua**.
- Batch B (tag `apk-android`, `agent-windows`, `simpanRilis`): **DITAHAN**
  atas instruksi pemilik — tunggu seluruh antrian beres + tes APK.

## Batch E — SEO, dashboard 10 menu baru, username & filter kata, WebP (2026-09-14)

### SEO (xycloud.my.id)
- Worker kini melayani `/google8d6555ceced0c8e7.html` (verifikasi Google
  Search Console) dan `/robots.txt` — tetap hidup walau mode pemeliharaan.
- Dashboard → menu **SEO & Situs**: pemeriksaan langsung (berkas verifikasi,
  robots, halaman utama, status maintenance) + panduan langkah GSC.

### Dashboard admin
- **Checkbox jelas**: bug CSS `input.xy-check:checked` — `background-image`
  menimpa gradasi sehingga centang putih tak terlihat ("cuma berubah warna").
  Kini dua lapisan dalam satu deklarasi + hover/focus ring; `.xy-check` kit
  membesar (19px, border 2px, gradasi + glow saat aktif); opsi `Select` aktif
  dapat tanda ✓; trigger select terbuka dapat ring ungu.
- **Banner bisa diedit**: halaman Banner ditulis ulang — buat/ubah/hapus,
  pratinjau langsung, pemilih warna, urutan, ikon, CTA, aksi, target, unggah
  gambar (otomatis WebP), toggle aktif, dan kirim push promo saat membuat.
- **10 menu baru berfungsi penuh**: Banding Akun, Laporan Pengguna,
  Agen Windows, Mode Pemeliharaan (+ pengecualian), SEO & Situs, Stok Akun,
  Database (jumlah baris per tabel), Statistik Push (OneSignal), Username,
  Kata Terlarang (+ penguji teks).
- Endpoint admin baru: `stok`, `dbinfo`, `usernames`, `kata`, `uji-kata`,
  `push/statistik`.

### Backend
- Migrasi 0009 (live di produksi): `users.username` + index unik parsial.
- `POST /api/cek-nama`: kebersihan nama & ketersediaan username (dipakai
  layar Ubah Profil dengan debounce).
- `PATCH /api/me` menerima `username` (3–20 karakter `[a-z0-9_.]`, unik,
  bebas kata terlarang; string kosong = hapus username).
- Filter kata terlarang identitas (`src/kata.js`): kasar + SARA + porno,
  tahan leetspeak & pemisah (a.n.j.i.n.g); kata ≤3 huruf hanya dicocokkan
  utuh supaya "Nasution" tidak terjaring "asu". Ditegakkan di register,
  PATCH me (nama/bio/username).
- Filter konten (`src/moderasi.js`) diperluas kategori SARA & porno
  (forum/ulasan sudah memakai modul ini).
- `POST /api/users/:id/lapor`: laporan antar-pengguna → tabel `laporan`
  (jenis `pengguna`) → muncul di dashboard Laporan & Moderasi.
- **Semua unggahan gambar otomatis WebP** (`quality:auto`) di Cloudinary;
  GIF dibiarkan agar animasi aman. Berlaku untuk profil, forum, DM, ulasan,
  bukti topup, banner, stiker.
- Profil publik kini menyertakan `username`.
- Test: 22/22 hijau (sosial diperluas: cek-nama, username unik 409, kata
  terlarang 422, "Nasution" lolos, lapor pengguna 201/422).

### Flutter
- Ubah Profil: field **Username** dengan cek ketersediaan live (debounce
  650 ms): spinner → centang hijau "Username tersedia!" / merah + alasannya
  (dipakai / kata terlarang / format salah).
- Profil publik: `@username` di bawah nama + tombol **Laporkan pengguna**
  (bottom sheet: kategori SARA/porno/pelecehan/spam/lainnya + rincian).
- Model/repo/AppState: `username`, `cekNama`, `laporPengguna`.
