# XyCloudStore 2.5.1 — sesi internal, CS dan pengaturan

## Persetujuan pemilik

Pemilik menyetujui engine Moonlight GPLv3 di dalam APK beserta penyediaan source aplikasi turunan. Pemilik juga memilih penghapusan riwayat CS yang lebih tua dari **7 hari**. Tidak ada penghapusan tiap kali membuka layar, dan tidak ada data/percakapan contoh baru di produksi.

## Streaming satu APK

- `SesiScreen` kini menghubungkan langsung ke engine GameStream native yang dibundel sebagai library. Tidak meluncurkan atau mewajibkan instalasi aplikasi Moonlight/Artemis terpisah.
- Pengguna tetap memerlukan Sunshine/Apollo berjalan pada PC, agen **1.1.0+**, serta jaringan/port streaming yang dapat diakses dari HP. Web admin Sunshine 47990 tetap lokal.
- Setelah unit siap: **Hubungkan PC → pilih Desktop/aplikasi dari daftar asli Sunshine → Buka Layar PC**.
- Pairing dikirim otomatis melalui backend ke agen. Identitas client unik dipakai untuk memilih permintaan pairing Sunshine modern, bukan sembarang permintaan yang kebetulan menunggu.
- Native activity berada dalam application ID XyCloudStore. Video menggunakan MediaCodec dan transport/audio/input native upstream; bukan WebView, screenshot berulang, atau simulasi video.
- HUD internal menyediakan kembali ke sesi, keyboard, Esc/Tab dan F1–F12; gamepad sentuh/trackpad dari engine tersedia.
- Pengaturan resolusi 480p–4K, FPS, bitrate, codec, gamepad, getar, trackpad, audio host, dan statistik berlaku pada koneksi berikutnya. Dukungan nyata tetap bergantung pada perangkat/encoder.
- Kembali dari layar video tidak otomatis membatalkan sewa. Gunakan **Akhiri Sesi** bila selesai.

### Batas verifikasi

Kompilasi library native telah berhasil untuk armeabi-v7a, arm64-v8a, dan x86_64 pada GitHub Actions. Uji otomatis membuktikan integrasi/build dan alur API, **bukan** kualitas streaming pada VM pengguna. Display virtual/monitor, driver GPU/encoder, firewall Windows/cloud dan koneksi internet harus diuji dengan HP. APK tidak memasang driver/display atau membuka firewall PC secara diam-diam.

## Alur sewa nyata

- Tombol Mulai Main tampil untuk pesanan dibayar/provisioning/aktif tanpa menunggu countdown yang sebelumnya justru membuat alur buntu.
- Host, progres dan waktu sewa mengikuti agen, bukan generator IP/password RDP acak. Tombol Perpanjang yang belum memiliki implementasi dihapus.
- Sewa dan pembelian akun menggunakan saldo. QRIS/VA tidak lagi dianggap lunas tanpa pembayaran; metode transfer/QRIS digunakan untuk top up melalui alur yang tersedia.
- Perhitungan sewa menyamakan biaya layanan Rp1.000, diskon durasi/member/voucher dengan ringkasan checkout. `total_disetujui` mencegah perubahan harga diam-diam.
- Pembuatan pesanan memiliki idempotency key. SQLite trigger membuat pemotongan saldo, stok dan reservasi satu host atomik. Percobaan pembayaran gagal tidak meninggalkan debit parsial.
- Pesanan dibayar yang belum dimulai dapat dibatalkan dan dikembalikan saldonya satu kali. Reservasi yang tidak dimulai selama 15 menit dibatalkan melalui pemeliharaan/aktivitas agen.
- Waktu sewa dimulai ketika agen mengonfirmasi unit siap, bukan ketika pengguna selesai membuka video. Kegagalan sebelum unit siap dapat dikembalikan otomatis; masalah video/encoder setelah unit siap memerlukan pemeriksaan dan penyelesaian lewat CS.
- Agen memulihkan deadline dari server setelah restart. Saat waktu habis ia menutup streaming, melepas perangkat, lalu melapor ke server. Host tetap dikunci ketika pembersihan gagal.

## Komentar

