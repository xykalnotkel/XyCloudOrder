#!/usr/bin/env python3
"""
================================================================
 XyCloudStore - Agen PC Host
================================================================
Program kecil yang dijalankan di setiap PC/VM yang disewakan.
Tugasnya:

  1. Melapor hidup (heartbeat) ke server XyCloudStore tiap 20 detik
  2. Mengambil perintah dari server (mulai sesi, pasangkan PIN, akhiri sesi)
  3. Mengatur Sunshine: menyalakan sesi, memasukkan PIN pairing, menutup sesi
  4. Membersihkan jejak penyewa sebelumnya di akhir sesi

Agen ini hanya melakukan koneksi KELUAR (polling), jadi PC tidak perlu
membuka port masuk untuk pengendalian. Port yang tetap harus terbuka
hanyalah port streaming Sunshine.

--------------------------------------------------------------
 Cara pakai
--------------------------------------------------------------
  1. Pasang Sunshine (atau Apollo) di PC ini, buat akun web UI-nya.
  2. Buat unit baru di dashboard admin XyCloudStore, salin kodenya.
  3. Jalankan:

       python xy_agent.py --kode xya_xxxxxxxx

     atau lewat environment PowerShell (bukan perintah set milik CMD):

       $env:XY_AGEN_KODE = Read-Host "Kode unit"
       $env:XY_SUNSHINE_USER = Read-Host "Username Sunshine"
       $pw = Read-Host "Password Sunshine" -AsSecureString
       $env:XY_SUNSHINE_PASS = [System.Net.NetworkCredential]::new("", $pw).Password
       python xy_agent.py --cek
       python xy_agent.py

  4. Supaya jalan otomatis saat PC menyala, daftarkan sebagai layanan
     (Windows: NSSM atau Task Scheduler saat logon).

Kebutuhan: Python 3.9 ke atas. Tidak ada pustaka luar yang wajib
(memakai urllib bawaan). Modul psutil dipakai bila tersedia untuk
melaporkan pemakaian CPU dan RAM.
"""

from __future__ import annotations

import argparse
import datetime
import base64
import json
import os
import platform
import shutil
import socket
import ssl
import subprocess
import sys
import time
import urllib.error
import urllib.request
import urllib.parse

VERSI = "1.1.0"

SERVER_BAWAAN = "https://api.xycloud.my.id"
SUNSHINE_BAWAAN = "https://127.0.0.1:47990"
JEDA_DETIK = 20


# ----------------------------------------------------------------------
#  Utilitas
# ----------------------------------------------------------------------
def catat(*pesan) -> None:
    waktu = time.strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{waktu}]", *pesan, flush=True)


def konteks_ssl_longgar() -> ssl.SSLContext:
    """Sunshine memakai sertifikat tanda tangan sendiri di localhost."""
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    return ctx


def minta(url: str, data: dict | None = None, header: dict | None = None,
          metode: str | None = None, ssl_longgar: bool = False, timeout: int = 20):
    """Permintaan HTTP sederhana yang mengembalikan dict."""
    isi = None
    kepala = {"Content-Type": "application/json", "User-Agent": f"XyAgent/{VERSI}"}
    kepala.update(header or {})

    if data is not None:
        isi = json.dumps(data).encode()

    permintaan = urllib.request.Request(url, data=isi, headers=kepala, method=metode or ("POST" if data else "GET"))
    ctx = konteks_ssl_longgar() if ssl_longgar else None

    try:
        # API Sunshine lokal jangan lewat proxy sistem/HTTP_PROXY.
        if ssl_longgar:
            opener = urllib.request.build_opener(
                urllib.request.ProxyHandler({}), urllib.request.HTTPSHandler(context=ctx))
            respons = opener.open(permintaan, timeout=timeout)
        else:
            respons = urllib.request.urlopen(permintaan, timeout=timeout)
        with respons as jawab:
            teks = jawab.read().decode()
            hasil = json.loads(teks) if teks.strip().startswith(("{", "[")) else {"teks": teks}
            if isinstance(hasil, dict):
                hasil["_http_status"] = jawab.status
            return hasil
    except urllib.error.HTTPError as e:
        badan = e.read().decode(errors="ignore")
        return {"_galat": f"HTTP {e.code}", "_http_status": e.code, "_isi": badan}
    except Exception as e:  # noqa: BLE001
        sebab = e.reason if isinstance(e, urllib.error.URLError) else e
        return {"_galat": str(sebab), "_jenis_galat": type(sebab).__name__}


