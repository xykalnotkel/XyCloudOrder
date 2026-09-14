# Perbaikan 2026-09-14 — Batch F (UI pil, bayar otomatis, gestur suara, legal refund, privasi, kompresi)

Status: **semua item di bawah sudah di-commit ke `main`**. Release/tag tetap DITAHAN
menunggu user tes APK + perintah eksplisit.

Konteks: user menjalankan Agen Windows v1.3.4 di PC asli — auto-setup Sunshine
sukses penuh (winget → MSI, kredensial otomatis, service running, API 47990 siap),
unit `xya_a7845c748e03427ba9b4ba473f4ea001` ("Pc Test Jir") terdaftar **online**
di D1 produksi dengan host = IP publik `20.25.10.64` (deteksi ipify) dan heartbeat
segar. Rantai agen → backend → dashboard terbukti hidup end-to-end.

## 1. Tombol rounded-full di semua platform (permintaan: "semua button rounded full")
- **App Flutter**: `XyRadius.tombol` 14 → 99 (pil). Otomatis mengenai
  FilledButton/OutlinedButton theme (terang+gelap), GradientButton, chip nominal
  top up, tombol follow, tombol login, dsb. Palet tetap UNGU (tidak diubah).
- **Dashboard**: `.xy-btn`, `.xy-btn-ghost`, `.xy-btn-danger`, `.xy-btn-ok`,
  `.xy-file-btn` radius 12px → 999px; komponen kit `Btn` `rounded-[12px]` →
  `rounded-full`. Warna tetap ungu #7C3AED dkk.
- **Agen Windows**: base `button` radius 10px → 999px, `button.mini` → 999px
  (step/lencana/btn utama memang sudah pil).

## 2. Splash native ungu (keluhan: "splash native background belum ganti warna")
- `flutter_native_splash.color` + `android_12.color`: `#1A1033` (nyaris hitam) →
  **`#2E1065`** (ungu tua brand, primaryDark). CI sudah menjalankan
  `dart run flutter_native_splash:create` tiap build — APK berikutnya langsung ungu.
- Splash dalam app (`splash_screen.dart`): latar `XyTheme.ink` polos → **gradien
  gradMidnight `#2E1065 → #100030`** + navbar senada → transisi native→app mulus.

## 3. Voice note bisa diputar di dashboard admin (keluhan utama)
- Penyebab: `<audio controls className="h-9">` — kontrol native Chrome butuh
  tinggi ±54px; dipaksa 36px → terpotong dan tidak bisa diklik (juga melanggar
  aturan Batch C "tanpa UI bawaan browser").
- Solusi: komponen baru `dashboard/components/ui/voice-note.tsx` — player custom
  (tombol putar/jeda bulat, bilah progres bisa diklik, durasi mm:ss, state error)
  mengikuti warna gelembung (putih di bubble CS ungu, ungu di bubble user).
  Dipakai di `cs/page.tsx`.

## 4. Gestur rekam suara ala WhatsApp (app: CS chat + DM)
Sebelumnya: tahan mic, geser atas = batal. Sekarang:
- **Geser ↑ ≥70px = batal**, **geser ← ≥70px = hapus** (zona merah + ikon delete).
- **Tahan diam ±1,4 detik = KUNCI rekaman** (hands-free): overlay berubah jadi
  kartu interaktif dengan timer + tombol **Kirim sekarang** / **Buang**; lepas
  jari tidak menghentikan rekaman. Di DM: mic berubah jadi tombol kirim + tombol ✕.
- **Feedback suara + getar**: `SystemSound.play(click)` + `HapticFeedback` tiap
  masuk/keluar zona gestur, saat kunci aktif, saat rekaman mulai, dan di semua
  `Pressable`/`GradientButton` (haptic halus app-wide).
- Guard: long-press/ketukan baru saat terkunci diabaikan; `_mulaiRekam` tidak
  bisa dobel.

## 5. Pembayaran otomatis QRIS/DANA — "bisa deteksi sudah benar-benar dibayar?"
Infrastruktur lengkap (Tripay + Midtrans) sudah ada di `api/src/bayar.js` tapi
ada 3 lubang yang ditutup:
- **`callback_url` kini dikirim** di create-transaction Tripay → webhook
  `/bayar/webhook/tripay` pasti terpanggil (sebelumnya bergantung setting manual
  di dashboard merchant). Base URL Tripay diperbaiki ke `/open-api` (yang benar).
