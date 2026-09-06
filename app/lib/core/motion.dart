import 'package:flutter/material.dart';

/// Transisi halaman premium: fade + slide halus.
Route<T> xyRoute<T>(Widget page, {bool fullscreen = false}) {
  return PageRouteBuilder<T>(
    fullscreenDialog: fullscreen,
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, a, __) => page,
    transitionsBuilder: (_, a, __, child) {
      final curve = CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, .035), end: Offset.zero).animate(curve),
          child: child,
        ),
      );
    },
  );
}

/// Transisi khusus untuk perpindahan flow besar (splash -> onboarding -> app).
Route<T> xyFadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 600),
    pageBuilder: (_, a, __) => page,
    transitionsBuilder: (_, a, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: a, curve: Curves.easeInOut),
      child: child,
    ),
  );
}
