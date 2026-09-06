import 'package:intl/intl.dart';

final _rp = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
final _jam = DateFormat('dd MMM yyyy · HH:mm', 'id_ID');
final _jamPendek = DateFormat('HH:mm');

String rupiah(num v) => _rp.format(v);
String tanggal(DateTime d) => _jam.format(d.toLocal());
String jam(DateTime d) => _jamPendek.format(d.toLocal());

String durasiSisa(DateTime end) {
  final d = end.difference(DateTime.now());
  if (d.isNegative) return 'Selesai';
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  if (h > 0) return '${h}j ${m}m';
  if (m > 0) return '${m}m ${s}d';
  return '${s}d';
}
