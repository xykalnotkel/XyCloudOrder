import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/prefs.dart';
import '../../core/theme.dart';
import '../widgets/common.dart';

/// Splash sederhana: hanya wordmark XyCloudStore di atas latar ungu.
/// Sengaja tanpa animasi supaya terasa cepat dan menyambung mulus
/// dengan splash bawaan Android.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.onSelesai, this.pesan});

  final void Function(bool onboardingSelesai)? onSelesai;
  final String? pesan;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.onSelesai != null) _lanjut();
  }

  Future<void> _lanjut() async {
    final selesai = await Prefs.onboardingSelesai();
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    widget.onSelesai!(selesai);
  }

  @override
  Widget build(BuildContext context) {
    // Container tidak punya konstruktor const → AnnotatedRegion di luar const,
    // bagian dalamnya saja yang di-const.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, systemNavigationBarColor: Color(0xFF100030),
        systemNavigationBarIconBrightness: Brightness.light),
      child: Scaffold(backgroundColor: XyTheme.primaryDark,
        body: Container(
          // gradMidnight #2E1065 → #100030: senada dengan splash native
          // (flutter_native_splash color #2E1065) supaya transisi mulus.
          decoration: const BoxDecoration(gradient: XyTheme.gradMidnight),
          child: const Center(child: XyWordmark(tinggi: 40, putih: true)),
        )),
    );
  }
}
