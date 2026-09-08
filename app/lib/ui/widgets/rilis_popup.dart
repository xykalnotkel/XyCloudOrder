import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../screens/pembaruan_screen.dart';

/// ============================================================
///  RilisPopup — popup saat ada versi baru
/// ============================================================
///  Hanya menampilkan gambar popup (di-generate AI, teks sudah ikut di
///  dalam gambar) + tombol X di pojok kanan atas. Tombol X menutup popup
///  lalu membuka layar pembaruan.
Future<void> tampilkanRilisPopup(BuildContext context, AppState s) async {
  final hasil = await showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Rilis',
    barrierColor: Colors.black.withOpacity(.6),
    transitionDuration: const Duration(milliseconds: 220),
    transitionBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
    pageBuilder: (_, __, ___) => const RilisPopup(),
  );
  if (hasil == 'buka' && context.mounted) {
    Navigator.of(context, rootNavigator: true)
        .push(MaterialPageRoute(builder: (_) => const PembaruanScreen()));
  }
}

class RilisPopup extends StatelessWidget {
  const RilisPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AspectRatio(
          aspectRatio: 928 / 1152,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Gambar popup penuh (morphing glossy violet, teks ikut di gambar)
              Image.asset(
                'assets/ilustrasi/rilis_popup.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: BoxDecoration(gradient: XyTheme.gradPrimary),
                ),
              ),
              // Tombol X — tutup popup lalu buka layar pembaruan
              Positioned(
                top: 14,
                right: 14,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, 'buka'),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2)),
                      ],
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 22, color: Color(0xFF2A1A44)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
