import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import '../widgets/topup_sheet.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final u = s.user!;

    return Scaffold(
      appBar: AppBar(title: const Text('Dompet & Riwayat', style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF4B1DA6), Color(0xFF2E1065), Color(0xFF130236)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0, .52, 1],
              ),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF2E1065).withOpacity(.34),
                    blurRadius: 26,
                    offset: const Offset(0, 14)),
                BoxShadow(
                    color: const Color(0xFF12042E).withOpacity(.9),
                    blurRadius: 0,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(.12),
                            Colors.white.withOpacity(.015),
                          ],
                          begin: Alignment.topCenter,
                          end: const Alignment(0, .5),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: -40,
                  top: -50,
                  child: Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFA78BFA).withOpacity(.22),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Text('Total Saldo',
                          style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: XyTheme.gradGold,
                          borderRadius: BorderRadius.circular(XyRadius.pill),
                        ),
                        child: Text(u.tier.toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1)),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Text(rupiah(u.saldo),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1.2)),
                    const SizedBox(height: 4),
                    Text(u.nama.toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 11.5, letterSpacing: .8)),
                  ]),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          GradientButton(
            label: 'Isi Saldo',
            icon: Icons.add_rounded,
            onPressed: () => bukaTopup(context),
          ),
          const SizedBox(height: 10),
          Row(children: [
             Icon(Icons.verified_user_rounded, size: 15, color: XyTheme.of(context).muted),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                'Transfer bank atau QRIS, saldo masuk setelah admin memverifikasi bukti.',
                style:  TextStyle(color: XyTheme.of(context).muted, fontSize: 11.8, height: 1.45),
              ),
            ),
          ]),

          if (s.topupSaya.where((t) => !t.selesai).isNotEmpty) ...[
            const SectionHeader('Top Up Berjalan'),
            ...s.topupSaya.where((t) => !t.selesai).map((t) => KartuTopup(t)),
          ],
          const SectionHeader('Riwayat Transaksi'),
          if (s.transaksi.isEmpty)
            const Kosong(icon: Icons.history_rounded, judul: 'Belum ada transaksi', sub: 'Top up saldo dulu untuk mulai transaksi.', ilustrasi: 'dompet')
          else
            ...s.transaksi.map((t) {
              final masuk = t.nominal > 0;
              final ikon = switch (t.tipe) {
                'topup' => Icons.add_circle_rounded,
                'sewa' => Icons.desktop_windows_rounded,
                'akun' => Icons.vpn_key_rounded,
                _ => Icons.replay_rounded,
              };
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: XyCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: (masuk ? XyTheme.success : XyTheme.primary).withOpacity(.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(ikon, size: 20, color: masuk ? XyTheme.success : XyTheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t.judul,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        Text(tanggal(t.waktu), style:  TextStyle(fontSize: 11.5, color: XyTheme.of(context).muted)),
                      ]),
                    ),
                    Text('${masuk ? '+' : '-'} ${rupiah(t.nominal.abs())}',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: masuk ? XyTheme.success : XyTheme.of(context).ink)),
                  ]),
                ),
              );
            }),
        ],
      ),
    );
  }
}
