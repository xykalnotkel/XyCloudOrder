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
      backgroundColor: XyTheme.of(context).bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ilustrasi 3D ungu glossy (transparan) dengan lingkaran cahaya lembut.
                Stack(alignment: Alignment.center, children: [
                  Container(
                    width: 230,
                    height: 230,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        XyTheme.primary.withOpacity(.18),
                        XyTheme.violet.withOpacity(.07),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                  Container(
                    width: 168,
                    height: 168,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF140E29),
                      boxShadow: [
                        BoxShadow(
                          color: XyTheme.primary.withOpacity(.25),
                          blurRadius: 40,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/ilustrasi/maintenance.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.engineering_rounded,
                        size: 60,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                  decoration: BoxDecoration(
                    color: XyTheme.primary.withOpacity(.14),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: XyTheme.primary.withOpacity(.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _TitikPulsa(),
                      SizedBox(width: 7),
                      Text(
                        'Sedang Perawatan',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.6,
                          color: Color(0xFFD8CDF5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Kami Sebentar Lagi',
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
                    color: XyTheme.of(context).muted,
                    fontSize: 13.5,
                    height: 1.6,
                  ),
                ),
                if (pesan.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: gelap ? XyTheme.lineGelap.withOpacity(.5) : XyTheme.of(context).primarySoft,
                      borderRadius: BorderRadius.circular(XyRadius.lg),
                      border: Border.all(
                          color: gelap ? XyTheme.lineGelap : XyTheme.of(context).line),
                    ),
                    child: Text(
                      pesan,
                      textAlign: TextAlign.center,
                      style:  TextStyle(fontSize: 12, height: 1.5, color: XyTheme.of(context).muted),
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
                        color: XyTheme.of(context).muted,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                        decorationColor: XyTheme.of(context).muted.withOpacity(.5),
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

/// Titik kecil pada lencana "Sedang Perawatan".
class _TitikPulsa extends StatelessWidget {
  const _TitikPulsa();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFC084FC),
      ),
    );
  }
}
