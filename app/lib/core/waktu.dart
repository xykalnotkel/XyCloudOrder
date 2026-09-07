DateTime tanggalServer(dynamic value) {
  var raw = '${value ?? ''}'.trim().replaceFirst(' ', 'T');
  if (raw.isEmpty) return DateTime.now();
  if (!RegExp(r'(Z|[+-]\d{2}:?\d{2})$', caseSensitive: false).hasMatch(raw))
    raw += 'Z';
  return DateTime.tryParse(raw) ?? DateTime.now();
}

String waktuRelatif(DateTime waktu, {DateTime? sekarang}) {
  final d = (sekarang ?? DateTime.now()).difference(waktu);
  if (d.inSeconds < 1) return 'baru saja';
  if (d.inSeconds < 60) return '${d.inSeconds} detik lalu';
  if (d.inMinutes < 60) return '${d.inMinutes} menit lalu';
  if (d.inHours < 24) return '${d.inHours} jam lalu';
  if (d.inDays < 30) return '${d.inDays} hari lalu';
  if (d.inDays < 365) return '${d.inDays ~/ 30} bulan lalu';
  return '${d.inDays ~/ 365} tahun lalu';
}
