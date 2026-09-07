import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

/// ============================================================
///  Notifikasi push (OneSignal)
/// ============================================================
///  Dipakai supaya pemberitahuan order, balasan CS, dan promo
///  tetap masuk walau aplikasi sedang tertutup.
///
///  Catatan penting: push Android baru benar-benar terkirim setelah
///  kredensial Firebase (FCM v1 Service Account JSON) diunggah ke
///  dashboard OneSignal. Sebelum itu, kode ini tetap aman berjalan.
class PushService {
  PushService._();

  static const String appId = String.fromEnvironment(
    'XY_ONESIGNAL_APP_ID',
    defaultValue: 'f4843c35-cc1d-4772-9f70-1c4349397ffb',
  );

  static bool _siap = false;

  /// Dipanggil saat pengguna mengetuk notifikasi. Diisi oleh aplikasi
  /// supaya bisa membuka halaman yang sesuai.
  static void Function(Map<String, dynamic> data)? saatDiketuk;

  /// Notifikasi yang diketuk sebelum aplikasi siap menampilkan halaman.
  static Map<String, dynamic>? tertunda;

  /// Dipanggil sekali saat aplikasi mulai.
  static Future<void> mulai() async {
    if (_siap || appId.isEmpty) return;
    try {
      OneSignal.Debug.setLogLevel(OSLogLevel.none);
      OneSignal.initialize(appId);

      OneSignal.Notifications.addClickListener((peristiwa) {
        final tambahan = peristiwa.notification.additionalData ?? const {};
        final data = Map<String, dynamic>.from(tambahan);
        if (saatDiketuk != null) {
          saatDiketuk!(data);
        } else {
          tertunda = data;
        }
      });

      _siap = true;
    } catch (e) {
      debugPrint('OneSignal gagal dimulai: $e');
    }
  }

  /// Minta izin notifikasi ke pengguna (Android 13 ke atas wajib).
  static Future<void> mintaIzin() async {
    if (!_siap) return;
    try {
      await OneSignal.Notifications.requestPermission(true);
    } catch (e) {
      debugPrint('Izin notifikasi gagal: $e');
    }
  }

  /// Kaitkan perangkat dengan id pengguna supaya server bisa mengirim
  /// notifikasi ke orang yang tepat.
  static Future<void> masuk(String userId) async {
    if (!_siap) await mulai();
    if (!_siap) return;
    try {
      await OneSignal.login(userId);
      await mintaIzin();
    } catch (e) {
      debugPrint('OneSignal login gagal: $e');
    }
  }

  static Future<void> keluar() async {
    if (!_siap) return;
    try {
      await OneSignal.logout();
    } catch (e) {
      debugPrint('OneSignal logout gagal: $e');
    }
  }
}
