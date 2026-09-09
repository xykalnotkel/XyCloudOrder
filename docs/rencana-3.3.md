# Rencana 3.3 — Native Updater, Fitur Baru, Dash Next.js, Security Full Audit

> Lanjutan dari v3.2. User minta: native gimana? tambah fitur/menu app+dash, dash upgrade ke Next.js, security update semua, boleh push build tapi jangan release dulu (user harus tes dulu).

## 1. Native — Status Sekarang & Fix

### Status v3.1-v3.2
- Flutter: `app/lib/data/pembaruan_channel.dart` MethodChannel `xycloud/updater` sudah ada, dengan method:
  - `available` → cek apakah native ada
  - `download(url, title, version)` → enqueue DownloadManager
  - `status(id)` → running/completed/failed
  - `install(id)` → ACTION_VIEW intent
- `PembaruanScreen` & `rilis_popup.dart` sudah pakai channel ini, fallback ke halaman web kalau belum ada.
- **Masalah sebelumnya:** folder `app/android/` tidak di-commit (digenerate via `flutter create` di CI). Jadi kode Kotlin/Java updater belum kesuntik otomatis.

### Fix v3.3 (baru)
- **tools/patch_manifest.py** di-update:
  - Tambah `REQUEST_INSTALL_PACKAGES` (wajib untuk install APK dari DownloadManager)
  - Tambah `POST_NOTIFICATIONS` (Android 13+ untuk notif progress)
  - Tetap ada INTERNET + queries WhatsApp/browser/email
- **tools/siapkan_pembaruan.py** (baru, 200+ baris):
  - Cari `MainActivity.kt` / `MainActivity.java` di `android/`
  - Inject imports `DownloadManager`, `Intent`, `Uri`, `MethodChannel`
  - Inject handler `xycloud/updater` di `configureFlutterEngine`
  - Validasi URL harus mengandung `xycloud.my.id` (prevent open redirect)
  - Simpan APK di `externalFilesDir/update/xycloud-update.apk` (aman, tanpa storage permission)
  - Idempotent — kalau sudah ada, dilewati
- **.github/workflows/build-apk.yml** di-update:
  - Step baru setelah `siapkan_streaming.py`:
    ```yaml
    - name: Siapkan updater native
      working-directory: app
      run: python3 ../tools/siapkan_pembaruan.py android
    ```

### Cara Uji Native (wajib di device)
```bash
cd app
flutter create . --platforms=android --org id.xycloud --project-name xycloud_order
python3 ../tools/siapkan_streaming.py
python3 ../tools/siapkan_pembaruan.py android
python3 ../tools/patch_manifest.py android/app/src/main/AndroidManifest.xml
flutter pub get
flutter analyze
flutter build apk --release
# Pasang APK lama, naikkan versi di server, buka app → popup muncul → X → PembaruanScreen
# Tap Perbarui Sekarang → cek notifikasi progress → tutup app → notif tetap jalan → selesai → tap untuk pasang
```

---

## 2. Fitur & Menu Baru — Proposal (App + Dash)

User pilih "kasih saran dulu". Berikut usulan menu baru yang cocok sama XyCloudStore (sewa PC + akun digital + komunitas).

### App — 10 Menu Baru (dari 5 jadi 8 bottom nav + drawer)
**Bottom Nav tetap 5, tapi isi diperkaya + drawer profil lebih lengkap:**

1. **Beranda** (existing, upgrade):
   - Tambah widget Live PC Status (berapa unit RTX 4090 online realtime)
   - Banner promo carousel + floating promo
   - Kartu "Pesanan Aktif" dengan countdown

2. **Sewa PC** (existing, upgrade):
   - Filter baru: GPU tier, region, harga, ready only
   - Favorit PC (heart icon)
   - Compare 2 paket

3. **Akun Digital** (existing, upgrade):
   - Wishlist + kategori filter chip
   - Badge "Best Seller" + "Garansi Terpanjang"
   - Ulasan dengan foto

4. **Komunitas** (existing, upgrade):
   - Tab: Trending, Terbaru, Mengikuti
   - Search + filter kategori
   - Mention + notif balasan

5. **Profil** (existing, upgrade jadi hub):
   - Drawer dengan:
     - Dompet (existing)
     - Order List (existing)
     - **Voucher Saya** (baru)
     - **Referral & Komisi** (baru)
     - **Notifikasi** (existing)
     - **Pengaturan** (existing)
     - **Bantuan & CS** (baru, gabung FAQ + Chat)
     - **Tentang & Versi** (existing)

**Menu Baru yang diusulkan (bisa jadi screen baru):**
6. **Voucher & Promo** — list voucher aktif, klaim, pakai di checkout
7. **Referral / Affiliate** — kode referral, share, lihat komisi, withdraw
8. **Leaderboard** — top spender, top pengundang, badge
9. **Status Unit Live** — peta unit PC, ping, load, region
10. **Pusat Bantuan** — FAQ searchable, video tutorial, kontak WA

### Dashboard Console — Menu Baru (dari 26 jadi 35+)
Existing: dash, orders, plans, produk, banners, promosi, stiker, security, perangkat, sampah, media, audit, cs, statistik, moderasi, galat, analitik, referral, unit, forum, voucher, topup, ulasan, users, alat, sistem, peran

