# Batch I — 2026-09-15

Rangkuman perbaikan Batch I (13 butir permintaan pemilik). Worker sudah
di-deploy ke produksi (Version `9083a510-b286-453b-a897-39929dfcc8b2`) dan
migrasi `0011` sudah diterapkan ke D1 `xycloud` (remote). API produksi saat
ini masih dalam **mode pemeliharaan** yang dipasang pemilik — endpoint baru
berada di belakang gate yang sama dan ikut hidup saat pemeliharaan dibuka.

## Commit

| Commit | Isi |
| --- | --- |
| `0d8c52f` | Worker: cooldown nama 7 hari & username 30 hari, validasi username ketat + cadangan, bingkai profil, banner media GIF/MP4 khusus langganan, transfer saldo ber-PIN + buku besar, leaderboard nyata (migrasi 0011, 26/26 test). |
| `af0bb81` | App: tema Midnight Aurora, tombol glossy-ring, login sidik jari, galeri picker kustom, banner & bingkai profil, transfer saldo, leaderboard & tier nyata, versi 3.5.0+23 (analyze 0 error, 17/17 test). |
| `ae352f0` | Agent: agen Windows pindah dari Tauri ke **egui/eframe native** (v1.5.0-rust, satu exe tanpa WebView2/terminal). |
| (commit ini) | Dokumen log Batch I. |

## Butir permintaan → penyelesaian

1. **Tombol rounded + border berkilau (bukan 3D)** — `GradientButton` didesain
   ulang: pil rounded dengan gradasi ungu datar + **cincin border berkilau**
   (ring luar gradasi `#D8C9FF → transparan → #D8C9FF` + hairline dalam putih
   24%) sehingga tampak premium/menonjol tanpa bayangan keras gaya 3D. Semua
   tombol CTA app otomatis ikut (dipakai di ±40 titik).
2. **Dark mode tidak pasaran** — tema baru **Midnight Aurora**: dasar plum
   tengah-malam (`#120C22`/`#17102B`), permukaan kartu bergradasi ungu-gelap
   (bukan abu datar), latar `XyLatar` aurora bergerak (blob ungu/pink/biru +
   bintang) di semua layar, glow ungu pada elemen aktif, aksen emas lembut
   untuk VIP. Mode terang tetap ada (default mengikuti sistem).
3. **Profil lebih lengkap** — header profil: banner (gradasi tema ATAU media
   GIF/video) + avatar berbingkai + statistik; baris **Bergabung** (tanggal
   daftar) di profil sendiri & publik; edit bio/telepon/email; unggah foto
   lewat galeri kustom; cooldown ganti nama/username terlihat dengan hitung
   mundur; profil publik memakai `copyWith` (follow/username berubah instan).
4. **Validasi username** — server (`PATCH /me` + `GET /api/me/cek-nama`):
   `^[a-z0-9_.]{3,20}$`, wajib diawali huruf/angka, tidak boleh berakhiran
   `.`/`_`, tanpa `..`, daftar cadangan (xycloud/xydesk/admin/official/support),
   cek unik, input dinormalkan lowercase. App: validasi lokal realtime +
   cek server saat kehilangan fokus + pesan galat spesifik.
5. **Login sidik jari/passkey** — `local_auth`: setelah login password sekali,
   pengguna dapat mengaktifkan **kunci biometrik** (Pengaturan → Keamanan).
   App terkunci saat dibuka ulang → `KunciBiometrikScreen` (tombol sidik jari,
   retry, fallback "Gunakan password saja" → konfirmasi → logout). Android CI:
   `tools/siapkan_biometrik.py` (MainActivity → `FlutterFragmentActivity`) +
   izin `USE_BIOMETRIC`. Catatan: ini biometrik perangkat (fingerprint/face);
   FIDO2 passkey lintas-perangkat butuh dukungan server WebAuthn — bisa jadi
   batch berikutnya bila diminta.
6. **Custom gallery picker** — `GaleriPicker` (photo_manager): grid foto/video
   dari galeri dengan izin runtime, pratinjau, fallback ke picker sistem bila
   plugin gagal. Dipakai di SEMUA pemilih gambar: foto profil, banner,
   lengkapi profil, forum, DM, CS, ulasan produk, bukti top-up, pembuat stiker.
   Izin `READ_MEDIA_IMAGES`/`READ_MEDIA_VIDEO` (+ legacy ≤API 32) ditambahkan
   `tools/patch_manifest.py`.
7. **Banner profil GIF/MP4 (khusus langganan)** — worker: kolom `banner_media`
   JSON `{tipe, url, gif}`; MP4 otomatis dikonversi ke GIF lewat Cloudinary
   (`f_gif,fps_12,w_480,c_limit`); hanya **Pro/VIP**; rate-limit 8 unggah/jam;
   `DELETE me/banner-media` untuk menghapus. App: widget `BannerProfil`
   (GIF via `Image.network`, video via `VideoPlayer`, fallback gradasi tema +
   scrim) di profil sendiri & publik; unggah/hapus di Ubah Profil dengan
   badge "Khusus Pro/VIP".
8. **Bingkai profil** — 6 bingkai: `polos, ungu, emas, neon, aurora, permata`
   (aurora & permata khusus Pro/VIP — divalidasi server, ditolak bila tier
   turun). Widget `AvatarBingkai` (gradient ring/animasi shimmer untuk aurora,
   sudut permata untuk permata) + `PilihBingkai` di Ubah Profil; ikut tampil
   di profil publik, leaderboard, dan sheet transfer.