def api_berhasil(j) -> bool:
    return isinstance(j, dict) and "_galat" not in j and "teks" not in j and not j.get("error") and j.get("status", True) not in (False, "false", 0)

def epoch(teks):
    if not teks:
        return None
    try:
        d = datetime.datetime.fromisoformat(str(teks).replace("Z", "+00:00"))
        if d.tzinfo is None:
            d = d.replace(tzinfo=datetime.timezone.utc)
        return d.timestamp()
    except (ValueError, TypeError):
        return None


def spesifikasi() -> dict:
    """Kumpulkan informasi mesin untuk ditampilkan di dashboard."""
    data = {
        "hostname": socket.gethostname(),
        "os": f"{platform.system()} {platform.release()}",
        "cpu": platform.processor() or platform.machine(),
        "python": platform.python_version(),
    }

    try:
        import psutil  # type: ignore

        data["cpu_persen"] = psutil.cpu_percent(interval=None)
        data["ram_total_gb"] = round(psutil.virtual_memory().total / 1024**3, 1)
        data["ram_persen"] = psutil.virtual_memory().percent
        data["disk_bebas_gb"] = round(psutil.disk_usage("/").free / 1024**3, 1)
    except Exception:  # noqa: BLE001
        pass

    # informasi GPU lewat nvidia-smi bila ada
    if shutil.which("nvidia-smi"):
        try:
            keluaran = subprocess.run(
                ["nvidia-smi", "--query-gpu=name,memory.total,utilization.gpu",
                 "--format=csv,noheader,nounits"],
                capture_output=True, text=True, timeout=8,
            ).stdout.strip().splitlines()
            if keluaran:
                nama, vram, util = [x.strip() for x in keluaran[0].split(",")]
                data["gpu"] = nama
                data["vram_mb"] = vram
                data["gpu_persen"] = util
        except Exception:  # noqa: BLE001
            pass

    return data


def ip_publik() -> str | None:
    for alamat in ("https://api.ipify.org", "https://ifconfig.me/ip"):
        try:
            with urllib.request.urlopen(alamat, timeout=8) as j:
                teks = j.read().decode().strip()
                if teks and len(teks) < 60:
                    return teks
        except Exception:  # noqa: BLE001
            continue
    return None


