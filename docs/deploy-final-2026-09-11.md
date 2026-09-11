# Deploy final — 2026-09-11

Commit head: **`7ccf721`** (`fix(ci): pulihkan Pill(this.teks) + YAML deploy-dashboard valid`)

## Yang di-deploy

| Target | Hasil | Detail |
|---|---|---|
| **Cloudflare Worker `xycloud-api`** | ✅ | Version `d56ffeab-282c-46d6-be19-0c66e18dfca9` · `api.xycloud.my.id` + custom domains |
| **Cloudflare Pages `xycloud-dashboard`** | ✅ | `https://b063f3ef.xycloud-dashboard.pages.dev` · prod `xycloud-dashboard.pages.dev` |
| **Vercel `dashboard` (alias admin)** | ✅ | Prod `https://dashboard-iota-ten-70.vercel.app` · proxy `admin.xycloud.my.id` |
| **Mode pemeliharaan D1** | ✅ OFF | `mode_pemeliharaan=0` (sebelumnya `1` + pesan pengembangan) |
| **APK (CI artifact `7ccf721`)** | ✅ unduh | run `34593655334` → `rilis/XyCloudStore-arm64-v8a.apk` + universal |
| **Tag `v*`** | ⏸ ditahan | setelah kamu tes APK |

## CI repo (siap push berikutnya)

**Vars:** `ENABLE_CF_PAGES=true`, `ENABLE_VERCEL=true`, `ENABLE_WORKER_DEPLOY=true`  
**Secrets ditambah:** `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, `VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID`  
(keystore + `ADMIN_KEY` sudah ada sebelumnya)

## Smoke test pasca-deploy

| URL | Status |
|---|---|
| `GET /health` | 200 `ok` |
| `GET /api/config` | 200 |
| `GET /api/forum` | 200 data |
| `GET /api/banners` | 200 data |
| `GET /api/produk` (tanpa token) | 401 (normal) |
| `https://admin.xycloud.my.id/` | 200 Next console |
| `…/peran` chunk | memuat **Putar** + `/api/admin/peran` + rotate |

## APK untuk uji

- `rilis/XyCloudStore-arm64-v8a.apk` (~35 MB) — HP arm64 modern  
- `rilis/XyCloudStore-universal.apk` (~76 MB) — cadangan semua ABI  

Sumber: artifact CI Build Android APK sukses di `7ccf721`.

## Checklist uji manual (kamu)

1. Install APK arm64 → login (email/Google)  
2. Saldo tampil; topup staging kecil  
3. Orders / unit  
4. Forum: post + filter kasar  
5. CS chat: filter kasar  
6. Admin: login → Peran → **Putar** kunci tambahan  
7. `?legacy=1` darurat di api host masih ada  

## Tidak diubah / ditunda

- Tag GitHub Release / `v*`  
- httpOnly cookie admin (butuh non-`output: 'export'` + proxy)  
- Upgrade Next 14.2.5 (ada advisory upstream; di luar scope final ini)

