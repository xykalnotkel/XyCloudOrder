import 'package:flutter/material.dart';
import 'onboarding_screen.dart';
import 'splash_screen.dart';
import 'welcome_screen.dart';

enum _Tahap { splash, onboarding, welcome }

/// Mengatur urutan Splash -> Onboarding -> Welcome tanpa menyentuh
/// Navigator root, supaya begitu login sukses widget induk bisa
/// langsung menukar seluruh flow dengan shell aplikasi.
class FlowGate extends StatefulWidget {
  const FlowGate({super.key});

  @override
  State<FlowGate> createState() => _FlowGateState();
}

class _FlowGateState extends State<FlowGate> {
  _Tahap _tahap = _Tahap.splash;

  void _ke(_Tahap t) {
    if (mounted) setState(() => _tahap = t);
  }

  @override
  Widget build(BuildContext context) {
    final Widget anak = switch (_tahap) {
      _Tahap.splash => SplashScreen(
          key: const ValueKey('splash'),
          onSelesai: (sudah) => _ke(sudah ? _Tahap.welcome : _Tahap.onboarding),
        ),
      _Tahap.onboarding => OnboardingScreen(
          key: const ValueKey('onboarding'),
          onSelesai: () => _ke(_Tahap.welcome),
        ),
      _Tahap.welcome => const WelcomeScreen(key: ValueKey('welcome')),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 620),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: anak,
    );
  }
}
