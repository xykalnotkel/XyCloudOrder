import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Penyimpanan lokal.
///
/// Token login disimpan di penyimpanan terenkripsi bawaan Android
/// (EncryptedSharedPreferences), bukan di preferensi biasa.
class Prefs {
  static const _kOnboarding = 'xy_onboarding_selesai';
  static const _kEmail = 'xy_email_terakhir';
  static const _kToken = 'xy_token';

  static const _aman = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ---------- onboarding ----------
  static Future<bool> onboardingSelesai() async =>
      (await SharedPreferences.getInstance()).getBool(_kOnboarding) ?? false;

  static Future<void> tandaiOnboardingSelesai() async =>
      (await SharedPreferences.getInstance()).setBool(_kOnboarding, true);

  static Future<void> resetOnboarding() async =>
      (await SharedPreferences.getInstance()).remove(_kOnboarding);

  // ---------- email terakhir ----------
  static Future<String?> emailTerakhir() async =>
      (await SharedPreferences.getInstance()).getString(_kEmail);

  static Future<void> simpanEmail(String e) async =>
      (await SharedPreferences.getInstance()).setString(_kEmail, e);

  // ---------- sesi login ----------
  static Future<String?> token() async {
    try {
      return await _aman.read(key: _kToken);
    } catch (_) {
      // perangkat lama kadang gagal membaca keystore; jangan sampai aplikasi mati
      return null;
    }
  }

  static Future<void> simpanToken(String t) async {
    try {
      await _aman.write(key: _kToken, value: t);
    } catch (_) {}
  }

  static Future<void> hapusToken() async {
    try {
      await _aman.delete(key: _kToken);
    } catch (_) {}
  }
}
