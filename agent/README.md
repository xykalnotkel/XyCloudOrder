# Agen PC Host XyCloudStore

Program kecil yang dijalankan di setiap PC atau VM yang disewakan. Tugasnya menyambungkan mesin itu
ke server XyCloudStore supaya sesi sewa bisa dinyalakan, dipasangkan, dan ditutup otomatis dari aplikasi.

## Cara paling gampang (Windows): instal otomatis

Berkas **`instal_otomatis.ps1`** berperan seperti aplikasi installer:

- Mengecek & **otomatis memasang Python** (winget) bila belum ada.
- Mengecek & **otomatis memasang Sunshine** (engine streaming) bila belum ada.
- Memandu isi **kode unit** (dari dashboard → Unit PC) + kredensial web-UI Sunshine sekali saja
  (disimpan **terenkripsi DPAPI** akun Windows, bukan teks polos).
- Menjalankan diagnosis `--cek`, lalu **menjalankan agen** dan **mendaftarkan autostart**
  (penjadwal `XyAgent` @ saat PC dinyalakan).

Cara pakai: letakkan `instal_otomatis.ps1` **di folder yang sama dengan `xy_agent.py`**,
klik kanan → *Run with PowerShell*. Jalankan ulang kapan saja untuk mengubah konfigurasi.

## Cara kerja singkat

```
Aplikasi (HP)          Server Cloudflare            Agen di PC             Sunshine
     |  Mulai Main  ->        |                          |                     |
     |                        |  simpan sesi + perintah  |                     |
     |                        |  <-- heartbeat 20 detik  |                     |
     |                        |  --> perintah mulai      |                     |
     |                        |                          |  bersihkan mesin    |
     |                        |                          |  cek Sunshine  -->  |
     |  status: siap  <--     |  <-- lapor siap          |                     |
     |  buka Moonlight, dapat PIN                        |                     |
     |  kirim PIN     ->      |  --> perintah pasangkan  |                     |
     |                        |                          |  POST /api/pin -->  |
     |  status: berjalan <--  |  <-- lapor berhasil      |                     |
```

Agen **hanya menghubungi keluar**, jadi PC tidak perlu membuka port apa pun untuk pengendalian.
Yang tetap harus terbuka hanyalah port streaming Sunshine.

## Yang perlu disiapkan di PC

1. **Sunshine** (atau **Apollo**, fork yang mendukung layar virtual - lebih cocok untuk PC sewaan headless).
   Unduh dari https://github.com/LizardByte/Sunshine atau https://github.com/ClassicOldSong/Apollo
2. Buat akun web UI Sunshine saat pertama kali dibuka di `https://127.0.0.1:47990`.
3. Python 3.9 ke atas.
4. Port yang dibuka ke internet:

| Port | Protokol | Guna |
|---|---|---|
| 47984, 47989 | TCP | Pairing dan handshake |
| 48010 | TCP | RTSP video |
| 47998, 47999, 48000, 48002 | UDP | Video, audio, kontrol, input |
| 47990 | TCP | **Jangan pernah dibuka ke internet**, ini web UI |

## Memasang agen

1. Buka dashboard admin, menu **Unit PC**, klik **Daftarkan Unit**, salin kode agennya.
2. Salin `xy_agent.py` ke PC tersebut.
3. Jalankan sesuai shell. **PowerShell menggunakan `$env:`, bukan `set` milik CMD.**

### PowerShell (seperti prompt `PS C:\Users\...>`)

Jalankan pada PC/VM yang juga menjalankan Sunshine. Username/password di bawah adalah
**akun web UI Sunshine**, bukan login Windows dan bukan kode unit XyCloud.

```powershell
$env:XY_AGEN_KODE = Read-Host "Kode unit XyCloud"
$env:XY_SUNSHINE_USER = Read-Host "Username web UI Sunshine"
$pw = Read-Host "Password web UI Sunshine" -AsSecureString
$env:XY_SUNSHINE_PASS = [System.Net.NetworkCredential]::new("", $pw).Password
python .\xy_agent.py --cek
# Bila hasilnya API_SIAP, jalankan agen:
python .\xy_agent.py
```

