# Popup Update & Tema Violet-Indigo Glossy — XyCloudStore v3.2

> Dokumen ini dibuat agar agent lain yang lanjutin project langsung paham warna, gaya, dan sistem popup bertema.
> Last update: 2026-09-08 (UTC) — oleh Agent Arena.
> Repo: `XyCloudOrder`, branch `master` (commit lokal, **jangan push** sampai user bilang).

---

## 1. Ringkasan Permintaan User

- **Warna dari popup contoh harus dipakai ke seluruh UI/UX** — bukan cuma popup.
  - Contoh: `/home/user/uploads/XyCloudStore_rental_pc_morphing.jpg` (768×1376 potret)
  - Analisa warna: BG **indigo tua** `#100030 / #200050 / #100040`, aksen **violet glossy** `#7830C0 / #8B5CF6 / #A855F7`
- **Gambar popup bakal beda-beda tema**: misal tema Ramadan, Idul Fitri, Natal, Tahun Baru, Imlek, Kemerdekaan, dll.
  - Harus disesuaikan otomatis & mudah diganti per rilis.
- **Setiap selesai, tulis progress** + cara lanjut.
- **Jangan push ke GitHub** sampai user bilang. Build/test dulu sebelum rilis. Rilis jangan berturut — minta izin.

---

## 2. Palet Warna Baru — Violet-Indigo Glossy v3.2

Ini palet resmi yang sekarang dipakai di **app (Flutter) + web (web.html) + console (admin.html)**.

