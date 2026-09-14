#!/usr/bin/env python3
"""
Menyiapkan channel native Android untuk MODE PRIVASI XyCloudStore
(FLAG_SECURE: blokir screenshot, perekaman layar, dan pratinjau recents).

Dipanggil setelah `flutter create` + streaming + updater di CI:
  python3 tools/siapkan_keamanan.py app/android

Yang dilakukan:
  1. Cari MainActivity.kt / MainActivity.java
  2. Suntik MethodChannel 'xycloud/keamanan' dengan handler:
     - setFlagSecure(aktif: bool) -> window.setFlags/clearFlags(FLAG_SECURE)
  3. Idempotent (penanda 'xycloud/keamanan' dicek dulu)
  4. Mengikuti tanda tangan configureFlutterEngine(engine) yang sudah
     dipakai streaming bridge & updater (penanda __ENGINE__), termasuk
     cek import MethodChannel supaya tidak bentrok/duplikat.

Kalau MainActivity tidak ditemukan, skrip keluar 0 (tidak menggagalkan
build) — sisi Flutter sudah menelan galat channel dengan try/catch.
"""
import re
import sys
from pathlib import Path

KOTLIN_HANDLER = """
        // === XyCloudStore Privacy Channel (FLAG_SECURE / mode privasi) ===
        MethodChannel(__ENGINE__.dartExecutor.binaryMessenger, "xycloud/keamanan")
          .setMethodCallHandler { call, result ->
            when (call.method) {
              "setFlagSecure" -> {
                val aktif = call.argument<Boolean>("aktif") ?: false
                runOnUiThread {
                  if (aktif) {
                    window.setFlags(
                      android.view.WindowManager.LayoutParams.FLAG_SECURE,
                      android.view.WindowManager.LayoutParams.FLAG_SECURE
                    )
                  } else {
                    window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE)
                  }
                  result.success(true)
                }
              }
              else -> result.notImplemented()
            }
          }
        // === End Privacy ===
"""

JAVA_HANDLER = """
        // === XyCloudStore Privacy Channel (FLAG_SECURE / mode privasi) ===
        new MethodChannel(__ENGINE__.getDartExecutor().getBinaryMessenger(), "xycloud/keamanan")
          .setMethodCallHandler((call, result) -> {
            if (call.method.equals("setFlagSecure")) {
              boolean aktif = Boolean.TRUE.equals(call.argument("aktif"));
              runOnUiThread(() -> {
                if (aktif) {
                  getWindow().setFlags(
                    android.view.WindowManager.LayoutParams.FLAG_SECURE,
                    android.view.WindowManager.LayoutParams.FLAG_SECURE);
                } else {
                  getWindow().clearFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE);
                }
                result.success(true);
              });
            } else {
              result.notImplemented();
            }
          });
        // === End Privacy ===
"""


def find_main_activity(android_dir: Path):
    candidates = list(android_dir.rglob("MainActivity.kt")) + list(
        android_dir.rglob("MainActivity.java")
    )
    if not candidates:
        return None
    candidates.sort(key=lambda p: len(str(p)))
    return candidates[0]


def _tambah_import(src: str, imp: str) -> str:
    if f"import {imp}" in src:
        return src
    if src.startswith("package "):
        nl = src.find("\n")
        return src[: nl + 1] + f"import {imp}\n" + src[nl + 1 :]
    return f"import {imp}\n" + src


def _sisip_handler(src: str, handler: str, pola_signature: str, fallback_engine: str,
                   pembuat_method: str) -> str:
    # PENTING: pola_signature punya DUA grup — grup 1 seluruh tanda tangan
    # (dipakai re.sub), grup 2 nama variabel engine. Penggantian lewat lambda
    # supaya teks handler bebas dari masalah escape backreference.
    m = re.search(pola_signature, src)
    if m:
        h = handler.replace("__ENGINE__", m.group(2))
        return re.sub(pola_signature,
                      lambda mm: mm.group(0) + "\n" + h.strip() + "\n",
                      src, count=1)
    # fallback generik tanpa nama variabel
    pola2 = r"(override fun configureFlutterEngine\([^)]*\)\s*\{)"
    if re.search(pola2, src):
        h = handler.replace("__ENGINE__", fallback_engine)
        return re.sub(pola2, lambda mm: mm.group(0) + "\n" + h.strip() + "\n",
                      src, count=1)
    # terakhir: buat configureFlutterEngine baru sebelum kurung penutup kelas
    h = handler.replace("__ENGINE__", fallback_engine)
    inject = pembuat_method + h + "\n    }\n"
    last = src.rfind("}")
    return src[:last] + inject + "}\n"


def patch_kotlin(path: Path):
    src = path.read_text(encoding="utf-8")
    if "xycloud/keamanan" in src:
        print(f"Sudah ada privacy channel di {path}, dilewati")
        return
    src = _tambah_import(src, "io.flutter.plugin.common.MethodChannel")
    pola = r"(override fun configureFlutterEngine\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*:\s*FlutterEngine\??\s*\)\s*\{)"
    src = _sisip_handler(
        src,
        KOTLIN_HANDLER,
        pola,
        "flutterEngine",
        "\n    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {\n        super.configureFlutterEngine(flutterEngine)\n",
    )
    path.write_text(src, encoding="utf-8")
    print(f"Patched Kotlin MainActivity: {path}")


def patch_java(path: Path):
    src = path.read_text(encoding="utf-8")
    if "xycloud/keamanan" in src:
        print(f"Sudah ada privacy channel di {path}, dilewati")
        return
    src = _tambah_import(src, "io.flutter.plugin.common.MethodChannel")
    pola = r"(public void configureFlutterEngine\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)\s*\{[^}]*?super\.configureFlutterEngine[^;]*;)"
    m = re.search(pola, src, re.DOTALL)
    if m:
        # grup 2 = nama variabel engine (grup 1 = seluruh blok tanda tangan)
        h = JAVA_HANDLER.replace("__ENGINE__", m.group(2))
        src = re.sub(pola, lambda mm: mm.group(0) + "\n" + h.strip() + "\n",
                     src, count=1, flags=re.DOTALL)
    else:
        inject = (
            "\n    @Override\n"
            "    public void configureFlutterEngine(io.flutter.embedding.engine.FlutterEngine flutterEngine) {\n"
            "        super.configureFlutterEngine(flutterEngine);\n"
            + JAVA_HANDLER.replace("__ENGINE__", "flutterEngine")
            + "\n    }\n"
        )
        last = src.rfind("}")
        src = src[:last] + inject + "}\n"
    path.write_text(src, encoding="utf-8")
    print(f"Patched Java MainActivity: {path}")


def main():
    android_dir = Path(sys.argv[1] if len(sys.argv) > 1 else "android")
    if not android_dir.exists():
        print(f"Folder {android_dir} tidak ditemukan — dilewati (tidak fatal)")
        return 0
    main_activity = find_main_activity(android_dir)
    if not main_activity:
        print("MainActivity.kt/java tidak ditemukan — dilewati (tidak fatal)")
        return 0
    print(f"Found MainActivity: {main_activity}")
    if main_activity.suffix == ".kt":
        patch_kotlin(main_activity)
    else:
        patch_java(main_activity)
    print("Selesai — mode privasi (FLAG_SECURE) siap.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
