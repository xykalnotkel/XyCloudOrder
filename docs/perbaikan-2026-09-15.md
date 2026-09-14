# Perbaikan Batch G — 15 September 2026

Fokus: **konektivitas streaming** (kasus nyata: HP gagal connect ke `20.25.10.64:47989`),
kontrol game lengkap, navigasi bawah yang bisa dikustom, promo model baru, komunitas, dan stiker.

## 1. Streaming tidak bisa konek (log: `failed to connect to /20.25.10.64 port 47989`)

**Akar masalah**: bukan bug aplikasi. HP menyewa melakukan pairing langsung ke Sunshine di PC
(port 47989/TCP). IP unit `20.25.10.64` ada di rentang Azure — port streaming belum dibuka di
NSG/firewall host, jadi koneksi dari internet selalu timeout setelah 5 detik.

Yang dikerjakan (diagnosa + jaring pengaman):

- **Worker**: endpoint baru `POST /api/agen/cek-port` (auth `x-agen-kode`) dan
  `POST /api/admin/agen/{id}/cek-port` — probe TCP 47984/47989/48010 dari sisi Cloudflare
  (`cloudflare:sockets`, import dinamis + timeout 6 dtk) → melaporkan port mana yang
  terbuka dari internet.
- **Agen PC (v1.4.0)**: tombol baru **"Cek port dari internet"** di langkah 2 + log
  panduan per port. Spesifikasi agen kini melaporkan **`ip_lan`** (Get-NetIPAddress).
- **Worker sewa**: payload sesi (`bacaSewa`/`mulaiSewa`) kini melampirkan **`host_lan`**
  dari `spec.ip_lan` agen.
- **App**: model `SesiMain.hostLan`; `_hubungkan()` di sesi_screen otomatis **fallback ke IP
  LAN** bila host publik tertutup dan penyewa berada satu jaringan dengan unit. Pesan error
  koneksi kini menyebut daftar port yang harus dibuka (47984–47990 TCP+UDP, 48010) +
  panduan NSG/Security Group untuk VM cloud.
- **Native**: pesan `stageFailed` diperjelas (port tertutup → daftar port).

**Diagnosa produksi (15 Sep, via endpoint baru)**: probe Cloudflare ke unit `20.25.10.64`
mengonfirmasi **47984, 47989, dan 48010 semuanya TERTUTUP** dari internet — persis
penyebab `failed to connect ... after 5000ms` di HP penyewa.

**Aksi yang harus dilakukan admin unit Azure** (sekali saja): buka inbound rule NSG untuk
TCP+UDP 47984–47990 dan TCP 48010 ke VM, izinkan Sunshine di Windows Firewall, lalu tekan
"Cek port dari internet" di agen sampai semua TERBUKA.

### Preset latensi rendah + on-mic
- Opsi Streaming & Kontrol dapat **preset**: `⚡ Latensi Ultra Rendah` (1080p · 120 FPS ·
  HEVC · 24 Mbps), `Seimbang` (720p60 auto 10 Mbps), `Hemat Data` (480p30 H.264 4 Mbps).
- **On-mic**: protokol Moonlight tidak meneruskan mic HP ke PC (suara PC→HP sudah jalan).
  Untuk voice chat: Discord di HP, atau Discord di PC (suaranya ikut terdengar di HP).
  Dinyatakan jujur di UI opsi streaming.

## 2. Kontrol game lengkap (F1–F12, keypad, touchpad, QWERTY)
- HUD streaming native kini punya tombol **Numpad** (0–9, `. + - * /`, Enter) menyusul
  Keyboard QWERTY, dialog Esc/Tab/F1–F12, gamepad virtual, dan mode trackpad yang
  sudah ada.

## 3. Bottom navigation
- **Tombol tengah lebih besar** (56px vs 46, glow lebih kuat, outline ungu saat tidak aktif).
- **Bisa dikustom**: Pengaturan → Teks & Gerakan → "Tombol tengah navigasi bawah" — pilih
  halaman mana yang duduk di tengah (posisi tombol lain bertukar). Tersimpan di
  `PengaturanLokal.navTengah`.
- **Swipe kiri/kanan** di body memindahkan tab (mengikuti urutan nav, haptic click).
- Notifikasi push tetap membuka halaman yang benar (index berbasis halaman, bukan posisi).

## 4. Kategori di bawah saldo (home)
- Menu cepat kini **tanpa kartu** (ikon + label kecil langsung di halaman).
- **8 item** (2 baris): Top Up, Voucher, Referral, Favorit, Statistik, Peringkat,
  Tier Saya, Bantuan — baris "Jelajahi" lama dilebur (tidak dobel).
- Item tanpa aset 3D memakai fallback pil gradien ungu + ikon material (errorBuilder).

## 5. Gambar otomatis WebP + tajam + tersandi
- Pipeline `/img/` sudah mengonversi semua gambar ke WebP/AVIF terkompresi (q_78/q_62).
  Baru: **gambar promo untuk app kini selalu lewat `samarkanGambar`** (sebelumnya URL
  Cloudinary mentah) → promo ikut terkompresi WebP + domain sendiri.
- Stiker tetap terenkripsi AES-GCM (kunci di secure storage).

## 6. Promosi model baru (dashboard + app)
- Migrasi **0010_promo_konten.sql**: kolom `konten` di `promo_overlay` (sudah diterapkan
  ke D1 produksi).
- Jenis baru: **`fullscreen`** (popup gambar penuh + teks konten + tombol X, tap = aksi)
  dan **`nav`** (banner tipis 60px tepat di atas bottom nav, nama + konten, X untuk tutup,
  tidak muncul saat keyboard terbuka).
- Dashboard → Promosi: pilihan jenis dengan deskripsi, textarea "Isi konten promosi",
  dan perbaikan platform `aplikasi` → nilai `app` yang valid.

## 7. Komunitas
- **Stiker**: path baru persis sesuai spesifikasi —
  `Android/media/<paket>/xycloudstore/media/stiker/<id>/<sha256>.webp.crypto15`
  (+ `index.crypto15`). Migrasi otomatis dari lokasi lama (`media/stiker` dan
  application support) termasuk rename `.byscrt` → `.crypto15`. Test diperbarui.
- **Profil publik pengguna lain**: endpoint benar, tapi posting/DM atas nama `admin`
  selalu 404 karena tidak ada baris users → worker kini mengembalikan **profil admin
  sintetis** (nama, bio, badge admin, jumlah posting). View profil dari forum/DM jalan.
- **Mention & balasan bergaya beda**: `@username` di isi post/balasan dirender tebal
  ungu; kutipan "Membalas X" jadi chip dengan garis kiri ungu + ikon reply — beda dari
  teks isi dan nama. Badge tier/khusus sudah berupa lencana terpisah di samping nama.
- **Swipe kiri/kanan pindah screen**: berlaku global di 5 tab utama (lihat §3).
- **PIP**: ditunda — butuh rombakan engine video native Moonlight (risiko tinggi, bukan
  bugfix). Streaming fullscreen sudah menyembunyikan UI sistem.

## Verifikasi
- `npm test` api: **22/22 lolos**.
- `node --check` index.js/sewa.js/engagement.js/app.js: bersih.
- Migrasi 0008 diterapkan ke D1 produksi (kolom `konten` terverifikasi ada).
- Flutter analyze/test + build APK (3 ABI) + build agen Windows via CI GitHub Actions.

## Catatan rilis
Batch B tetap ditahan: tidak ada tag `apk-android`/`agent-windows`, tidak ada
`simpanRilis` — menunggu instruksi rilis eksplisit setelah pengujian APK.
