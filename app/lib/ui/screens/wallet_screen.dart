import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final u = s.user!;

    return Scaffold(
      appBar: AppBar(title: const Text('Dompet & Riwayat', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Total Saldo', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
              const SizedBox(height: 6),
              Text(rupiah(u.saldo),
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1)),
              const SizedBox(height: 4),
              Text('${u.nama} · ${u.tier.toUpperCase()}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ]),
          ),
          const SectionHeader('Top Up Cepat'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [25000, 50000, 100000, 250000, 500000].map((n) {
              return SizedBox(
                width: (MediaQuery.of(context).size.width - 60) / 2,
                child: OutlinedButton(
                  onPressed: () async {
                    await s.topup(n);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('Top up ${rupiah(n)} berhasil')));
                    }
                  },
                  child: Text('+ ${rupiah(n)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              );
            }).toList(),
          ),
          const SectionHeader('Riwayat Transaksi'),
          if (s.transaksi.isEmpty)
            const Kosong(icon: Icons.history_rounded, judul: 'Belum ada transaksi')
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
                        Text(tanggal(t.waktu), style: const TextStyle(fontSize: 11.5, color: XyTheme.muted)),
                      ]),
                    ),
                    Text('${masuk ? '+' : '-'} ${rupiah(t.nominal.abs())}',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color: masuk ? XyTheme.success : XyTheme.ink)),
                  ]),
                ),
              );
            }),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.read<AppState>().logout(),
            icon: const Icon(Icons.logout_rounded, size: 18, color: XyTheme.danger),
            label: const Text('Keluar', style: TextStyle(color: XyTheme.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
