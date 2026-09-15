import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// ============================================================
///  XyLatar — latar "Midnight Aurora" global (Batch I)
/// ============================================================
///  Permintaan pemilik: mode gelap harus terlihat premium, tidak
///  pasaran. Alih-alih satu warna datar, seluruh app duduk di atas
///  gradasi vertikal dalam + blob aurora violet/plum yang lembut.
///  Dipasang sekali di MaterialApp.builder; semua Scaffold memakai
///  latar transparan sehingga aurora tembus di setiap layar.
///
///  Statis (tanpa AnimationController) supaya hemat baterai dan
///  tidak memicu repaint saat daftar digulir.
class XyLatar extends StatelessWidget {
  const XyLatar({super.key, required this.child, this.padat = false, this.paksaGelap});

  final Widget child;

  /// Blob lebih pekat untuk layar autentikasi (login/welcome/onboarding).
  final bool padat;

  /// Paksa varian gelap/terang tanpa melihat tema (layar hero welcome).
  final bool? paksaGelap;

  static Widget blob(Color warna, double diameter, {double opasitas = 1}) =>
      Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [warna.withOpacity(.30 * opasitas), warna.withOpacity(0)],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final gelap =
        paksaGelap ?? (Theme.of(context).brightness == Brightness.dark);
    final o = padat ? 1.5 : 1.0;

    return RepaintBoundary(
      child: Stack(fit: StackFit.expand, children: [
        // Dasar: gradasi vertikal dalam (gelap) / lavender halus (terang).
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gelap
                  ? const [
                      Color(0xFF1B0745),
                      Color(0xFF0D0224),
                      Color(0xFF13042E),
                    ]
                  : const [
                      Color(0xFFFDFBFF),
                      Color(0xFFF4EFFF),
                      Color(0xFFEEE6FF),
                    ],
              stops: const [0, .55, 1],
            ),
          ),
        ),
        // Blob aurora: violet kiri-atas, plum kanan-tengah, indigo bawah.
        if (gelap) ...[
          Positioned(
            left: -140,
            top: -120,
            child: blob(XyTheme.violet, 420, opasitas: .85 * o),
          ),
          Positioned(
            right: -160,
            top: 220,
            child: blob(XyTheme.plum, 380, opasitas: .55 * o),
          ),
          Positioned(
            left: -100,
            bottom: -60,
            child: blob(const Color(0xFF4C1D95), 460, opasitas: .9 * o),
          ),
          Positioned(
            right: -60,
            bottom: 140,
            child: blob(XyTheme.primaryDeep, 260, opasitas: .5 * o),
          ),
        ] else ...[
          Positioned(
            left: -150,
            top: -130,
            child: blob(XyTheme.lavender, 400, opasitas: .9 * o),
          ),
          Positioned(
            right: -170,
            top: 180,
            child: blob(const Color(0xFFDDD6FE), 360, opasitas: .8 * o),
          ),
          Positioned(
            left: -120,
            bottom: -80,
            child: blob(const Color(0xFFE9D5FF), 420, opasitas: .75 * o),
          ),
        ],
        // Kilau tipis di tepi atas supaya tidak datar.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 220,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    (gelap ? XyTheme.lilac : XyTheme.lavender)
                        .withOpacity(gelap ? .07 : .18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ]),
    );
  }
}