- **`cekStatusPenyedia()` baru**: server bertanya LANGSUNG ke penyedia
  (Tripay `transaction/detail` / Midtrans `/v2/{id}/status`). Dipakai 3 tempat:
  1. **Cron** (`pollPembayaran` di scheduled): top up gateway `menunggu` 24 jam
     terakhir dicek tiap siklus → lunas = saldo masuk otomatis (klaim atomik via
     helper baru `setujuiTopupOtomatis`, webhook lama direfaktor ke helper sama).
  2. **App**: endpoint baru `GET /api/wallet/topup/{id}` (status+saldo) di-poll
     sheet top up tiap 4 detik + `POST /api/wallet/topup/{id}/cek` (tombol
     **"Sudah bayar? Cek sekarang"** → server tanya penyedia). Status `disetujui`
     → sheet otomatis pindah ke tampilan sukses "Saldo Bertambah!" + saldo
     disinkron — juga untuk jalur manual (admin approve saat sheet terbuka).
  3. **Dashboard**: `POST /api/admin/topup/{id}/verifikasi` → tombol ⚡ per baris
     pending + `GET /api/admin/bayar/info` → banner status penyedia di halaman
     TopUp (hijau = otomatis aktif; amber = masih manual + petunjuk secret).
- **Yang belum**: secret penyedia belum diisi (belum punya akun gateway). Untuk
  mengaktifkan QRIS otomatis penuh: daftar Tripay → `wrangler secret put
  TRIPAY_API_KEY / TRIPAY_PRIVATE_KEY / TRIPAY_MERCHANT_CODE` → deploy. Tanpa
  itu sistem tetap jalan manual (transfer + kode unik + bukti) seperti sekarang.
  QRIS statis: isi var `QRIS_URL` (gambar QRIS DANA di Cloudinary).

## 6. Legal lengkap: Kebijakan Pengembalian Dana (refund)
- `api/src/legal.js`: konten REFUND 8 pasal (sewa PC, akun digital, saldo,
  cara mengajukan, lama proses, pengecualian). Route baru: HTML publik
  `/legal/refund` (lolos gate pemeliharaan), API `/api/legal/refund`, entri
  sitemap.xml. Tanggal pembaruan → 14 September 2026. Tautan silang 3 halaman.
- **App**: `legal_screen.dart` publik baru; tile "Kebijakan Pengembalian Dana"
  di Tentang; seksi **"Legal dan kebijakan"** baru di Pengaturan (Syarat,
  Privasi, Refund) → pengaturan kini super lengkap: Akun (+Mode Privasi),
  Tampilan (tema, teks&gerakan, streaming&kontrol FPS/bitrate), Aplikasi
  (stiker, notifikasi, data, privasi konten, pembaruan), Sesi (hapus akun,
  keluar), Legal, Lainnya (bantuan, tentang).

## 7. Keamanan: Mode Privasi (anti screenshot) — fitur baru
- Native: `tools/siapkan_keamanan.py` menyuntik MethodChannel `xycloud/keamanan`
  (FLAG_SECURE set/clear, idempotent, ikut pola skrip updater; sudah diuji lokal
  terhadap fixture MainActivity hasil streaming-bridge — brace balance 0).
  Step baru di CI `build-apk.yml` setelah updater.
- Dart: `core/keamanan.dart` + prefs `xy_mode_privasi` + dipulihkan saat start
  di `main.dart` + layar toggle **Pengaturan → Mode Privasi** (instant apply,
  tanpa restart). Efek: screenshot/rekam layar hitam, pratinjau recents tertutup.
- Token sudah di EncryptedSharedPreferences (dari sebelumnya) ✓.

## 8. Kompresi & kecepatan ("compres semuanya agar super duper cepat")
- `core/kompres.dart` baru: SEMUA unggahan gambar (chat CS, DM, foto profil,
  forum, foto ulasan, bukti top up) dikompres **WebP q72** client-side sebelum
  base64 (fallback JPEG; GIF animasi dilewati agar tetap bergerak; hasil lebih
  besar dari asli → pakai asli). Upload jauh lebih kecil → lebih cepat + hemat
  kuota; server/Cloudinary tetap auto-WebP juga.
- Pull-to-refresh ditambah: Favorit, Dompet, Aktivitas & Keamanan (home/forum/
  order/notifikasi/sewa/stiker sudah punya). Refresh rate/FPS streaming sudah
  ada di Pengaturan → Streaming & Kontrol.

## 9. App
- Versi dinaikkan `3.3.0+21 → 3.4.0+22`.

## Verifikasi
- `api`: `npm test` **22/22 lulus** (setelah semua perubahan worker).
- `dashboard`: `next build` **sukses** (semua halaman terkompilasi).
- Agen: perubahan hanya CSS → CI Build Agen Windows yang memverifikasi.
- App: tidak ada toolchain Flutter di sandbox → CI `flutter analyze` (fatal
  error) + `flutter test` + build APK 4 ABI yang memverifikasi.
- Produksi (setelah deploy CI): `curl api.xycloud.my.id/legal/refund` (JSON),
  `xycloud.my.id/legal/refund` (HTML lolos maintenance), sitemap memuat refund,
  `GET /api/admin/bayar/info` → `{penyedia:'manual'}` sampai secret diisi.

## Release — MASIH DITAHAN
Tag `apk-android` (APK 3.4.0+22, 4 ABI), `agent-windows` (exe v1.3.4), dan
`simpanRilis` menunggu user selesai tes + perintah "gas release".
