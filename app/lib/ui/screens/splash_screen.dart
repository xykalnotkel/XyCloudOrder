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
    return const AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, systemNavigationBarColor: XyTheme.ink,
        systemNavigationBarIconBrightness: Brightness.light),
      child: Scaffold(backgroundColor: XyTheme.ink,
        body: Center(child: XyWordmark(tinggi: 40, putih: true))),
    );
  }
}
