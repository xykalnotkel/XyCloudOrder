import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import '../widgets/lembar.dart';
import '../widgets/topup_sheet.dart';
import 'tentang_screen.dart';

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
                  colors: [Color(0xFF33087F), Color(0xFF6C2BE2)],
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
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color: masuk ? XyTheme.success : XyTheme.of(context).ink)),
                  ]),
                ),
              );
            }),
          const SectionHeader('Lainnya'),
          XyCard(
            padding: const EdgeInsets.all(15),
            onTap: () => Navigator.push(context, xyRoute(const TentangScreen())),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: XyTheme.of(context).primarySoft, borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.info_outline_rounded, size: 20, color: XyTheme.primary),
              ),
              const SizedBox(width: 13),
               Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Tentang Aplikasi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  SizedBox(height: 3),
                  Text('Versi, syarat, privasi, dan lisensi',
                      style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.8)),
                ]),
              ),
               Icon(Icons.chevron_right_rounded, color: XyTheme.of(context).muted),
            ]),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () async {
              final yakin = await konfirmasi(
                context,
                judul: 'Keluar dari akun?',
                pesan: 'Kamu perlu masuk lagi untuk memakai aplikasi.',
                tombolYa: 'Keluar',
                ikon: Icons.logout_rounded,
                bahaya: true,
              );
              if (yakin && context.mounted) context.read<AppState>().logout();
            },
            icon: const Icon(Icons.logout_rounded, size: 18, color: XyTheme.danger),
            label: const Text('Keluar', style: TextStyle(color: XyTheme.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
