## Unduh siap pakai

- **Permanent:** https://github.com/xykalnotkel/XyCloudOrder/releases/download/agent-windows/XyCloudStore-Agent-Windows.zip
- Actions artifact: workflow **Build Agen Windows**

> EXE lama yang error `localhost refused to connect` = build tanpa UI embed. Pakai v1.3.2+ dari link di atas.

# Agen PC Host XyCloudStore (Rust + Tauri, v1.3)

Program kecil di setiap PC/VM sewa. Menyambungkan mesin ke server XyCloudStore supaya
sesi **dinyalakan, dipasangkan, dan ditutup otomatis** dari aplikasi HP.

**v1.3** — wizard UI + **auto kredensial Sunshine** (`sunshine --creds`).  
Tidak perlu buka `https://127.0.0.1:47990` / login web UI manual.

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

Agen hanya keluar ke server + API lokal Sunshine. Port streaming Sunshine
(47984/47989 TCP, 48010 TCP, 47998–48002 UDP) tetap dibuka ke internet bila perlu.

## Struktur

| Path | Isi |
|---|---|
| `agent-gui/src-tauri/src/main.rs` | Komando Tauri (simpan/status/uji/setup/mulai/henti/autostart) |
| `agent-gui/src-tauri/src/agent.rs` | Heartbeat, perintah, `sunshine --creds`, winget, autostart |
| `agent-gui/ui/` | Wizard 3 langkah (Unit → Engine → Jalan) |

## Setup di PC (3 klik)

1. **Admin** → [Unit PC](https://admin.xycloud.my.id/unit) → Daftarkan unit → **salin kode**.
2. Unduh `XyCloudStore-Agent.exe` (artifact CI / rilis) → jalankan.
3. Wizard:
   - **1 · Unit** — tempel kode → Simpan & lanjut  
   - **2 · Engine** — *Pasang & kunci otomatis* (winget + `sunshine --creds`, tanpa web UI)  
   - **3 · Jalan** — *Jalankan Agen* (+ opsional autostart Windows)

Opsi lanjutan (username/password Sunshine) hanya jika mau pakai akun yang sudah ada.

## CLI

```powershell
.\XyCloudStore-Agent.exe --veri          # cek versi
.\XyCloudStore-Agent.exe -Jalankan       # headless (autostart)
```

## Hasil uji Engine

| Status | Arti |
|---|---|
| `API_SIAP` | Kredensial OK, API 47990 merespons |
| `API_TIDAK_SESUAI` | Sunshine hidup tapi auth ditolak — ulang auto-setup |
| `KREDENSIAL_KOSONG` | Belum setup — klik *Pasang & kunci otomatis* |
| `TIDAK_TERHUBUNG` | Service/exe belum jalan |

## Keamanan

- API Sunshine hanya `127.0.0.1:47990` (self-signed, diterima longgar).
- Server hanya memerintahkan agen dengan **kode unit** valid.
- Sandi lokal di `%APPDATA%\XyCloudStore\Agent\config.json` (akun Windows itu saja).

## Build

CI: `.github/workflows/agent-windows.yml` → artifact `XyCloudStore-Agent-Windows.zip`.

```powershell
cd agent-gui/src-tauri
cargo build --release --locked
# hasil: target/release/xycloud-agent.exe
```
