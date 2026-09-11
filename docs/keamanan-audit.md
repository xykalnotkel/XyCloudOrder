# Keamanan — status terkini (2026-09-11)

> Banyak checklist di bawah ini sudah **diimplementasi** di Worker (`index.js` + `security.js`). Ringkasan verifikasi kode:
>
> | Item | Status kode |
> |---|---|
> | Rate limit login IP (`login:${ip}` 12/5m) + email | ✅ |
> | Rate limit OTP / OAuth start | ✅ `requireRate` |
> | Device fingerprint `X-XY-Device` 64 hex + kuota daftar | ✅ `beforeRegistration` |
> | Forum max 5 post/jam (memory + D1) + `bolehLanjut` | ✅ |
> | CSP di respons JSON/HTML/admin/web | ✅ beberapa profil CSP |
> | Atomic topup / saldo / claim kredensial | ✅ (v3.0+) |
> | Dashboard Next.js shell + aksi admin | ✅ migrasi 2026-09-11 |
> | Admin key httpOnly cookie (Next proxy) | ⏳ ditunda (static export Pages) |
> | Filter kata kasar otomatis | ⏳ backlog |
> | Admin key rotate endpoint | ⏳ backlog |
>
> Detail historis checklist tetap di bawah untuk jejak audit.

---

# Keamanan Audit — v3.3c Full (Updated 2026-09-09)

> Audit semua lapisan sesuai request user. Status: ✅ sudah ada, ⏳ perlu ditambah di v3.3, ❌ belum.
> Last update: 2026-09-09 — v3.3c hosting replacement + 31 routes dashboard + 8 quick menu app + CSP fonts fix + Worker global-scope fix.

## 1. Ringkasan Temuan v3.3c (Progress 2026-09-09)

### Yang Sudah Aman di v3.3c (baru di-commit)
- **Hosting replacement**: `api/src/admin.html` old 166KB → 8KB redirect launcher v3.3c, preserved as `admin-legacy.html`, CSP updated allow `fonts.googleapis.com`, `fonts.gstatic.com`, `unpkg.com` untuk Plus Jakarta Sans + Lucide CDN. Worker deploy sukses `3f56546b-cfab-4e78-855b-c0c38c690b0c` via `cfut_...` token. Verified curl 200 `xycloud-dashboard.pages.dev`. Legacy fallback `?legacy=1` & `/admin-legacy`.
- **Global IP rate-limit**: 180 req/60s via `securitySlot(env,'global-ip',ip,180,60)` di `api/src/index.js` — atomic D1 `batas` table, fail-open kalau D1 error. Skip untuk admin/agen/webhook.
- **Forum spam**: `rateMem 5/jam` + DB check `SELECT COUNT(*) FROM forum_post WHERE user_id=? AND dibuat>? (1 jam)` + tolak >3 link.
- **Dashboard Next.js**: build sukses 31 routes (27→31 + referral,favorit,galat,sesi), no TS error, Lucide icons, Plus Jakarta Sans, no emoji. Deployed Pages `e2f56dc0.xycloud-dashboard.pages.dev` + Vercel `dashboard-miepqucf4-...` aliased to `dashboard-iota-ten-70`.
- **App 8 quick menu**: Sewa PC, Beli Akun, Top Up, Chat, Komunitas, Voucher, Referral, Favorit (2 rows) + Jelajahi chips Statistik, Leaderboard, Tier — no emoji, Material icons, Plus Jakarta Sans consistent. File `home_screen.dart` rewritten v3.3c.
- **Worker global-scope fix**: `setInterval` removed (Disallowed operation in global scope) — cleanup moved to comment, will be in scheduled handler.
- **Upload validasi**: sudah di `upload.js` whitelist png/jpeg/jpg/webp/gif, 5MB, signed Cloudinary.
- **Device limit 2**: `security.js beforeRegistration` + DB trigger `DEVICE_LIMIT`.
- **Updater native**: `tools/siapkan_pembaruan.py` idempotent inject MethodChannel `xycloud/updater` DownloadManager + notif progress tetap jalan walau app ditutup, validated domain `xycloud.my.id`, `patch_manifest.py` includes REQUEST_INSTALL_PACKAGES + POST_NOTIFICATIONS.

### Yang Masih TODO (low priority, next slice)
- httpOnly cookie untuk admin key di Next.js (saat ini localStorage).
- CSP header Next.js dashboard (headers() in next.config.js sudah SAMEORIGIN + nosniff, bisa tambah font-src).
- Voucher stack abuse: sudah cek 1 voucher per transaksi, tapi perlu test e2e concurrent.
- Generate gambar popup tema Ramadan etc — nanti pas waktunya (sesuai instruksi user).

## 2. Ringkasan Temuan v3.2 (Sudah Push a1c267e)

