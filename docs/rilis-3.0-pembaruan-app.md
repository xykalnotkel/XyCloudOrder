# Pembaruan aplikasi (v3.0) — popup rilis + unduh dengan notifikasi

Fitur sisi Flutter sudah ditulis. Bagian unduh APK **dengan notifikasi progress yang
tetap berjalan walau app ditutup** memakai sistem `DownloadManager` Android lewat
MethodChannel `xycloud/updater`. Folder `app/android/` digenerate saat build (tidak
di-commit), jadi kode native di bawah perlu disuntikkan lewat helper build kamu
(mirip `tools/siapkan_streaming.py` / `patch_manifest.py`).

## Ringkasan alur
1. App menjalankan `periksaPembaruan()` di latar saat start.
2. Server `/api/rilis` mengembalikan `gambar` (banner kustom per rilis, opsional)
   + daftar berkas APK (`/unduh/…`). Kolom `gambar` baru di tabel `rilis`
   (migrasi `0004_rilis_gambar_pembaruan.sql`).
3. Jika versi server > versi terpasang → **popup rilis** (`rilis_popup.dart`) muncul
   otomatis (aman sekali per sesi). Tombol **X** → buka `PembaruanScreen`.
4. `PembaruanScreen` menampilkan gambar rilis (murni) + catatan + tombol
   "Perbarui Sekarang".
5. Tombol itu memanggil `PembaruanChannel.unduh()` → native `DownloadManager`
   mengunduh APK, menampilkan **notifikasi progress**, dan terus jalan walau app
   ditutup. Selesai → notifikasi "ketuk untuk pasang".

## File Flutter baru
- `app/lib/data/pembaruan_channel.dart` — MethodChannel `xycloud/updater`.
- `app/lib/ui/widgets/morph_bg.dart` — latar elemen melayang (blur) beranimasi.
- `app/lib/ui/widgets/rilis_popup.dart` — popup banner rilis.
- `app/lib/ui/screens/pembaruan_screen.dart` — layar pembaruan & unduh.
- Integrasi: `app_state.dart` (flag popup), `shell.dart` (auto-tampil), `pengaturan_screen.dart`.

## Kode native Android (tambahkan pada build)
Di dalam kelas utama (mis. setelah `configureFlutterEngine`), pasang handler:

```kotlin
// MainActivity / FlutterActivity — tambahkan setelah configureFlutterEngine
MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "xycloud/updater")
  .setMethodCallHandler { call, result ->
    when (call.method) {
      "available" -> result.success(true)
      "download" -> {
        val url = call.argument<String>("url")
        val title = call.argument<String>("title") ?: "XyCloudStore"
        val dm = getSystemService(DOWNLOAD_SERVICE) as DownloadManager
        val req = DownloadManager.Request(Uri.parse(url))
        req.setTitle(title)
        req.setDescription("Mengunduh pembaruan…")
        req.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
        req.setDestinationInExternalFilesDir(this, "update", "xycloud-update.apk")
        result.success(dm.enqueue(req).toString())
      }
      "status" -> {
        val id = call.argument<String>("id")?.toLong() ?: -1L
        val dm = getSystemService(DOWNLOAD_SERVICE) as DownloadManager
        val q = DownloadManager.Query().setFilterById(id)
        dm.query(q).use { c ->
          if (!c.moveToFirst()) { result.success("unknown"); return@setMethodCallHandler }
          when (c.getInt(c.getColumnIndex(DownloadManager.COLUMN_STATUS))) {
            DownloadManager.STATUS_SUCCESSFUL -> result.success("completed")
            DownloadManager.STATUS_FAILED -> result.success("failed")
            else -> result.success("running")
          }
        }
      }
      "install" -> {
        val id = call.argument<String>("id")?.toLong() ?: -1L
        val dm = getSystemService(DOWNLOAD_SERVICE) as DownloadManager
        val uri = dm.getUriForDownloadedFile(id)
        val i = Intent(Intent.ACTION_VIEW).apply {
          setDataAndType(uri, "application/vnd.android.package-archive")
          addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(i)
        result.success(null)
      }
      else -> result.notImplemented()
    }
  }
```

Manifest/permission yang perlu ada:
```xml
<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>
```
(Untuk Android 10+ target, `DownloadManager` tidak butuh izin penyimpanan bila memakai
`setDestinationInExternalFilesDir`.)

> Catatan keamanan: aplikasi akan menimpa dirinya sendiri — pastikan APK yang diunduh
> memakai kunci penandatanganan yang SAMA dengan versi terpasang, dan cek
> `url` selalu berasal dari `xycloud.my.id` sebelum mengunduh (sudah dipatok di Flutter).

## Cara uji (harus di perangkat, oleh pemilik)
1. `cd app && flutter pub get`
2. Suntik kode native di atas ke `android/` yang digenerate, lalu
   `flutter analyze` & `flutter build apk --release`.
3. Pasang APK lama, naikkan `version` rilis server → buka app → popup muncul.
4. Tekan X → layar pembaruan → "Perbarui Sekarang" → cek notifikasi progress,
   tutup app saat mengunduh → notif tetap jalan → selesai → pasang.

Fitur ini **tidak boleh di-release** sebelum langkah uji di atas lolos (lihat juga
panduan rilis & izin pemilik di `rencana-3.0.md`).