**Usulan tambahan:**
- **Live Unit Monitor** — websocket live status semua agen, CPU/RAM/GPU, restart remote
- **Anti-Abuse Dashboard** — deteksi multi-akun, device fingerprint, IP, transaksi mencurigakan
- **Keuangan** — omzet harian/mingguan, fee, saldo beredar, topup pending, export CSV
- **Manajemen Voucher Lanjutan** — bulk generate, export, analytics pemakaian
- **Notifikasi Push Builder** — compose push dengan targeting (semua, tier, user tertentu) + schedule
- **Email Campaign** — template, preview, kirim massal
- **Manajemen Rilis (Update App)** — upload APK, set versi, catatan, gambar tema (ramadan dll), publish
- **Log Aktivitas Detail** — filter per admin, per aksi, timeline
- **Pengaturan Web** — kelola hero, SEO, FAQ, kontak WA, banner
- **KYC / Verifikasi** — untuk topup besar, cek KTP (optional)

---

## 3. Dashboard Upgrade ke Next.js — Full Rewrite

User pilih **full Next.js**. Rencana:

### Struktur Baru
```
dashboard/ (Next.js 14 App Router)
  app/
    layout.tsx (sidebar + theme violet-indigo #7C3AED)
    page.tsx (dashboard)
    orders/page.tsx
    users/page.tsx
    plans/page.tsx
    produk/page.tsx
    rilis/page.tsx (manajemen update app + tema popup)
    security/page.tsx
    ... (semua menu)
  components/
    ui/ (Card, Button, Tag, Table, Modal — pakai Tailwind + XyTheme)
    layout/Sidebar.tsx (violet-indigo glossy, collapsible)
    charts/ (bar, line)
  lib/
    api.ts (fetch ke /api/admin dengan x-admin-key)
    theme.ts (palet #7C3AED / #100030)
  public/
    brand/
  tailwind.config.js
  package.json
```

### Kenapa Next.js?
- **Performa:** admin.html sekarang 1800 baris single file, render semua tabel sekaligus → lag di data banyak. Next.js bisa virtualisasi, pagination server-side, debounce search.
- **Maintainability:** komponen reusable, TypeScript, tidak lagi edit 1 file raksasa.
- **Security:** middleware untuk cek admin key, rate limit, audit log lebih rapi.
- **Fitur baru lebih cepat:** tambah menu baru tinggal bikin folder `app/namamenu/page.tsx`.