Password tidak dicetak dan tidak ditulis ke berkas oleh agen. Variabel hanya berlaku
pada sesi PowerShell ini; isi lagi bila membuka terminal baru. Setelah agen dihentikan,
`Remove-Item Env:XY_SUNSHINE_PASS` menghapus nilai dari environment terminal tersebut.

### CMD (bukan PowerShell)

```cmd
set XY_AGEN_KODE=KODE_UNIT_KAMU
set XY_SUNSHINE_USER=USERNAME_SUNSHINE
set XY_SUNSHINE_PASS=PASSWORD_SUNSHINE
python xy_agent.py --cek
python xy_agent.py
```

### Linux

```bash
export XY_AGEN_KODE=KODE_UNIT_KAMU
export XY_SUNSHINE_USER=USERNAME_SUNSHINE
read -rsp "Password Sunshine: " XY_SUNSHINE_PASS; echo
export XY_SUNSHINE_PASS
python3 xy_agent.py --cek
python3 xy_agent.py
```

## Diagnosis Sunshine (agen 1.1.0)

```powershell
Test-NetConnection 127.0.0.1 -Port 47990
python .\xy_agent.py --cek
```

`--cek` hanya membaca API lokal: **tidak mengirim heartbeat, tidak mengambil perintah,
tidak pairing, dan tidak menutup/membersihkan aplikasi**. Kode unit tidak diperlukan.

| Hasil | Arti dan tindakan |
|---|---|
| `API_SIAP` | Kredensial diterima API Sunshine. Encoder, layar, dan streaming dari HP masih perlu diuji. |
| `LOGIN_DITOLAK` / HTTP 401–403 | Sunshine merespons, tetapi akses API ditolak. Cocokkan akun web UI dan environment PowerShell. |
| `PORT_TERTUTUP` | Sunshine/Apollo belum berjalan atau port/alamatnya berbeda. |
| `WAKTU_HABIS` | Layanan tidak merespons. Periksa proses, port, dan log Sunshine. |
| `API_TIDAK_DITEMUKAN` / HTTP 404 | Alamat/port atau versi API tidak sesuai. |
| `API_TIDAK_SESUAI` | Respons berupa halaman HTML/setup atau bukan objek `/api/apps` Sunshine. |

- Agen 1.0.0 menyatukan semua kegagalan di atas sebagai `TIDAK TERHUBUNG`; log itu **tidak membuktikan Sunshine mati**.
- Jika `TcpTestSucceeded : False`, buka Sunshine/Apollo. Periksa dari PowerShell:
  `Get-Service *sunshine*,*apollo* -ErrorAction SilentlyContinue` dan
  `Get-Process *sunshine*,*apollo* -ErrorAction SilentlyContinue`.
- Buka `https://127.0.0.1:47990` **di browser PC/VM host**, bukan browser HP. Jika baru dipasang, selesaikan setup akun web UI.
- `127.0.0.1` benar jika agen dan Sunshine berjalan pada PC/VM yang sama. Jangan menggantinya dengan IP publik, dan **jangan membuka port admin 47990 ke internet**.
- Pada VM tanpa monitor/GPU, kegagalan display/encoder harus dibuktikan dari log Sunshine; tidak dapat disimpulkan dari empat baris startup agen.
- `Host: ...` hanya informasi alamat publik. Log `HEARTBEAT DITERIMA` pada versi 1.0.1 membuktikan server menerima laporan agen. Unit hijau di dashboard menunjukkan heartbeat, bukan jaminan streaming sudah berfungsi.

## Pengujian agen

```bash
python -m unittest discover -s agent -p "test_*.py" -v
```

Tes memakai mock; tidak menjalankan perintah pada PC penyewa atau mengirim heartbeat ke produksi.

## Menjalankan otomatis saat PC menyala

