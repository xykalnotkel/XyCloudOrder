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
  static const _kSaldoTampil = 'xy_saldo_tampil';
  static const _kSaringKonten = 'xy_saring_konten';
  static const _kTema = 'xy_tema';

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

  // ---------- tampilan saldo ----------
  static Future<bool> saldoTampil() async =>
      (await SharedPreferences.getInstance()).getBool(_kSaldoTampil) ?? true;

  static Future<void> simpanSaldoTampil(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kSaldoTampil, v);

  // ---------- saringan konten ----------
  static Future<bool> saringKonten() async =>
      (await SharedPreferences.getInstance()).getBool(_kSaringKonten) ?? true;

  static Future<void> simpanSaringKonten(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kSaringKonten, v);

  // ---------- tema tampilan ----------
  /// sistem | terang | gelap
  static Future<String> tema() async =>
      (await SharedPreferences.getInstance()).getString(_kTema) ?? 'terang';

  static Future<void> simpanTema(String v) async =>
      (await SharedPreferences.getInstance()).setString(_kTema, v);

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
