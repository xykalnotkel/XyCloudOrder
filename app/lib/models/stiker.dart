import 'dart:convert';
import 'dart:typed_data';

class Stiker {
  const Stiker(
      {this.url = '',
      this.mime = 'image/webp',
      this.nama = 'Stiker',
      this.sumber = 'galeri',
      this.sumberUrl = ''});
  final String url, mime, nama, sumber, sumberUrl;
  bool get dariGiphy => sumber == 'giphy';
  factory Stiker.fromJson(Map<String, dynamic> j) => Stiker(
      url: '${j['url'] ?? ''}',
      mime: '${j['mime'] ?? 'image/webp'}',
      nama: '${j['nama'] ?? 'Stiker'}',
      sumber: '${j['sumber'] ?? 'galeri'}',
      sumberUrl: '${j['sumber_url'] ?? ''}');
  Map<String, dynamic> toJson() => {
        'url': url,
        'mime': mime,
        'nama': nama,
        'sumber': sumber,
        'sumber_url': sumberUrl
      };
  static Stiker? baca(dynamic v) {
    try {
      if (v is String) v = jsonDecode(v);
      return v is Map && v['url'] != null
          ? Stiker.fromJson(Map<String, dynamic>.from(v))
          : null;
    } catch (_) {
      return null;
    }
  }
}

class PilihanStiker {
  const PilihanStiker(this.stiker, {this.bytes});
  final Stiker stiker;
  final Uint8List? bytes;
  Map<String, dynamic> toPayload() => {
        ...stiker.toJson(),
        if (stiker.url.isEmpty && bytes != null)
          'data_uri': 'data:${stiker.mime};base64,${base64Encode(bytes!)}',
      };
}

class StikerLokal {
  const StikerLokal(this.id, this.stiker);
  final String id;
  final Stiker stiker;
  Map<String, dynamic> toJson() => {'id': id, 'stiker': stiker.toJson()};
  factory StikerLokal.fromJson(Map<String, dynamic> j) => StikerLokal(
      '${j['id']}', Stiker.fromJson(Map<String, dynamic>.from(j['stiker'])));
}
