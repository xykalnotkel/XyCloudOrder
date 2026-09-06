/// Konfigurasi endpoint XyCloud.
///
/// Ganti [baseUrl] dengan domain Cloudflare Worker milikmu, misalnya:
///   https://api.xycloud.id
/// atau  https://xycloud-api.<akun>.workers.dev
///
/// Bisa juga di-override saat build:
///   flutter build apk --dart-define=XY_BASE_URL=https://api.xycloud.id
class XyConfig {
  static const String baseUrl = String.fromEnvironment(
    'XY_BASE_URL',
    defaultValue: 'https://xycloud-api.akuntiktok76y.workers.dev',
  );

  /// Kalau true, app jalan tanpa server (data dummy) — enak buat demo/UI test.
  static const bool useMock = bool.fromEnvironment(
    'XY_MOCK',
    defaultValue: false,
  );

  static String get apiUrl => '$baseUrl/api';

  /// WebSocket realtime (Cloudflare Durable Object).
  static String wsUrl(String room, String token) {
    final ws = baseUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
    return '$ws/ws/$room?token=$token';
  }

  static const String appName = 'XyCloudOrder';
  static const String waCs = '6281234567890'; // fallback CS WhatsApp
}