# ----------------------------------------------------------------------
#  Pengendali Sunshine
# ----------------------------------------------------------------------
class Sunshine:
    """Pembungkus tipis untuk API web Sunshine / Apollo."""

    def __init__(self, alamat: str, pengguna: str, sandi: str):
        self.alamat = alamat.rstrip("/")
        self.auth = base64.b64encode(f"{pengguna}:{sandi}".encode()).decode()
        self.kredensial_lengkap = bool(pengguna and sandi)

    def _header(self) -> dict:
        return {"Authorization": f"Basic {self.auth}"}

    def periksa(self) -> dict:
        """Cek API saja; tidak pairing, mengakhiri sesi, atau menutup aplikasi."""
        j = minta(f"{self.alamat}/api/apps", header=self._header(), ssl_longgar=True, timeout=8)
        if not isinstance(j, dict):
            return {"siap": False, "status": "API_TIDAK_SESUAI", "pesan": "Respons bukan API Sunshine /api/apps."}
        kode = j.get("_http_status")
        if kode in (401, 403):
            return {"siap": False, "status": "LOGIN_DITOLAK", "http": kode,
                    "pesan": f"Sunshine menjawab HTTP {kode}, tetapi akses API ditolak. Isi username/password web UI Sunshine melalui XY_SUNSHINE_USER dan XY_SUNSHINE_PASS."}
        if kode == 404:
            return {"siap": False, "status": "API_TIDAK_DITEMUKAN", "http": kode,
                    "pesan": "Layanan menjawab HTTP 404. Periksa alamat/port Sunshine atau kompatibilitas versi Apollo/Sunshine."}
        if "_galat" in j:
            jenis = j.get("_jenis_galat", "")
            pesan = j["_galat"]
            if jenis in ("TimeoutError", "timeout") or "timed out" in pesan.lower():
                status = "WAKTU_HABIS"
                rincian = "Sunshine tidak menjawab dalam 8 detik. Periksa proses/layanan dan alamat port lokal."
            elif jenis == "ConnectionRefusedError" or "10061" in pesan or "refused" in pesan.lower():
                status = "PORT_TERTUTUP"
                rincian = "Koneksi ditolak. Sunshine/Apollo belum berjalan atau tidak mendengarkan pada port ini."
            else:
                status = "GALAT_KONEKSI" if not kode else "GALAT_HTTP"
                rincian = "Gagal memeriksa Sunshine: " + pesan
            return {"siap": False, "status": status, "http": kode, "pesan": rincian}
        if not isinstance(j.get("apps"), list):
            return {"siap": False, "status": "API_TIDAK_SESUAI", "http": kode,
                    "pesan": "Layanan menjawab, tetapi bukan daftar aplikasi Sunshine. Buka web UI pada alamat ini dan selesaikan setup/login."}
        return {"siap": True, "status": "API_SIAP", "http": kode,
                "pesan": "Login API Sunshine berhasil. Ini belum menguji encoder, layar, atau koneksi streaming dari HP."}

    def hidup(self) -> bool:
        return self.periksa()["siap"]

    def pasangkan(self, pin: str, nama: str = "XyCloudStore", client_id: str | None = None) -> dict:
        """Approve only the matching pending pairing request; never equate HTTP 200 with success."""
        for _ in range(12):
            pending = minta(f"{self.alamat}/api/pin", header=self._header(), ssl_longgar=True, timeout=8)
            data = {"pin": pin, "name": nama}
            if pending.get("_http_status") == 404:
                # Older Sunshine/Apollo versions use the legacy one-request PIN API.
                result = minta(f"{self.alamat}/api/pin", data=data, header=self._header(), metode="POST", ssl_longgar=True, timeout=12)
                return result if api_berhasil(result) else {"_galat": "PIN ditolak Sunshine"}
            if not api_berhasil(pending):
                return {"_galat": "Tidak dapat membaca permintaan pairing Sunshine"}
            candidates = pending.get("pairings", [])
            if client_id:
                candidates = [x for x in candidates if x.get("name") == "XyCloudStore-" + client_id]
            if len(candidates) > 1:
                return {"_galat": "Ada beberapa permintaan pairing. Tutup permintaan lain lalu coba lagi."}
            if len(candidates) == 1:
                data["pairing_id"] = candidates[0]["id"]
                result = minta(f"{self.alamat}/api/pin", data=data, header=self._header(), metode="POST", ssl_longgar=True, timeout=12)
                return result if api_berhasil(result) else {"_galat": "Permintaan pairing atau PIN ditolak Sunshine"}
            time.sleep(1)
        return {"_galat": "Belum ada permintaan pairing dari HP. Periksa port streaming dan koneksi HP."}

    def putuskan_semua(self) -> dict:
        """Hentikan sesi streaming yang sedang berjalan."""
        return minta(f"{self.alamat}/api/apps/close", data={}, header=self._header(),
                     metode="POST", ssl_longgar=True, timeout=10)

    def hapus_perangkat(self) -> dict:
        """Lupakan semua perangkat yang pernah dipasangkan."""
        return minta(f"{self.alamat}/api/clients/unpair-all", data={}, header=self._header(),
                     metode="POST", ssl_longgar=True, timeout=10)


# ----------------------------------------------------------------------
#  Pembersihan antar penyewa
# ----------------------------------------------------------------------
def bersihkan_sesi() -> list[str]:
    """
    Tutup aplikasi penyewa sebelumnya supaya akun mereka tidak kebawa.
    Skrip tambahan bisa diletakkan di berkas bersih.bat / bersih.sh
    di folder yang sama dengan agen ini.
    """
    langkah: list[str] = []
    sistem = platform.system()

    program = ["steam.exe", "EpicGamesLauncher.exe", "Discord.exe", "chrome.exe", "msedge.exe"]
    if sistem == "Windows":
        for nama in program:
            try:
                subprocess.run(["taskkill", "/F", "/IM", nama], capture_output=True, timeout=10)
                langkah.append(f"tutup {nama}")
            except Exception:  # noqa: BLE001
                pass

    skrip = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                         "bersih.bat" if sistem == "Windows" else "bersih.sh")
    if os.path.exists(skrip):
        try:
            subprocess.run([skrip], capture_output=True, timeout=120, shell=(sistem == "Windows"))
            langkah.append("jalankan skrip bersih")
        except Exception as e:  # noqa: BLE001
            langkah.append(f"skrip bersih gagal: {e}")

    return langkah


