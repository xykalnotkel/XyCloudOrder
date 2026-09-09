# Agen PC Host XyCloudStore (Rust + Tauri, tanpa Python)

Program kecil yang dijalankan di setiap PC/VM yang disewakan untuk menyambungkan mesin
ke server XyCloudStore: sesi sewa bisa **dinyalakan, dipasangkan, dan ditutup** otomatis
dari aplikasi. Ditulis dalam **Rust + Tauri v2** — tidak ada runtime Python, tidak ada
ps2exe. Pengganti `xy_agent_ui.ps1` / `xy_agent.py` versi lama.

```
Aplikasi (HP)          Server Cloudflare            Agen (Rust) di PC        Sunshine
     |  Mulai Main  ->        |                          |                       |
     |                        |  simpan sesi + perintah  |                       |
     |                        |  <-- heartbeat 20 dtk    |                       |
     |                        |  --> perintah mulai      |                       |
     |                        |                          |  bersihkan mesin     |
     |                        |                          |  cek API 47990  -->  |
     |  status: siap  <--     |  <-- lapor siap          |                       |
     |  kirim PIN     ->      |  --> perintah pasangkan  |                       |
     |                        |                          |  POST /api/pin  -->  |
     |  status: berjalan <--  |  <-- lapor berhasil      |                       |
```

Agen hanya menghubungi keluar (server) + API lokal Sunshine; PC tidak perlu membuka
port apa pun untuk pengendalian. Port streaming Sunshine (47984/47989 TCP, 48010 TCP,
47998–48002 UDP) tetap yang dibuka ke internet bila diperlukan.

## Struktur

| Path | Isi |
|---|---|
| `agent-gui/src-tauri/src/main.rs` | Komando Tauri (simpan/status/uji/setup/mulai/henti/autostart) |
| `agent-gui/src-tauri/src/agent.rs` | Inti agen: heartbeat, eksekusi perintah, kontrol API Sunshine, autostart registry |
| `agent-gui/ui/` | Frontend WebView (HTML/CSS/JS) |
| `agent-gui/src-tauri/Cargo.toml` | Dependensi: tauri v2, reqwest (rustls, ignore self-signed), serde |

## Fitur

- **Jendela pengaturan** (`XyCloudStore-Agent.exe`): isi kode unit, kredensial web-UI
  Sunshine, server API → **Simpan Pengaturan** (tersimpan di `%APPDATA%\XyCloudStore\Agent\config.json`).
- **Auto-setup**: mendeteksi Sunshine; bila belum ada, memasang lewat `winget` otomatis.
- **Uji Koneksi Lokal**: diagnosis setara `--cek` lama — hanya membaca API Sunshine,
  tidak mengirim heartbeat/pairing/penutupan.
- **Jalankan / Hentikan Agen**: mengendalikan loop heartbeat (interval 20 detik).
- **Mulai otomatis saat Windows menyala**: autostart lewat registry `HKCU\...\Run` → menjalankan
  agen mode `-Jalankan` tanpa jendela.
- **Kode asli Rust**: tanpa runtime Python, tanpa dependensi ps2exe.

## Yang perlu disiapkan di PC

1. **Sunshine** (atau **Apollo**, fork layar virtual untuk PC headless).
2. Akun web UI Sunshine saat pertama dibuka di `https://127.0.0.1:47990`.
3. Buka dashboard admin → menu **Unit PC** → **Daftarkan Unit**, salin kode agen.

## Penggunaan

```powershell
# 1) buka UI, isi: kode unit, username/password web UI Sunshine, server API
#    lalu klik: Simpan Pengaturan → Uji Koneksi → (Setup bila perlu) → Jalankan Agen

# 2) verifikasi versi dari CLI:
.\XyCloudStore-Agent.exe --veri

# 3) mode headless (autostart / penjadwal):
.\XyCloudStore-Agent.exe -Jalankan
```

| Hasil uji | Arti dan tindakan |
|---|---|
| `API_SIAP` | Kredensial diterima API Sunshine. Encoder/layar/streaming dari HP masih perlu diuji. |
| `API_TIDAK_SESUAI` / HTTP 401–403 | Sunshine merespons tetapi akses API ditolak; cocokkan akun web UI. |
| `KREDENSIAL_KOSONG` | Username/password Sunshine belum diisi. |
| `TIDAK_TERHUBUNG` | Sunshine tidak merespons di 127.0.0.1:47990; jalankan auto-setup atau periksa service. |

## Catatan keamanan

- Akses ke Sunshine memakai `https://127.0.0.1:47990` dengan sertifikat self-signed
  yang diterima longgar — hal yang sama dilakukan versi Python lama; hanya proses lokal
  yang dapat menjangkaunya karena web UI tidak dibuka ke internet.
- Server XyCloud hanya bisa memerintahkan agen yang sudah punya **kode unit** yang valid.
- Sebelum menyimpan sandi, konfirmasi: sandi tetap disimpan **plaintext di
  `%APPDATA%`** milik akun Windows pengguna (versi baru tidak lagi memakai Python/DPAPI
  wrapper; folder `%APPDATA%\XyCloudStore\Agent` hanya bisa dibaca oleh akun itu).
