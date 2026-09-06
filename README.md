# XyCloudStore — Premium Edition

Aplikasi **Flutter (Android)** untuk layanan XyCloud: **Sewa PC Cloud**, **Beli Akun Digital**, **Customer Service realtime**, **Riwayat Order**, dan **Dompet** — terhubung ke backend **Cloudflare Workers + D1 + Durable Objects**.

Desain: modern, clean, quick. Tanpa satu pun emoji — seluruh ikon memakai sistem ikon vektor (Material Icons di Flutter, SVG kustom di preview).

**Preview interaktif:** buka `preview/xycloudorder-preview.html` di browser. Alurnya lengkap: Splash → Onboarding → Welcome → Login → Aplikasi.

---

## Isi Repository

```
xycloud/
├─ app/                              Aplikasi Flutter
│  ├─ pubspec.yaml                   deps + config icon & native splash
│  ├─ assets/brand/                  logo, adaptive icon, splash mark (PNG)
│  ├─ test/app_test.dart
│  └─ lib/
│     ├─ main.dart
│     ├─ core/     config, theme (design system), motion, prefs, format
│     ├─ models/   UserProfile, PcPlan, RentOrder, AkunProduk, ChatMessage
│     ├─ data/     api_client, realtime_service, repository, mock_data
│     ├─ providers/app_state.dart
│     └─ ui/
│        ├─ widgets/common.dart      XyCard, GradientButton, Pill, LiveDot,
│        │                           ProgressRing, Shimmer, AuroraBackground,
│        │                           DotGrid, FadeInUp, XyLogo, GradientThumb
│        └─ screens/                 splash, onboarding, welcome, login,
│                                    flow_gate, shell, home, sewa_pc, checkout,
│                                    order_detail, order_list, akun, cs, wallet
├─ api/                              Backend Cloudflare
│  ├─ src/index.js                   Worker REST + Durable Object RealtimeHub
│  ├─ schema.sql                     tabel D1 + seed
│  └─ wrangler.toml
├─ preview/xycloudorder-preview.html
└─ .github/workflows/build-apk.yml   CI build APK
```

---

## Alur Layar

| Tahap | Isi |
|---|---|
| **Splash** | Logo beranimasi, orbit partikel, progress bar, label PREMIUM EDITION. Native splash (`flutter_native_splash`) tampil lebih dulu supaya tidak ada layar putih. |
| **Onboarding** | 3 slide dengan ilustrasi digambar sendiri (rig PC dengan meter GPU/CPU/RAM, kartu akun bertumpuk, gelombang realtime). Indikator dinamis, tombol Lewati, status disimpan di `SharedPreferences` sehingga hanya muncul sekali. |
| **Welcome** | Latar midnight + konstelasi animatif, headline, statistik sosial, CTA Masuk / Daftar. |
| **Login / Daftar** | Satu layar dua mode, validasi form, toggle password, ingat email, opsi Google & Apple. |
| **Aplikasi** | Bottom nav 5 tab dengan pill indikator beranimasi. |

## Fitur Aplikasi

| Modul | Isi |
|---|---|
| **Beranda** | Kartu saldo midnight dengan angka menghitung naik, menu cepat, kartu sesi berjalan, carousel PC, banner promo, akun terlaris |
| **Sewa PC** | 4 paket, filter region/ready, bar okupansi realtime, spesifikasi lengkap |
| **Checkout** | Pilihan durasi 1–24 jam, diskon 10% untuk 8 jam ke atas, 3 metode bayar, ringkasan biaya |
| **Detail Order** | Kartu status, ring progres provisioning, timeline 5 langkah, countdown per detik, kredensial RDP dengan tombol salin |
| **Beli Akun** | Grid produk, badge diskon, kategori + pencarian, bottom sheet detail, dialog kredensial |
| **Customer Service** | Live chat, indikator mengetik, quick reply, badge notifikasi |
| **Dompet** | Top up cepat, riwayat transaksi berkategori |

## Realtime

`RealtimeService` membuka WebSocket ke Durable Object dengan **reconnect exponential backoff + jitter** dan **ping/pong** tiap 25 detik. Indikator status (Realtime / Menyambung / Offline) tampil di setiap layar utama.

Event dari server:

```json
{"type":"order.update",  "payload":{ "...order" }}
{"type":"stock.update",  "payload":{"id":"pc-gaming","unitTersedia":3}}
{"type":"chat.message",  "payload":{"dari":"cs","teks":"Halo kak","waktu":"..."}}
{"type":"cs.typing",     "payload":{"typing":true}}
{"type":"wallet.update", "payload":{"saldo":275000}}
```

---

## Build via GitHub Actions

Workflow `.github/workflows/build-apk.yml` berjalan otomatis pada setiap push ke `main`, atau bisa dijalankan manual dari tab **Actions → Build Android APK → Run workflow**.

Yang dilakukan CI:

