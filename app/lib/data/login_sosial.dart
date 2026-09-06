import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import '../core/config.dart';

/// ============================================================
///  Login lewat Google atau Facebook
/// ============================================================
///  Aplikasi membuka halaman izin milik penyedia di browser aman
///  (Custom Tabs). Setelah pengguna menyetujui, server XyCloudStore
///  mengembalikan token lewat tautan `xycloudstore://auth?token=...`
///  yang ditangkap kembali oleh aplikasi.
class LoginSosial {
  LoginSosial._();

  static const String skema = 'xycloudstore';

  /// Mengembalikan token XyCloudStore, atau melempar [GagalLoginSosial].
  static Future<String> masuk(String provider) async {
    final mulai = Uri.parse('${XyConfig.aktif}/api/auth/$provider/start')
        .replace(queryParameters: {'state': DateTime.now().millisecondsSinceEpoch.toString()});

    try {
      final hasil = await FlutterWebAuth2.authenticate(
        url: mulai.toString(),
        callbackUrlScheme: skema,
        options: const FlutterWebAuth2Options(
          preferEphemeral: false,
          timeout: 300,
        ),
      );

      final u = Uri.parse(hasil);
      final token = u.queryParameters['token'];
      final galat = u.queryParameters['error'];

      if (token != null && token.isNotEmpty) return token;
      throw GagalLoginSosial(_pesanRamah(galat ?? 'Login dibatalkan'));
    } on GagalLoginSosial {
      rethrow;
    } catch (e) {
      debugPrint('Login sosial gagal: $e');
      final t = e.toString().toLowerCase();
      if (t.contains('cancel') || t.contains('user_cancel')) {
        throw GagalLoginSosial('Login dibatalkan.');
      }
      throw GagalLoginSosial('Tidak bisa membuka halaman login. Coba lagi atau pakai email.');
    }
  }

  static String _pesanRamah(String kode) {
    if (kode.contains('access_denied') || kode.contains('dibatalkan')) return 'Login dibatalkan.';
    if (kode.contains('redirect_uri_mismatch')) {
      return 'Alamat callback belum terdaftar di konsol penyedia. Hubungi admin.';
    }
    return kode;
  }
}

class GagalLoginSosial implements Exception {
  GagalLoginSosial(this.pesan);
  final String pesan;
  @override
  String toString() => pesan;
}
