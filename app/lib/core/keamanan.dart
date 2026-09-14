import 'package:flutter/services.dart';

/// Mode privasi: memasang FLAG_SECURE Android lewat channel native.
/// Handler-nya disuntik ke MainActivity saat build CI oleh
/// tools/siapkan_keamanan.py. Kalau aktif, tangkapan layar dan
/// perekaman layar menghasilkan gambar hitam — saldo, chat, dan
/// kredensial tidak bisa dicuri lewat screenshot.
class Keamanan {
  Keamanan._();

  static const _ch = MethodChannel('xycloud/keamanan');

  static Future<void> setelPrivasi(bool aktif) async {
    try {
      await _ch.invokeMethod<bool>('setFlagSecure', {'aktif': aktif});
    } catch (_) {
      // Channel tidak tersedia (platform lain / APK lama) — abaikan diam-diam.
    }
  }
}