- Waktu relatif bahasa Indonesia: detik, menit, jam, hari, bulan, tahun; diletakkan di kanan bawah komentar.
- Tooltip menyediakan waktu lengkap. Timestamp SQLite tanpa zona dianggap UTC sehingga tidak meleset karena zona HP.
- Komentar yang memiliki stiker memakai latar transparan, tanpa kartu putih/border. Teks berada di atas stiker.
- Tulisan Membalas memakai warna teks netral.
- Label Realtime dibuang dari UI; koneksi tetap berjalan. Indikator hanya titik kecil dengan tooltip, bukan klaim admin/manusia sedang online.

## Chat CS

- Pesan server memiliki client-generated ID untuk mencegah duplikasi akibat retry/putus koneksi. Respons REST dan event socket digabung berdasarkan ID, bukan hanya kesamaan teks.
- Pesan pending tidak ditimpa begitu saja saat riwayat dimuat. Draft tidak dihapus saat pengiriman gagal; pesan gagal dapat diketuk untuk retry dengan ID yang sama.
- Chat membaca pesan terbaru, bukan terus menampilkan 200 pesan paling awal.
- Pesan lebih tua dari 7 hari disembunyikan dari riwayat dan dihapus oleh pemeliharaan. Lampiran unggahan CS dijadwalkan dihapus dari Cloudinary, dengan retry bila gagal; invalidasi cache/CDN bukan penghapusan salinan yang sudah disimpan penerima.
- Riwayat kosong menampilkan ajakan memulai percakapan baru, bukan balasan manusia palsu. Tidak ada klaim SLA dua menit yang belum diukur.
- Room socket pribadi memerlukan token pemilik atau otorisasi CS/admin. Pesan client tidak dapat memalsukan event saldo/chat admin. Endpoint balas CS lama yang dapat dipanggil pengguna biasa ditutup.

## Pengaturan

- **Streaming & Kontrol**: opsi nyata yang dipetakan ke engine native.
- **Teks & Gerakan**: ukuran teks dan animasi perpindahan layar tersimpan di perangkat.
- **Notifikasi & Nada**: lima channel Android (pesanan/saldo, CS, forum, promo, sistem). Pengguna mengatur nada, getar, prioritas dan layar kunci melalui pengaturan channel Android yang sungguhan, termasuk saat aplikasi tidak terbuka.
- Status izin/channel dibaca ulang setelah kembali dari pengaturan Android. Tombol tes push mengirim hanya atas tindakan pengguna, maksimal 3 kali/jam.
- Nada/channel tidak menggantikan kebutuhan konfigurasi OneSignal/FCM. Keberhasilan pengiriman penyedia belum menjamin perangkat menampilkan suara (izin, mode senyap dan DND masih berlaku).
- GIPHY tetap memerlukan API key yang diisi melalui dashboard; perubahan versi ini tidak mengklaim key tersebut sudah diberikan.

## Operator dan source

1. Perbarui `xy_agent.py` ke **1.1.0**, gunakan kode unit dan kredensial Sunshine yang sama. Hentikan proses agen lama sebelum menjalankan yang baru.
2. Jalankan `python xy_agent.py --cek`, lalu agen normal. Jangan menjalankan dua proses dengan kode unit yang sama.
3. Terapkan `api/migrations/0002_streaming_cs.sql` via `wrangler d1 migrations apply`, bukan `schema.sql` yang ditujukan untuk inisialisasi lokal.
4. Deploy Worker; pasang APK 2.5.1. Tidak ada transaksi uji produksi atau penyewa nyata yang dibuat/dihapus oleh pengujian otomatis.
5. Source lengkap aplikasi/engine dan dependency native disertakan sebagai asset rilis. Lihat `native/README.md`, `app/LICENSE`, dan halaman lisensi dalam aplikasi. Signing key, API key dan password tidak disertakan.

Uji: `flutter analyze --no-fatal-infos --no-fatal-warnings`, `flutter test`, `cd api && npm test`, dan `python -m unittest discover -s agent -p 'test_*.py'`. Firmware/streaming nyata harus diuji pada PC + HP setelah pembaruan.
