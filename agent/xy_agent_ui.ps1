<# ================================================================
 XyCloudStore - Agen PC Host (UI Windows)
================================================================
Jendela pengaturan agen PC host:
  - Atur kode unit, kredensial Sunshine, server API.
  - Auto-download & setup otomatis: Python (winget), Sunshine
    (winget), xy_agent.py (unduh dari GitHub) bila belum ada.
  - Uji koneksi (--cek), jalankan/hentikan agen, autostart.
Kredensial disimpan terenkripsi (DPAPI) di samping berkas ini.
Jalankan headless (tanpa jendela) dengan argumen:  -Jalankan
================================================================ #>
[CmdletBinding()]
param(
  [switch]$Jalankan
)

$ErrorActionPreference = 'Stop'
$ProgressPreference  = 'SilentlyContinue'
$folder    = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($folder)) { $folder = Split-Path -Parent $MyInvocation.MyCommand.Path }
$cfgPath   = Join-Path $folder '.xy_agent_ui.json'
$pwdPath   = Join-Path $folder '.xy_agent_pwd.dat'
$agenPy    = Join-Path $folder 'xy_agent.py'
$urlAgen   = 'https://raw.githubusercontent.com/xykalnotkel/XyCloudOrder/main/agent/xy_agent.py'

# Jalur berkas ini (bisa .ps1 atau .exe hasil ps2exe)
$berkasSendiri = $PSCommandPath
if ([string]::IsNullOrWhiteSpace($berkasSendiri)) { $berkasSendiri = $MyInvocation.MyCommand.Path }
$adalahExe = ($berkasSendiri -like '*.exe')
$pythonCmd = 'python'

function CariPython {
  try { $v = & $pythonCmd --version 2>&1; if ("$v" -match 'Python 3\.') { return "$v" } } catch {}
  if (Get-Command py -ErrorAction SilentlyContinue) {
    try { $script:pythonCmd = 'py'; $v = & $script:pythonCmd --version 2>&1; if ("$v" -match 'Python 3\.') { return "$v" } } catch {}
  }
  return $null
}

function BacaCfg {
  if (-not (Test-Path $cfgPath)) { return @{ kode=''; user='admin'; server='https://api.xycloud.my.id' } }
  try { return (Get-Content $cfgPath -Raw | ConvertFrom-Json) } catch { return @{ kode=''; user='admin'; server='https://api.xycloud.my.id' } }
}
function SimpanCfg($cfg) {
  $cfg | ConvertTo-Json | Out-File $cfgPath -Encoding utf8
  try { icacls $cfgPath /inheritance:r /grant:r "$env:USERNAME:R" | Out-Null } catch {}
}
function BacaPwd {
  if (-not (Test-Path $pwdPath)) { return '' }
  try { return (ConvertTo-SecureString (Get-Content $pwdPath -Raw) | ForEach-Object { [System.Net.NetworkCredential]::new('', $_).Password }) } catch { return '' }
}
function SimpanPwd($plain) {
  $sec = ConvertTo-SecureString $plain -AsPlainText -Force
  (ConvertFrom-SecureString $sec) | Out-File $pwdPath -Encoding ascii
  try { icacls $pwdPath /inheritance:r /grant:r "$env:USERNAME:R" | Out-Null } catch {}
}
function IsiEnvDariCfg {
  $cfg = BacaCfg; $pwd = BacaPwd
  $env:XY_AGEN_KODE     = $cfg.kode
  $env:XY_SUNSHINE_USER = $cfg.user
  $env:XY_SUNSHINE_PASS = $pwd
  if ($cfg.server) { $env:XY_SERVER = $cfg.server }
}
function CekTugasAutostart { return [bool](Get-ScheduledTask -TaskName 'XyAgent' -ErrorAction SilentlyContinue) }
function CekAgenBerjalan {
  try {
    $procs = Get-CimInstance Win32_Process -Filter "Name = 'python.exe' OR Name = 'python3.exe'" -ErrorAction Stop
    return [bool]($procs | Where-Object { $_.CommandLine -like '*xy_agent.py*' })
  } catch { return $false }
}

