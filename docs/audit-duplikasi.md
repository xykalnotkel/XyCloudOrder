# Audit duplikasi & kode mati — XyCloudStore

Tanggal: 11 September 2026 · Lingkup: `app/` (Flutter), `api/` (Worker), `dashboard/` (Next.js)
Status: **gelombang 1 selesai & terkirim** (`9ffc7ab`), gelombang 2 masih tersisa (daftar di bawah).

## Ringkasan

| Area | Temuan | Status |
|---|---|---|
| `app/lib` | `BantuanScreen` didefinisikan **dua kali** (berkas sendiri + salinan di `pengaturan_screen.dart`) | ✅ disatukan |
| `app/lib` | `PembaruanScreen` didefinisikan **dua kali**, versi di `pengaturan_screen.dart` bahkan menavigasi ke dirinya sendiri (tombol perbarui tidak berfungsi) | ✅ disatukan |
| `app/lib` | Baris menu berkartu disalin **3×** (`_Baris` di pengaturan & tentang, `_Menu` di profil) dengan ukuran teks berbeda | ✅ jadi `XyBarisMenu` |
| `app/lib` | Judul kecil bidang input disalin **2×** (`_Label` di login & pengaturan) | ✅ jadi `XyLabel` |
| `app/lib` | Import tak terpakai di 7 berkas | ✅ dibuang |
| `app/lib` | Widget/painter mati: `_GarisKartu`, `_MiniBtn`, `_MeshPainter`, cabang `if (cmd == null)` yang tak mungkin benar di parser SVG | ✅ dibuang |
| `api/src` | Tidak ada blok/fungsi yang identik lintas berkas (pemindaian blok 12 baris) | ✅ bersih |
| `dashboard/` | Kit bersama `kit.tsx` diperluas + halaman stub diisi aksi (migrasi tuntas `47f8804`) | ✅ gelombang migrasi |

Hasil analyzer setelah perbaikan: **0 error, 0 warning** untuk `app/lib` (328 catatan tersisa semuanya `info`: `prefer_const_constructors`, `deprecated_member_use` pada `withOpacity`, `curly_braces_in_flow_control_structures`).

## Detail perbaikan gelombang 1

### 1. `BantuanScreen` — dua versi berbeda isi
- `bantuan_screen.dart` (lama): hero bergradien mencolok, 5 FAQ, nomor WA **di-hardcode** `6281234567890`, tombol "Chat CS" hanya `Navigator.pop`.
- salinan di `pengaturan_screen.dart` (baru): 6 FAQ lebih rapi + `XyIlustrasi('cs')`, tanpa aksi chat/WA.
- Pengguna melihat versi berbeda tergantung pintu masuk: lewat Profil → versi lama, lewat Pengaturan → versi baru.
- **Sekarang**: satu berkas `bantuan_screen.dart` berisi gabungan terbaik — 9 FAQ, ilustrasi, tombol **Chat Kirana** (langsung ke `CsScreen`) dan **WA Admin** yang nomornya diambil dari `konfigurasi.whatsapp` server dengan fallback `XyConfig.waCs` (tidak lagi hardcode). Gradien berat dibuang sesuai gaya UI konservatif.

### 2. `PembaruanScreen` — salinan rusak
- Versi di `pengaturan_screen.dart` adalah penampil status sederhana; tombol "Lihat & Perbarui Sekarang" memanggil `xyRoute(const PembaruanScreen())` yang, karena kelasnya lokal, **membuka halaman itu sendiri** — bukan alur unduh APK.
- Versi di `pembaruan_screen.dart` adalah pengunggah sebenarnya (unduh via notifikasi `PembaruanChannel`, fallback halaman web).
- **Sekarang**: salinan lokal dihapus, semua pintu masuk memakai `pembaruan_screen.dart`. Berkas `pengaturan_screen.dart` menyusut 1021 → 865 baris.

### 3. `XyBarisMenu` & `XyLabel` (baru di `ui/widgets/common.dart`)
Satu widget untuk baris menu berkartu (ikon bulat warna lembut + judul + subjudul + chevron), dipakai 3 berkas:
- `pengaturan_screen.dart` (9 pemakaian, `_Baris` dihapus)
- `profil_screen.dart` (15 pemakaian, `_Menu` dihapus)
- `tentang_screen.dart` (4 pemakaian, `_Baris` dihapus)

Efek samping positif: di `profil_screen.dart` ikon sebelumnya memakai `primarySoft` polos sedangkan di `tentang_screen.dart` subjudulnya 11.8 vs 11.5 — sekarang seragam (ikon 40px, radius 13, subjudul 11.5, panggal 15).

> Catatan kompatibilitas: widget ini memakai `withOpacity` (bukan `withValues`) karena APK dibangun dengan Flutter 3.24.5, sementara `Color.withValues` baru ada di 3.27.

### 4. Kode mati yang dibuang
| Berkas | Yang dibuang | Alasan |
|---|---|---|
| `home_screen.dart` | `_GarisKartu`, `_MiniBtn` (+ param `utama`) | tidak ada pemanggil |
| `ui/widgets/common.dart` | `_MeshPainter` | tidak ada pemanggil sejak `GradientThumb` disederhanakan |
| `ui/widgets/brand_logos.dart` | `if (cmd == null) break;` | `cmd` sudah pasti non-null di titik itu |
| 7 berkas | `dart:async`, `mock_data.dart`, `common.dart`, `error_state.dart`, `motion.dart`, 2× `android_intent_plus` | import tak terpakai |

## Gelombang 2 — sisa yang belum dikerjakan

1. **Dashboard `dashboard/app/**`**: migrasi aksi selesai (`docs/migrasi-dashboard.md`). Sisa kosmetik dedup filter tanggal antar halaman analitik/keuangan bila perlu. (sebelumnya: filter rentang tanggal, kartu statistik, tombol ekspor, dan pembungkus fetch API. Usulan: tarik ke `dashboard/components/`.
2. **`api/src/index.js` (361 KB, satu berkas)**: belum dipindai untuk blok rute berulang **di dalam** berkas. Kandidat: validasi admin, parsing body, dan pola respons error.
3. **`_Stat` di `akun_screen.dart` vs `welcome_screen.dart`**: sebelumnya terdeteksi nama sama; setelah diperiksa isinya berbeda (satu berkartu vertikal, satu teks putih besar) — **bukan duplikat**, biarkan.
4. **Pemakaian `XyBarisMenu` lebih luas**: `checkout_sewa_screen.dart` masih punya `_Baris` untuk baris rincian harga (kiri–kanan) — beda peran, jadi tetap lokal; tinjau ulang kalau nanti dipakai di 3+ tempat.
5. **Sisa 328 catatan `info`**: bisa dikerjakan serentak sebagai pembersihan (`prefer_const_constructors` 101, `withOpacity` → pola aman untuk 3.24, `curly_braces` 56).

## Verifikasi

- `flutter analyze lib` → **0 error, 0 warning**.
- `flutter pub get` + `flutter build bundle --release` lolos lokal (Flutter 3.27.4).
- CI: workflow `Build Android APK` untuk commit `9ffc7ab` menjalankan Analyze → Test → build APK; dashboard deploy dijalankan workflow terpisah.
