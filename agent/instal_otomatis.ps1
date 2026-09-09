<#
================================================================
 XyCloudStore - Agen Auto-Install (Windows)
================================================================
 "Agen berbentuk aplikasi" untuk unit PC: satu berkas ini otomatis
 memasang & menyiapkan ENGINE (Python + Sunshine streaming),
 memandu isi kode unit + kredensial, lalu mendaftarkan agen berjalan
 otomatis saat PC menyala.

 Cara pakai:
   1. Letakkan berkas ini DI FOLDER yang sama dengan xy_agent.py
      (unduh xy_agent.py dari repo XyCloudOrder/agent).
   2. Klik kanan -> "Run with PowerShell".
   3. Ikuti wizard: kode unit dari dashboard (Unit PC -> Daftarkan Unit),
      lalu username/password web-UI Sunshine.
   4. Selesai. Agen langsung berjalan dan akan otomatis menyala lagi
      setiap PC dinyalakan (terdaftar sebagai penjadwal sistem).

 Bisa dijalankan ulang kapan saja (idempoten). Tambahan:
   -Argumen  -Jalankan : mode menjalankan agen (dipakai oleh penjadwal).
   -Argumen  -Cek      : hanya diagnosis lokal Sunshine lalu keluar.
================================================================
#>
[CmdletBinding()]
param(
  [switch]$Jalankan,
  [switch]$Cek
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$folder = $PSScriptRoot
$agenPy = Join-Path $folder 'xy_agent.py'
$berkasRahasia = Join-Path $folder '.xy_agen_cred'
$pythonExe = 'python'

function Tulis($msg, $warna='Cyan') { Write-Host $msg -ForegroundColor $warna }

# ---------------------------------------------------------------
# Pastikan Python ada (auto-instal lewat winget bila belum ada)
# ---------------------------------------------------------------
function PastikanPython {
  try {
    $v = & $pythonExe --version 2>&1
    if ($v -match 'Python 3\.') { Tulis "Python ditemukan: $v" 'Green'; return }
  } catch {}
  Tulis "Python belum terpasang. Mencoba instal otomatis lewat winget…" 'Yellow'
  try {
    winget install --id Python.Python.3.12 -e --silent --accept-source-agreements --accept-package-agreements
  } catch {
    Tulis "winget gagal. Pasang Python 3.12 dari https://www.python.org lalu jalankan ulang." 'Red'
    exit 1
  }
  # path winget: py launcher biasanya langsung bisa
  if (Get-Command py -ErrorAction SilentlyContinue) { $script:pythonExe = 'py' }
  Tulis "Python berhasil dipasang." 'Green'
}

# ---------------------------------------------------------------
# Pastikan Sunshine (engine streaming) ada / pasang otomatis
# ---------------------------------------------------------------
function PastikanSunshine {
  $ada = Get-Service -Name 'SunshineService' -ErrorAction SilentlyContinue
  $proses = Get-Process -Name 'sunshine','apollo' -ErrorAction SilentlyContinue
  if ($ada -or $proses) {
    Tulis "Sunshine/Apollo sudah terpasang (${($ada.Name)})." 'Green'
    return
  }
  Tulis "Sunshine (engine streaming) belum ada. Mencoba instal otomatis…" 'Yellow'
  try {
    winget install --id LizardByte.Sunshine -e --silent --accept-source-agreements --accept-package-agreements
    Start-Sleep -Seconds 2
  } catch {
    Tulis "Gagal instal Sunshine otomatis. Unduh manual: https://github.com/LizardByte/Sunshine lalu jalankan ulang." 'Red'
    exit 1
  }
  # Mulai layanannya
  $svc = Get-Service -Name 'SunshineService' -ErrorAction SilentlyContinue
  if ($svc) { Start-Service $svc -ErrorAction SilentlyContinue }
  Tulis "Sunshine terpasang. Buka https://127.0.0.1:47990 di PC ini sekali untuk membuat akun web-UI." 'Green'
}

# ---------------------------------------------------------------
# Simpan rahasia terenkripsi Windows (DPAPI, hanya akun ini)
# ---------------------------------------------------------------
function SimpanRahasia {
  param($Kode, $User, $PassSecure)
  $data = @{ kode = $Kode; user = $User; pass = (ConvertFrom-SecureString $PassSecure) }
  $data | ConvertTo-Json | Out-File -FilePath $berkasRahasia -Encoding utf8
  try {
    icacls $berkasRahasia /inheritance:r /grant:r "$env:USERNAME:R" | Out-Null
  } catch {}
}

function BacaRahasia {
  if (-not (Test-Path $berkasRahasia)) { return $null }
  try {
    $d = Get-Content $berkasRahasia -Raw | ConvertFrom-Json
    $pass = ConvertTo-SecureString $d.pass
    return @{ kode = $d.kode; user = $d.user; pass = [System.Net.NetworkCredential]::new('', $pass).Password }
  } catch { return $null }
}

# ---------------------------------------------------------------
# Daftarkan penjadwal agar agen menyala saat PC dinyalakan
# ---------------------------------------------------------------
function DaftarkanAutostart {
  $tugas = "XyAgent"
  # Bila dijalankan sebagai .ps1 -> lewat powershell -File.
  # Bila sudah dikemas jadi .exe (ps2exe) -> jalankan exe langsung dengan argumen.
  $sendiri = $MyInvocation.MyCommand.Path
  if ($sendiri -like '*.ps1') {
    $pemula = 'powershell.exe'
    $argumen = "-NoProfile -ExecutionPolicy Bypass -File `"$sendiri`" -Jalankan"
  } else {
    $pemula = $sendiri
    $argumen = '-Jalankan'
  }
  $aksi = New-ScheduledTaskAction -Execute $pemula -Argument $argumen
  $pemicu = New-ScheduledTaskTrigger -AtStartup
  $set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
  try {
    Register-ScheduledTask -TaskName $tugas -Action $aksi -Trigger $pemicu -Settings $set -Force -ErrorAction Stop | Out-Null
    Tulis "Terdaftar sebagai penjadwal '$tugas' — agen otomatis menyala tiap PC dinyalakan." 'Green'
  } catch {
    Tulis "Autostart gagal didaftarkan (jalankan sebagai Administrator untuk ini). Agen tetap bisa dijalankan manual." 'Yellow'
  }
}

# ===============================================================
# MODE: jalankan agen (dipakai penjadwal & manual)
# ===============================================================
if ($Jalankan) {
  if (-not (Test-Path $agenPy)) { Tulis "xy_agent.py tidak ditemukan di $folder" 'Red'; exit 1 }
  $r = BacaRahasia
  if (-not $r) { Tulis "Kredensial belum diisi. Jalankan instal_otomatis.ps1 tanpa argumen dulu." 'Red'; exit 1 }
  $env:XY_AGEN_KODE = $r.kode
  $env:XY_SUNSHINE_USER = $r.user
  $env:XY_SUNSHINE_PASS = $r.pass
  Tulis "Menjalankan agen untuk unit $($r.kode)…" 'Cyan'
  & $pythonExe $agenPy
  exit $LASTEXITCODE
}

# ===============================================================
# MODE: diagnosis lokal (--cek)
# ===============================================================
if ($Cek) {
  $r = BacaRahasia
  if ($r) {
    $env:XY_AGEN_KODE = $r.kode
    $env:XY_SUNSHINE_USER = $r.user
    $env:XY_SUNSHINE_PASS = $r.pass
    & $pythonExe $agenPy --cek
  } else {
    & $pythonExe $agenPy --cek
  }
  exit $LASTEXITCODE
}

# ===============================================================
# MODE: wizard instalasi
# ===============================================================
Tulis "===================================================" 'Magenta'
Tulis "  XyCloudStore - Agen Auto Install" 'Magenta'
Tulis "  Persiapan otomatis Python + Sunshine + autostart" 'Magenta'
Tulis "===================================================" 'Magenta'

if (-not (Test-Path $agenPy)) {
  Tulis "xy_agent.py tidak ditemukan di folder yang sama ($folder)." 'Red'
  Tulis "Letakkan berkas ini di folder berisi xy_agent.py lalu jalankan lagi." 'Yellow'
  exit 1
}

# 1) Prasyarat
PastikanPython
PastikanSunshine

# 2) Baca nilai lama (kalau sudah pernah diisi)
$lama = BacaRahasia
$kodeLama = $lama.kode; $userLama = $lama.user

# 3) Kode unit
$kode = Read-Host "Kode unit XyCloud (dari dashboard -> Unit PC). Kosongkan utk memakai: $kodeLama"
if ([string]::IsNullOrWhiteSpace($kode)) { $kode = $kodeLama }
if ([string]::IsNullOrWhiteSpace($kode)) { Tulis "Kode unit wajib diisi." 'Red'; exit 1 }

# 4) Kredensial Sunshine (sekali saja, disimpan terenkripsi)
$user = Read-Host "Username web-UI Sunshine (bawaan: admin)"
if ([string]::IsNullOrWhiteSpace($user)) { $user = $userLama }
if ([string]::IsNullOrWhiteSpace($user)) { $user = 'admin' }
$pw = Read-Host "Password web-UI Sunshine" -AsSecureString
if ($pw.Length -eq 0) { Tulis "Password kosong — biarkan bila memakai akun tanpa password." 'Yellow' }

SimpanRahasia -Kode $kode.Trim() -User $user.Trim() -PassSecure $pw

# 5) Autostart + uji lokal + jalankan
DaftarkanAutostart

$env:XY_AGEN_KODE = $kode.Trim()
$env:XY_SUNSHINE_USER = $user.Trim()
$env:XY_SUNSHINE_PASS = [System.Net.NetworkCredential]::new('', $pw).Password

Tulis "Uji koneksi lokal ke Sunshine…" 'Cyan'
& $pythonExe $agenPy --cek
Tulis "Menjalankan agen (Ctrl+C untuk berhenti)…" 'Cyan'
& $pythonExe $agenPy
