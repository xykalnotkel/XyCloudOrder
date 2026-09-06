import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import 'order_detail_screen.dart';

class CheckoutSewaScreen extends StatefulWidget {
  const CheckoutSewaScreen({super.key, required this.plan});
  final PcPlan plan;
  @override
  State<CheckoutSewaScreen> createState() => _CheckoutSewaScreenState();
}

class _CheckoutSewaScreenState extends State<CheckoutSewaScreen> {
  int jam = 3;
  String metode = 'saldo';
  bool proses = false;

  static const opsiJam = [1, 2, 3, 5, 8, 12, 24];

  int get subtotal => widget.plan.hargaPerJam * jam;
  int get diskon => jam >= 8 ? (subtotal * .1).round() : 0;
  int get biayaLayanan => 1000;
  int get total => subtotal - diskon + biayaLayanan;

  Future<void> _bayar() async {
    final s = context.read<AppState>();
    if (metode == 'saldo' && (s.user?.saldo ?? 0) < total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saldo tidak cukup. Silakan top up dulu.')),
      );
      return;
    }
    setState(() => proses = true);
    final order = await s.sewaPc(widget.plan, jam, metode);
    if (!mounted) return;
    setState(() => proses = false);
    if (order == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.error ?? 'Gagal membuat order')));
      return;
    }
    Navigator.pushReplacement(
      context,
      xyRoute(OrderDetailScreen(orderId: order.id, baru: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.plan;
    final saldo = context.select<AppState, int>((s) => s.user?.saldo ?? 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout Sewa', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          XyCard(
            child: Row(children: [
              GradientThumb(seed: p.id, icon: Icons.memory_rounded, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.nama, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text('${p.gpu} · ${p.ramGb}GB RAM', style: const TextStyle(color: XyTheme.muted, fontSize: 12.5)),
                  const SizedBox(height: 6),
                  Pill('${p.unitTersedia} unit ready', warna: XyTheme.success, icon: Icons.bolt_rounded),
                ]),
              ),
            ]),
          ),
          const SectionHeader('Durasi Sewa'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: opsiJam.map((j) {
              final aktif = j == jam;
              return GestureDetector(
                onTap: () => setState(() => jam = j),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: aktif ? XyTheme.primary : XyTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: aktif ? XyTheme.primary : XyTheme.line),
                  ),
                  child: Text('$j jam',
                      style: TextStyle(
                          color: aktif ? Colors.white : XyTheme.ink, fontWeight: FontWeight.w700, fontSize: 13.5)),
                ),
              );
            }).toList(),
          ),
          if (jam >= 8)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Row(children: [
                Icon(Icons.local_offer_rounded, size: 15, color: XyTheme.success),
                SizedBox(width: 6),
                Text('Diskon 10% untuk sewa 8 jam ke atas',
                    style: TextStyle(color: XyTheme.success, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ]),
            ),
          const SectionHeader('Metode Pembayaran'),
          _Metode(
            id: 'saldo',
            aktif: metode == 'saldo',
            icon: Icons.account_balance_wallet_rounded,
            judul: 'Saldo XyCloud',
            sub: rupiah(saldo),
            onTap: () => setState(() => metode = 'saldo'),
          ),
          const SizedBox(height: 10),
          _Metode(
            id: 'qris',
            aktif: metode == 'qris',
            icon: Icons.qr_code_2_rounded,
            judul: 'QRIS',
            sub: 'Semua e-wallet & mobile banking',
            onTap: () => setState(() => metode = 'qris'),
          ),
          const SizedBox(height: 10),
          _Metode(
            id: 'va',
            aktif: metode == 'va',
            icon: Icons.account_balance_rounded,
            judul: 'Virtual Account',
            sub: 'BCA, BRI, Mandiri, BNI',
            onTap: () => setState(() => metode = 'va'),
          ),
          const SectionHeader('Ringkasan'),
          XyCard(
            child: Column(children: [
              _Baris('Sewa ${p.nama} × $jam jam', rupiah(subtotal)),
              if (diskon > 0) _Baris('Diskon durasi', '- ${rupiah(diskon)}', warna: XyTheme.success),
              _Baris('Biaya layanan', rupiah(biayaLayanan)),
              const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
              _Baris('Total', rupiah(total), tebal: true),
            ]),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
        decoration: BoxDecoration(color: XyTheme.surface, boxShadow: XyTheme.shadowMd),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const Text('Total bayar', style: TextStyle(fontSize: 11.5, color: XyTheme.muted)),
            Text(rupiah(total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -.5)),
          ]),
          const SizedBox(width: 16),
          Expanded(
            child: GradientButton(
              label: 'Bayar & Nyalakan',
              icon: Icons.lock_rounded,
              loading: proses,
              onPressed: proses ? null : _bayar,
            ),
          ),
        ]),
      ),
    );
  }
}

class _Metode extends StatelessWidget {
  const _Metode({required this.id, required this.aktif, required this.icon, required this.judul, required this.sub, required this.onTap});
  final String id;
  final bool aktif;
  final IconData icon;
  final String judul;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: XyTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: aktif ? XyTheme.primary : XyTheme.line, width: aktif ? 1.7 : 1),
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: XyTheme.primary.withOpacity(.09), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: XyTheme.primary, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(judul, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text(sub, style: const TextStyle(color: XyTheme.muted, fontSize: 12)),
            ]),
          ),
          Icon(aktif ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              color: aktif ? XyTheme.primary : XyTheme.line),
        ]),
      ),
    );
  }
}

class _Baris extends StatelessWidget {
  const _Baris(this.kiri, this.kanan, {this.tebal = false, this.warna});
  final String kiri;
  final String kanan;
  final bool tebal;
  final Color? warna;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text(kiri, style: TextStyle(fontSize: 13.5, color: tebal ? XyTheme.ink : XyTheme.muted, fontWeight: tebal ? FontWeight.w800 : FontWeight.w500)),
        const Spacer(),
        Text(kanan, style: TextStyle(fontSize: tebal ? 16 : 13.5, fontWeight: FontWeight.w800, color: warna ?? XyTheme.ink)),
      ]),
    );
  }
}
