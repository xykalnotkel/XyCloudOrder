# Konsistensi lintas platform — token kanonik (2026-09-11)

Satu sumber kebenaran visual untuk **App Flutter**, **Web** (`api/src/web.html`), **Dashboard** (`dashboard/`), dan **launcher admin**.

## Warna terang

| Token | Hex | App (`XyTheme`) | Web CSS | Dashboard |
|---|---|---|---|---|
| Primary violet | `#7C3AED` | `primary` | `--u` | `--xy-violet` / `xyLight.violet` |
| Violet pekat | `#5B21B6` | `primaryDeep` | `--u2` | `--xy-violet2` |
| Indigo | `#2E1065` | `primaryDark` | `--u3` | `xyLight.indigo` |
| Violet terang | `#8B5CF6` | `violet` | `--ungu-terang` | — |
| Accent plum | `#A855F7` | `plum` | — | `xyLight.violet3` |
| BG | `#F5F3FF` | `bg` | `--bg` | `--xy-bg` |
| Soft | `#F3F0FF` | `lineSoft` / soft | `--soft` | `--xy-soft` |
| Line | `#E9E3F5` | `line` | `--line` | `--xy-line` |
| Ink | `#1E1B2E` | `ink` | `--ink` | `--xy-ink` |
| Ink soft | `#4B445F` | `inkSoft` | `--ink2` | `--xy-ink2` |
| Muted | `#7C738F` | `muted` | `--muted` | `--xy-muted` |
| Surface | `#FFFFFF` | `surface` | `--putih` | `--xy-card` |
| Gold | `#D9A441` | `gold` | `--emas` | `xyLight.gold` |
| Midnight (hero) | `#100030` | `bgGelap` | — | `xyLight.midnight` |

## Tipografi
- **Font UI:** Inter (bobot **≤ 600** / `font-semibold`).
- Fallback: Plus Jakarta Sans, system-ui.
- Mono: JetBrains Mono (kode / ID).

## Ikon
- App: Material rounded + aset 3D clay (menu).
- Dashboard: **Lucide only** — tanpa emoji.
- Web: SVG inline / Lucide-equivalent, tanpa emoji.

## Tombol
- Pill gradient violet `#A78BFA → #7C3AED` (efek “3D tapi 2D”).
- Radius tombol app: `XyRadius.tombol` (12); dash: `999px` pill.

## Perubahan sesi ini
1. `web.html` `:root` diselaraskan ke hex di atas (sebelumnya `#6C2BE2` / `#FAF8FF` sedikit beda).
2. `admin.html` + web: Inter didahulukan.
3. `dashboard/lib/theme.ts` ekspor `xyLight`.
4. Bobot teks dashboard `font-black/bold` → `font-semibold`.
5. Migrasi admin aksi penuh (lihat `migrasi-dashboard.md`).

## Cek cepat
- App light: `XyTheme.bg` == web `--bg` == dash `--xy-bg`.
- Primary sama di tombol isi saldo (app), CTA web, tombol `xy-btn` dash.
