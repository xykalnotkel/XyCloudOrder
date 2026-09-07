import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// AES-256-GCM: nonce acak 96-bit + tag autentikasi 128-bit + ciphertext.
/// Metadata dan media memakai format yang sama. Tidak ada fallback plaintext.
class StikerCipher {
  static final _aes = AesGcm.with256bits();
  static Future<Uint8List> kunciBaru() async =>
      Uint8List.fromList(await (await _aes.newSecretKey()).extractBytes());
  static Future<Uint8List> enkripsi(List<int> data, List<int> kunci) async {
    final box = await _aes.encrypt(data, secretKey: SecretKey(kunci));
    return Uint8List.fromList(
        [...box.nonce, ...box.mac.bytes, ...box.cipherText]);
  }

  static Future<Uint8List> dekripsi(List<int> data, List<int> kunci) async {
    if (data.length < 28) throw const FormatException('Koleksi stiker rusak.');
    final box = SecretBox(data.sublist(28),
        nonce: data.sublist(0, 12), mac: Mac(data.sublist(12, 28)));
    return Uint8List.fromList(
        await _aes.decrypt(box, secretKey: SecretKey(kunci)));
  }
}
