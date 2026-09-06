import 'package:shared_preferences/shared_preferences.dart';

/// Penyimpanan lokal sederhana.
class Prefs {
  static const _kOnboarding = 'xy_onboarding_selesai';
  static const _kEmail = 'xy_email_terakhir';

  static Future<bool> onboardingSelesai() async =>
      (await SharedPreferences.getInstance()).getBool(_kOnboarding) ?? false;

  static Future<void> tandaiOnboardingSelesai() async =>
      (await SharedPreferences.getInstance()).setBool(_kOnboarding, true);

  static Future<void> resetOnboarding() async =>
      (await SharedPreferences.getInstance()).remove(_kOnboarding);

  static Future<String?> emailTerakhir() async =>
      (await SharedPreferences.getInstance()).getString(_kEmail);

  static Future<void> simpanEmail(String e) async =>
      (await SharedPreferences.getInstance()).setString(_kEmail, e);
}
