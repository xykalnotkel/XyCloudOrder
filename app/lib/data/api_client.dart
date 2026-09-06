import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';

class ApiException implements Exception {
  final int status;
  final String pesan;
  ApiException(this.status, this.pesan);
  @override
  String toString() => 'ApiException($status): $pesan';
}

/// Client HTTP ke Cloudflare Worker XyCloud.
class ApiClient {
  ApiClient({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;
  String? _token;

  String? get token => _token;
  void setToken(String? t) => _token = t;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _uri(String path, [Map<String, dynamic>? q]) =>
      Uri.parse('${XyConfig.apiUrl}$path').replace(
        queryParameters: q?.map((k, v) => MapEntry(k, '$v')),
      );

  /// Jalankan permintaan; kalau jaringan gagal, coba sekali lagi lewat alamat cadangan.
  Future<dynamic> _coba(Future<http.Response> Function() aksi) async {
    try {
      return _parse(await aksi());
    } on ApiException {
      rethrow;
    } catch (e) {
      if (XyConfig.pindahKeCadangan()) return _parse(await aksi());
      rethrow;
    }
  }

  Future<dynamic> get(String path, [Map<String, dynamic>? q]) =>
      _coba(() => _http.get(_uri(path, q), headers: _headers).timeout(const Duration(seconds: 20)));

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) => _coba(() => _http
      .post(_uri(path), headers: _headers, body: jsonEncode(body ?? {}))
      .timeout(const Duration(seconds: 20)));

  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) => _coba(() => _http
      .patch(_uri(path), headers: _headers, body: jsonEncode(body ?? {}))
      .timeout(const Duration(seconds: 20)));

  dynamic _parse(http.Response r) {
    final body = r.body.isEmpty ? {} : jsonDecode(r.body);
    if (r.statusCode >= 200 && r.statusCode < 300) {
      if (body is Map && body['data'] != null) return body['data'];
      return body;
    }
    final msg = (body is Map ? body['error'] ?? body['message'] : null) ?? 'Terjadi kesalahan';
    throw ApiException(r.statusCode, '$msg');
  }

  void dispose() => _http.close();
}
