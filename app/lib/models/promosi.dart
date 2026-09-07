class Promosi {
  const Promosi(
      {required this.id,
      required this.gambar,
      required this.jenis,
      required this.aksi,
      required this.target,
      this.nama = 'Promo',
      this.posisi = 'kanan',
      this.platform = 'semua',
      this.revisi = 1});
  final String id, gambar, jenis, aksi, target, nama, posisi, platform;
  final int revisi;
  String get versiKey => '${id}_$revisi';
  factory Promosi.fromJson(Map<String, dynamic> j) => Promosi(
      id: '${j['id']}',
      gambar: '${j['gambar']}',
      jenis: '${j['jenis']}',
      aksi: '${j['aksi']}',
      target: '${j['target'] ?? ''}',
      nama: '${j['nama'] ?? 'Promo'}',
      posisi: '${j['posisi'] ?? 'kanan'}',
      platform: '${j['platform'] ?? 'semua'}',
      revisi: (j['revisi'] as num?)?.toInt() ?? 1);
}
