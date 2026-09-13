#!/usr/bin/env python3
"""Bandingkan skema D1 PRODUKSI dengan skema yang diharapkan repository.

Latar belakang (audit 2026-09-13)
---------------------------------
`api/schema.sql` selalu diperbarui ke bentuk terbaru dan hanya dipakai untuk
basis data baru. Basis data produksi yang sudah berisi data tidak bisa
dijalankan ulang (ada `DROP TABLE`), jadi perubahannya masuk lewat
`api/migrations/*.sql` yang dijalankan manual. Migrasi 0004 (`rilis.gambar`)
pernah terlewat, dan akibatnya `simpanRilis()` gagal selama lima hari tanpa
satu pun pemeriksaan yang merah. Alat ini menutup celah itu.

Cara pakai
----------
    export CLOUDFLARE_API_TOKEN=...          # wajib
    export CLOUDFLARE_ACCOUNT_ID=...         # opsional, dibaca dari wrangler.toml/env
    python3 tools/cek_skema_d1.py            # laporkan selisih (exit 1 kalau ada)
    python3 tools/cek_skema_d1.py --fix      # cetak SQL perbaikan
    python3 tools/cek_skema_d1.py --fix --apply   # jalankan SQL perbaikan
    python3 tools/cek_skema_d1.py --lokal    # bandingkan skema repo vs sqlite lokal saja (tanpa jaringan)

Yang dibandingkan: daftar tabel, daftar kolom tiap tabel, trigger, dan index.
Nilai data TIDAK pernah dibaca atau diubah.
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import re
import sqlite3
import sys
import urllib.error
import urllib.request

API = 'https://api.cloudflare.com/client/v4'
AKAR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
API_DIR = os.path.join(AKAR, 'api')


# --------------------------------------------------------------------------
#  Skema harapan: schema.sql + migrations/*.sql dijalankan di sqlite lokal
# --------------------------------------------------------------------------
def pisah_statement(jalur: str) -> list[str]:
    """Pisahkan berkas SQL per pernyataan, sadar blok BEGIN…END milik trigger."""
    keluar: list[str] = []
    buf = ''
    for ch in open(jalur, encoding='utf-8').read():
        buf += ch
        if ch == ';' and sqlite3.complete_statement(buf):
            keluar.append(buf)
            buf = ''
    return [s for s in keluar if s.strip()]


def skema_dari_repo() -> sqlite3.Connection:
    db = sqlite3.connect(':memory:')
    berkas = [os.path.join(API_DIR, 'schema.sql')] + sorted(
        glob.glob(os.path.join(API_DIR, 'migrations', '*.sql')))
    for nama in berkas:
        jalur = nama if os.path.isabs(nama) else os.path.join(API_DIR, nama)
        if not os.path.exists(jalur):
            continue
        for pernyataan in pisah_statement(jalur):
            try:
                db.executescript(pernyataan)
            except sqlite3.Error as e:
                pesan = str(e)
                # Kolom/tabel yang sudah ada boleh diulang (skema dasar & migrasi tumpang tindih).
                if 'duplicate column' in pesan or 'already exists' in pesan:
                    continue
                raise SystemExit(f'Gagal menerapkan {os.path.basename(jalur)}: {pesan}')
    return db


def ringkas(db: sqlite3.Connection) -> dict:
    """Ambil tabel → kolom (+ tipe), plus daftar trigger & index."""
    tabel = [r[0] for r in db.execute(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '\\_%' ESCAPE '\\' ORDER BY name")]
    kolom, tipe = {}, {}
    for t in tabel:
        info = list(db.execute(f"PRAGMA table_info('{t}')"))
        kolom[t] = [r[1] for r in info]
        tipe[t] = {r[1]: (r[2] or 'TEXT') for r in info}
    objek = {r[0]: r[1] for r in db.execute(
        "SELECT name, type FROM sqlite_master WHERE type IN ('trigger','index') "
        "AND name NOT LIKE 'sqlite_%' ORDER BY name")}
    return {'kolom': kolom, 'tipe': tipe, 'objek': objek}


# --------------------------------------------------------------------------
#  Skema nyata: D1 remote lewat Cloudflare REST API
# --------------------------------------------------------------------------
def baca_wrangler() -> dict:
    teks = open(os.path.join(API_DIR, 'wrangler.toml'), encoding='utf-8').read()
    nama = re.search(r'database_name\s*=\s*"([^"]+)"', teks)
    dbid = re.search(r'database_id\s*=\s*"([^"]+)"', teks)
    return {'nama': nama.group(1) if nama else '', 'id': dbid.group(1) if dbid else ''}


def d1_query(token: str, akun: str, dbid: str, sql: str) -> list[dict]:
    req = urllib.request.Request(
        f'{API}/accounts/{akun}/d1/database/{dbid}/query',
        data=json.dumps({'sql': sql}).encode(),
        headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'},
        method='POST')
    try:
        with urllib.request.urlopen(req, timeout=60) as jawab:
            data = json.load(jawab)
    except urllib.error.HTTPError as e:
        raise SystemExit(f'D1 menolak permintaan (HTTP {e.code}): {e.read().decode()[:300]}')
    if data.get('errors'):
        raise SystemExit(f'D1 galat: {json.dumps(data["errors"], ensure_ascii=False)[:300]}')
    return data['result'][0].get('results', [])


def skema_dari_d1(token: str, akun: str, dbid: str) -> dict:
    baris = d1_query(token, akun, dbid,
        "SELECT m.name AS tabel, p.name AS kolom, p.cid AS cid "
        "FROM sqlite_master m JOIN pragma_table_info(m.name) p "
        "WHERE m.type='table' AND m.name NOT LIKE 'sqlite_%' AND m.name NOT LIKE '\\_%' ESCAPE '\\' "
        "ORDER BY m.name, p.cid")
    kolom: dict[str, list[str]] = {}
    for r in baris:
        kolom.setdefault(r['tabel'], []).append(r['kolom'])
    objek = {r['name']: r['type'] for r in d1_query(token, akun, dbid,
        "SELECT name, type FROM sqlite_master WHERE type IN ('trigger','index') "
        "AND name NOT LIKE 'sqlite_%' ORDER BY name")}
    return {'kolom': kolom, 'objek': objek}


# --------------------------------------------------------------------------
#  Bandingkan
# --------------------------------------------------------------------------
def bandingkan(harap: dict, nyata: dict) -> list[str]:
    masalah: list[str] = []
    ht, nt = set(harap['kolom']), set(nyata['kolom'])
    for t in sorted(ht - nt):
        masalah.append(f'TABEL HILANG di produksi: {t}')
    for t in sorted(nt - ht):
        # d1_migrations adalah tabel buku migrasi milik wrangler — bukan bagian skema repo.
        if t != 'd1_migrations':
            masalah.append(f'tabel ekstra di produksi (tidak ada di schema.sql): {t}')
    for t in sorted(ht & nt):
        hilang = [c for c in harap['kolom'][t] if c not in set(nyata['kolom'][t])]
        if hilang:
            masalah.append(f'{t}: KOLOM HILANG di produksi -> {hilang}')
    for nama, jenis in sorted(harap['objek'].items()):
        if nama not in nyata['objek']:
            masalah.append(f'{jenis} HILANG di produksi: {nama}')
    return masalah


def berkas_migrasi_untuk(tabel: str, kolom: str) -> str | None:
    """Cari berkas migrasi yang memang menambahkan kolom ini (kalau ada)."""
    for jalur in sorted(glob.glob(os.path.join(API_DIR, 'migrations', '*.sql'))):
        teks = open(jalur, encoding='utf-8').read()
        if re.search(rf'ALTER\s+TABLE\s+{re.escape(tabel)}\s+ADD\s+COLUMN\s+"?{re.escape(kolom)}"?\b',
                     teks, re.I):
            return os.path.basename(jalur)
    return None


def sql_perbaikan(harap: dict, nyata: dict) -> list[str]:
    """ALTER TABLE untuk kolom yang hilang. Tabel/trigger hilang butuh perhatian manusia."""
    keluar = []
    for t in sorted(set(harap['kolom']) & set(nyata['kolom'])):
        for c in harap['kolom'][t]:
            if c in set(nyata['kolom'][t]):
                continue
            tipe = harap.get('tipe', {}).get(t, {}).get(c, 'TEXT')
            asal = berkas_migrasi_untuk(t, c)
            catatan = f'  -- dari {asal}' if asal else '  -- TIDAK ada migrasinya, buat dulu!'
            keluar.append(f'ALTER TABLE {t} ADD COLUMN {c} {tipe};{catatan}')
    return keluar


def utama() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--fix', action='store_true', help='cetak SQL perbaikan untuk kolom yang hilang')
    ap.add_argument('--apply', action='store_true', help='jalankan SQL perbaikan ke D1 (butuh --fix)')
    ap.add_argument('--lokal', action='store_true', help='hanya bangun skema repo, jangan hubungi D1')
    ap.add_argument('--json', action='store_true', help='keluarkan hasil sebagai JSON')
    args = ap.parse_args()

    harap = ringkas(skema_dari_repo())

    if args.lokal:
        print(f"Skema repo: {len(harap['kolom'])} tabel, "
              f"{sum(len(v) for v in harap['kolom'].values())} kolom, {len(harap['objek'])} trigger/index.")
        for t in sorted(harap['kolom']):
            print(f'  {t:24s} {len(harap["kolom"][t])} kolom')
        return 0

    token = os.getenv('CLOUDFLARE_API_TOKEN') or os.getenv('CF_API_TOKEN') or ''
    if not token:
        print('CLOUDFLARE_API_TOKEN belum diatur.', file=sys.stderr)
        return 2
    cfg = baca_wrangler()
    dbid = os.getenv('D1_DATABASE_ID') or cfg['id']
    akun = os.getenv('CLOUDFLARE_ACCOUNT_ID') or ''
    if not akun:
        with urllib.request.urlopen(urllib.request.Request(
                f'{API}/accounts', headers={'Authorization': f'Bearer {token}'}), timeout=30) as j:
            d = json.load(j)
        if not d.get('success') or not d['result']:
            print('Tidak dapat menemukan akun Cloudflare untuk token ini.', file=sys.stderr)
            return 2
        akun = d['result'][0]['id']
    if not dbid:
        print('database_id tidak ditemukan di api/wrangler.toml.', file=sys.stderr)
        return 2

    nyata = skema_dari_d1(token, akun, dbid)
    masalah = bandingkan(harap, nyata)

    if args.json:
        print(json.dumps({'tabel_repo': len(harap['kolom']), 'tabel_produksi': len(nyata['kolom']),
                          'masalah': masalah, 'perbaikan': sql_perbaikan(harap, nyata) if args.fix else []},
                         ensure_ascii=False, indent=2))
        return 1 if masalah else 0

    print(f'D1 {cfg["nama"] or dbid} · {len(nyata["kolom"])} tabel produksi vs {len(harap["kolom"])} tabel repo')
    if not masalah:
        print('✅ Skema produksi cocok dengan repository. Tidak ada selisih.')
        return 0

    print(f'❌ {len(masalah)} selisih ditemukan:')
    for m in masalah:
        print('   -', m)

    if args.fix:
        perbaikan = sql_perbaikan(harap, nyata)
        if perbaikan:
            print('\nSQL perbaikan (kolom hilang):')
            for s in perbaikan:
                print('   ', s)
            if args.apply:
                print('\nMenerapkan…')
                for s in perbaikan:
                    d1_query(token, akun, dbid, s)
                    print('   ok:', s)
                print('Selesai. Jalankan ulang untuk memastikan tidak ada selisih tersisa.')
        sisa = [m for m in masalah if 'TABEL HILANG' in m or 'trigger' in m or 'index' in m]
        if sisa:
            print('\nPerlu tindakan manusia (tidak bisa diperbaiki otomatis):')
            for m in sisa:
                print('   -', m)
    else:
        print('\nJalankan dengan --fix untuk melihat SQL perbaikan, --fix --apply untuk menerapkannya.')
    return 1


if __name__ == '__main__':
    raise SystemExit(utama())
