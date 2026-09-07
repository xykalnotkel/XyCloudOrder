import 'pengaturan.dart';
import 'package:flutter/material.dart';

/// ============================================================
///  Gerak dan transisi halaman XyCloudStore
/// ============================================================
///  Memakai gaya shared axis: halaman baru masuk dari kanan sambil
///  membesar sedikit, halaman lama mundur dan meredup. Terasa lembut
///  tetapi tetap gesit, tidak sekadar geser polos bawaan Android.

const Duration _durasi = Duration(milliseconds: 420);
const Duration _durasiBalik = Duration(milliseconds: 320);

Route<T> xyRoute<T>(Widget page, {bool fullscreen = false}) {
  return PageRouteBuilder<T>(
    fullscreenDialog: fullscreen,
    transitionDuration: PengaturanLokal.animasi ? _durasi : Duration.zero,
    reverseTransitionDuration: PengaturanLokal.animasi ? _durasiBalik : Duration.zero,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, masuk, keluar, child) {
      final maju = CurvedAnimation(
        parent: masuk,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final mundur = CurvedAnimation(parent: keluar, curve: Curves.easeOutCubic);

      return Stack(children: [
        // halaman lama sedikit menyusut dan meredup
        FadeTransition(
          opacity: Tween<double>(begin: 1, end: 0).animate(mundur),
          child: ScaleTransition(
            scale: Tween<double>(begin: 1, end: .96).animate(mundur),
            child: const SizedBox.shrink(),
          ),
        ),
        SlideTransition(
          position: Tween(begin: const Offset(.06, 0), end: Offset.zero).animate(maju),
          child: FadeTransition(
            opacity: maju,
            child: ScaleTransition(
              scale: Tween<double>(begin: .985, end: 1).animate(maju),
              child: child,
            ),
          ),
        ),
      ]);
    },
  );
}

/// Transisi lembut dari bawah, cocok untuk halaman berisi formulir.
Route<T> xyRouteBawah<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: PengaturanLokal.animasi ? _durasi : Duration.zero,
    reverseTransitionDuration: PengaturanLokal.animasi ? _durasiBalik : Duration.zero,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, a, __, child) {
      final k = CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return SlideTransition(
        position: Tween(begin: const Offset(0, .06), end: Offset.zero).animate(k),
        child: FadeTransition(opacity: k, child: child),
      );
    },
  );
}

/// Transisi khusus perpindahan alur besar (splash, onboarding, shell).
Route<T> xyFadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: PengaturanLokal.animasi ? const Duration(milliseconds:560) : Duration.zero,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, a, __, child) {
      final k = CurvedAnimation(parent: a, curve: Curves.easeInOutCubic);
      return FadeTransition(
        opacity: k,
        child: ScaleTransition(scale: Tween<double>(begin: 1.03, end: 1).animate(k), child: child),
      );
    },
  );
}

/// Pergantian isi tab bawah supaya tidak berkedip saat berpindah.
class TukarHalus extends StatelessWidget {
  const TukarHalus({super.key, required this.child, this.kunci});
  final Widget child;
  final Key? kunci;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (anak, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, .012), end: Offset.zero).animate(a),
            child: anak,
          ),
        ),
        child: KeyedSubtree(key: kunci, child: child),
      );
}
