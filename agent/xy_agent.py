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

     atau lewat variabel lingkungan:

       set XY_AGEN_KODE=xya_xxxxxxxx
       set XY_SUNSHINE_USER=admin
       set XY_SUNSHINE_PASS=rahasia
       python xy_agent.py

  4. Supaya jalan otomatis saat PC menyala, daftarkan sebagai layanan
     (Windows: NSSM atau Task Scheduler saat logon).

Kebutuhan: Python 3.9 ke atas. Tidak ada pustaka luar yang wajib
(memakai urllib bawaan). Modul psutil dipakai bila tersedia untuk
melaporkan pemakaian CPU dan RAM.
"""

from __future__ import annotations

import argparse
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

VERSI = "1.0.0"

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
        with urllib.request.urlopen(permintaan, timeout=timeout, context=ctx) as jawab:
            teks = jawab.read().decode()
            return json.loads(teks) if teks.strip().startswith(("{", "[")) else {"teks": teks}
    except urllib.error.HTTPError as e:
        badan = e.read().decode(errors="ignore")
        return {"_galat": f"HTTP {e.code}", "_isi": badan}
    except Exception as e:  # noqa: BLE001
        return {"_galat": str(e)}


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

    def _header(self) -> dict:
        return {"Authorization": f"Basic {self.auth}"}

    def hidup(self) -> bool:
        j = minta(f"{self.alamat}/api/apps", header=self._header(), ssl_longgar=True, timeout=8)
        return "_galat" not in j

    def pasangkan(self, pin: str, nama: str = "XyCloudStore") -> dict:
        """Masukkan PIN yang muncul di aplikasi penyewa."""
        for jalur in (f"/api/pin?pin={pin}&name={nama}", "/api/pin"):
            data = {"pin": pin, "name": nama} if jalur == "/api/pin" else None
            j = minta(f"{self.alamat}{jalur}", data=data, header=self._header(),
                      metode="POST", ssl_longgar=True, timeout=15)
            if "_galat" not in j:
                return j
        return {"_galat": "Gagal mengirim PIN ke Sunshine"}

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

    # ---------- komunikasi ----------
    def lapor(self) -> list[dict]:
        muatan = {
            "status": "sibuk" if self.sesi_aktif else "online",
            "versi": VERSI,
            "spec": spesifikasi(),
        }
        if self.host:
            muatan["host"] = self.host

        j = minta(f"{self.server}/api/agen/heartbeat", data=muatan,
                  header={"x-agen-kode": self.kode})
        if "_galat" in j:
            catat("Gagal lapor ke server:", j["_galat"])
            return []
        return (j.get("data") or {}).get("perintah", [])

    def balas(self, perintah_id: str, hasil: dict) -> None:
        minta(f"{self.server}/api/agen/perintah/{perintah_id}", data=hasil,
              header={"x-agen-kode": self.kode})

    # ---------- penanganan perintah ----------
    def kerjakan(self, perintah: dict) -> None:
        jenis = perintah.get("jenis")
        muatan = perintah.get("muatan") or {}
        sesi_id = muatan.get("sesi_id")
        catat(f"Perintah masuk: {jenis} ({sesi_id})")

        if jenis == "mulai_sesi":
            langkah = bersihkan_sesi()
            self.sunshine.hapus_perangkat()

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
            hasil = self.sunshine.pasangkan(str(muatan.get("pin", "")))
            berhasil = "_galat" not in hasil
            self.balas(perintah["id"], {
                "ok": berhasil,
                "sesi_id": sesi_id,
                "status": "berjalan" if berhasil else "siap",
                "catatan": "Perangkat berhasil dipasangkan" if berhasil
                           else "PIN ditolak, minta penyewa mencoba lagi",
            })

        elif jenis == "akhiri_sesi":
            self.sunshine.putuskan_semua()
            self.sunshine.hapus_perangkat()
            langkah = bersihkan_sesi()
            self.sesi_aktif = None
            self.batas_waktu = None
            self.balas(perintah["id"], {
                "ok": True,
                "sesi_id": sesi_id,
                "status": "selesai",
                "catatan": "Sesi ditutup dan mesin dibersihkan",
                "langkah": langkah,
            })

        else:
            self.balas(perintah["id"], {"ok": False, "catatan": f"Perintah {jenis} tidak dikenal"})

    # ---------- putaran utama ----------
    def jalan(self) -> None:
        catat(f"XyCloudStore Agen {VERSI}")
        catat("Server   :", self.server)
        catat("Sunshine :", self.sunshine.alamat, "->", "terhubung" if self.sunshine.hidup() else "TIDAK TERHUBUNG")
        catat("Host     :", self.host or "(otomatis dari server)")

        while True:
            try:
                for perintah in self.lapor():
                    self.kerjakan(perintah)

                # waktu sewa habis: tutup sendiri walau aplikasi penyewa diam
                if self.batas_waktu and time.time() > self.batas_waktu:
                    catat("Waktu sewa habis, menutup sesi")
                    self.sunshine.putuskan_semua()
                    self.sunshine.hapus_perangkat()
                    bersihkan_sesi()
                    self.sesi_aktif = None
                    self.batas_waktu = None

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
    p.add_argument("--pass", dest="sandi", default=os.getenv("XY_SUNSHINE_PASS", ""))
    p.add_argument("--host", default=os.getenv("XY_HOST_PUBLIK"))
    a = p.parse_args()

    if not a.kode:
        print("Kode agen belum diisi. Pakai --kode atau set XY_AGEN_KODE.", file=sys.stderr)
        return 2

    host = a.host or ip_publik()
    agen = Agen(a.server, a.kode, Sunshine(a.sunshine, a.user, a.sandi), host)
    agen.jalan()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