**Windows (paling gampang, NSSM):**

```powershell
nssm install XyAgent "C:\Python312\python.exe" "C:\xycloud\xy_agent.py"
nssm set XyAgent AppEnvironmentExtra XY_AGEN_KODE=xya_xxx XY_SUNSHINE_USER=admin XY_SUNSHINE_PASS=xxx
nssm start XyAgent
```

**Linux (systemd):**

```ini
[Unit]
Description=XyCloudStore Agent
After=network-online.target

[Service]
Environment=XY_AGEN_KODE=xya_xxx
Environment=XY_SUNSHINE_USER=admin
Environment=XY_SUNSHINE_PASS=xxx
ExecStart=/usr/bin/python3 /opt/xycloud/xy_agent.py
Restart=always

[Install]
WantedBy=multi-user.target
```

## Pembersihan antar penyewa

Agen otomatis menutup Steam, Epic Games, Discord, dan browser di akhir sesi, lalu melepas semua
perangkat yang pernah dipasangkan supaya penyewa lama tidak bisa menyambung lagi.

Untuk pembersihan lebih dalam, buat berkas `bersih.bat` (Windows) atau `bersih.sh` (Linux)
di folder yang sama. Contoh isi untuk Windows:

```bat
@echo off
rem hapus profil sementara penyewa
rmdir /s /q "%USERPROFILE%\AppData\Local\Temp"
rem kembalikan snapshot bersih kalau memakai Deep Freeze atau Hyper-V checkpoint
rem powershell Restore-VMSnapshot -Name "Bersih" -VMName "GameVM" -Confirm:$false
```

## Pilihan perintah

| Argumen | Variabel lingkungan | Bawaan |
|---|---|---|
| `--server` | `XY_SERVER` | `https://api.xycloud.my.id` |
| `--kode` | `XY_AGEN_KODE` | wajib diisi |
| `--sunshine` | `XY_SUNSHINE_URL` | `https://127.0.0.1:47990` |
| `--user` | `XY_SUNSHINE_USER` | `admin` |
| `--pass` | `XY_SUNSHINE_PASS` | kosong |
| `--host` | `XY_HOST_PUBLIK` | terdeteksi otomatis |
| `--cek` | — | diagnosis lokal saja, lalu keluar |

## Catatan penting soal anti-cheat

Game dengan anti-cheat tingkat kernel (Valorant/Vanguard, sebagian FACEIT, beberapa judul EAC)
**menolak berjalan di dalam mesin virtual**. Kalau target jualannya game seperti itu, unit harus
PC fisik, bukan VM cloud. Untuk game single player, Steam umum, emulator, dan pekerjaan
render atau editing, VM cloud sudah cukup.


## Integrasi APK 2.5.0 (agen 1.1.0)

- Streaming sudah berada di APK XyCloudStore. HP tidak harus memasang Moonlight/Artemis terpisah.
- Gunakan agen 1.1.0 atau lebih baru. Sunshine modern memakai `pairing_id`; agen membaca antrean pairing lokal dan hanya memilih permintaan dari identitas client yang dikirim APK.
- Hasil JSON `status:false` adalah kegagalan meskipun HTTP 200. Sesi tidak dinyatakan terhubung hanya karena permintaan diterima.
- Deadline sewa dipulihkan dari server saat agen restart. Agen menutup streaming dan melepas perangkat saat waktu habis, kemudian melaporkan pelepasan unit ke server.
- Unit tetap dikunci jika pembersihan Sunshine gagal. Perbaiki kredensial/layanan dan biarkan agen mencoba ulang; jangan melepas unit secara paksa ketika penyewa lama masih bisa tersambung.
- Perintah mulai kedaluwarsa setelah dua menit. Jangan menjalankan beberapa agen bersamaan untuk kode unit yang sama.
- `--cek` tetap hanya memeriksa API lokal, bukan encoder/display ataupun port streaming dari internet. Port admin 47990 tetap lokal, tidak dibuka ke internet.
