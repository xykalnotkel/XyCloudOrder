#!/usr/bin/env python3
"""
Menyiapkan adapter native Android untuk fitur pembaruan aplikasi
XyCloudStore (DownloadManager + notifikasi progress + install).

Dipanggil setelah `flutter create` dan `siapkan_streaming.py` di CI:
  python3 tools/siapkan_pembaruan.py app/android

Yang dilakukan:
  1. Cari MainActivity.kt / MainActivity.java
  2. Suntik MethodChannel 'xycloud/updater' dengan handler:
     - available -> true
     - download(url, title, version) -> DownloadManager enqueue
     - status(id) -> cek STATUS_SUCCESSFUL/FAILED/RUNNING
     - install(id) -> ACTION_VIEW intent via FileProvider
  3. Pastikan tidak double-inject (idempotent)
  4. Validasi url harus dari xycloud.my.id (dicek di Flutter juga, tapi di native kita log)

Catatan:
  - Folder android/ digenerate saat build (tidak di-commit)
  - Butuh permission REQUEST_INSTALL_PACKAGES (sudah ditambah di patch_manifest.py)
  - Untuk Android 10+ pakai setDestinationInExternalFilesDir jadi tidak butuh storage permission
  - FileProvider sudah ada dari flutter, kita pakai DownloadManager.getUriForDownloadedFile

Pemakaian lokal:
  cd app
  flutter create . --platforms=android --org id.xycloud --project-name xycloud_order
  python3 ../tools/siapkan_pembaruan.py android
"""
import sys
import re
from pathlib import Path

# Kotlin code untuk disisipkan
KOTLIN_IMPORTS = """
import android.app.DownloadManager
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.MethodChannel
"""

KOTLIN_HANDLER = """
        // === XyCloudStore Updater Channel (DownloadManager + notif progress) ===
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "xycloud/updater")
          .setMethodCallHandler { call, result ->
            when (call.method) {
              "available" -> result.success(true)
              "download" -> {
                try {
                  val url = call.argument<String>("url") ?: ""
                  val title = call.argument<String>("title") ?: "XyCloudStore"
                  // Validasi domain — hanya izinkan xycloud.my.id / api.xycloud.my.id
                  if (!url.contains("xycloud.my.id")) {
                    result.error("INVALID_URL", "URL harus dari xycloud.my.id", null)
                    return@setMethodCallHandler
                  }
                  val dm = getSystemService(DOWNLOAD_SERVICE) as DownloadManager
                  val req = DownloadManager.Request(Uri.parse(url))
                  req.setTitle(title)
                  req.setDescription("Mengunduh pembaruan versi ${call.argument<String>("version") ?: ""}...")
                  req.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                  req.setMimeType("application/vnd.android.package-archive")
                  // Simpan di externalFilesDir/update — aman tanpa storage permission
                  req.setDestinationInExternalFilesDir(this, "update", "xycloud-update.apk")
                  val id = dm.enqueue(req)
                  result.success(id.toString())
                } catch (e: Exception) {
                  result.error("DOWNLOAD_FAILED", e.message, null)
                }
              }
              "status" -> {
                try {
                  val id = call.argument<String>("id")?.toLong() ?: -1L
                  val dm = getSystemService(DOWNLOAD_SERVICE) as DownloadManager
                  val q = DownloadManager.Query().setFilterById(id)
                  dm.query(q).use { c ->
                    if (!c.moveToFirst()) {
                      result.success("unknown")
                      return@setMethodCallHandler
                    }
                    val statusIdx = c.getColumnIndex(DownloadManager.COLUMN_STATUS)
                    when (c.getInt(statusIdx)) {
                      DownloadManager.STATUS_SUCCESSFUL -> result.success("completed")
                      DownloadManager.STATUS_FAILED -> result.success("failed")
                      DownloadManager.STATUS_PAUSED -> result.success("paused")
                      else -> result.success("running")
                    }
                  }
                } catch (e: Exception) {
                  result.success("unknown")
                }
              }
              "install" -> {
                try {
                  val id = call.argument<String>("id")?.toLong() ?: -1L
                  val dm = getSystemService(DOWNLOAD_SERVICE) as DownloadManager
                  val uri = dm.getUriForDownloadedFile(id)
                  val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, "application/vnd.android.package-archive")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
                  }
                  startActivity(intent)
                  result.success(null)
                } catch (e: Exception) {
                  result.error("INSTALL_FAILED", e.message, null)
                }
              }
              else -> result.notImplemented()
            }
          }
        // === End Updater Channel ===
"""

