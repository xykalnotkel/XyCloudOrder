import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import 'cs_screen.dart';

/// Layar penuh saat akun diblokir / dibekukan admin.
/// User hanya bisa chat CS (banding) atau keluar.
class BlokirScreen extends StatelessWidget {
  const BlokirScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final u = s.user;
    final alasan = u?.alasanBlokir?.trim();
    final p = XyTheme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 1),
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: XyTheme.danger.withOpacity(.12),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(Icons.gpp_bad_rounded, size: 36, color: XyTheme.danger),
              ),
              const SizedBox(height: 22),
              Text(
                'Akun dibekukan',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: p.ink,
                  letterSpacing: -.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                alasan != null && alasan.isNotEmpty
                    ? 'Alasan: $alasan'
                    : 'Admin membatasi akunmu karena melanggar ketentuan komunitas.',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.inkSoft, height: 1.5, fontSize: 14.5),
              ),
              const SizedBox(height: 18),
              XyCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Apa yang bisa dilakukan?',
                        style: TextStyle(fontWeight: FontWeight.w700, color: p.ink)),
                    const SizedBox(height: 8),
                    Text(
                      '• Ajukan banding lewat chat CS admin.\n'
                      '• Baca ulang ketentuan komunitas.\n'
                      '• Sesi sewa aktif dihentikan otomatis saat pembekuan.',
                      style: TextStyle(color: p.muted, height: 1.55, fontSize: 13),
                    ),
                    if ((u?.peringatan ?? 0) > 0) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Riwayat: ${u!.peringatan} peringatan sebelum pembekuan.',
                        style: TextStyle(color: XyTheme.warning, fontWeight: FontWeight.w600, fontSize: 12.5),
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(flex: 2),
              GradientButton(
                label: 'Ajukan banding (Chat CS)',
                icon: Icons.support_agent_rounded,
                onPressed: () {
                  Navigator.of(context).push(xyRoute(const CsScreen()));
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => s.logout(),
                child: const Text('Keluar dari akun'),
              ),
              const SizedBox(height: 8),
              Text(
                u?.email ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