# ----------------------------------------------------------------------
#  Program utama
# ----------------------------------------------------------------------
class Agen:
    def __init__(self, server: str, kode: str, sunshine: Sunshine, host_publik: str | None):
        self.server = server.rstrip("/")
        self.kode = kode
        self.sunshine = sunshine
        self.host = host_publik
        self.sesi_aktif: str | None = None
        self.batas_waktu: float | None = None
        self._status_sunshine: str | None = None
        self._server_ok = False
        self._akhir_pending = None

    # ---------- komunikasi ----------
    def lapor(self) -> list[dict]:
        cek = self.sunshine.periksa()
        if cek["status"] != self._status_sunshine:
            catat("Sunshine :", cek["status"], "-", cek["pesan"])
            self._status_sunshine = cek["status"]
        spec = spesifikasi()
        spec["sunshine"] = cek
        muatan = {
            "status": "sibuk" if self.sesi_aktif else "online",
            "versi": VERSI,
            "spec": spec,
        }
        if self.host:
            muatan["host"] = self.host

        j = minta(f"{self.server}/api/agen/heartbeat", data=muatan,
                  header={"x-agen-kode": self.kode})
        if "_galat" in j:
            self._server_ok = False
            catat("Gagal lapor ke server:", j["_galat"])
            return []
        data = j.get("data") or {}
        if not isinstance(data, dict) or data.get("ok") is not True:
            self._server_ok = False
            catat("Server belum mengonfirmasi heartbeat. Periksa alamat server dan kode unit.")
            return []
        if not self._server_ok:
            catat("Server   : HEARTBEAT DITERIMA (agen terhubung ke XyCloudStore)")
        self._server_ok = True
        if "lease" in data:
            lease = data.get("lease")
            if lease:
                self.sesi_aktif = lease["id"]
                self.batas_waktu = epoch(lease.get("berakhir"))
                if lease.get("status") == "mengakhiri":
                    self.batas_waktu = time.time() - 1
            elif not self._akhir_pending:
                self.sesi_aktif = None
                self.batas_waktu = None
        if self._akhir_pending:
            hasil = minta(f"{self.server}/api/agen/sesi/selesai", data={"sesi_id": self._akhir_pending, "ok": True}, header={"x-agen-kode": self.kode})
            if "_galat" not in hasil:
                self._akhir_pending = None
        return data.get("perintah", [])

    def balas(self, perintah_id: str, hasil: dict) -> None:
        minta(f"{self.server}/api/agen/perintah/{perintah_id}", data=hasil,
              header={"x-agen-kode": self.kode})

    # ---------- penanganan perintah ----------
    def kerjakan(self, perintah: dict) -> None:
        jenis = perintah.get("jenis")
        muatan = perintah.get("muatan") or {}
        sesi_id = muatan.get("sesi_id")
        catat(f"Perintah masuk: {jenis} ({sesi_id})")

        if self.sesi_aktif and self.sesi_aktif != sesi_id:
            self.balas(perintah["id"], {"ok": False, "sesi_id": sesi_id, "catatan": "Unit sedang menangani sesi lain"})
            return
        if jenis == "mulai_sesi":
            valid = epoch(muatan.get("valid_sampai"))
            if valid and time.time() > valid:
                self.balas(perintah["id"], {"ok": False, "sesi_id": sesi_id, "catatan": "Perintah mulai sudah kedaluwarsa"})
                return
            cek = self.sunshine.periksa()
            if not cek["siap"]:
                self.balas(perintah["id"], {"ok": False, "sesi_id": sesi_id,
                           "status": "gagal", "catatan": cek["pesan"]})
                return
            if not api_berhasil(self.sunshine.hapus_perangkat()):
                self.balas(perintah["id"], {"ok": False, "sesi_id": sesi_id, "catatan": "Sunshine belum berhasil melepas perangkat lama. Sesi tidak dimulai."})
                return
            langkah = bersihkan_sesi()
            siap = self.sunshine.hidup()
            self.sesi_aktif = sesi_id if siap else None
            menit = int(muatan.get("durasi_menit") or 60)
            self.batas_waktu = time.time() + menit * 60 if siap else None

            self.balas(perintah["id"], {
                "ok": siap,
                "sesi_id": sesi_id,
                "status": "siap" if siap else "gagal",
                "host": self.host,
                "catatan": "Sunshine siap menerima sambungan" if siap
                           else "Sunshine tidak merespons di PC ini",
                "langkah": langkah,
            })

        elif jenis == "pasangkan":
            hasil = self.sunshine.pasangkan(str(muatan.get("pin", "")), client_id=muatan.get("client_id"))
            berhasil = api_berhasil(hasil)
            self.balas(perintah["id"], {
                "ok": berhasil,
                "sesi_id": sesi_id,
                "status": "siap",
                "catatan": "Perangkat berhasil dipasangkan" if berhasil
                           else "PIN ditolak, minta penyewa mencoba lagi",
            })

        elif jenis == "akhiri_sesi":
            ok = self.tutup_sesi()
            self.balas(perintah["id"], {"ok": ok, "sesi_id": sesi_id,
                "status": "selesai" if ok else "mengakhiri",
                "catatan": "Sesi dibersihkan" if ok else "API pembersihan belum berhasil; unit tetap dikunci"})

        else:
            self.balas(perintah["id"], {"ok": False, "catatan": f"Perintah {jenis} tidak dikenal"})

    def tutup_sesi(self) -> bool:
        close = self.sunshine.putuskan_semua()
        unpair = self.sunshine.hapus_perangkat()
        if not api_berhasil(close) or not api_berhasil(unpair):
            catat("Pembersihan Sunshine belum berhasil; mencoba lagi pada putaran berikutnya")
            return False
        bersihkan_sesi()
        self._akhir_pending = self.sesi_aktif
        self.sesi_aktif = None
        self.batas_waktu = None
        return True

    # ---------- putaran utama ----------
    def jalan(self) -> None:
        catat(f"XyCloudStore Agen {VERSI}")
        catat("Server   :", self.server)
        catat("Sunshine :", self.sunshine.alamat)
        if not self.sunshine.kredensial_lengkap:
            catat("Perhatian:", "Kredensial Sunshine belum lengkap. Kode unit XyCloud berbeda dari username/password Sunshine.")
        catat("Host     :", self.host or "(otomatis dari server)")

        while True:
            try:
                for perintah in self.lapor():
                    self.kerjakan(perintah)

                # waktu sewa habis: tutup sendiri walau aplikasi penyewa diam
                if self.batas_waktu and time.time() > self.batas_waktu:
                    catat("Waktu sewa habis, menutup sesi")
                    self.tutup_sesi()

            except KeyboardInterrupt:
                catat("Agen dihentikan")
                return
            except Exception as e:  # noqa: BLE001
                catat("Kesalahan tidak terduga:", e)

            time.sleep(JEDA_DETIK)


