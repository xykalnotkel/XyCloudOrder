import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import '../widgets/lembar.dart';
import 'sesi_screen.dart';
import 'cs_screen.dart';

/// Halaman inti realtime: status order berubah sendiri mengikuti event server.
class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen(
      {super.key, required this.orderId, this.baru = false});
  final String orderId;
  final bool baru;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final order = s.orders.where((o) => o.id == orderId).firstOrNull;

    if (order == null) {
      return const Scaffold(
          body: Kosong(
              icon: Icons.error_outline_rounded,
              judul: 'Order tidak ditemukan'));
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(order.kode,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          Text(order.planNama,
              style:
                  TextStyle(fontSize: 11.5, color: XyTheme.of(context).muted)),
        ]),
        actions: [
          Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: LiveDot(state: s.koneksi)))
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          if (baru)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: XyTheme.success.withOpacity(.09),
                  borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Icon(Icons.check_circle_rounded,
                    color: XyTheme.success, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                      'Order berhasil dibuat! Pantau prosesnya di bawah — update langsung dari server.',
                      style: TextStyle(
                          fontSize: 12.5, color: XyTheme.of(context).ink)),
                ),
              ]),
            ),

          // ---- status besar ----
          _KartuStatus(order: order),

          const SectionHeader('Status Pesanan'),
          _Timeline(status: order.status, progress: order.progress),

          const SectionHeader('Rincian'),
          XyCard(
            child: Column(children: [
              _Info('Kode Order', order.kode),
              _Info('Paket', order.planNama),
              _Info('Durasi', '${order.durasiJam} jam'),
              _Info('Dibuat', tanggal(order.dibuat)),
              if (order.mulai != null) _Info('Mulai', tanggal(order.mulai!)),
              if (order.berakhir != null)
                _Info('Berakhir', tanggal(order.berakhir!)),
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
              _Info('Total Bayar', rupiah(order.total), tebal: true),
            ]),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(context, xyRoute(const CsScreen())),
            icon: const Icon(Icons.support_agent_rounded, size: 19),
            label: const Text('Ada kendala? Chat CS',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _KartuStatus extends StatelessWidget {
  const _KartuStatus({required this.order});
  final RentOrder order;

  @override
  Widget build(BuildContext context) {
    final aktif = order.status == OrderStatus.aktif;
    final warna = switch (order.status) {
      OrderStatus.aktif => XyTheme.success,
      OrderStatus.selesai => XyTheme.of(context).muted,
      OrderStatus.batal => XyTheme.danger,
      _ => XyTheme.warning,
    };
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: warna.withOpacity(.08),
        border: Border.all(color: warna.withOpacity(.25)),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: warna.withOpacity(.14), shape: BoxShape.circle),
            child: Icon(
              aktif ? Icons.play_circle_fill_rounded : Icons.autorenew_rounded,
              color: warna,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(order.status.label,
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16, color: warna)),
              const SizedBox(height: 2),
              Text(
                aktif
                    ? 'Unit telah menerima sesi'
                    : order.status == OrderStatus.dibayar
                        ? 'Pembayaran diterima. Ketuk Mulai Main.'
                        : 'Status diperbarui dari agen PC',
                style:
                    TextStyle(fontSize: 12.5, color: XyTheme.of(context).muted),
              ),
            ]),
          ),
        ]),
        if (aktif && order.berakhir != null) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
                color: XyTheme.of(context).surface,
                borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              Text('SISA WAKTU',
                  style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 1.2,
                      color: XyTheme.of(context).muted,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(durasiSisa(order.berakhir!),
                  style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1)),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        if ([OrderStatus.dibayar, OrderStatus.provisioning, OrderStatus.aktif]
            .contains(order.status)) ...[
          const SizedBox(height: 16),
          GradientButton(
              label: 'Mulai Main',
              icon: Icons.sports_esports_rounded,
              height: 52,
              onPressed: () =>
                  Navigator.push(context, xyRoute(SesiScreen(order: order)))),
          if (order.status == OrderStatus.dibayar)
            TextButton(
                onPressed: () async {
                  final ya = await konfirmasi(context,
                      judul: 'Batalkan pesanan?',
                      pesan:
                          'Reservasi yang belum disiapkan akan dibatalkan dan pembayaran saldo dikembalikan.',
                      tombolYa: 'Batalkan');
                  if (!ya || !context.mounted) return;
                  final e = await context.read<AppState>().batalOrder(order.id);
                  if (e != null && context.mounted)
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(e)));
                },
                child: const Text('Batalkan sebelum disiapkan')),
        ],
        if (order.status == OrderStatus.provisioning) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: XyTheme.of(context).surface,
                borderRadius: BorderRadius.circular(XyRadius.md)),
            child: Row(children: [
              ProgressRing(value: order.progress / 100, size: 66),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Menyiapkan mesin',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14)),
                      SizedBox(height: 4),
                      Text('Agen memeriksa Sunshine dan menyiapkan sesi.',
                          style: TextStyle(
                              fontSize: 12,
                              color: XyTheme.of(context).muted,
                              height: 1.5)),
                    ]),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.status, required this.progress});
  final OrderStatus status;
  final int progress;

  static const langkah = [
    ('Order dibuat', Icons.receipt_long_rounded),
    ('Pembayaran diterima', Icons.payments_rounded),
    ('Menyiapkan mesin', Icons.settings_suggest_rounded),
    ('Sesi aktif', Icons.rocket_launch_rounded),
    ('Selesai', Icons.check_circle_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final step = status.step;
    return XyCard(
      child: Column(
        children: List.generate(langkah.length, (i) {
          final done = i <= step;
          final aktifSekarang = i == step;
          final warna = done ? XyTheme.primary : XyTheme.of(context).line;
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: done ? XyTheme.primary : XyTheme.of(context).bg,
                  shape: BoxShape.circle,
                  border: Border.all(color: warna, width: 1.6),
                  boxShadow: aktifSekarang
                      ? [
                          BoxShadow(
                              color: XyTheme.primary.withOpacity(.3),
                              blurRadius: 12,
                              spreadRadius: 2)
                        ]
                      : null,
                ),
                child: Icon(langkah[i].$2,
                    size: 17,
                    color: done ? Colors.white : XyTheme.of(context).muted),
              ),
              if (i != langkah.length - 1)
                Container(
                    width: 2,
                    height: 30,
                    color:
                        i < step ? XyTheme.primary : XyTheme.of(context).line),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(langkah[i].$1,
                          style: TextStyle(
                            fontWeight: aktifSekarang
                                ? FontWeight.w800
                                : FontWeight.w600,
                            fontSize: 13.5,
                            color: done
                                ? XyTheme.of(context).ink
                                : XyTheme.of(context).muted,
                          )),
                      if (aktifSekarang && status == OrderStatus.provisioning)
                        Text('$progress% selesai',
                            style: const TextStyle(
                                fontSize: 11.5, color: XyTheme.primary)),
                      const SizedBox(height: 18),
                    ]),
              ),
            ),
          ]);
        }),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.k, this.v, {this.tebal = false});
  final String k;
  final String v;
  final bool tebal;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Text(k,
            style: TextStyle(fontSize: 13, color: XyTheme.of(context).muted)),
        const Spacer(),
        Text(v,
            style: TextStyle(
                fontSize: tebal ? 15.5 : 13, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

extension _F<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
