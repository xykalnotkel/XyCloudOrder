import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import 'order_detail_screen.dart';
import 'wallet_screen.dart';

class OrderListScreen extends StatelessWidget {
  const OrderListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final berjalan = s.orders.where((o) => o.status != OrderStatus.selesai && o.status != OrderStatus.batal).toList();
    final riwayat = s.orders.where((o) => o.status == OrderStatus.selesai || o.status == OrderStatus.batal).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Order Saya', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -.4)),
          actions: [
            IconButton(
              onPressed: () => Navigator.push(context, xyRoute(const WalletScreen())),
              icon: const Icon(Icons.account_balance_wallet_outlined),
            ),
            Padding(padding: const EdgeInsets.only(right: 12), child: Center(child: LiveDot(state: s.koneksi))),
          ],
          bottom: TabBar(
            labelColor: XyTheme.primary,
            unselectedLabelColor: XyTheme.muted,
            indicatorColor: XyTheme.primary,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
            tabs: [Tab(text: 'Berjalan (${berjalan.length})'), Tab(text: 'Riwayat (${riwayat.length})')],
          ),
        ),
        body: TabBarView(children: [
          _List(orders: berjalan, kosong: 'Belum ada order berjalan'),
          _List(orders: riwayat, kosong: 'Riwayat masih kosong'),
        ]),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.orders, required this.kosong});
  final List<RentOrder> orders;
  final String kosong;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Kosong(icon: Icons.inbox_rounded, judul: kosong, sub: 'Order sewa PC kamu akan muncul di sini.');
    }
    return RefreshIndicator(
      onRefresh: context.read<AppState>().refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final o = orders[i];
          final warna = switch (o.status) {
            OrderStatus.aktif => XyTheme.success,
            OrderStatus.selesai => XyTheme.muted,
            OrderStatus.batal => XyTheme.danger,
            _ => XyTheme.warning,
          };
          return XyCard(
            onTap: () => Navigator.push(context, xyRoute(OrderDetailScreen(orderId: o.id))),
            child: Column(children: [
              Row(children: [
                GradientThumb(seed: o.planId, icon: Icons.memory_rounded, size: 46, radius: 13),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(o.planNama, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    Text('${o.kode} · ${tanggal(o.dibuat)}', style: const TextStyle(fontSize: 11.5, color: XyTheme.muted)),
                  ]),
                ),
                Pill(o.status.label, warna: warna),
              ]),
              if (o.status == OrderStatus.provisioning) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                      value: o.progress / 100, minHeight: 6, backgroundColor: XyTheme.line, color: XyTheme.primary),
                ),
              ],
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 10),
              Row(children: [
                Text('${o.durasiJam} jam', style: const TextStyle(fontSize: 12.5, color: XyTheme.muted)),
                if (o.status == OrderStatus.aktif && o.berakhir != null) ...[
                  const Text('  ·  ', style: TextStyle(color: XyTheme.muted)),
                  Text('sisa ${durasiSisa(o.berakhir!)}',
                      style: const TextStyle(fontSize: 12.5, color: XyTheme.success, fontWeight: FontWeight.w700)),
                ],
                const Spacer(),
                Text(rupiah(o.total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ]),
            ]),
          );
        },
      ),
    );
  }
}