# ---------------- MODE HEADLESS (autostart) ----------------
if ($Jalankan) {
  if (-not (Test-Path $agenPy)) { exit 1 }
  IsiEnvDariCfg
  $py = CariPython
  if (-not $py) { exit 1 }
  Start-Process -FilePath $pythonCmd -ArgumentList "`"$agenPy`"" -WindowStyle Hidden | Out-Null
  exit 0
}

# ==============================================================
#  UI (WinForms)
# ==============================================================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$ui = @{}
$ui.form = New-Object System.Windows.Forms.Form
$ui.form.Text = 'XyCloudStore - Agen PC Host'
$ui.form.Size = New-Object System.Drawing.Size(728, 660)
$ui.form.StartPosition = 'CenterScreen'
$ui.form.FormBorderStyle = 'FixedSingle'
$ui.form.MaximizeBox = $false
$ui.form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

function TulisLog($txt) {
  $ui.log.AppendText((Get-Date -Format 'HH:mm:ss') + '  ' + $txt + "`r`n")
  $ui.log.SelectionStart = $ui.log.TextLength
  $ui.log.ScrollToCaret()
  [System.Windows.Forms.Application]::DoEvents()
}

function SegarkanStatus {
  $baris = @()
  $pyv = CariPython
  $baris += ('Python        : ' + $(if ($pyv) { 'OK (' + $pyv.Trim() + ')' } else { 'BELUM ADA' }))
  $svc = Get-Service -Name 'SunshineService' -ErrorAction SilentlyContinue
  $baris += ('Sunshine      : ' + $(if ($svc) { 'OK (' + $svc.Status + ')' } else { 'BELUM ADA' }))
  $baris += ('xy_agent.py   : ' + $(if (Test-Path $agenPy) { 'OK' } else { 'BELUM ADA' }))
  $baris += ('Autostart     : ' + $(if (CekTugasAutostart) { 'TERDAFTAR' } else { 'belum' }))
  $baris += ('Agen jalan    : ' + $(if (CekAgenBerjalan) { 'SEDANG BERJALAN' } else { 'berhenti' }))
  $ui.lblStatus.Text = ($baris -join "`r`n")
}

# banner
$ui.banner = New-Object System.Windows.Forms.Panel
$ui.banner.Dock = 'Top'
$ui.banner.Height = 74
$ui.banner.BackColor = [System.Drawing.Color]::FromArgb(124, 58, 237)
$ui.form.Controls.Add($ui.banner)
$l1 = New-Object System.Windows.Forms.Label
$l1.Text = 'XyCloudStore — Agen PC Host'
$l1.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)
$l1.ForeColor = [System.Drawing.Color]::White
$l1.Location = New-Object System.Drawing.Point(20, 14)
$l1.AutoSize = $true
$ui.banner.Controls.Add($l1)
$l2 = New-Object System.Windows.Forms.Label
$l2.Text = 'Setup otomatis + konfigurasi unit. Kredensial disimpan terenkripsi.'
$l2.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$l2.ForeColor = [System.Drawing.Color]::FromArgb(235, 226, 255)
$l2.Location = New-Object System.Drawing.Point(21, 47)
$l2.AutoSize = $true
$ui.banner.Controls.Add($l2)

# panel kiri: pengaturan
$gkiri = New-Object System.Windows.Forms.Label
$gkiri.Text = 'PENGATURAN UNIT'
$gkiri.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$gkiri.ForeColor = [System.Drawing.Color]::FromArgb(80, 50, 150)
$gkiri.Location = New-Object System.Drawing.Point(18, 88)
$gkiri.AutoSize = $true
$ui.form.Controls.Add($gkiri)

function BuatLabel($txt, $x, $y, $w) {
  $lb = New-Object System.Windows.Forms.Label
  $lb.Text = $txt; $lb.Location = New-Object System.Drawing.Point($x, $y)
  $lb.Size = New-Object System.Drawing.Size($w, 18)
  $lb.ForeColor = [System.Drawing.Color]::FromArgb(70, 65, 95)
  return $lb
}
function BuatTeks($x, $y, $w, $pw) {
  $tb = New-Object System.Windows.Forms.TextBox
  $tb.Location = New-Object System.Drawing.Point($x, $y)
  $tb.Size = New-Object System.Drawing.Size($w, 24)
  if ($pw) { $tb.PasswordChar = [char]0x25CF }
  return $tb
}

$ui.form.Controls.Add((BuatLabel 'Kode unit XyCloud (dashboard -> Unit PC -> Daftarkan Unit)' 18 112 330))
$ui.txtKode = BuatTeks 18 132 330 $false; $ui.form.Controls.Add($ui.txtKode)
$ui.form.Controls.Add((BuatLabel 'Username web-UI Sunshine' 18 162 330))
$ui.txtUser = BuatTeks 18 182 330 $false; $ui.txtUser.Text = 'admin'; $ui.form.Controls.Add($ui.txtUser)
$ui.form.Controls.Add((BuatLabel 'Password web-UI Sunshine' 18 212 330))
$ui.txtPwd = BuatTeks 18 232 330 $true; $ui.form.Controls.Add($ui.txtPwd)
$ui.form.Controls.Add((BuatLabel 'Server API (kosongkan utk bawaan)' 18 262 330))
$ui.txtServer = BuatTeks 18 282 330 $false; $ui.txtServer.Text = 'https://api.xycloud.my.id'; $ui.form.Controls.Add($ui.txtServer)

$ui.btnSimpan = New-Object System.Windows.Forms.Button
$ui.btnSimpan.Text = 'Simpan Pengaturan'
$ui.btnSimpan.Location = New-Object System.Drawing.Point(18, 312)
$ui.btnSimpan.Size = New-Object System.Drawing.Size(330, 32)
$ui.btnSimpan.BackColor = [System.Drawing.Color]::FromArgb(124, 58, 237)
$ui.btnSimpan.ForeColor = [System.Drawing.Color]::White
$ui.btnSimpan.FlatStyle = 'Flat'
$ui.form.Controls.Add($ui.btnSimpan)

# panel kanan: aksi & status
$ui.lblStatus = New-Object System.Windows.Forms.Label
$ui.lblStatus.Location = New-Object System.Drawing.Point(366, 112)
$ui.lblStatus.Size = New-Object System.Drawing.Size(338, 96)
$ui.lblStatus.Font = New-Object System.Drawing.Font('Consolas', 9)
$ui.lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(40, 35, 60)
$ui.form.Controls.Add($ui.lblStatus)

function BuatTombol($txt, $y, $warna) {
  $b = New-Object System.Windows.Forms.Button
  $b.Text = $txt
  $b.Location = New-Object System.Drawing.Point(366, $y)
  $b.Size = New-Object System.Drawing.Size(338, 32)
  if ($warna -eq 'ungu')  { $b.BackColor = [System.Drawing.Color]::FromArgb(124,58,237); $b.ForeColor = [System.Drawing.Color]::White }
  elseif ($warna -eq 'hijau'){ $b.BackColor = [System.Drawing.Color]::FromArgb(22,163,74); $b.ForeColor = [System.Drawing.Color]::White }
  elseif ($warna -eq 'abu') { $b.BackColor = [System.Drawing.Color]::FromArgb(226,220,240) }
  $b.FlatStyle = 'Flat'
  return $b
}
$ui.btnPasang = BuatTombol 'Auto-setup yang belum ada (Python, Sunshine, xy_agent.py)' 214 'ungu'; $ui.form.Controls.Add($ui.btnPasang)
$ui.btnUji = BuatTombol 'Uji Koneksi Lokal (--cek)' 250 'abu'; $ui.form.Controls.Add($ui.btnUji)
$ui.btnJalan = BuatTombol 'Jalankan Agen' 286 'hijau'; $ui.form.Controls.Add($ui.btnJalan)
$ui.btnHenti = BuatTombol 'Hentikan Agen' 322 'abu'; $ui.form.Controls.Add($ui.btnHenti)

$ui.chkAuto = New-Object System.Windows.Forms.CheckBox
$ui.chkAuto.Text = 'Mulai otomatis saat Windows menyala'
$ui.chkAuto.Location = New-Object System.Drawing.Point(366, 360)
$ui.chkAuto.Size = New-Object System.Drawing.Size(240, 22)
$ui.form.Controls.Add($ui.chkAuto)
$ui.btnAuto = New-Object System.Windows.Forms.Button
$ui.btnAuto.Text = 'Terapkan Autostart'
$ui.btnAuto.Location = New-Object System.Drawing.Point(366, 386)
$ui.btnAuto.Size = New-Object System.Drawing.Size(338, 32)
$ui.btnAuto.BackColor = [System.Drawing.Color]::FromArgb(124,58,237)
$ui.btnAuto.ForeColor = [System.Drawing.Color]::White
$ui.btnAuto.FlatStyle = 'Flat'
$ui.form.Controls.Add($ui.btnAuto)

# log bawah
$ui.lblLog = New-Object System.Windows.Forms.Label
$ui.lblLog.Text = 'LOG'
$ui.lblLog.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$ui.lblLog.ForeColor = [System.Drawing.Color]::FromArgb(80,50,150)
$ui.lblLog.Location = New-Object System.Drawing.Point(18, 430)
$ui.lblLog.AutoSize = $true
$ui.form.Controls.Add($ui.lblLog)
$ui.log = New-Object System.Windows.Forms.TextBox
$ui.log.Multiline = $true
$ui.log.ReadOnly = $true
$ui.log.ScrollBars = 'Vertical'
$ui.log.BackColor = [System.Drawing.Color]::FromArgb(248,246,255)
$ui.log.Font = New-Object System.Drawing.Font('Consolas', 8.5)
$ui.log.Location = New-Object System.Drawing.Point(18, 452)
$ui.log.Size = New-Object System.Drawing.Size(686, 140)
$ui.form.Controls.Add($ui.log)

$ui.prog = New-Object System.Windows.Forms.ProgressBar
$ui.prog.Style = 'Marquee'
$ui.prog.Visible = $false
$ui.prog.Location = New-Object System.Drawing.Point(18, 598)
$ui.prog.Size = New-Object System.Drawing.Size(686, 14)
$ui.form.Controls.Add($ui.prog)

# -------- aksi --------
$ui.btnSimpan.Add_Click({
  $kode = $ui.txtKode.Text.Trim()
  if (-not $kode) { TulisLog 'Kode unit wajib diisi.'; [System.Windows.Forms.MessageBox]::Show('Kode unit kosong. Isi dari dashboard Unit PC.', 'XyCloudStore', 'OK', 'Warning') | Out-Null; return }
  $cfg = @{ kode=$kode; user=$ui.txtUser.Text.Trim(); server=$ui.txtServer.Text.Trim() }
  if (-not $cfg.user) { $cfg.user = 'admin' }
  if (-not $cfg.server) { $cfg.server = 'https://api.xycloud.my.id' }
  SimpanCfg $cfg
  SimpanPwd $ui.txtPwd.Text
  TulisLog ('Pengaturan disimpan untuk unit ' + $kode)
  [System.Windows.Forms.MessageBox]::Show('Pengaturan tersimpan.', 'XyCloudStore', 'OK', 'Information') | Out-Null
})

$ui.btnPasang.Add_Click({
  $ui.btnPasang.Enabled = $false; $ui.btnUji.Enabled = $false; $ui.prog.Visible = $true
  try {
    # 1) Python
    if (-not (CariPython)) {
      TulisLog 'Python belum ada -> instal otomatis via winget…'
      try {
        winget install --id Python.Python.3.12 -e --silent --accept-source-agreements --accept-package-agreements 2>&1 | ForEach-Object { TulisLog ($_ ) }
      } catch { TulisLog ('winget gagal: ' + $_.Exception.Message) }
      Start-Sleep -Seconds 2
      if (-not (CariPython)) {
        TulisLog 'Python belum siap. Pasang manual: https://www.python.org (centang Add to PATH).'
        Start-Process 'https://www.python.org/downloads/'
      } else { TulisLog ('Python siap: ' + (CariPython)) }
    } else { TulisLog ('Python sudah ada: ' + (CariPython)) }

    # 2) Sunshine
    $svc = Get-Service -Name 'SunshineService' -ErrorAction SilentlyContinue
    $ada = $svc -or (Get-Process -Name 'sunshine','apollo' -ErrorAction SilentlyContinue)
    if (-not $ada) {
      TulisLog 'Sunshine belum ada -> instal otomatis via winget…'
      try {
        winget install --id LizardByte.Sunshine -e --silent --accept-source-agreements --accept-package-agreements 2>&1 | ForEach-Object { TulisLog ($_) }
      } catch { TulisLog ('winget gagal: ' + $_.Exception.Message) }
      Start-Sleep -Seconds 3
      $svc = Get-Service -Name 'SunshineService' -ErrorAction SilentlyContinue
      if ($svc) { try { Start-Service $svc } catch { TulisLog 'Gagal menyalakan SunshineService.' } }
      TulisLog 'Buka https://127.0.0.1:47990 untuk membuat akun web-UI Sunshine (sekali saja).'
      Start-Process 'https://127.0.0.1:47990'
    } else { TulisLog 'Sunshine sudah terpasang.' }

    # 3) xy_agent.py
    if (-not (Test-Path $agenPy)) {
      TulisLog 'xy_agent.py belum ada -> unduh otomatis dari GitHub…'
      try {
        Invoke-WebRequest -Uri $urlAgen -OutFile $agenPy -UseBasicParsing
        TulisLog ('Berhasil diunduh ke ' + $agenPy)
      } catch {
        TulisLog ('Unduh gagal: ' + $_.Exception.Message)
        TulisLog ('Unduh manual lalu simpan sebagai xy_agent.py: ' + $urlAgen)
      }
    } else { TulisLog 'xy_agent.py sudah ada.' }

    SegarkanStatus
  } finally {
    $ui.prog.Visible = $false; $ui.btnPasang.Enabled = $true; $ui.btnUji.Enabled = $true
  }
})

$ui.btnUji.Add_Click({
  if (-not (Test-Path $agenPy)) { TulisLog 'xy_agent.py belum ada — klik tombol Auto-setup dulu.'; return }
  $cfg = BacaCfg
  if (-not $cfg.kode) { TulisLog 'Simpan pengaturan (kode unit) dulu sebelum uji.'; return }
  IsiEnvDariCfg
  TulisLog 'Menjalankan xy_agent.py --cek…'
  $tmpOut = Join-Path $env:TEMP ('xy_cek_' + [guid]::NewGuid().ToString('N') + '.txt')
  $tmpErr = $tmpOut + '.err'
  try {
    $p = Start-Process -FilePath $pythonCmd -ArgumentList @("`"$agenPy`"", '--cek') -Wait -PassThru -NoNewWindow -RedirectStandardOutput $tmpOut -RedirectStandardError $tmpErr
    if (Test-Path $tmpOut) { Get-Content $tmpOut | ForEach-Object { if ($_) { TulisLog $_ } } }
    if (Test-Path $tmpErr) { Get-Content $tmpErr | ForEach-Object { if ($_) { TulisLog ('ERR ' + $_) } } }
    TulisLog ('Selesai (exit ' + $p.ExitCode + ').')
  } catch { TulisLog ('Gagal uji: ' + $_.Exception.Message) }
  finally { Remove-Item $tmpOut,$tmpErr -ErrorAction SilentlyContinue }
})

