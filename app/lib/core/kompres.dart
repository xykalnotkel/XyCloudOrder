import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Kompresi gambar sebelum diunggah — permintaan 2026-09-14:
/// "compres semuanya agar super duper cepat".
///
/// Semua lampiran (chat CS, DM, foto profil, forum, ulasan, bukti top up)
/// diubah ke WebP berkualitas baik sehingga unggahan jauh lebih kecil dan
/// cepat, hemat kuota pengguna, dan hemat penyimpanan CDN.
/// GIF animasi TIDAK disentuh supaya tetap bergerak.
class Kompres {
  Kompres._();

  /// bytes + nama berkas asal → dataUri siap kirim.
  /// Kalau konversi WebP gagal (perangkat aneh) atau hasilnya malah lebih
  /// besar, bytes asli dipakai dengan mime berdasar ekstensi.
  static Future<String> dataUri(
    Uint8List bytes,
    String namaBerkas, {
    int maxSisi = 1400,
    int kualitas = 72,
  }) async {
    final nama = namaBerkas.toLowerCase();
    if (nama.endsWith('.gif')) {
      return 'data:image/gif;base64,${base64Encode(bytes)}';
    }

    Uint8List hasil = bytes;
    String mime = nama.endsWith('.png')
        ? 'image/png'
        : nama.endsWith('.webp')
            ? 'image/webp'
            : 'image/jpeg';

    try {
      final webp = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: maxSisi,
        minHeight: maxSisi,
        quality: kualitas,
        format: CompressFormat.webp,
      );
      if (webp.isNotEmpty && webp.length < bytes.length) {
        hasil = webp;
        mime = 'image/webp';
      }
    } catch (_) {
      // biarkan bytes asli
    }
    return 'data:$mime;base64,${base64Encode(hasil)}';
  }
}