### Tahapan Migrasi
1. **Scaffold dashboard/** — `npx create-next-app@latest dashboard --typescript --tailwind --app`
2. **Port theme** — Tailwind config dengan warna v3.2 `#7C3AED / #100030`
3. **Buat Sidebar** — mirror MENU dari admin.html, tapi pakai Next.js Link + active state
4. **Port 3 menu pertama** sebagai POC: Dashboard (stats), Orders, Users (dengan multi-select yang sudah ada)
5. **Auth** — simpan admin key di httpOnly cookie atau localStorage + header `x-admin-key`
6. **API proxy** — Next.js route `/api/admin/*` proxy ke Worker (biar tidak CORS)
7. **Jika POC oke**, port semua menu lain bertahap, admin.html tetap jalan sebagai fallback sampai full migrasi.

### Catatan
- Backend tetap Cloudflare Workers + D1 (tidak diubah)
- Build dashboard bisa di-deploy ke Vercel / Cloudflare Pages terpisah, atau di-serve dari Worker via `/admin-next/*`
- File `api/src/admin.html` jangan dihapus sampai Next.js 100% ready.

---

## 4. Security — Full Audit (Semua Lapisan)

User pilih **audit semua**. Berikut checklist yang akan dikerjakan:

### A. API & Auth
- [ ] Rate limit per endpoint: `/auth/login`, `/auth/register`, `/auth/verify`, `/wallet/topup`, `/orders`, `/akun/beli`
- [ ] Device fingerprint: `X-XY-Device` header wajib, validasi format 64 hex, block kalau abusive
- [ ] Admin key: rotate periodic, log pemakaian, bedakan peran (pemilik/cs/moderator) sudah ada tapi perlu perketat menu Sistem & Peran hanya pemilik
- [ ] OTP: digest (sudah), expiry 10 menit, max 3 percobaan, IP + email limit (sudah ada config tapi perlu audit)

### B. Transaksi & Saldo
- [ ] Atomic claim kredensial (sudah di v3.0c) — pastikan tidak ada race condition
- [ ] Saldo tidak boleh minus: `WHERE saldo >= ?` (sudah) + check di semua jalur (sewa, beli akun, voucher)
- [ ] Webhook topup idempotent: claim status `disetujui` hanya sekali (sudah) + log duplicate webhook
- [ ] Voucher: validasi `min_belanja`, `maks_potongan`, `kuota`, `berlaku_sampai`, tidak bisa stack abuse
- [ ] Bukti transfer: validasi file type, size max 5MB, scan via Cloudinary, jangan simpan base64 di D1

### C. Upload & Media
- [ ] Validasi `file` base64: max 5MB (produk) / 4MB (promo) / 2MB (stiker) — sudah ada tapi perlu di semua endpoint
- [ ] Content-Type whitelist: hanya image/png, jpeg, webp, gif
- [ ] Sanitasi URL: hanya izinkan https:// + domain Cloudinary / xycloud.my.id
- [ ] `mediaUrl` di admin.html & web.html sudah pakai proxy `/img/` — pastikan tidak ada XSS via `esc()`

### D. Forum & Ulasan
- [ ] Rate limit post forum: max 5 post/jam per user
- [ ] Filter kata kasar / spam link (moderasi)
- [ ] Laporan (sudah ada `laporan` table) + auto-sensitif jika banyak laporan
- [ ] Hapus permanen hanya owner atau moderator + audit log

### E. Perangkat & Pendaftaran
- [ ] Device limit 2 akun per device (sudah) + IP limit (sudah) — perlu reset manual hanya oleh pemilik + audit
- [ ] Block device: cek di semua auth flow, tidak hanya register
- [ ] Identitas browser: 64 hex random, simpan di localStorage, bukan fingerprint invasif

### F. Dashboard & Web
- [ ] CSP header di Worker: `default-src 'self'` + whitelist Cloudinary, Giphy, OneSignal
- [ ] `esc()` di semua innerHTML (sudah) — audit ulang, jangan ada `innerHTML = userInput` tanpa esc
- [ ] Admin.html & web.html: jangan expose admin key di client JS (sudah pakai header, tapi cek lagi)
- [ ] Next.js: pakai httpOnly cookie untuk admin key, bukan localStorage (lebih aman dari XSS)

### G. APK & Native
- [ ] Validasi URL update hanya `xycloud.my.id` (sudah di Kotlin + Flutter)
- [ ] Signing key sama untuk semua APK (sudah di CI)
- [ ] `allowBackup=false` (sudah di patch_manifest)
- [ ] `REQUEST_INSTALL_PACKAGES` hanya dipakai untuk updater, jangan untuk fitur lain

---

## 5. Push Build Tapi Jangan Release Dulu — Alur Baru

User: "kalo udh Lu boleh Push build Tapi jan releases dlu, Gua harus tes dlu"

**Ngerti bre.** Alurnya sekarang:

1. **Push build** = `git push origin main` → trigger GitHub Actions `Build Android APK` → hasil APK ada di **Artifacts** (bukan Release). Kamu bisa download APK universal + per-ABI dari tab Actions.
2. **Jangan release** = jangan push tag `v*`. Job `release` di workflow hanya jalan kalau ada tag `v*` (misal `v3.3.0`). Jadi selama kita push ke `main` saja, tidak akan bikin Release otomatis.
3. **Kamu tes dulu** → download APK dari Artifacts → pasang di HP → cek fitur baru, security, native updater, popup tema.
4. **Kalau udah mantep**, baru kamu bilang "release" → kita push tag `v3.3.0` → baru bikin Release + daftarkan ke server via `daftar_rilis.py`.

**Jadi:** push ke main = build doang, aman buat tes. Release = tag, baru publik.

---

## 6. Progress & Next Steps

### Sudah (v3.2, sudah push)
- ✅ Violet-Indigo Glossy #100030 + #7C3AED ke semua UI/UX
- ✅ Popup support tema + docs PopupUpdate.md
- ✅ Native channel di Flutter + patch_manifest + siapkan_pembaruan.py (baru) + workflow update
- ✅ Push ke main (a1c267e)

### Sedang Dikerjakan (v3.3, belum push)
- 🔄 Docs rencana-3.3.md ini
- ⏳ Scaffold dashboard Next.js (folder dashboard/)
- ⏳ Security audit checklist + implementasi rate limit tambahan di index.js
- ⏳ Tambah menu baru di app (Voucher Saya, Referral, Leaderboard) — butuh flutter code

### TODO Setelah Ini
- [ ] Buat `dashboard/` Next.js minimal POC (layout + sidebar + 3 halaman)
- [ ] Tambah rate limit middleware di `api/src/index.js` (misal 10 req/menit per IP untuk /auth/*)
- [ ] Tambah screen baru di Flutter: `voucher_screen.dart`, `referral_screen.dart`, `leaderboard_screen.dart`
- [ ] Update `shell.dart` untuk drawer baru
- [ ] Push build ke main (bukan tag) → kamu tes
- [ ] Kalau oke, baru release tag v3.3.0

---

## 7. File Terkait

- Native: `app/lib/data/pembaruan_channel.dart`, `tools/siapkan_pembaruan.py`, `tools/patch_manifest.py`, `.github/workflows/build-apk.yml`
- Security: `api/src/index.js`, `api/src/security.js`, `api/src/admin_security.js`, `api/src/sistem.js`
- App menus: `app/lib/ui/screens/shell.dart`, `app/lib/ui/screens/*.dart`
- Dash: `api/src/admin.html` (lama), `dashboard/` (baru, Next.js)
- Docs: `docs/PopupUpdate.md`, `docs/rencana-3.0.md`, `docs/rencana-3.3.md` (ini)

