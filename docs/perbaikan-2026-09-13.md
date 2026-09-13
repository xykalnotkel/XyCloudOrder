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

## 5. OneSignal — hasil pengecekan (butuh keputusan)

REST key pada berkas kredensial **bukan** milik app yang terpasang di Worker:

| App ID | Nama | REST key di berkas | FCM/Google |
|---|---|---|---|
| `f4843c35-…` (terpasang di `wrangler.toml` + binding live) | XyCloudStore | ❌ ditolak (*access denied*) | dipasang menurut README |
| `e3d5adea-…` (di berkas kredensial) | **XyDesk** | ✅ cocok | ❌ **belum ada** (`gcm_key` kosong) |

Artinya saat ini salah satu dari dua hal benar: secret `ONESIGNAL_API_KEY` di
Worker adalah key lama yang cocok dengan `f4843c35` (push jalan), atau push mati.
Dan app `XyDesk` belum bisa mengirim push Android sama sekali sebelum service
account FCM dipasang di dashboard OneSignal.

Rekomendasi: pilih satu app. Kalau `XyDesk` yang dilanjutkan → pasang FCM service
account di OneSignal, lalu samakan `ONESIGNAL_APP_ID` di `api/wrangler.toml`,
`--dart-define=XY_ONESIGNAL_APP_ID` di `build-apk.yml`, dan secret
`ONESIGNAL_API_KEY`. Gw tunggu keputusan sebelum menyentuh apa pun di sini.

## 6. Masih menunggu (Batch B, ditahan sampai APK dites)

- Build APK dari head baru → artifact Actions (bukan Release), sesuai alur
  “push build boleh, release jangan”.
- Pindahkan tag `apk-android` ke head + unggah 4 ABI + betulkan body rilis
  (body sekarang mengklaim `18e883c` padahal tag menunjuk `f626c87`).
- Gerakkan tag `agent-windows` ke head (agen 1.3.3) supaya link unduhan permanen
  tidak lagi menyajikan 1.3.2.
- Daftarkan rilis baru ke D1 (kini sudah mungkin karena kolom `gambar` ada).
