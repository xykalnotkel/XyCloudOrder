import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// ============================================================
///  Passkey lokal XyCloudStore (Batch I) — sidik jari / wajah
/// ============================================================
///  Permintaan pemilik: "bisa login dengan paskey / sidik jari".
///  Sesi login tetap tersimpan aman di keystore; biometrik menjadi
///  KUNCI pembuka aplikasi. Ini pola "device-bound passkey":
///  sidik jari/wajah (atau kunci layar perangkat sebagai fallback)
///  membuka sesi tanpa mengetik password lagi.
///
///  Galat platform (tidak ada sensor, kunci layar belum diset, dll.)
///  ditelan dan dilaporkan sebagai "tidak tersedia" supaya aplikasi
///  tidak pernah macet di perangkat lama.
class Biometrik {
  Biometrik._();

  static final LocalAuthentication _auth = LocalAuthentication();

  /// Perangkat punya biometrik terdaftar ATAU setidaknya kunci layar
  /// (PIN/pola) yang bisa dipakai local_auth sebagai fallback.
  static Future<bool> tersedia() async {
    try {
      final bisa = await _auth.canCheckBiometrics;
      final didukung = await _auth.isDeviceSupported();
      if (!bisa && !didukung) return false;
      // Tanpa kunci layar sama sekali, local_auth menolak; anggap tak tersedia.
      return bisa || didukung;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Daftar biometrik yang terdaftar (untuk teks bantuan di pengaturan).
  static Future<List<String>> jenis() async {
    try {
      final daftar = await _auth.getAvailableBiometrics();
      final nama = <String>[];
      for (final b in daftar) {
        if (b == BiometricType.fingerprint) nama.add('Sidik jari');
        if (b == BiometricType.face) nama.add('Wajah');
        if (b == BiometricType.iris) nama.add('Iris');
      }
      return nama;
    } catch (_) {
      return const [];
    }
  }

  /// Minta autentikasi. `stickyAuth` = dialog tetap hidup saat app
  /// ke latar; `sensitiveTransaction` = proteksi ekstra saat pembayaran.
  /// `biometricOnly: false` mengizinkan fallback ke kunci layar perangkat.
  static Future<bool> autentikasi({
    String alasan = 'Verifikasi identitasmu untuk membuka XyCloudStore',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: alasan,
        options: const AuthenticationOptions(
          stickyAuth: true,
          sensitiveTransaction: true,
          biometricOnly: false,
        ),
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
