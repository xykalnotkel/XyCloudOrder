import 'package:flutter/services.dart';

/// ============================================================
///  PembaruanChannel — jalur unduh APK dengan notifikasi progress
/// ============================================================
///  Alur pada perangkat Android yang sudah dipasangi adapter native
///  (lihat docs/rilis-3.0-pembaruan-app.md):
///    1) App memanggil `unduh(urlApk)`.
///    2) Native (Android DownloadManager) mengunduh ke penyimpanan,
///       menampilkan notifikasi progress, dan TETAP jalan walau app
///       ditutup. Id unduhan dikembalikan untuk cek status/menginstal.
///    3) Saat selesai, native menampilkan notif "ketuk untuk pasang"
///       (pakai FileProvider + ACTION_VIEW) + REQUEST_INSTALL_PACKAGES.
///
///  Kalau adapter native belum terpasang (mis. masih development tanpa
///  android/), channel tak tersedia -> fallback aman: `tersedia` = false
///  dan pemanggil bisa memakai [fallbackUrl] (halaman unduh web).
class PembaruanChannel {
  static const _ch = MethodChannel('xycloud/updater');

  /// Benar kalau perangkat menjalankan adapter unduhan native.
  static Future<bool> tersedia() async {
    try {
      return await _ch.invokeMethod<bool>('available') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Mulai unduh APK dari [url]. Kembalikan id unduhan (string) atau null.
  /// [judul]/[versi] dipakai untuk label notifikasi.
  static Future<String?> unduh({
    required String url,
    required String judul,
    String versi = '',
  }) async {
    try {
      final r = await _ch.invokeMethod<String?>('download', {
        'url': url,
        'title': judul,
        'version': versi,
      });
      return r;
    } catch (_) {
      return null;
    }
  }

  /// Status unduhan id [id]: 'running' | 'completed' | 'failed' | 'unknown'.
  static Future<String> status(String id) async {
    try {
      return (await _ch.invokeMethod<String>('status', {'id': id})) ??
          'unknown';
    } catch (_) {
      return 'unknown';
    }
  }

  /// Minta native memunculkan dialog pasang untuk unduhan yang selesai.
  static Future<void> pasang(String id) async {
    try {
      await _ch.invokeMethod('install', {'id': id});
    } catch (_) {}
  }
}
