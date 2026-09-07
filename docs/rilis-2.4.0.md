# XyCloudStore 2.4.0

## Aplikasi

- Palet kartu, teks, formulir, dialog, navigasi, dan pengaturan mengikuti **Terang / Gelap / Sistem**. Splash tetap memakai latar merek gelap. Preferensi tema disimpan di perangkat.
- Keluar membersihkan token, push identity, koneksi realtime, notifikasi dan cache akun. Navigator dibuat ulang ketika akun berubah sehingga halaman pengaturan/akun lama tidak tertinggal di atas layar masuk.
- **Hapus Akun** dapat ditemukan langsung di Profil maupun Pengaturan, bukan hanya di bawah form password. Pengguna mengetik `HAPUS` dan memverifikasi password; akun sosial menggunakan kode konfirmasi email yang diminta secara manual. Saldo, pesanan/sesi aktif, atau top up tertunda harus diselesaikan dahulu. Parameter lama `paksa` tidak lagi menghanguskan saldo.
- Penghapusan membersihkan data akun di database utama dan koleksi stiker lokal akun tersebut. Data pembukuan dianonimkan. Prosedur retensi cadangan dan media yang pernah dibagikan tetap harus diperhatikan oleh pengelola layanan.
- Banner minimal 244 logical pixels, mengikuti skala teks, menggunakan lebar responsif, dan menjaga CTA di dalam kartu. Aksi URL benar-benar membuka browser. Daftar kosong tidak menampilkan banner contoh/shimmer selamanya.
- Komentar disusun sebagai thread dengan garis penghubung, avatar, balasan ke induk, suka, laporan, dan penghapusan komentar sendiri. Menghapus komentar tidak menghapus balasan milik orang lain.
- Perubahan nama/foto mengikuti identitas terbaru pada diskusi, komentar, dan ulasan, termasuk melalui trigger D1 untuk perubahan profil dari jalur admin. Teks isi pesan yang ditulis pengguna tidak diubah otomatis.
- Komentar dapat berisi teks, stiker, atau keduanya. Urutan tampilan: **teks di atas, stiker di bawah**. Saat pengiriman gagal, draft tidak dibuang.
- Detail menampilkan hingga 200 komentar terbaru. Data parent yang hilang atau siklus dari data lama tidak menyebabkan UI hang.

## Koleksi stiker lokal

- Koleksi dipisahkan per akun pada perangkat yang sama, maksimal **100 stiker** dan **2 MB per stiker**.
- Impor galeri: PNG/JPG dikonversi menjadi WebP. GIF dan WebP animasi dipertahankan agar tidak berubah menjadi gambar statis. Berkas asal maksimal 8 MB.
- Ketuk/tekan lama stiker di komentar untuk menambahkannya ke koleksi. Di koleksi, tekan lama untuk menghapusnya dari HP; pesan yang sudah terkirim tidak ikut terhapus.
- Metadata dan media menggunakan **AES-256-GCM**, nonce acak 96-bit dan tag autentikasi 128-bit. Kunci 256-bit disimpan lewat Android EncryptedSharedPreferences/Keystore. Tidak ada fallback penyimpanan plaintext. Preview didekripsi di RAM.
- Direktori lokal aplikasi tidak dicadangkan otomatis oleh Android (`allowBackup=false`) agar berkas terenkripsi tidak dipulihkan tanpa kuncinya.
- Sumber gambar asli di galeri tetap milik pengguna dan tidak dihapus/diubah. Stiker yang sudah dibagikan di komunitas adalah konten publik, **bukan enkripsi end-to-end**.

## Mengaktifkan pencarian GIPHY

1. Siapkan API key melalui akun GIPHY Developers sendiri dan ikuti ketentuan atribusi/kuota mereka.
2. Buka dashboard → **Stiker & GIPHY**.
3. Isi API key → **Simpan & aktifkan**. Server memeriksa key sebelum menyimpannya.
4. Key dari dashboard dienkripsi di D1 memakai kunci yang diturunkan dari `JWT_SECRET`, dan tidak dikembalikan oleh API ke aplikasi/dashboard. Jika `JWT_SECRET` dirotasi, isi ulang key GIPHY.
5. Alternatif: pasang secret Worker `GIPHY_API_KEY`. Jika ada, secret Worker diutamakan dan pengelolaannya dilakukan dari Cloudflare.