9. **Progres benefit** — `tier_screen.dart` ditulis ulang: definisi tier kini
   **identik dengan server** (`api/src/loyal.js`): Basic 0 / Pro 300.000 /
   VIP 1.500.000 dari total belanja lunas, diskon 0/3/7%. Kartu hero: tier
   aktif + **bar progres animasi** menuju tier berikutnya + sisa belanja;
   daftar benefit per level dengan status tercapai/terkunci + badge "BARU"
   untuk benefit Batch I (banner bergerak, bingkai premium). Menggantikan
   layar lama Bronze/Silver/Gold/Platinum yang tidak pernah ada di server.
10. **Leaderboard nyata** — `GET /api/leaderboard?periode=bulan|total`:
    bulan = SUM(ABS(nominal)) transaksi lunas bulan berjalan; total =
    `users.total_belanja`; top-50 + peringkat & poin sendiri; hanya poin > 0;
    akun diblokir dikeluarkan; **transfer saldo tidak dihitung**. App: podium
    top-3 (emas/perak/perunggu, avatar berbingkai), daftar 4–50 dengan badge
    "KAMU" + ikon tier, kartu peringkatku di bawah, toggle Bulan Ini /
    Sepanjang Masa, pull-to-refresh.
11. **Transfer saldo antar pengguna** — worker: tabel `transfer` + PIN 6 digit
    (hash, bukan plaintext). Batas: min Rp10.000, maks Rp5.000.000/transaksi,
    Rp10.000.000/hari (UTC); debit atomik (guard `saldo >= nominal`) + kredit +
    buku besar + riwayat dalam satu `DB.batch`. Kode galat: **428** belum punya
    PIN, **401** PIN salah (6 percobaan/jam lalu terkunci), **422** kirim ke
    diri sendiri/pelanggaran batas/penerima tidak ada. Aktivasi PIN lewat OTP
    email (`pin_transfer`) ATAU konfirmasi password. App: sheet **Kirim
    Saldo** (cari @username → pratinjau penerima berbingkai → nominal → panel
    PIN inline) di Wallet; riwayat dengan ikon/tipe `transfer_keluar` (merah)
    & `transfer_masuk` (hijau); menu atur/ubah PIN di Keamanan & profil.
12. **Cooldown nama 7 hari / username 30 hari** — worker: kolom
    `nama_diubah_pada` & `username_diubah_pada`; `PATCH /me` menolak dengan
    429 + `sisa_jam` bila belum waktunya (penggantian username PERTAMA tidak
    kena cooldown). App: label hitung mundur ("Bisa diganti 5 hari lagi") di
    Ubah Profil; tombol simpan menyesuaikan; galat 429 server ditampilkan apa
    adanya.
13. **Agen Windows tanpa Tauri** — crate baru `agent-gui/src-native`
    (**egui 0.29 / eframe**): GUI native penuh (pengaturan unit & server,
    uji koneksi, Setup Engine, Mulai/Hentikan, autostart registry, panel log
    WIB live) — **satu exe mandiri tanpa WebView2, tanpa tauri-cli, tanpa
    jendela terminal**. `agent.rs` (heartbeat, perintah, `sunshine --creds`,
    winget) dipakai ulang apa adanya via `#[path]` → perilaku identik, config
    `%APPDATA%\XyCloudStore\Agent\config.json` tetap terbaca (drop-in upgrade).
    Mode CLI `--veri` & `-Jalankan` dipertahankan. CI `agent-windows.yml` kini
    hanya `cargo build --release --locked` (±2–4 menit, tanpa tauri build);
    artifact/rilis `XyCloudStore-Agent-Windows.zip` & nama exe tidak berubah.
    Build Tauri lama dipertahankan di repo sebagai legacy.

## Perubahan skema (migrasi 0011 — sudah diterapkan di produksi)

- `users` += `bingkai TEXT DEFAULT 'polos'`, `banner_media TEXT`,
  `nama_diubah_pada TEXT`, `username_diubah_pada TEXT`, `pin_transfer TEXT`
- Tabel `transfer` (id, pengirim, penerima, nominal, catatan, dibuat_pada) +
  indeks pengirim/penerima/dibuat_pada
- `schema.sql` disinkronkan (dipakai `engagement.test.mjs` yang tidak menjalankan migrasi)

## Verifikasi

- Worker: `npm test` → **26/26 lolos** (termasuk `batch_i.test.mjs` 12 test baru).
- App: `flutter analyze` (SDK 3.24.5 = versi CI) → **0 error**; `flutter test`
  → **17/17 lolos** (1 assertion dark-mode disesuaikan dengan kartu bergradasi).
- Agent: `cargo check` bersih; build rilis Linux OK (7,3 MB); `--veri` exit 0;
  `-Jalankan` exit 2 tanpa konfig (setara perilaku Tauri). Build Windows final
  dilakukan CI `agent-windows.yml`.
- Produksi: migrasi 0011 ✅ (5 kolom users + tabel transfer terverifikasi via
  pragma/sqlite_master); `wrangler deploy` Version `9083a510-...` ✅;
  `/health` 200, `/api/config` 200; endpoint lain 503 karena **mode
  pemeliharaan global sedang aktif** (perilaku gate Batch H yang diharapkan).
- `tools/siapkan_biometrik.py` & `tools/patch_manifest.py` diuji terhadap
  MainActivity/AndroidManifest simulasi (idempoten, FLAG_SECURE aman).

## Catatan tindak lanjut

- Buka mode pemeliharaan saat rilis 3.5.0 siap diedarkan (APK dibangun CI
  `build-apk.yml` dari `main`).
- Passkey FIDO2/WebAuthn lintas-perangkat (bila diminta) — butuh kolom
  credential + endpoint WebAuthn di worker.
- Hapus `agent-gui/src-tauri` + `agent-gui/ui` bila build native sudah terbukti
  stabil 1–2 minggu di PC host produksi.
