# XyCloudStore 2.6.0 — Quiet Surface & Security

## Pilihan yang disetujui

- Tampilan modern clean, permukaan netral dan aksen ungu tenang, tanpa glow/neon/cyber.
- Maksimal **2 pendaftaran akun baru per identitas perangkat yang dikenali**. Batas bisa diubah atau direset oleh pemilik dari dashboard.
- “Package stiker” berarti **folder penyimpanan internal aplikasi**, bukan penggantian applicationId. Package tetap `id.xycloud.xycloud_order`; signing key dan konfigurasi Google Android tidak diganti.

## Tampilan

Dashboard default terang dengan surface putih/abu netral, tipografi bersih, navigasi berkelompok, tabel pengguna dan lembar pengelolaan yang nyaman di HP. Glow, latar radial, pola cyber dan gradien dekoratif dihilangkan. Website memakai bahasa dan ilustrasi pratinjau yang tidak mengaku sebagai saldo/pengguna sungguhan. Tema Android terang/gelap tetap didukung dengan permukaan lebih netral.

Menu baru yang berfungsi:
- **Keamanan:** kuota pendaftaran, OTP dan email harian serta ringkasan kejadian.
- **Perangkat:** identitas pseudonim, pendaftaran/akun terkait, blokir dan reset kuota.
- **Sampah Pengguna:** pulihkan atau hapus permanen.
- **Audit & Kejadian:** catatan admin dan penolakan keamanan tanpa password/OTP.
- **Pusat Media:** inventaris unggahan baru, preview teroptimasi, uji ukuran sajian aktual.

## Perlindungan akun

1. Pembatasan ditegakkan di server, dengan penghitung atomik D1 dan trigger pendaftaran. Pemeriksaan di UI saja tidak dianggap cukup.
2. Pendaftaran email dan pembuatan akun Google memakai kuota perangkat yang sama. Pending registration juga mengonsumsi jatah. Menghapus akun tidak otomatis mengembalikan jatah; admin dapat meresetnya setelah peninjauan.
3. Akun lama tidak diberi identitas perangkat berdasarkan tebakan. Masuk ke akun yang sudah ada tidak dihitung sebagai pendaftaran baru.
4. Android memakai digest ANDROID_ID yang tersedia bagi aplikasi; fallback identitas instalasi bila tidak tersedia. Server menyimpan HMAC identitas, bukan ANDROID_ID mentah/IMEI. Browser memakai identitas penyimpanan lokal.
5. **Ini bukan hardware attestation.** Root, reset, profil baru, penghapusan penyimpanan browser atau client modifikasi dapat mengubah/memalsukan identifier. Batas perangkat dilapis dengan IP/email/OTP; tidak diklaim kebal bypass atau setara Play Integrity.
6. OTP baru disimpan sebagai digest dan dikonsumsi satu kali secara atomik. Percobaan verifikasi dibatasi per email; pengiriman dibatasi per menit/jam/hari. Email global memakai batas atomik dan berhenti mengirim jika penyimpanan limiter gagal.
7. State OAuth acak, terikat cookie dan hanya sekali pakai selama 10 menit. Client tidak menentukan state yang dipercaya server.
8. Celah verifikasi ulang tanpa OTP dan login memakai penanda password akun sosial ditutup. Pendaftaran ulang tidak dapat menimpa password akun pending.
9. Format token lama dicabut; pengguna perlu masuk ulang sekali. Blokir, Sampah dan perubahan password mencabut sesi akun. Ini tidak menghapus saldo, pesanan atau riwayat.
10. Akun sosial yang ingin memasang password harus membuktikan penguasaan email melalui OTP. Setelah password diubah, masuk ulang diperlukan.

### Nilai awal

- Pendaftaran per perangkat: 2.
- Pendaftaran per IP: 6/jam.
- OTP per email: 1 pada jendela menit, 3/jam, 8/hari.
- Percobaan OTP per email: 5/15 menit.
- Email global: maksimal 100/hari secara default, tidak melampaui batas environment `EMAIL_BATAS_HARIAN`.
- Kejadian audit keamanan: retensi 30 hari. Tidak mencatat password, OTP, bearer token atau API key.

