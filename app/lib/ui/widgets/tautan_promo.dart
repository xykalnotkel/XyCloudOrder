import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/motion.dart';
import '../screens/akun_screen.dart';
import '../screens/sewa_pc_screen.dart';
import '../screens/wallet_screen.dart';
import '../screens/forum_screen.dart';

Future<void> bukaTujuanPromo(
    BuildContext context, String aksi, String target) async {
  if (aksi == 'url' || aksi == 'unduh') {
    final uri =
        Uri.tryParse(aksi == 'unduh' ? 'https://xycloud.my.id/unduh' : target);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) return;
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Tautan belum bisa dibuka. Pastikan browser tersedia.')));
    return;
  }
  final Widget page = switch (aksi) {
    'akun' => AkunScreen(fokusId: target.isEmpty ? null : target),
    'topup' => const WalletScreen(),
    'komunitas' => const ForumScreen(),
    _ => SewaPcScreen(fokusId: target.isEmpty ? null : target),
  };
  await Navigator.push(context, xyRoute(page));
}
