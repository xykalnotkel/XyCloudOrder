import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../core/stiker_cipher.dart';
import '../models/stiker.dart';

/// Koleksi per akun, disimpan terenkripsi di application support, bukan galeri.
/// Sumber galeri milik pengguna tidak dihapus/diubah. Preview hanya didekripsi di RAM.
class StikerStore {
  StikerStore._(String akun)
      : _id = sha256.convert(utf8.encode(akun)).toString();
  static final _stores = <String, StikerStore>{};
  static StikerStore untuk(String akun) =>
      _stores.putIfAbsent(akun, () => StikerStore._(akun));
  static const batasBytes = 2 * 1024 * 1024;
  static const _secure = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true));
  final String _id;
  Directory? _dir;
  Uint8List? _key;
  Future<void>? _initializing;
  Future<void> _queue = Future.value();
  List<StikerLokal> _items = [];
  String get _keyName => 'xy_stiker_key_$_id';

  Future<void> _siap() => _initializing ??= _buka();
  Future<void> _buka() async {
    _dir = Directory(
        '${(await getApplicationSupportDirectory()).path}/xy_stiker/$_id');
    await _dir!.create(recursive: true);
    final saved = await _secure.read(key: _keyName);
    if (saved != null) {
      _key = base64Decode(saved);
    } else {
      if (await File('${_dir!.path}/index.xys').exists())
        throw const FormatException(
            'Kunci koleksi lokal tidak tersedia pada perangkat ini.');
      _key = await StikerCipher.kunciBaru();
      await _secure.write(key: _keyName, value: base64Encode(_key!));
    }
    final index = File('${_dir!.path}/index.xys');
    if (await index.exists()) {
      final json = jsonDecode(utf8.decode(
              await StikerCipher.dekripsi(await index.readAsBytes(), _key!)))
          as List;
      _items = json
          .map((x) => StikerLokal.fromJson(Map<String, dynamic>.from(x)))
          .toList();
    }
  }

  Future<T> _urut<T>(Future<T> Function() work) {
    final c = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        c.complete(await work());
      } catch (e, st) {
        c.completeError(e, st);
      }
    });
    return c.future;
  }

  Future<void> _tulis(String nama, List<int> data) async {
    final tmp = File('${_dir!.path}/$nama.tmp');
    await tmp.writeAsBytes(await StikerCipher.enkripsi(data, _key!),
        flush: true);
    await tmp.rename('${_dir!.path}/$nama');
  }

  Future<void> _index() => _tulis('index.xys',
      utf8.encode(jsonEncode(_items.map((x) => x.toJson()).toList())));
  Future<List<StikerLokal>> daftar() async {
    await _siap();
    await _queue;
    return List.unmodifiable(_items);
  }

  Future<Uint8List> baca(StikerLokal item) async {
    await _siap();
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(item.id))
      throw const FormatException('ID stiker tidak valid.');
    return StikerCipher.dekripsi(
        await File('${_dir!.path}/${item.id}.xys').readAsBytes(), _key!);
  }

  Future<StikerLokal> simpan(Stiker sticker, {Uint8List? bytes}) =>
      _urut(() async {
        await _siap();
        bytes ??= await unduh(sticker.url);
        if (bytes!.length > batasBytes)
          throw const FormatException('Stiker maksimal 2 MB.');
        final id = sha256.convert(bytes!).toString();
        final ada = _items.where((x) => x.id == id);
        if (ada.isNotEmpty) return ada.first;
        if (_items.length >= 100)
          throw const FormatException(
              'Koleksi penuh (100 stiker). Hapus beberapa stiker dahulu.');
        final item = StikerLokal(id, sticker);
        await _tulis('$id.xys', bytes!);
        _items.insert(0, item);
        try {
          await _index();
        } catch (_) {
          _items.remove(item);
          rethrow;
        }
        return item;
      });
  Future<void> hapus(StikerLokal item) => _urut(() async {
        await _siap();
        _items.removeWhere((x) => x.id == item.id);
        await _index();
        final file = File('${_dir!.path}/${item.id}.xys');
        if (await file.exists()) await file.delete();
      });
  Future<void> hapusSemua() => _urut(() async {
        final dir = _dir ??
            Directory(
                '${(await getApplicationSupportDirectory()).path}/xy_stiker/$_id');
        if (await dir.exists()) await dir.delete(recursive: true);
        await _secure.delete(key: _keyName);
        _items = [];
        _key = null;
        _initializing = null;
      });

  static Future<Uint8List> unduh(String value) async {
    final u = Uri.tryParse(value);
    if (u == null ||
        u.scheme != 'https' ||
        !(u.host == 'res.cloudinary.com' ||
            RegExp(r'^(media\d*|i)\.giphy\.com$').hasMatch(u.host)))
      throw const FormatException('Alamat stiker tidak didukung.');
    final client = http.Client();
    try {
      final r = await client
          .send(http.Request('GET', u)..followRedirects = false)
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200)
        throw const HttpException('Gagal mengunduh stiker.');
      if ((r.contentLength ?? 0) > batasBytes)
        throw const FormatException('Stiker maksimal 2 MB.');
      final b = BytesBuilder();
      await for (final chunk in r.stream.timeout(const Duration(seconds: 20))) {
        if (b.length + chunk.length > batasBytes)
          throw const FormatException('Stiker maksimal 2 MB.');
        b.add(chunk);
      }
      final data = b.takeBytes();
      if (format(data) == null)
        throw const FormatException('Alamat ini tidak berisi gambar stiker.');
      return data;
    } finally {
      client.close();
    }
  }

  static String? format(Uint8List b) {
    if (b.length < 12) return null;
    final s = String.fromCharCodes(b.take(12));
    if (s.startsWith('GIF87a') || s.startsWith('GIF89a')) return 'image/gif';
    if (s.startsWith('RIFF') && s.substring(8, 12) == 'WEBP')
      return 'image/webp';
    if (b[0] == 137 && s.substring(1, 4) == 'PNG') return 'image/png';
    if (b[0] == 255 && b[1] == 216 && b[2] == 255) return 'image/jpeg';
    return null;
  }

  static Future<PilihanStiker> dariGaleri(Uint8List bytes) async {
    if (bytes.length > 8 * 1024 * 1024)
      throw const FormatException('Gambar asal maksimal 8 MB.');
    var mime = format(bytes);
    if (mime == null)
      throw const FormatException('Pilih PNG, JPG, GIF, atau WebP.');
    if (mime == 'image/jpeg' || mime == 'image/png') {
      bytes = await FlutterImageCompress.compressWithList(bytes,
          minWidth: 512,
          minHeight: 512,
          quality: 85,
          format: CompressFormat.webp);
      mime = 'image/webp';
    }
    if (bytes.length > batasBytes)
      throw const FormatException(
          'Animasi terlalu besar. Gunakan stiker di bawah 2 MB.');
    return PilihanStiker(Stiker(mime: mime), bytes: bytes);
  }
}
