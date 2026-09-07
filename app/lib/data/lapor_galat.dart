import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../core/config.dart';

/// ============================================================
///  Pelaporan galat aplikasi
/// ============================================================
///  Kalau ada yang error di HP pengguna, laporannya dikirim diam-diam
///  ke server sendiri supaya bisa dilihat di dashboard admin.
///  Tidak memakai layanan pihak ketiga dan tidak mengirim data pribadi
///  selain id pengguna yang sedang masuk.
class LaporGalat {
  LaporGalat._();

  static String? _versi;
  static String? _perangkat;
  static String? _android;
  static String? userId;
  static String? layarSekarang;

  /// Simpan galat yang sama sebentar supaya tidak dikirim berulang.
  static final Map<String, DateTime> _terakhir = {};

  static Future<void> siapkan() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _versi = info.version;
    } catch (_) {}
    try {
      _perangkat = Platform.operatingSystem;
      _android = Platform.operatingSystemVersion;
    } catch (_) {}
  }

  /// Pasang penangkap galat global. Bungkus runApp dengan ini.
  static void pasang(void Function() jalankanAplikasi) {
    runZonedGuarded(() {
      FlutterError.onError = (rincian) {
        FlutterError.presentError(rincian);
        kirim(rincian.exceptionAsString(), rincian.stack?.toString());
      };
      PlatformDispatcher.instance.onError = (galat, jejak) {
        kirim(galat.toString(), jejak.toString());
        return true;
      };
      jalankanAplikasi();
    }, (galat, jejak) => kirim(galat.toString(), jejak.toString()));
  }

  /// Kirim satu laporan. Gagal kirim tidak pernah mengganggu pengguna.
  static Future<void> kirim(String pesan, [String? jejak]) async {
    if (pesan.trim().isEmpty) return;

    final kunci = pesan.length > 120 ? pesan.substring(0, 120) : pesan;
    final sebelumnya = _terakhir[kunci];
    if (sebelumnya != null && DateTime.now().difference(sebelumnya).inMinutes < 10) return;
    _terakhir[kunci] = DateTime.now();

    if (kDebugMode) {
      debugPrint('Galat dilaporkan: $pesan');
    }

    try {
      await http
          .post(
            Uri.parse('${XyConfig.apiUrl}/galat'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'pesan': pesan.length > 400 ? pesan.substring(0, 400) : pesan,
              'jejak': (jejak ?? '').length > 2000 ? jejak!.substring(0, 2000) : jejak,
              'layar': layarSekarang,
              'versi': _versi,
              'perangkat': _perangkat,
              'android': _android,
              'user_id': userId,
            }),
          )
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      // sengaja diabaikan, laporan galat tidak boleh bikin galat baru
    }
  }
}
