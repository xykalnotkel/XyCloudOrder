# Perbaikan Batch K — 15 September 2026

Commit: `b9f4419` · Agen: **v1.5.1-rust** · App: tetap 3.6.0+24 (perubahan UI minor)

## 1. Status Unit Live — auto-polling
- `live_unit_screen.dart`: spek agen dijajak otomatis tiap **30 detik**
  (Timer.periodic, dibersihkan di dispose) + penanda waktu
  "Spek agen diperbarui HH:MM:SS • otomatis tiap 30 detik".
- Pull-to-refresh tetap ada.

## 2. Pra-cek agen host sebelum "Mulai Main"
- `order_detail_screen.dart`: sebelum masuk SesiScreen, app memanggil
  `GET /api/pc/unit-live` dan mencocokkan `planId` pesanan.
- Kalau tidak ada agen online untuk paket itu → bottom-sheet konfirmasi
  "Agen host sedang offline — koneksi streaming kemungkinan gagal.
  Tetap coba mulai sekarang?" (Tetap Coba / Batal).
- Kalau pra-cek gagal (mis. mode pemeliharaan) → tidak menghalangi sesi.
- Tujuan: keluhan "tidak dapat connection" dapat penjelasan di depan,
  bukan layar hitam/timeout yang membingungkan.

## 3. Pra-cek ukuran berkas di galeri picker
- `galeri_picker.dart`: sebelum berkas dikembalikan ke pemanggil, ukuran
  diperiksa — **video maks 15MB** (batas banner di server), **foto maks 10MB**.
- Lewat batas → snackbar jelas ("Video ini 23.4 MB — melebihi batas 15 MB.
  Potong atau kompres dulu videonya.") alih-alih gagal unggah di tengah jalan.

## 4. Tile pembaruan di Tentang → jalur kanonik
- Ternyata sistem pembaruan in-app sudah lengkap: tabel `rilis` di D1 +
  `PembaruanScreen` (unduh APK langsung, pilih ABI) + popup rilis otomatis.
- Tile Batch J ("Periksa pembaruan" → GitHub releases) **melewati** mekanisme
  itu — diganti navigasi ke `PembaruanScreen` (server resmi, bukan GitHub).

## 5. Versi agen 1.5.1-rust
- `agent.rs VERSI` + `src-native/Cargo.toml` dinaikkan — chip "agen vX" di
  Status Unit Live kini mencerminkan penambahan field spek GPU/os_versi.

## Catatan operasional (untuk owner)
- Tabel `rilis` di D1 masih **v2.6.0**. Setelah APK 3.6.0+ didistribusikan,
  terbitkan rilis baru lewat panel admin (POST /api/rilis + unggah berkas APK)
  supaya pembaruan in-app & popup rilis menunjuk versi terbaru.
- Artefak APK 3.6.0+24 (arm64 + universal) tersimpan di `/home/user/rilis-batch-j/`
  dan di Actions → commit `fd8fc55`.

## Verifikasi
- `flutter analyze`: 0 error.
- `flutter test`: 17/17 lulus.
- Worker tidak berubah (tetap `66c3b76f`, 26/26 test dari Batch J).
