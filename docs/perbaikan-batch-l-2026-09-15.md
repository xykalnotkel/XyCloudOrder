# Batch L — 2026-09-15

Permintaan pemilik: mode relay untuk testing (host GitHub Actions VM / tanpa
IP publik), UI/UX diperbagus semua platform, bingkai AI baru + tier premium,
slogan + bio link + gaya nama kustom, komunitas lengkap (mention @, balasan
tanpa bubble), leaderboard di-upgrade, topbar seamless, tombol nav tengah
hexagon morphing, halaman blokir/login dipercantik, Cloudinary di-setup,
agen tidak memunculkan jendela CMD/PowerShell, UI desktop clean.

## Server (worker) — deploy produksi
- **Migrasi D1 0012**: kolom `users.slogan`, `users.bio_link`,
  `users.gaya_nama` (sudah dijalankan di produksi).
- **Cloudinary AKTIF**: secret `CLOUDINARY_KEY` + `CLOUDINARY_SECRET`
  dipasang di worker (cloud `jxjvz3qi` sudah ada di wrangler.toml) —
  upload foto profil, banner, forum, stiker CS kini berfungsi.
- **Bingkai baru** di whitelist: `sakura`, `sirkuit`, `sayap`, `petir`
  (Pro/VIP) + `mahkota`, `naga` (khusus VIP — `BINGKAI_VIP`, gate 403).
- **Gaya nama** (`GAYA_NAMA`): normal/tebal/miring/serif/mono gratis;
  gradasi/emas/neon/pelangi/ombak/ketik khusus Pro/VIP (gate 403).
- **Slogan** (maks 60, filter kata terlarang), **bio link** (validasi URL
  http/https, simpan bentuk normalisasi, kosong = hapus).
- **Mention @** (`notifMention`): deteksi `@username` di diskusi baru &
  komentar → notifikasi jenis `sebut` (maks 8 per pesan, tanpa self-mention),
  pakai tombol sosial. Jenis `sebut` sudah ada di whitelist push lama.
- **Endpoint baru** `GET /api/pengguna/mention?q=` — autocomplete username
  (awalan, maks 8, exact match diprioritaskan, rate-limit 120/jam).
- Profil publik + forum (list, detail, balasan) + leaderboard kini membawa
  `bingkai`, `gaya_nama`, `slogan` penulis — kustomisasi terlihat semua orang.
- Tes: 26/26 lulus.

## Aplikasi (Flutter) — v3.7.0+25
- **Bingkai AI baru (6)**: Sakura, Sirkuit Neon, Sayap Surgawi, Petir Badai,
  Mahkota Raja (VIP), Naga Emas (VIP). Digenerate AI → chroma-key hijau →
  transparan → **WebP** (43–79 KB; PNG lama api/galaksi ikut dikonversi,
  hemat ~450 KB). Partikel khas per bingkai: kelopak sakura jatuh, cahaya
  naik, bara naga, orbit listrik/neon/emas. Pemilih bingkai kini menampilkan
  label kelas **PRO+/VIP**.
- **Gaya nama kustom** (`gaya_nama.dart`): 11 gaya — tebal, miring, serif,
  mono, gradasi ungu, emas berkilau (shimmer), neon glow, pelangi hidup,
  ombak huruf, mesin ketik. Pratinjau langsung di Ubah Profil. Tampil di
  profil, profil publik, komunitas (post + komentar), leaderboard.
- **Slogan & bio link** di Ubah Profil; slogan tampil di bawah nama di
  profil/leaderboard/profil publik, bio link jadi chip yang bisa dibuka.
- **Komunitas**: autocomplete @mention di composer (debounce 300 ms, panel
  saran dengan avatar), komentar **flat tanpa bubble** (bersih seperti
  thread modern), bingkai avatar tampil di komentar & detail post.
- **Leaderboard**: gaya nama + slogan di daftar, mahkota di juara 1 podium,
  GayaNama di podium.
- **Nav bawah**: tombol tengah **hexagon morphing** (hexagon → membulat
  dengan easeOutBack saat aktif, garis hexagon tipis saat pasif); bar nav
  **seamless tanpa garis pemisah** (bayangan lembut). Composer forum/CS/DM
  juga tanpa garis pemisah.
- **Login/Register & Blokir**: partikel elemen melayang halus
  (`elemen_melayang.dart` — satu AnimationController, ringan).

## Agen Windows — v1.5.3-rust
- **Tidak ada lagi jendela CMD/PowerShell berkedip**: semua proses anak
  (powershell/cmd/reg/where/sunshine) lewat helper `perintah()` dengan
  `CREATE_NO_WINDOW` (0x08000000).
- **Mode Relay (Tailscale)** — untuk TESTING di host tanpa IP publik
  (VM GitHub Actions, CGNAT): checkbox di GUI, simpan `mode_relay` di
  config.json; `alamat_stream()` memprioritaskan IP tailnet 100.64/10;
  Cek Port menampilkan catatan bahwa hasil TERTUTUP itu normal di mode ini.
  Penyewa harus join tailnet yang sama. **Bukan untuk produksi.**
- **UI desktop "quiet surface"**: latar netral gelap tenang, kartu seksi
  lembut bersudut besar, heading huruf kecil kapital redup, tanpa garis
  separator keras (seamless), ungu hanya aksen.

## Catatan operasional
- D1 `rilis` masih menunjuk v2.6.0 — publikasikan APK 3.7.0 lewat panel
  admin supaya popup pembaruan muncul di pengguna lama.
- Mode relay = jalur testing; produksi tetap butuh host dengan IP publik
  (ISP non-CGNAT atau VPS GPU).
