/// Konfigurasi endpoint XyCloud.
///
/// Ganti [baseUrl] dengan domain Cloudflare Worker milikmu, misalnya:
///   https://api.xycloud.my.id
/// atau  https://xycloud-api.<akun>.workers.dev
///
/// Bisa juga di-override saat build:
///   flutter build apk --dart-define=XY_BASE_URL=https://api.xycloud.id
class XyConfig {
  static const String baseUrl = String.fromEnvironment(
    'XY_BASE_URL',
    defaultValue: 'https://api.xycloud.my.id',
  );

  /// Kalau true, app jalan tanpa server (data dummy) — enak buat demo/UI test.
  static const bool useMock = bool.fromEnvironment(
    'XY_MOCK',
    defaultValue: false,
  );

  /// Alamat yang sedang dipakai. Otomatis pindah ke [baseUrlCadangan]
  /// kalau domain utama tidak bisa dihubungi.
  static String aktif = baseUrl;

  static bool _sudahPindah = false;

  /// Pindah ke alamat cadangan sekali saja. Mengembalikan true kalau berhasil pindah.
  static bool pindahKeCadangan() {
    if (_sudahPindah || baseUrlCadangan.isEmpty || baseUrlCadangan == aktif) return false;
    aktif = baseUrlCadangan;
    _sudahPindah = true;
    return true;
  }

  static String get apiUrl => '$aktif/api';

  /// WebSocket realtime (Cloudflare Durable Object).
  static String wsUrl(String room, String token) {
    final ws = aktif.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
    return '$ws/ws/$room?token=$token';
  }

  static const String appName = 'XyCloudStore';

  /// Kalau domain utama bermasalah, aplikasi otomatis pindah ke alamat cadangan.
  static const String baseUrlCadangan = String.fromEnvironment(
    'XY_BASE_URL_FALLBACK',
    defaultValue: 'https://xycloud-api.akuntiktok76y.workers.dev',
  );
  static const String waCs = '6281234567890'; // fallback CS WhatsApp
}
