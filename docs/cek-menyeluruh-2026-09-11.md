# Cek menyeluruh — 2026-09-11 (tanpa build lokal)

Head: lihat `git log -1` saat laporan ini ditulis.

## Git / remote
- `main` lokal = remote (fetch cocok).
- CI otomatis jalan tiap push (APK + deploy workflow).

## CI temuan (sebelum perbaikan hotfix)
| Run | Workflow | Hasil | Penyebab |
|---|---|---|---|
| head `ca6ad59` | Build Android APK | **failure** | `common.dart` `Pill(this.Pill, …)` — regresi regex const; field `teks` tidak terinisialisasi |
| head `ca6ad59` | deploy-dashboard | **failure** (0 jobs) | YAML invalid: step name `Build Next.js (output: export → out/)` mengandung `:` tanpa quote |

## Kode — ringkas
| Area | Status |
|---|---|
| Flutter `Color(0xFF)` di luar theme | 1 sisa: Facebook blue di `brand_logos.dart` (sengaja) |
| Import `theme.dart` untuk `XyTheme` | lengkap |
| Dashboard pages | 45; 0 TODO/placeholder; 1 tipis (`alat` L36, sengaja form uji) |
| Worker CS rooms SQL | 1 salinan (alias digabung) |
| `moderasi.js` | forum post/balas + cs/messages |
| `peran/:id/rotate` | ada + UI dash |
| Hardcode const+XyTheme | banyak `const TextStyle(color: XyTheme.primary)` — **valid** jika field `static const Color` |

## Backlog sadar (bukan blocker merge)
1. httpOnly cookie admin (butuh non-static Next)
2. FontWeight w700 masih banyak di app (preferensi ≤600 — gaya, bukan error CI)
3. Hex Tailwind di dash belum dipetakan ke `var(--xy-*)` (kosmetik)
4. Lint info Flutter ~328
5. Deploy produksi CF/Vercel/Worker — sekali di akhir + set repo vars
6. Tag `v*` ditahan sampai tes APK

## Perbaikan ikut laporan ini
- Restore `Pill(this.teks, …)`
- Rewrite `deploy-dashboard.yml` (YAML valid, nama step tanpa `:`)