### Yang Sudah Aman
- **Transaksi atomik (v3.0c)**: `WHERE status='tersedia'` + `UPDATE ... WHERE id=? AND status='tersedia'` untuk klaim kredensial akun — cegah double claim.
- **Saldo anti-minus**: `WHERE saldo >= ?` di semua jalur sewa/beli, plus check di aplikasi.
- **Device limit**: max 2 pendaftaran per device_id + IP limit, ada tabel `device_reg` + `blocked_devices`.
- **OTP**: digest SHA256, expiry 10 menit, max 3 percobaan, rate limit IP + email (config `OTP_MAX_PER_EMAIL_PER_JAM=3`, `OTP_MAX_PER_IP_PER_JAM=10`).
- **Upload validasi**: max 5MB produk, 4MB promo, 2MB stiker, whitelist mime `image/png/jpeg/webp/gif`.
- **esc()**: semua `innerHTML` di `admin.html` & `web.html` sudah pakai `esc()` untuk cegah XSS.
- **APK signing**: keystore sama untuk semua ABI, `allowBackup=false`, `REQUEST_INSTALL_PACKAGES` hanya untuk updater.
- **URL update validasi**: Kotlin + Flutter cek `contains xycloud.my.id`.
- **Admin key**: header `x-admin-key`, tidak di-expose di client JS (hanya dipakai di fetch header).

### Yang Perlu Ditingkatkan (v3.3 TODO)
- Rate limit per endpoint belum ada middleware global — baru di beberapa endpoint (OTP).
- Admin key masih di localStorage (rentan XSS kalau ada celah). Next.js akan pakai httpOnly cookie.
- CSP header belum di-set di Worker.
- Forum spam: belum ada rate limit post/jam.
- Voucher stack abuse: perlu validasi tidak bisa pakai 2 voucher sekaligus.
- Webhook topup idempotent sudah, tapi perlu log duplicate lebih jelas.

---

## 2. Checklist Detail Per Lapisan

### A. API & Auth — `api/src/index.js`, `api/src/security.js`

| Item | Status | Catatan |
|------|--------|---------|
| Rate limit `/auth/login` | ⏳ | Tambah 10 req/menit/IP |
| Rate limit `/auth/register` | ⏳ | 5 req/menit/IP |
| Rate limit `/auth/verify` | ✅ | Sudah ada limit OTP |
| Device fingerprint wajib | ✅ | `X-XY-Device` header, 64 hex |
| Block device check di semua auth flow | ✅ | `isDeviceBlocked()` dipanggil di register & login |
| Admin key rotate | ⏳ | Buat endpoint rotate di `sistem.js`, hanya pemilik |
| Peran: Sistem & Peran hanya pemilik | ✅ | Sudah cek `role=owner` di admin_security |
| CORS ketat | ✅ | Hanya `xycloud.my.id` + localhost dev |

**Implementasi v3.3:**
```js
// di api/src/index.js tambah middleware rateLimit
const RL = new Map();
function rateLimit(key, max, windowMs) {
  const now = Date.now();
  const arr = RL.get(key) || [];
  const fresh = arr.filter(t => now - t < windowMs);
  if (fresh.length >= max) return false;
  fresh.push(now); RL.set(key, fresh); return true;
}
// pakai di /auth/login, /auth/register, /auth/lupa-password, /forum/buat, /akun/beli, /wallet/topup
```

### B. Transaksi & Saldo — `api/src/dompet.js`, `api/src/sewa.js`, `api/src/akun.js`

| Item | Status | Fix |
|------|--------|-----|
| Atomic claim kredensial | ✅ | `UPDATE kredensial SET status='terpakai' WHERE id=? AND status='tersedia'` |
| Saldo minus | ✅ | `UPDATE users SET saldo = saldo - ? WHERE id=? AND saldo >= ?` |
| Webhook topup idempotent | ✅ | Cek `status='disetujui'` sudah pernah, jika iya skip |
| Voucher min_belanja, maks_potongan, kuota, expired | ✅ | Sudah di `cekVoucher` |
| Voucher tidak bisa stack | ⏳ | Tambah validasi hanya 1 voucher per transaksi di `sewa.js` |
| Bukti transfer 5MB max | ✅ | Validasi size di frontend + backend |

### C. Upload & Media — `api/src/media.js`, `api/src/admin_produk.js`, `api/src/admin_banners.js`

| Item | Status |
|------|--------|
| Validasi file base64 size | ✅ |
| Whitelist mime | ✅ |
| Sanitasi URL https only | ✅ |
| mediaUrl proxy `/img/` | ✅ |
| Cloudinary upload aman | ✅ |

**Tambahan v3.3:** tambah validasi `data:` URI harus `data:image/(png|jpeg|webp|gif);base64,` saja, tolak `data:text/html`.

### D. Forum & Ulasan — `api/src/forum.js`, `api/src/ulasan.js`

| Item | Status | Fix v3.3 |
|------|--------|----------|
| Rate limit post forum 5/jam | ⏳ | Tambah `SELECT COUNT(*) FROM forum WHERE user_id=? AND created_at > ?` |
| Filter kata kasar | ⏳ | List sederhana + moderasi manual |
| Spam link | ⏳ | Tolak jika ada >3 URL atau domain mencurigakan |
| Laporan auto-sensitif | ✅ | Sudah ada `laporan` table |
| Hapus hanya owner/moderator + audit log | ✅ | Sudah |