1. Setup Java 17 + Flutter 3.24.5 (dengan cache)
2. `flutter create . --platforms=android --org id.xycloud`
3. `flutter pub get`
4. Generate adaptive launcher icon (`flutter_launcher_icons`)
5. Generate native splash (`flutter_native_splash:create`)
6. Set label aplikasi jadi **XyCloudStore** dan pastikan izin `INTERNET`
7. `flutter analyze` + `flutter test`
8. Build APK **universal** dan **split-per-ABI**
9. Upload semua APK sebagai artifact `XyCloudStore-APK`

Input opsional saat run manual:

| Input | Default | Fungsi |
|---|---|---|
| `mock` | `false` | `true` = jalan dengan data demo tanpa server |
| `base_url` | `https://api.xycloud.my.id` | Base URL API XyCloud |

Push tag `v1.0.0` untuk sekaligus membuat GitHub Release berisi APK.

### Build lokal

```bash
cd app
flutter create . --platforms=android --org id.xycloud --project-name xycloud_order
flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create
flutter run                       # mode demo
flutter build apk --release       # APK rilis
```

Sambungkan ke server sungguhan:

```bash
flutter build apk --release \
  --dart-define=XY_MOCK=false \
  --dart-define=XY_BASE_URL=https://api.xycloud.my.id
```

---

## Deploy Backend Cloudflare

```bash
cd api
npm install
npx wrangler login
npx wrangler d1 create xycloud        # salin database_id ke wrangler.toml
npm run db:init                       # buat tabel + seed
npm run deploy
```

### Endpoint

| Method | Path | Fungsi |
|---|---|---|
| POST | `/api/auth/login`, `/api/auth/register` | autentikasi (token HMAC) |
| GET | `/api/pc/plans` | daftar paket PC |
| GET | `/api/akun/produk` | katalog akun |
| GET | `/api/banners` | banner slider beranda |
| GET, POST | `/api/orders` | list dan buat order sewa |
| GET | `/api/orders/:id` | detail order |
| POST | `/api/akun/beli` | beli akun, kredensial otomatis |
| GET | `/api/wallet/transaksi` | riwayat dompet |
| POST | `/api/wallet/topup` | top up saldo |
| GET, POST | `/api/cs/messages` | riwayat dan kirim chat |
| POST | `/api/cs/reply` | balasan dari dashboard admin |
| WS | `/ws/user:<id>` | channel realtime user |
| WS | `/ws/katalog` | channel stok unit dan banner |
| WS | `/ws/cs:inbox` | channel dashboard CS |
| GET | `/admin` | dashboard admin dan CS (butuh admin key) |
| GET, POST, PATCH, DELETE | `/api/admin/*` | API dashboard, header `x-admin-key` |

---

## Identitas Merek

- Nama: **XyCloudStore**
- Warna utama: ungu `#6C2BE2`, ungu pekat `#4A12B8`, ungu terang `#8B5CF6`, lavender `#C4B5FD`
- Tanpa warna neon. Aksen emas `#D9A441` hanya untuk rating dan tier.
- Logo resmi ada di `app/assets/brand/` (ikon, wordmark, versi putih) dan dipakai di splash, onboarding,
  welcome, login, dashboard admin, serta ikon launcher.
- Ilustrasi di `app/assets/ilustrasi/` dibuat dengan AI bergaya 3D glosi ungu di atas latar putih,
  lalu latarnya dihapus memakai `rembg` (model `isnet-general-use`) sehingga transparan.

## Domain

| Alamat | Fungsi |
|---|---|
| `https://api.xycloud.my.id` | API dan WebSocket aplikasi |
| `https://admin.xycloud.my.id` | dashboard admin dan CS |
| `https://xycloud-api.akuntiktok76y.workers.dev` | alamat cadangan otomatis |

Aplikasi memakai domain utama; kalau tidak bisa dihubungi, `ApiClient` otomatis pindah ke alamat cadangan.

---

## Dashboard Admin dan CS

Dashboard web ikut dibundel di dalam Worker, jadi tidak perlu hosting terpisah.

- URL: `https://admin.xycloud.my.id` atau `https://api.xycloud.my.id/admin`
- Masuk dengan **admin key** (`wrangler secret put ADMIN_KEY`), tersimpan di browser.

Yang bisa dikerjakan dari dashboard:

| Menu | Fungsi |
|---|---|
| Dashboard | jumlah pengguna, order, order berjalan, pendapatan, grafik 7 hari |
| Order | ubah status order; status `aktif` otomatis mengisi host, user, dan password lalu mendorong push realtime ke aplikasi |
| Paket PC | tambah, ubah, hapus paket sewa beserta harga dan stok unit |
| Produk Akun | kelola katalog akun digital (harga, stok, garansi, fitur) |
| Banner Slider | kelola banner beranda; perubahan langsung tampil di aplikasi tanpa update APK |
| Inbox CS | balas chat pengguna secara realtime, lengkap dengan indikator mengetik |
| Pengguna | lihat daftar akun dan sesuaikan saldo dompet |