Pencarian stiker transparan/GIF dijalankan melalui backend, dibatasi per akun, memakai rating `g`, dan menampilkan atribusi GIPHY. Impor tautan mendukung halaman GIPHY (memerlukan key) atau tautan gambar resmi GIPHY langsung. Tanpa key, aplikasi menampilkan keadaan belum dikonfigurasi—bukan hasil pencarian palsu. Galeri, koleksi lokal, dan menyimpan stiker yang sudah tersedia tetap bisa digunakan.

**Status saat implementasi:** pengguna belum memberikan API key GIPHY; aktivasi pencarian masih memerlukan langkah di atas. Tidak perlu APK baru setelah key diaktifkan.

## Floating promo dan pop-up

Dashboard → **Floating & Pop-up**:

- Klik **Promo melayang** atau **Pop-up info**.
- Unggah gambar (PNG/JPG/WebP/GIF maksimal 4 MB) atau masukkan URL gambar HTTPS, lalu isi tujuan klik HTTPS.
- Pengaturan tambahan: nama internal, aktif/nonaktif, posisi kiri/kanan, urutan, platform aplikasi/web/keduanya, serta aksi internal.
- Tampilan pelanggan hanya gambar yang dapat diklik dan tombol **×**. Floating dapat digeser dan posisinya disimpan di perangkat.
- Maksimal dua floating dan satu pop-up per sesi. Pop-up ditandai sudah dilihat **per revisi promo per perangkat**; bukan sinkronisasi lintas perangkat/akun. Menyimpan perubahan membuat revisi baru.
- Floating yang ditutup disembunyikan sampai revisi promo berubah. Gambar ditampilkan dengan `contain`, bukan dipotong.
- Aplikasi menampilkan promo pada shell utama, bukan menutup editor komentar, layar login, atau halaman checkout yang didorong di atasnya. Floating disembunyikan saat keyboard terbuka. Web memuat ulang pengaturan ketika aktif, interval 60 detik; aplikasi melalui event katalog atau pembukaan ulang.
- Tidak ada promo/stiker contoh yang dimasukkan ke database produksi.

## Backend dan operasional

- **Laporan email harian dihapus total**: scheduler, endpoint kirim manual, dan template. Pemeliharaan/cadangan serta peringatan gangguan yang dibatasi cooldown tetap berjalan. Email OTP/transaksi tetap tersedia.
- Dashboard memakai pengelompokan menu, token komponen yang konsisten, footer simpan yang dapat diakses di HP, pencegahan klik simpan ganda, error state, dan perlindungan respons navigasi usang.
- Channel publik forum/katalog hanya menerima broadcast dari server; pesan client tidak bisa memalsukan perubahan identitas/promo di channel tersebut.
- Migrasi non-destruktif: `api/migrations/0001_komentar_stiker_promosi.sql`.
- Terapkan ke produksi dengan `npx wrangler d1 migrations apply xycloud --remote`, **bukan** `schema.sql` yang berisi DROP untuk inisialisasi lokal.

## Verifikasi

- `flutter analyze --no-fatal-infos --no-fatal-warnings`.
- `flutter test`: tema gelap, banner 320/390 px dengan skala teks 1.5, AES-GCM/tamper, pengurutan thread, model teks+stiker, UI balas dengan induk, serta konfirmasi hapus akun.
- `cd api && npm test`: integrasi Miniflare/D1 untuk rename, komentar, batas URL/format, promo, status GIPHY tanpa key, dan penghapusan akun beserta penolakan saat saldo masih ada.
- Browser QA dashboard 390/1280 px: pembuatan dan penyimpanan promo, navigasi serta field secret GIPHY. Web: pop-up sekali tampil, drag floating, penyimpanan posisi, dan penutupan persisten.
- Uji fixture hanya di lingkungan lokal; tidak membuat komentar/promo/akun contoh atau menghapus akun nyata di produksi.

Login Google menggunakan konfigurasi Android/Web dan sertifikat rilis yang sama seperti 2.3.0; lihat `login-google.md`. Perubahan UI versi ini membutuhkan pemasangan APK 2.4.0.
