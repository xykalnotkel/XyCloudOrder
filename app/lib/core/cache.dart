import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// ============================================================
///  Singgahan lokal (cache)
/// ============================================================
///  Menyimpan data terakhir yang berhasil diambil dari server supaya:
///   - aplikasi langsung menampilkan isi saat dibuka, tanpa layar kosong
///   - tetap bisa dilihat ketika sedang tidak ada internet
///   - hemat kuota, karena tidak semua layar perlu memuat ulang
class Cache {
  Cache._();

  static const _awalan = 'xy_cache_';
  static const _kHematData = 'xy_hemat_data';

  /// Umur wajar sebuah singgahan sebelum dianggap basi.
  static const Duration umurWajar = Duration(minutes: 10);

  static Future<void> simpan(String kunci, Object data) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(
        '$_awalan$kunci',
        jsonEncode({'waktu': DateTime.now().toIso8601String(), 'data': data}),
      );
    } catch (_) {}
  }

  /// Mengembalikan {'data': ..., 'umur': Duration} atau null.
  static Future<Map<String, dynamic>?> baca(String kunci) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final t = sp.getString('$_awalan$kunci');
      if (t == null) return null;
      final j = jsonDecode(t) as Map<String, dynamic>;
      final waktu = DateTime.tryParse('${j['waktu']}') ?? DateTime.now();
      return {'data': j['data'], 'umur': DateTime.now().difference(waktu)};
    } catch (_) {
      return null;
    }
  }

  static Future<List<dynamic>> daftar(String kunci) async {
    final c = await baca(kunci);
    final d = c?['data'];
    return d is List ? d : const [];
  }

  static Future<void> bersihkan() async {
    try {
      final sp = await SharedPreferences.getInstance();
      for (final k in sp.getKeys().where((k) => k.startsWith(_awalan)).toList()) {
        await sp.remove(k);
      }
    } catch (_) {}
  }

  /// Perkiraan ukuran singgahan dalam kilobita.
  static Future<int> ukuranKb() async {
    try {
      final sp = await SharedPreferences.getInstance();
      var total = 0;
      for (final k in sp.getKeys().where((k) => k.startsWith(_awalan))) {
        total += (sp.getString(k) ?? '').length;
      }
      return (total / 1024).ceil();
    } catch (_) {
      return 0;
    }
  }

  // ---------- mode hemat data ----------
  static Future<bool> hematData() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_kHematData) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setHematData(bool nilai) async {
    try {
      await (await SharedPreferences.getInstance()).setBool(_kHematData, nilai);
    } catch (_) {}
  }
}
