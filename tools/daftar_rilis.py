#!/usr/bin/env python3
"""Mendaftarkan rilis APK baru ke server XyCloudStore.

Dipanggil alur build setelah rilis GitHub terbit, sehingga halaman unduh
di situs langsung menampilkan versi terbaru tanpa menanyakan GitHub.

Pemakaian:
    python3 tools/daftar_rilis.py v1.9.0

Variabel lingkungan:
    ADMIN_KEY   kunci admin XyCloudStore (wajib)
    API_URL     alamat API, bawaan https://api.xycloud.my.id
"""
import json
import os
import sys
import urllib.error
import urllib.request


def cari_apk(akar: str = '.') -> list[dict]:
    """Kumpulkan semua berkas APK hasil build beserta ukurannya."""
    ketemu: dict[str, dict] = {}
    for direktori, _, berkas in os.walk(akar):
        for nama in berkas:
            if nama.startswith('XyCloudStore-') and nama.endswith('.apk'):
                jalur = os.path.join(direktori, nama)
                ketemu[nama] = {'nama': nama, 'ukuran': os.path.getsize(jalur)}
    return list(ketemu.values())


def main() -> int:
    versi = sys.argv[1] if len(sys.argv) > 1 else os.getenv('GITHUB_REF_NAME', '')
    kunci = os.getenv('ADMIN_KEY', '')
    alamat = os.getenv('API_URL', 'https://api.xycloud.my.id')

    if not kunci:
        print('ADMIN_KEY belum diatur, pendaftaran rilis dilewati.')
        return 0
    if not versi:
        print('Versi tidak diketahui, pendaftaran rilis dilewati.')
        return 0

    berkas = cari_apk()
    if not berkas:
        print('Tidak ada berkas APK yang ditemukan.')
        return 0

    muatan = json.dumps({'versi': versi, 'berkas': berkas}).encode()
    permintaan = urllib.request.Request(
        f'{alamat}/api/admin/rilis',
        data=muatan,
        headers={
            'Content-Type': 'application/json',
            'x-admin-key': kunci,
            # penting: user agent bawaan urllib ditolak penyaring bot Cloudflare
            'User-Agent': 'XyCloudStore-CI/1.0',
        },
    )

    try:
        with urllib.request.urlopen(permintaan, timeout=25) as jawab:
            print(f'Rilis {versi} terdaftar ({jawab.status}) dengan {len(berkas)} berkas:')
            for b in berkas:
                print(f"  - {b['nama']} {round(b['ukuran'] / 1048576, 1)} MB")
    except urllib.error.HTTPError as e:
        print(f'Gagal mendaftarkan rilis: HTTP {e.code} {e.read().decode(errors="ignore")[:200]}')
    except Exception as e:  # noqa: BLE001
        print(f'Gagal mendaftarkan rilis: {e}')

    return 0


if __name__ == '__main__':
    raise SystemExit(main())
