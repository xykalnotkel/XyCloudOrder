import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart' as fmt;
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';

String formatRupiah(int v) => fmt.rupiah(v);
String formatTanggal(DateTime d) => fmt.tanggal(d);

/// Statistik Pengeluaran — ringkasan belanja pribadi
class StatistikScreen extends StatelessWidget {
  const StatistikScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final orders = s.orders;
    final transaksi = s.transaksi;
    final totalBelanja = orders.fold<int>(0, (a, o) => a + o.total) + transaksi.where((t) => t.tipe == 'akun').fold<int>(0, (a, t) => a + t.nominal.abs());
    final totalSewa = orders.length;
    final totalAkun = transaksi.where((t) => t.tipe == 'akun').length;
    final allCount = orders.length + totalAkun;
    final avg = allCount == 0 ? 0 : (totalBelanja / allCount).round();
    // monthly breakdown simple
    final now = DateTime.now();
    final bulanIni = orders.where((o) => o.dibuat.month == now.month && o.dibuat.year == now.year).fold<int>(0, (a, o) => a + o.total) +
        transaksi.where((t) => t.waktu.month == now.month && t.waktu.year == now.year && t.tipe != 'topup').fold<int>(0, (a, t) => a + t.nominal.abs());
    final bulanLalu = (() {
      final d = now.month == 1 ? DateTime(now.year - 1, 12) : DateTime(now.year, now.month - 1);
      return orders.where((o) => o.dibuat.month == d.month && o.dibuat.year == d.year).fold<int>(0, (a, o) => a + o.total) +
          transaksi.where((t) => t.waktu.month == d.month && t.waktu.year == d.year && t.tipe != 'topup').fold<int>(0, (a, t) => a + t.nominal.abs());
    })();

    return Scaffold(
      appBar: AppBar(title: const Text('Statistik & Pengeluaran')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF100030), Color(0xFF200050), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(.14), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.bar_chart_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Ringkasan Belanja', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                    SizedBox(height: 2),
                    Text('Pantau pengeluaran & hemat dengan tier', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                  ]),
                ),
              ]),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: _StatBig(label: 'Total Belanja', value: formatRupiah(totalBelanja))),
                const SizedBox(width: 12),
                Expanded(child: _StatBig(label: 'Rata / Order', value: formatRupiah(avg))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _StatSmall(label: 'Bulan Ini', value: formatRupiah(bulanIni), icon: Icons.calendar_month_rounded)),
                const SizedBox(width: 10),
                Expanded(child: _StatSmall(label: 'Bulan Lalu', value: formatRupiah(bulanLalu), icon: Icons.history_rounded)),
              ]),
            ]),
          ),
          const SectionHeader('Breakdown'),
          Row(children: [
            Expanded(
              child: XyCard(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: const Color(0xFF7C3AED).withOpacity(.12), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.desktop_windows_rounded, color: XyTheme.primary),
                  ),
                  const SizedBox(height: 10),
                  Text('$totalSewa', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 22)),
                  const SizedBox(height: 2),
                  Text('Sewa PC', style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5)),
                ]),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: XyCard(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: const Color(0xFFA855F7).withOpacity(.12), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.account_circle_rounded, color: Color(0xFFA855F7)),
                  ),
                  const SizedBox(height: 10),
                  Text('$totalAkun', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 22)),
                  const SizedBox(height: 2),
                  Text('Beli Akun', style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5)),
                ]),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: XyCard(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: const Color(0xFF22C55E).withOpacity(.12), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.savings_rounded, color: Color(0xFF22C55E)),
                  ),
                  const SizedBox(height: 10),
                  Text('${s.user?.tier ?? "-"}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                  const SizedBox(height: 2),
                  Text('Tier', style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5)),
                ]),
              ),
            ),
          ]),
          const SectionHeader('Riwayat Terbaru'),
          if (orders.isEmpty && transaksi.isEmpty)
            const Kosong(icon: Icons.receipt_long_rounded, judul: 'Belum ada transaksi', sub: 'Sewa PC atau beli akun untuk melihat statistik.', ilustrasi: 'order')
          else
            ...[
              ...orders.take(4).map((o) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: XyCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: const Color(0xFF7C3AED).withOpacity(.12), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.desktop_windows_rounded, size: 18, color: Color(0xFF7C3AED)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(o.planNama, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text('${formatTanggal(o.dibuat)} • ${o.status.name}', style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11)),
                          ]),
                        ),
                        Text(formatRupiah(o.total), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                      ]),
                    ),
                  )),
              ...transaksi.where((t) => t.tipe != 'topup').take(4).map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: XyCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: const Color(0xFFA855F7).withOpacity(.12), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.account_circle_rounded, size: 18, color: Color(0xFFA855F7)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(t.judul, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text('${formatTanggal(t.waktu)} • ${t.status}', style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11)),
                          ]),
                        ),
                        Text(formatRupiah(t.nominal.abs()), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                      ]),
                    ),
                  )),
            ],
          const SizedBox(height: 8),
          XyCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Hemat dengan Tier', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                '• Bronze: 0% — tier awal\n• Silver: 2% cashback setelah 500rb belanja\n• Gold: 5% + prioritas support setelah 2jt\n• Platinum: 8% + unit prioritas + voucher eksklusif setelah 5jt',
                style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12.5, height: 1.6),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _StatBig extends StatelessWidget {
  final String label;
  final String value;
  const _StatBig({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white.withOpacity(.10), borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(.72), fontSize: 11)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
        ]),
      );
}

class _StatSmall extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatSmall({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: Colors.white.withOpacity(.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(.10))),
        child: Row(children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(color: Colors.white.withOpacity(.6), fontSize: 10)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11.5)),
            ]),
          ),
        ]),
      );
}