JAVA_IMPORTS = """
import android.app.DownloadManager;
import android.content.Intent;
import android.net.Uri;
import io.flutter.plugin.common.MethodChannel;
"""

JAVA_HANDLER = """
        // === XyCloudStore Updater Channel ===
        new MethodChannel(getFlutterEngine().getDartExecutor().getBinaryMessenger(), "xycloud/updater")
          .setMethodCallHandler((call, result) -> {
            if ("available".equals(call.method)) {
              result.success(true);
            } else if ("download".equals(call.method)) {
              try {
                String url = call.argument("url");
                String title = call.argument("title");
                if (title == null) title = "XyCloudStore";
                if (url == null || !url.contains("xycloud.my.id")) {
                  result.error("INVALID_URL", "URL harus dari xycloud.my.id", null);
                  return;
                }
                DownloadManager dm = (DownloadManager) getSystemService(DOWNLOAD_SERVICE);
                DownloadManager.Request req = new DownloadManager.Request(Uri.parse(url));
                req.setTitle(title);
                req.setDescription("Mengunduh pembaruan...");
                req.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
                req.setMimeType("application/vnd.android.package-archive");
                req.setDestinationInExternalFilesDir(this, "update", "xycloud-update.apk");
                long id = dm.enqueue(req);
                result.success(String.valueOf(id));
              } catch (Exception e) {
                result.error("DOWNLOAD_FAILED", e.getMessage(), null);
              }
            } else if ("status".equals(call.method)) {
              try {
                long id = Long.parseLong((String) call.argument("id"));
                DownloadManager dm = (DownloadManager) getSystemService(DOWNLOAD_SERVICE);
                DownloadManager.Query q = new DownloadManager.Query().setFilterById(id);
                try (android.database.Cursor c = dm.query(q)) {
                  if (!c.moveToFirst()) { result.success("unknown"); return; }
                  int status = c.getInt(c.getColumnIndex(DownloadManager.COLUMN_STATUS));
                  if (status == DownloadManager.STATUS_SUCCESSFUL) result.success("completed");
                  else if (status == DownloadManager.STATUS_FAILED) result.success("failed");
                  else result.success("running");
                }
              } catch (Exception e) { result.success("unknown"); }
            } else if ("install".equals(call.method)) {
              try {
                long id = Long.parseLong((String) call.argument("id"));
                DownloadManager dm = (DownloadManager) getSystemService(DOWNLOAD_SERVICE);
                Uri uri = dm.getUriForDownloadedFile(id);
                Intent intent = new Intent(Intent.ACTION_VIEW);
                intent.setDataAndType(uri, "application/vnd.android.package-archive");
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_GRANT_READ_URI_PERMISSION);
                startActivity(intent);
                result.success(null);
              } catch (Exception e) {
                result.error("INSTALL_FAILED", e.getMessage(), null);
              }
            } else {
              result.notImplemented();
            }
          });
        // === End Updater ===
"""

def find_main_activity(android_dir: Path):
    # Cari MainActivity.kt atau .java
    candidates = list(android_dir.rglob("MainActivity.kt")) + list(android_dir.rglob("MainActivity.java"))
    if not candidates:
        # fallback: cari di app/src/main
        return None
    # Pilih yang paling pendek path (biasanya yang benar)
    candidates.sort(key=lambda p: len(str(p)))
    return candidates[0]

