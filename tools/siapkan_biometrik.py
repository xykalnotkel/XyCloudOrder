#!/usr/bin/env python3
"""
Menyiapkan MainActivity untuk LOGIN BIOMETRIK (local_auth, Batch I).

Plugin local_auth di Android mewajibkan activity utama meng-extend
FlutterFragmentActivity (bukan FlutterActivity default `flutter create`).
Skrip ini idempotent dan dipanggil CI setelah skrip patch MainActivity lain
(streaming/updater/privasi) supaya tidak saling menimpa.

Pemakaian: python3 tools/siapkan_biometrik.py app/android
"""
import re
import sys
from pathlib import Path


def find_main_activity(android_dir: Path):
    candidates = list(android_dir.rglob("MainActivity.kt")) + list(
        android_dir.rglob("MainActivity.java")
    )
    if not candidates:
        return None
    candidates.sort(key=lambda p: len(str(p)))
    return candidates[0]


def patch_kotlin(src: str) -> str:
    if "FlutterFragmentActivity" in src:
        return src
    src = src.replace(
        "import io.flutter.embedding.android.FlutterActivity",
        "import io.flutter.embedding.android.FlutterFragmentActivity",
    )
    # `class MainActivity: FlutterActivity()` / `class MainActivity : FlutterActivity() {`
    src = re.sub(r":\s*FlutterActivity\s*\(", ": FlutterFragmentActivity(", src)
    return src


def patch_java(src: str) -> str:
    if "FlutterFragmentActivity" in src:
        return src
    src = src.replace(
        "import io.flutter.embedding.android.FlutterActivity;",
        "import io.flutter.embedding.android.FlutterFragmentActivity;",
    )
    src = re.sub(r"extends\s+FlutterActivity\b", "extends FlutterFragmentActivity", src)
    return src


def main() -> int:
    android_dir = Path(sys.argv[1] if len(sys.argv) > 1 else "app/android")
    if not android_dir.exists():
        android_dir = Path("android")
    berkas = find_main_activity(android_dir)
    if berkas is None:
        print("MainActivity tidak ditemukan — dilewati (tidak menggagalkan build).")
        return 0

    src = berkas.read_text(encoding="utf-8")
    if berkas.suffix == ".kt":
        hasil = patch_kotlin(src)
    else:
        hasil = patch_java(src)

    if hasil != src:
        berkas.write_text(hasil, encoding="utf-8")
        print(f"{berkas}: FlutterActivity -> FlutterFragmentActivity (local_auth)")
    else:
        print(f"{berkas}: sudah FlutterFragmentActivity (idempotent)")

    if "FlutterFragmentActivity" not in berkas.read_text(encoding="utf-8"):
        print("PERINGATAN: patch biometrik gagal diterapkan!", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