### Core Hex
| Token | Hex | Penggunaan |
|-------|-----|------------|
| `primary` | `#7C3AED` | Violet utama glossy (dari #7830C0 ref) |
| `primaryDeep` | `#5B21B6` | Violet pekat untuk hover/CTA |
| `primaryDark` | `#2E1065` | Indigo tua untuk hero/midnight |
| `bgGelap` | `#100030` | BG indigo tua **persis referensi popup** |
| `surfaceGelap` | `#1A0B2E` | Surface gelap (card dark) |
| `violet` | `#8B5CF6` | Ungu terang glossy |
| `lavender` | `#C4B5FD` | Aksen lembut |
| `plum` | `#A855F7` | Magenta-violet accent popup |
| `ink` | `#1E1B2E` | Teks utama (indigo kehitaman) |
| `bg` (light) | `#F5F3FF` | BG app light (lavender tint, bukan abu) |
| `line` | `#E9E3F5` | Border lembut ungu |
| `lineSoft` | `#F3F0FF` | Border paling lembut |

### Gradien Glossy (vertical glossy = terang di atas, pekat di bawah)
```dart
gradPrimary: [#A78BFA → #7C3AED]  // tombol & kartu saldo (paling sering)
gradDeep:    [#8B5CF6 → #4C1D95]  // header / CTA penting
gradMidnight:[#2E1065 → #100030] // latar indigo tua, persis BG popup referensi
gradAurora:  [#C4B5FD → #8B5CF6]  // aksen lembut / shimmer
gradSoft:    [#F5F3FF → #EEE8FF]  // latar soft
```

### Glow / Shadow
```dart
XyTheme.glow(primary, .28) = 2 lapis shadow:
  - blur 26, offset (0,10), opacity .28
  - blur 40, offset (0,18), opacity .12
```
Dipakai di: kartu saldo, tombol hero, popup, banner.

### Web & Console CSS Variables (sinkron)
```css
/* web.html :root baru */
--u:#7C3AED; --u2:#5B21B6; --u3:#2E1065;
--bg:#F5F3FF; --soft:#F3F0FF; --line:#E9E3F5;
--ink:#1E1B2E; --ink2:#4B445F; --muted:#7C738F;

/* admin.html :root light baru */
--primary:#7C3AED; --violet:#8B5CF6; --cyan:#A855F7;
--bg:#F5F3FF; --panel:#FFFFFF; --panel2:#F3F0FF; --line:#E9E3F5;
--ink:#1E1B2E; --muted:#7C738F;
```

**Catatan:** Versi lama "Quiet Surface" `#6254A8 / #F5F6F8` sudah diganti total ke glossy ini di commit terbaru. Jangan kembalikan ke flat.

---

## 3. Penerapan ke Seluruh UI/UX

### Flutter App (`app/lib/core/theme.dart`)
- Sudah di-update ke palet v3.2 (primary #7C3AED, gradPrimary #A78BFA→#7C3AED, gradMidnight #2E1065→#100030).
- `bgGelap = #100030` (persis popup), `surfaceGelap = #1A0B2E`.
- `glow()` lebih terasa (opacity .28, blur 26+40).
- Semua widget pakai token ini, jadi otomatis glossy.

### Flutter Morph BG (`app/lib/ui/widgets/morph_bg.dart`)
- Palet gumpalan: `[#8B5CF6, #A855F7, #7C3AED, #C4B5FD]` — sebelumnya orchid pastel.
- Blur 44, opacity .42, jumlah default 6.
- Dipakai di `PembaruanScreen` sebagai latar melayang.

### Flutter Popup (`app/lib/ui/widgets/rilis_popup.dart`)
- Barrier: `Color(0xFF100030).withOpacity(.68)` (indigo tua, bukan hitam flat).
- Transisi: Fade + Scale dengan curve `easeOutBack` (lebih premium).
- Gambar prioritas:
  1. `rilis.gambar` dari server (URL) — bisa themed per rilis
  2. `assets/ilustrasi/rilis_popup_{tema}.png` lokal
  3. `assets/ilustrasi/rilis_popup.png` default
- Overlay glossy putih 18% di atas → bawah indigo 12%.
- Tombol X: putih 92%, border `#C4B5FD`, shadow indigo + violet glow, icon `#2E1065`.

### Web (`api/src/web.html`)
- Meta theme-color: `#7C3AED` (sebelumnya #6254A8).
- `:root` baru glossy, header blur 14px, hero gradient putih→#F5F3FF + radial violet.
- Tombol: gradient `#A78BFA→#7C3AED`, shadow violet, hover lift -2px.
- Kartu: shadow `0 14px 36px rgba(16,0,48,.08)`, border `#E9E3F5`.
- Unduh box: `linear-gradient(135deg,#2E1065,#7C3AED)` (midnight→primary).
- Modal: backdrop `rgba(16,0,48,.56)` blur 8px.

### Console Admin (`api/src/admin.html`)
- Light theme baru `#7C3AED` + `#F5F3FF`.
- Gate: radial `#2E1065→#100030`, gatebox putih 96% blur 12px.
- Sidebar active: gradient `rgba(124,58,237,.18)` + border violet, text `#5B21B6`.
- Card: shadow `0 14px 36px rgba(16,0,48,.06)`.
- Tombol: gradient `#A78BFA→#7C3AED`, shadow violet.
- Ikon: gradient `#F5F3FF→#EDE8FF`, border violet.

---

## 4. Sistem Gambar Popup Bertema

### Konsep
User minta: **gambar popup bakal beda-beda tema, misal Ramadan dll**. Jadi kita bikin sistem theming, bukan satu gambar statis.

### Struktur Aset
```
app/assets/ilustrasi/
  rilis_popup.png                // default violet-indigo glossy
  rilis_popup_ramadan.png        // Ramadan (bulan, lentera, ungu+emas)
  rilis_popup_idulfitri.png      // Idul Fitri / Lebaran
  rilis_popup_natal.png          // Natal (salju + violet)
  rilis_popup_tahunbaru.png      // Tahun baru
  rilis_popup_imlek.png          // Imlek (merah + emas + ungu)
  rilis_popup_kemerdekaan.png    // 17 Agustus (merah putih + violet)
  rilis_popup_halloween.png      // optional

api/src/assets/
  popup-update.png               // 928×1152 (source AI)
  update-app.png (1024×1024)     // fallback ilustrasi update
  update-web.png (1376×768)      // banner web
  maintenance-app.png / web.png  // maintenance
```

**Ukuran wajib:**
- Popup portrait: `928×1152` (ratio 0.805), minimal 768×1152. Teks **baked-in di gambar** (AI generate dengan teks), jadi app cuma tampil gambar + X.
- Update app: `1024×1024` square, transparan BG atau indigo.
- Update web: `1376×768` landscape.

### Gaya Visual per Tema (panduan untuk generate AI)

**Base style (selalu sama):**
- BG: indigo tua `#100030` → `#2E1065` gradient, morphing blobs violet glossy
- Aksen: `#7C3AED / #8B5CF6 / #A855F7` glowing
- Karakter: 3D glossy, soft shadow, glassmorphism, tidak flat
- Teks di gambar: bold, rounded, putih/krem, shadow indigo

**Varian:**
- **Ramadan:** BG indigo tua + bulan sabit + lentera emas `#D9A441` glow, pattern arabesque halus, teks "Ramadan Mubarak — Update Spesial" atau "Versi Baru Ramadan"
- **Idul Fitri:** Ketupat minimalis, confetti, emas + violet, teks "Selamat Idul Fitri — Ada Pembaruan!"
- **Natal:** Salju tipis, lampu warm, pohon natal minimalis ungu, teks "Merry Christmas — Update Baru"
- **Tahun Baru:** Kembang api violet-emas, angka tahun, teks "Tahun Baru, Fitur Baru!"
- **Imlek:** Lampion merah + emas, naga minimalis, teks "Gong Xi Fa Cai — Update"
- **Kemerdekaan:** Bendera merah-putih subtle, confetti, teks "Merdeka! Update Spesial 17 Agustus"
- **Default:** Morphing glossy violet tanpa ornamen hari raya, teks "Ada Pembaruan Baru" / "Update Tersedia"

### Logika Pemilihan di Code

```dart
// rilis_popup.dart
String assetUntukTema(String? tema) {
  if (tema == null) return 'rilis_popup.png';
  return 'rilis_popup_${tema.toLowerCase()}.png';
}

// Prioritas:
// 1. rilis['gambar'] (URL dari server, bisa upload per tema)
// 2. asset lokal sesuai tema
// 3. default
```

**Backend suggestion (belum diimplementasi, butuh migrasi):**
- Tambah kolom `tema TEXT` di tabel `rilis` (nullable): `ramadan|idulfitri|natal|tahunbaru|imlek|kemerdekaan|default`
- Saat admin bikin rilis di console, pilih tema → otomatis set `gambar` ke URL yang sesuai atau upload gambar themed.
- Endpoint `/api/rilis` sudah return `gambar`, tinggal tambah `tema` di response.

```sql
-- migration 0005_rilis_tema.sql (rencana)
ALTER TABLE rilis ADD COLUMN tema TEXT DEFAULT 'default';
```

### Cara Generate Gambar AI (untuk user / agent selanjutnya)

Prompt template:
```
"3D glossy illustration, violet-indigo theme, background #100030 to #2E1065 gradient,
morphing soft blobs #8B5CF6 and #A855F7 glowing, [TEMA ORNAMEN],
text '[TEKS]' baked in bold rounded white with indigo shadow,
center composition, portrait 928x1152, premium app update popup, ultra detailed, soft lighting"
```

Contoh Ramadan:
```
"... Ramadan theme, crescent moon and golden lanterns #D9A441 glowing,
arabesque subtle pattern, text 'Update Ramadan — Fitur Lebih Berkah',
..."
```

Tool: bisa pakai model AI image generator (Midjourney/DALL-E/ComfyUI). Simpan hasil ke `api/src/assets/popup-update-{tema}.png` lalu copy ke `app/assets/ilustrasi/rilis_popup_{tema}.png`.

---

## 5. File Penting & Perubahan

| File | Status | Catatan |
|------|--------|---------|
| `app/lib/core/theme.dart` | ✅ Updated v3.2 | Palet violet-indigo glossy, gradMidnight #100030 |
| `app/lib/ui/widgets/morph_bg.dart` | ✅ Updated | Palet baru #8B5CF6 etc |
| `app/lib/ui/widgets/rilis_popup.dart` | ✅ Updated | Support tema, barrier indigo, transisi premium |
| `app/lib/ui/screens/pembaruan_screen.dart` | ✅ Ada (perlu cek) | Pakai hero gradPrimary baru |
| `api/src/web.html` | ✅ Updated | :root baru #7C3AED, glossy button/card |
| `api/src/admin.html` | ✅ Updated | Light theme glossy #7C3AED, gate indigo |
| `app/assets/ilustrasi/rilis_popup.png` | ✅ Ada (1381 KB) | Default, perlu generate varian tema |
| `api/src/assets/popup-update.png` | ✅ Ada | Source AI |
| `docs/PopupUpdate.md` | ✅ Baru | Dokumen ini |
| `docs/popupupdate.md` | 🔜 TODO | Copy lowercase untuk kompatibilitas |
| `api/migrations/0005_rilis_tema.sql` | ⏳ Rencana | Tambah kolom tema (belum dibuat) |
| `preview/` | ⏳ Perlu update | Preview HTML masih pakai warna lama, perlu regenerate |

---

## 6. Progress Project — Udah Sampai Mana & Lanjut Gimana

### ✅ Sudah Selesai (commit lokal, belum push)
- **D. Maintenance bertingkat** — `semua|web|aplikasi`, ilustrasi 3D, console bisa pilih cakupan.
- **C. Multi-select** — Order/TopUp/Users/Sampah bisa pilih banyak + aksi massal.
- **B. Validasi transaksi** — Beli akun tidak langsung konfirmasi, saldo tidak dipotong kalau stok kosong, webhook idempotent.
- **A. UI/UX glossy fondasi** — RepaintBoundary di XyCard, cached_network_image, dll.
- **Popup rilis** — Gambar AI + tombol X saja, auto-popup sekali per sesi, X → PembaruanScreen.
- **v3.2 Violet-Indigo Glossy** — Palet baru #100030 + #7C3AED diterapkan ke app+web+console (commit hari ini).

### 🔄 Yang Baru Dikerjakan Hari Ini (2026-09-08)
- Update `theme.dart` ke violet-indigo glossy sesuai referensi `XyCloudStore_rental_pc_morphing.jpg`.
- Update `morph_bg.dart` ke palet baru.
- Update `rilis_popup.dart` untuk support tema dinamis + barrier indigo + animasi premium.
- Update `web.html` & `admin.html` dari Quiet Surface flat ke glossy violet-indigo.
- Buat dokumen `PopupUpdate.md` ini.

### ⏳ Belum / Next Steps
1. **Generate varian gambar popup bertema** (Ramadan, Idul Fitri, Natal, Tahun Baru, Imlek, Kemerdekaan):
   - Pakai prompt template di atas, ukuran 928×1152.
   - Simpan ke `api/src/assets/` dan `app/assets/ilustrasi/`.
   - Commit lokal, jangan push dulu.
2. **Tambah kolom `tema` di backend** (migration 0005):
   - `api/migrations/0005_rilis_tema.sql`
   - Update `rilis.js` untuk simpan & return `tema`.
   - Update console admin form rilis: dropdown tema + preview gambar.
3. **Update preview HTML** (`preview/popup-final-preview.html`, `warna-glossy.html`, `app-glossy-preview.html`) biar pakai palet baru #7C3AED.
4. **Test di perangkat**:
   - `flutter pub get` → `flutter analyze`
   - `flutter build apk --release` (android folder digenerate via tools/*.py)
   - Cek: gradien glossy di kartu saldo terang & gelap, popup muncul, X ke PembaruanScreen, morph BG tidak lag.
5. **Backend test**:
   - `cd api && npm i && npx wrangler dev`
   - Test mode pemeliharaan bertingkat + rilis gambar per tema.
6. **Minta izin user sebelum rilis** — "klo uda mantep baru release", jangan berturut.

---

## 7. Cara Uji (Wajib Sebelum Rilis)

**Flutter:**
```bash
cd app
flutter pub get
flutter analyze
flutter build apk --release
# Pasang APK lama, naikkan versi rilis server → buka app → popup harus muncul violet-indigo
# Tekan X → PembaruanScreen → Perbarui Sekarang → cek notif DownloadManager (jalan saat app ditutup)
```

**Backend:**
```bash
cd api
npm i
npx wrangler dev
# Buka console admin → Sistem → coba mode pemeliharaan web saja / app saja
# Buka /api/rilis → cek field gambar & tema
```

**Visual:**
- Light mode: BG #F5F3FF, kartu putih shadow lembut violet, tombol gradient #A78BFA→#7C3AED
- Dark mode: BG #100030 (indigo tua), surface #1A0B2E, teks #F0EBFF, glow violet

---

## 8. Catatan Keamanan & Kebijakan

- **Jangan push ke GitHub** sampai user bilang. Semua commit lokal (`git log` ada 17b622b dll).
- **Kredensial** ada di `/home/user/uploads/my-binimbg.txt` — jangan commit, jangan kirim, pakai hanya yang perlu. Simpan di folder uploads.
- **Rilis jangan berturut** — setiap menjelang build, minta izin user.
- **Token GitHub dll** sudah ada di uploads, jangan expose.
- **Android folder** tidak di-commit, digenerate saat build via `tools/*.py`.

---

## 9. Referensi File

- Repo: `/home/user/XyCloudOrder`
- Popup contoh user: `/home/user/uploads/XyCloudStore_rental_pc_morphing.jpg`
- Kredensial: `/home/user/uploads/my-binimbg.txt`
- Theme: `app/lib/core/theme.dart`
- Popup: `app/lib/ui/widgets/rilis_popup.dart`
- Morph BG: `app/lib/ui/widgets/morph_bg.dart`
- Pembaruan: `app/lib/ui/screens/pembaruan_screen.dart`
- Web: `api/src/web.html`
- Console: `api/src/admin.html`
- Aset: `app/assets/ilustrasi/rilis_popup.png`, `api/src/assets/popup-update.png`
- Docs: `docs/rencana-3.0.md`, `docs/rilis-3.0-pembaruan-app.md`, `docs/PopupUpdate.md`

---

**Status akhir hari ini:** ✅ Palet violet-indigo glossy (#100030 + #7C3AED) sudah diterapkan ke semua UI/UX (app+web+console). Popup sudah support tema dinamis (code siap), tinggal generate gambar varian Ramadan dll. Dokumentasi ini dibuat agar agent selanjutnya langsung paham.

**Lanjut besok:** Generate gambar popup bertema + migration tema + update preview + test build.