## Penghapusan pengguna

- **Blokir:** mencabut sesi dan meminta agen mengakhiri sesi PC aktif. Akun/data tetap ada.
- **Hapus ke Sampah:** menonaktifkan akun dan mempertahankan data agar dapat dipulihkan.
- **Pulihkan:** mengembalikan akun dari Sampah, tidak mengaktifkan kembali token lama atau otomatis membuka blokir yang sudah ada sebelumnya.
- **Hapus permanen:** hanya pemilik, hanya dari Sampah, memerlukan konfirmasi eksplisit dan email target. Data pembukuan dianonimkan.
- Akun pemilik dilindungi. Saldo/pesanan/sesi/top-up yang belum selesai harus dibereskan sebelum penghapusan.
- Pengujian memakai fixture lokal, tidak menghapus atau mereset akun/perangkat produksi.

## Gambar dan stiker

### Sajian gambar

Gambar statis Cloudinary dikirim melalui domain API dengan varian lebar 160/360/800/1280/2048 px, WebP (atau AVIF saat browser menyatakan dukungan), kualitas terkontrol dan cache edge/browser. Tidak lagi menggandakan lebar lewat `dpr_2.0`. URL versi sajian berubah agar cache lama tidak mempertahankan varian besar.

Animasi GIF/WebP yang perlu dipertahankan disajikan tanpa merusak frame/transparansi. Original tidak ditimpa; resize/konversi dilakukan pada sajian. Gambar pihak ketiga yang tidak berada di Cloudinary milik layanan tidak diubah menjadi open proxy. Logo inline web/admin dikompresi menjadi WebP. Pusat Media menampilkan ukuran sumber dan dapat mengukur ukuran hasil sajian, bukan angka penghematan palsu.

### Penyimpanan di HP

- Koleksi tetap di application support directory: folder internal package Android, di bawah `xy_stiker/<hash akun>`.
- Media dan index terenkripsi AES-256-GCM, bukan WebP yang terbuka di galeri. Tidak perlu root atau izin penyimpanan umum.
- Stiker yang berhasil dikirim otomatis disimpan bila opsi tersebut aktif. Bisa dimatikan dari **Pengaturan → Stiker & Penyimpanan**.
- Stiker yang ditampilkan memiliki cache terenkripsi maksimum 32 MB; stiker orang lain tidak otomatis memenuhi koleksi favorit.
- Halaman pengelola menampilkan jumlah, ukuran koleksi/cache dan lokasi folder sebenarnya; mendukung tambah/hapus koleksi dan bersihkan cache saja.
- Perangkat baru/uninstall tidak otomatis membawa kunci lama. Mengubah package APK bukan solusi untuk memindahkan file terenkripsi; package tidak diubah pada rilis ini.

## Verifikasi dan rilis

`flutter analyze`, tes Flutter (termasuk penyimpanan file terenkripsi), tes backend (quota/OTP/state/sesi/penghapusan/media), serta QA browser dashboard 390/1360 px. Build rilis Android dan source GPL dipublikasikan bersama. Native streaming tetap menggunakan engine yang sudah diintegrasikan pada seri 2.5 dan memerlukan agen PC 1.1.0+.

Migrasi produksi: `0003_security_media.sql` melalui `wrangler d1 migrations apply`. Jangan menjalankan `schema.sql` pada produksi: itu hanya inisialisasi lokal. Seed data contoh dihapus dari inisialisasi lokal; katalog nyata yang sudah ada tidak dihapus.

Pengiriman push aktual tetap bergantung konfigurasi OneSignal/FCM dan izin HP; pencarian GIPHY tetap memerlukan key operator. Rilis ini tidak mengklaim kedua konfigurasi pihak ketiga sudah diubah.