def patch_kotlin(file_path: Path):
    src = file_path.read_text(encoding='utf-8')
    if 'xycloud/updater' in src:
        print(f"Sudah ada updater di {file_path}, dilewati")
        return

    # Tambah imports jika belum
    if 'import android.app.DownloadManager' not in src:
        # sisipkan setelah import terakhir
        if 'import io.flutter.embedding.android.FlutterActivity' in src:
            src = src.replace(
                'import io.flutter.embedding.android.FlutterActivity',
                'import io.flutter.embedding.android.FlutterActivity\n' + KOTLIN_IMPORTS.strip()
            )
        else:
            # fallback: tambah di atas
            src = KOTLIN_IMPORTS + "\n" + src

    # Cari configureFlutterEngine dan sisipkan handler di dalamnya
    # Pola: override fun configureFlutterEngine(...)
    pattern = r"(override fun configureFlutterEngine\([^)]*\)\s*\{)"
    if re.search(pattern, src):
        src = re.sub(
            pattern,
            r"\1\n" + KOTLIN_HANDLER.strip() + "\n",
            src,
            count=1
        )
    else:
        # fallback: cari onCreate atau super
        # sisipkan di akhir kelas sebelum penutup terakhir
        # cari baris terakhir '}'
        if 'MethodChannel' not in src:
            # buat configureFlutterEngine baru
            inject = """
    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
""" + KOTLIN_HANDLER + """
    }
"""
            src = src.replace(
                "class MainActivity",
                "class MainActivity",
                1
            )
            # sisipkan sebelum penutup kelas terakhir
            # cari posisi terakhir }
            last_brace = src.rfind("}")
            src = src[:last_brace] + inject + "\n}\n"

    file_path.write_text(src, encoding='utf-8')
    print(f"Patched Kotlin MainActivity: {file_path}")

def patch_java(file_path: Path):
    src = file_path.read_text(encoding='utf-8')
    if 'xycloud/updater' in src:
        print(f"Sudah ada updater di {file_path}, dilewati")
        return

    if 'import android.app.DownloadManager' not in src:
        if 'import io.flutter.embedding.android.FlutterActivity;' in src:
            src = src.replace(
                'import io.flutter.embedding.android.FlutterActivity;',
                'import io.flutter.embedding.android.FlutterActivity;\n' + JAVA_IMPORTS.strip()
            )
        else:
            src = JAVA_IMPORTS + "\n" + src

    # Cari configureFlutterEngine
    pattern = r"(public void configureFlutterEngine\([^)]*\)\s*\{[^}]*super\.configureFlutterEngine[^;]*;)"
    if re.search(pattern, src, re.DOTALL):
        src = re.sub(
            pattern,
            r"\1\n" + JAVA_HANDLER.strip(),
            src,
            count=1,
            flags=re.DOTALL
        )
    else:
        # fallback inject method baru
        inject = """
    @Override
    public void configureFlutterEngine(io.flutter.embedding.engine.FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
""" + JAVA_HANDLER + """
    }
"""
        last_brace = src.rfind("}")
        src = src[:last_brace] + inject + "\n}\n"

    file_path.write_text(src, encoding='utf-8')
    print(f"Patched Java MainActivity: {file_path}")

def main():
    android_dir = Path(sys.argv[1] if len(sys.argv) > 1 else "android")
    if not android_dir.exists():
        print(f"Folder {android_dir} tidak ditemukan")
        return 1

    main_activity = find_main_activity(android_dir)
    if not main_activity:
        print("MainActivity.kt/java tidak ditemukan di", android_dir)
        print("Pastikan sudah menjalankan `flutter create --platforms=android`")
        return 1

    print(f"Found MainActivity: {main_activity}")

    if main_activity.suffix == ".kt":
        patch_kotlin(main_activity)
    else:
        patch_java(main_activity)

    print("Selesai — updater native siap. Lanjutkan flutter build apk")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
