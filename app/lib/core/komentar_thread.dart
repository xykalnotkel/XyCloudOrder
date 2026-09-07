import '../models/models.dart';

class BarisKomentar {
  const BarisKomentar(
      this.komentar, this.kedalaman, this.lanjutan, this.punyaAnak);
  final ForumBalasan komentar;
  final int kedalaman;
  final List<bool> lanjutan;
  final bool punyaAnak;
}

/// Susun thread berurutan, tahan parent hilang/siklus dari data lama.
List<BarisKomentar> susunKomentar(List<ForumBalasan> data) {
  final ids = data.map((x) => x.id).toSet();
  final anak = <String?, List<ForumBalasan>>{};
  for (final b in data) {
    final parent =
        b.balasKe != b.id && ids.contains(b.balasKe) ? b.balasKe : null;
    anak.putIfAbsent(parent, () => []).add(b);
  }
  final hasil = <BarisKomentar>[], seen = <String>{};
  void jalan(ForumBalasan b, int depth, List<bool> garis) {
    if (!seen.add(b.id)) return;
    final children = anak[b.id] ?? [];
    hasil.add(
        BarisKomentar(b, depth, List.unmodifiable(garis), children.isNotEmpty));
    for (var i = 0; i < children.length; i++) {
      jalan(children[i], depth + 1, [...garis, i < children.length - 1]);
    }
  }

  for (final b in anak[null] ?? <ForumBalasan>[]) {
    jalan(b, 0, []);
  }
  for (final b in data) {
    if (!seen.contains(b.id)) jalan(b, 0, []);
  }
  return hasil;
}
