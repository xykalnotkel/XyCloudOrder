import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'common.dart';

/// ============================================================
///  Halaman saat server sedang mode pemeliharaan (HTTP 503)
/// ============================================================
///  Muncul menggantikan layar aplikasi ketika `AppState.perawatan` aktif,
///  supaya pengguna tidak bingung melihat galat. Desain sendiri khas
///  XyCloudStore, tanpa emoji.
class PerawatanScreen extends StatelessWidget {
  const PerawatanScreen({
    super.key,
    required this.pesan,
    this.onCoba,
    this.onKeluar,
  });

  final String pesan;
  final VoidCallback? onCoba;
  final VoidCallback? onKeluar;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: XyTheme.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(alignment: Alignment.center, children: [
                  Container(
                    width: 210,
                    height: 210,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        XyTheme.primary.withOpacity(.14),
                        XyTheme.violet.withOpacity(.05),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                  Container(
                    width: 118,
                    height: 118,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: XyTheme.gradPrimary,
                      boxShadow: XyTheme.glow(XyTheme.primary, .32),
                    ),
                    child: const Icon(Icons.engineering_rounded, size: 56, color: Colors.white),
                  ),
                ]),
                const SizedBox(height: 18),
                const Text(
                  'Sedang Perawatan',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 21,
                    letterSpacing: -.6,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Kami sedang menyempurnakan layanan sebentar. '
                  'Data dan saldo kamu aman — tinggal tunggu sampai selesai.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: XyTheme.muted,
                    fontSize: 13.5,
                    height: 1.6,
                  ),
                ),
                if (pesan.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: gelap ? XyTheme.lineGelap.withOpacity(.5) : XyTheme.primarySoft,
                      borderRadius: BorderRadius.circular(XyRadius.lg),
                      border: Border.all(
                          color: gelap ? XyTheme.lineGelap : XyTheme.line),
                    ),
                    child: Text(
                      pesan,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, height: 1.5, color: XyTheme.muted),
                    ),
                  ),
                ],
                const SizedBox(height: 26),
                if (onCoba != null) ...[
                  SizedBox(
                    width: 210,
                    child: GradientButton(
                      label: 'Coba Lagi',
                      icon: Icons.refresh_rounded,
                      height: 50,
                      onPressed: onCoba,
                    ),
                  ),
                ],
                if (onKeluar != null) ...[
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: onKeluar,
                    child: Text(
                      'Keluar dari akun ini',
                      style: TextStyle(
                        color: XyTheme.muted,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                        decorationColor: XyTheme.muted.withOpacity(.5),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
