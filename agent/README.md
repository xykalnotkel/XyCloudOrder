# Agen PC Host XyCloudStore

Program kecil yang dijalankan di setiap PC atau VM yang disewakan. Tugasnya menyambungkan mesin itu
ke server XyCloudStore supaya sesi sewa bisa dinyalakan, dipasangkan, dan ditutup otomatis dari aplikasi.

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
3. Jalankan:

```bash
# Windows
set XY_AGEN_KODE=xya_xxxxxxxxxxxx
set XY_SUNSHINE_USER=admin
set XY_SUNSHINE_PASS=passwordwebui
python xy_agent.py

# Linux
XY_AGEN_KODE=xya_xxxxxxxxxxxx XY_SUNSHINE_USER=admin XY_SUNSHINE_PASS=passwordwebui python3 xy_agent.py
```

Kalau berhasil, dalam 20 detik unit akan tampil hijau di dashboard beserta GPU, RAM, dan IP publiknya.

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

## Catatan penting soal anti-cheat

Game dengan anti-cheat tingkat kernel (Valorant/Vanguard, sebagian FACEIT, beberapa judul EAC)
**menolak berjalan di dalam mesin virtual**. Kalau target jualannya game seperti itu, unit harus
PC fisik, bukan VM cloud. Untuk game single player, Steam umum, emulator, dan pekerjaan
render atau editing, VM cloud sudah cukup.