### E. Perangkat — `api/src/security.js`

| Item | Status |
|------|--------|
| Device limit 2 akun | ✅ |
| IP limit | ✅ |
| Block device | ✅ |
| Identitas browser 64 hex random | ✅ |

### F. Dashboard & Web — `api/src/admin.html`, `api/src/web.html`, `dashboard/`

| Item | Status | Fix |
|------|--------|-----|
| CSP header | ⏳ | Tambah di Worker: `Content-Security-Policy: default-src 'self' https://api.xycloud.my.id https://res.cloudinary.com https://*.giphy.com` |
| esc() di innerHTML | ✅ | Sudah, tapi audit ulang sebelum v3.3 |
| Admin key expose | ✅ | Tidak di-expose, hanya header |
| Next.js httpOnly cookie | ⏳ | Implementasi di `dashboard/app/api/auth/route.ts` (proxy) |

### G. APK & Native — `tools/patch_manifest.py`, `tools/siapkan_pembaruan.py`

| Item | Status |
|------|--------|
| Validasi URL xycloud.my.id | ✅ |
| Signing key sama | ✅ |
| allowBackup=false | ✅ |
| REQUEST_INSTALL_PACKAGES hanya updater | ✅ |
| POST_NOTIFICATIONS untuk notif progress | ✅ (baru di v3.3) |
| externalFilesDir (aman tanpa storage perm) | ✅ |

---

## 3. Implementasi Kode Baru v3.3 (Akan Dikerjakan)

### 3.1 Rate Limit Middleware (api/src/index.js)

```js
const rateBuckets = new Map();
function checkRate(ip, route, max, windowSec) {
  const key = `${ip}:${route}`;
  const now = Date.now()/1000;
  let bucket = rateBuckets.get(key) || [];
  bucket = bucket.filter(t => t > now - windowSec);
  if (bucket.length >= max) return false;
  bucket.push(now);
  rateBuckets.set(key, bucket);
  return true;
}

// contoh pakai:
if (path === '/api/auth/login' && !checkRate(ip, 'login', 10, 60)) return Response.json({error:'Terlalu banyak percobaan'}, {status:429});
```

### 3.2 CSP Header (api/src/index.js)

```js
headers.set('Content-Security-Policy', "default-src 'self'; img-src 'self' https://res.cloudinary.com https://media.giphy.com data:; script-src 'self' 'unsafe-inline' https://*.onesignal.com; connect-src 'self' https://api.xycloud.my.id wss://*.xycloud.my.id");
headers.set('X-Frame-Options', 'SAMEORIGIN');
headers.set('X-Content-Type-Options', 'nosniff');
```

### 3.3 Forum Spam Guard

```js
// di forum buat
const satuJamLalu = new Date(Date.now()-3600000).toISOString();
const { count } = await db.prepare('SELECT COUNT(*) as count FROM forum WHERE user_id=? AND created_at>?').bind(userId, satuJamLalu).first();
if (count >= 5) return error 429 'Maks 5 post per jam';
if ((isi.match(/https?:\/\//g) || []).length > 3) return error 400 'Terlalu banyak link';
```

---

## 4. Testing Checklist

- [ ] Coba daftar 3 akun dengan device_id sama → harus ditolak akun ke-3
- [ ] Coba beli akun yang sama dari 2 device bersamaan → hanya 1 yang dapat kredensial (atomic)
- [ ] Coba topup webhook dipanggil 2x → hanya 1x yang nambah saldo
- [ ] Coba upload file 10MB → ditolak
- [ ] Coba pakai voucher 2x di transaksi sama → ditolak
- [ ] Coba post forum 6x dalam 1 jam → ditolak post ke-6
- [ ] Coba login 11x dalam 1 menit dari IP sama → 429
- [ ] Coba XSS di nama produk `<script>alert(1)</script>` → harus ter-escape jadi teks
- [ ] Coba update APK dari URL selain xycloud.my.id → ditolak di native
- [ ] Cek notif progress tetap jalan walau app ditutup (Android)

---

## 5. File Terkait

- `api/src/index.js` — tambah rate limit + CSP
- `api/src/security.js` — device & IP limit (sudah)
- `api/src/forum.js` — spam guard
- `api/src/admin_security.js` — role check
- `tools/siapkan_pembaruan.py` — validasi URL (sudah)
- `tools/patch_manifest.py` — permissions (sudah update)
- `dashboard/` — Next.js dengan httpOnly cookie (TODO)
- `app/lib/data/pembaruan_channel.dart` — validasi URL (sudah)

---

## 6. Progress

- ✅ Audit & dokumen ini
- ✅ patch_manifest + siapkan_pembaruan sudah push (v3.2)
- ⏳ Implementasi rate limit + CSP di Worker (next commit)
- ⏳ Port dashboard ke Next.js (POC sudah ada di `dashboard/`)
- ⏳ Flutter menu baru (voucher, leaderboard, live unit, bantuan) — sudah dibuat di v3.3 ini

> Catatan: push build ke main boleh, tapi jangan tag release `v*` sampai user tes APK. Build artifact ada di GitHub Actions → Artifacts.