Semua perubahan katalog dan banner disiarkan lewat WebSocket, aplikasi menerimanya tanpa perlu refresh manual.

---

## Menandatangani APK

APK rilis ditandatangani otomatis oleh GitHub Actions memakai keystore yang disimpan sebagai secret repository:

| Secret | Isi |
|---|---|
| `KEYSTORE_BASE64` | isi berkas `.jks` dalam base64 |
| `KEY_ALIAS` | alias kunci |
| `STORE_PASSWORD` | password keystore |
| `KEY_PASSWORD` | password kunci |

Membuat keystore baru:

```bash
keytool -genkeypair -v -keystore xycloud-release.jks -alias xycloud \
  -keyalg RSA -keysize 2048 -validity 10950
base64 -w0 xycloud-release.jks > keystore.b64
```

Saat build, workflow menulis `android/key.properties` lalu menjalankan `tools/patch_signing.py`
untuk menyisipkan `signingConfigs.release` ke berkas Gradle, dan memverifikasi hasilnya dengan `apksigner`.
Berkas keystore tidak pernah masuk ke repository.

---

## Email (Resend) dan Push (OneSignal)

### Email transaksional

Worker mengirim email lewat Resend memakai template ungu XyCloudStore (`api/src/mail.js`):

| Kejadian | Email |
|---|---|
| Daftar akun | kode verifikasi 6 digit, berlaku 15 menit |
| Verifikasi berhasil | email selamat datang |
| Lupa password | kode reset 6 digit |
| Beli akun digital | kredensial akun + struk pembayaran |
| Order sewa berubah jadi aktif | alamat RDP, username, password, durasi |

Pengaturan: `MAIL_FROM` dan `PUBLIC_URL` ada di `wrangler.toml`, kunci `RESEND_API_KEY` disimpan sebagai secret.
Logo untuk email dilayani Worker di `/brand/logo.png`.

Verifikasi email **wajib**: akun baru berstatus `email_verified = 0` dan harus memasukkan kode
sebelum bisa dipakai. Login dengan akun yang belum terverifikasi otomatis mengirim kode baru
dan aplikasi langsung membuka layar OTP.

Endpoint auth:

| Method | Path | Fungsi |
|---|---|---|
| POST | `/api/auth/register` | daftar, kirim kode verifikasi |
| POST | `/api/auth/verify` | tukar kode jadi token |
| POST | `/api/auth/resend` | kirim ulang kode (`tipe`: verifikasi / reset) |
| POST | `/api/auth/forgot` | minta kode reset password |
| POST | `/api/auth/reset` | pasang password baru |

### Push notification

`api/src/push.js` mengirim push lewat OneSignal saat status order berubah, saat CS membalas chat,
dan saat banner promo baru dibuat dengan opsi "Kirim notifikasi push". Aplikasi memakai
`onesignal_flutter` dan mengaitkan perangkat ke `external_id` = id pengguna, jadi kiriman selalu
tepat sasaran.

App OneSignal yang dipakai: **XyCloudStore** (`f4843c35-cc1d-4772-9f70-1c4349397ffb`), kredensial
**Firebase FCM v1 (Service Account JSON)** sudah terpasang di dashboard OneSignal, jadi push Android
siap terkirim begitu ada perangkat yang memasang aplikasi.

App ID dipakai di dua tempat: variabel `ONESIGNAL_APP_ID` pada `api/wrangler.toml` (sisi server) dan
`--dart-define=XY_ONESIGNAL_APP_ID` pada workflow build (sisi aplikasi). REST API key disimpan sebagai
secret Worker `ONESIGNAL_API_KEY`.

Menu **Email & Push** di dashboard admin bisa dipakai untuk menguji keduanya.

---

## Integrasi ke web XyCloud yang sudah ada

1. **Worker sebagai gateway** — ubah handler di `api/src/index.js` agar `fetch()` ke API web kamu, Durable Object tetap dipakai untuk push realtime. Paling cepat.
2. **Langsung ke API web kamu** — ganti `XyConfig.baseUrl` di app. Semua `fromJson` di `models.dart` sudah menerima gaya `snake_case` maupun `camelCase`.

Push pesan realtime dari sisi admin:

```bash
curl -X POST https://api.xycloud.my.id/api/cs/reply \
  -H "Authorization: Bearer <token-admin>" \
  -H "Content-Type: application/json" \
  -d '{"room":"user:u_001","teks":"Order kakak sudah kami proses ya"}'
```

---

## Sebelum produksi

- Ganti password plaintext di D1 dengan hash (SHA-256 + salt atau bcrypt via Worker).
- Sambungkan payment gateway sungguhan (Midtrans, Xendit, atau Tripay).
- Hubungkan fungsi `provision()` di Worker ke API hypervisor atau panel VPS.
- Tambahkan push notification agar notifikasi order tetap masuk saat aplikasi tertutup.
- Simpan berkas keystore rilis di tempat aman; kalau hilang, aplikasi tidak bisa diperbarui di Play Store.