$ui.btnJalan.Add_Click({
  if (CekAgenBerjalan) { TulisLog 'Agen sudah berjalan.'; return }
  if (-not (Test-Path $agenPy)) { TulisLog 'xy_agent.py belum ada — klik tombol Auto-setup dulu.'; return }
  $cfg = BacaCfg
  if (-not $cfg.kode) { TulisLog 'Simpan pengaturan (kode unit) dulu.'; return }
  IsiEnvDariCfg
  $p = Start-Process -FilePath $pythonCmd -ArgumentList @("`"$agenPy`"") -WindowStyle Hidden -PassThru
  TulisLog ('Agen dijalankan (PID ' + $p.Id + ').')
  SegarkanStatus
})
$ui.btnHenti.Add_Click({
  try {
    $procs = Get-CimInstance Win32_Process -Filter "Name = 'python.exe' OR Name = 'python3.exe'" -ErrorAction Stop
    $target = $procs | Where-Object { $_.CommandLine -like '*xy_agent.py*' }
    foreach ($t in $target) { Stop-Process -Id $t.ProcessId -Force -ErrorAction SilentlyContinue; TulisLog ('Agen dihentikan (PID ' + $t.ProcessId + ').') }
    if (-not $target) { TulisLog 'Tidak ada agen yang berjalan.' }
  } catch { TulisLog ('Gagal: ' + $_.Exception.Message) }
  SegarkanStatus
})

$ui.btnAuto.Add_Click({
  $sudah = CekTugasAutostart
  if ($ui.chkAuto.Checked) {
    if (-not $sudah) {
      if ($adalahExe) {
        $act = New-ScheduledTaskAction -Execute $berkasSendiri -Argument '-Jalankan'
      } else {
        $act = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$berkasSendiri`" -Jalankan"
      }
      $trg = New-ScheduledTaskTrigger -AtStartup
      $st  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
      try {
        Register-ScheduledTask -TaskName 'XyAgent' -Action $act -Trigger $trg -Settings $st -Force | Out-Null
        TulisLog 'Autostart didaftarkan (XyAgent @ saat menyala).'
      } catch { TulisLog ('Gagal daftar autostart: ' + $_.Exception.Message + ' — jalankan sebagai Administrator.') }
    } else { TulisLog 'Autostart sudah terdaftar.' }
  } else {
    if ($sudah) {
      try { Unregister-ScheduledTask -TaskName 'XyAgent' -Confirm:$false; TulisLog 'Autostart dihapus.' }
      catch { TulisLog ('Gagal hapus autostart: ' + $_.Exception.Message) }
    } else { TulisLog 'Autostart belum ada.' }
  }
  SegarkanStatus
})

# saat form dimuat
$ui.form.add_Shown({
  $cfg = BacaCfg
  $ui.txtKode.Text = $cfg.kode
  if ($cfg.user) { $ui.txtUser.Text = $cfg.user }
  if ($cfg.server) { $ui.txtServer.Text = $cfg.server }
  $pw = BacaPwd
  if ($pw) { $ui.txtPwd.Text = $pw }
  $ui.chkAuto.Checked = CekTugasAutostart
  SegarkanStatus
  TulisLog 'UI siap. Isi kode unit lalu Simpan; kalau ada yang belum terpasang, klik Auto-setup.'
})

[void]$ui.form.ShowDialog()