def main() -> int:
    p = argparse.ArgumentParser(description="Agen PC host XyCloudStore")
    p.add_argument("--server", default=os.getenv("XY_SERVER", SERVER_BAWAAN))
    p.add_argument("--kode", default=os.getenv("XY_AGEN_KODE"))
    p.add_argument("--sunshine", default=os.getenv("XY_SUNSHINE_URL", SUNSHINE_BAWAAN))
    p.add_argument("--user", default=os.getenv("XY_SUNSHINE_USER", "admin"))
    p.add_argument("--pass", "--sandi", dest="sandi", default=os.getenv("XY_SUNSHINE_PASS", ""))
    p.add_argument("--cek", action="store_true", help="Hanya diagnosis Sunshine; tidak heartbeat, pairing, atau membersihkan sesi")
    p.add_argument("--host", default=os.getenv("XY_HOST_PUBLIK"))
    a = p.parse_args()

    url = urllib.parse.urlsplit(a.sunshine)
    if url.scheme not in ("http", "https") or not url.hostname or url.username or url.password:
        print("Alamat Sunshine harus URL HTTP/HTTPS tanpa username/password di URL.", file=sys.stderr)
        return 2
    sunshine = Sunshine(a.sunshine, a.user, a.sandi)
    if a.cek:
        catat(f"XyCloudStore Agen {VERSI} - diagnosis saja")
        catat("Sunshine :", sunshine.alamat)
        if not sunshine.kredensial_lengkap:
            catat("Perhatian:", "Isi XY_SUNSHINE_USER dan XY_SUNSHINE_PASS dengan akun web UI Sunshine.")
        cek = sunshine.periksa()
        catat("Hasil    :", cek["status"], "-", cek["pesan"])
        return 0 if cek["siap"] else 1
    if not a.kode:
        print("Kode agen belum diisi. Pakai --kode atau set XY_AGEN_KODE.", file=sys.stderr)
        return 2

    host = a.host or ip_publik()
    agen = Agen(a.server, a.kode, sunshine, host)
    agen.jalan()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
