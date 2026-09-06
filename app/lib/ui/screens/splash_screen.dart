import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/prefs.dart';
import '../../core/theme.dart';
import '../widgets/common.dart';

/// Splash bermerek dengan animasi logo, orbit, dan progress bar tipis.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onSelesai});

  /// Dipanggil setelah animasi selesai: true jika onboarding sudah pernah dilihat.
  final void Function(bool onboardingSelesai) onSelesai;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _masuk =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  late final AnimationController _orbit =
      AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();

  late final Animation<double> _logoScale = CurvedAnimation(
    parent: _masuk,
    curve: const Interval(0, .55, curve: Curves.easeOutBack),
  );
  late final Animation<double> _teks = CurvedAnimation(
    parent: _masuk,
    curve: const Interval(.35, .8, curve: Curves.easeOut),
  );
  late final Animation<double> _bar = CurvedAnimation(
    parent: _masuk,
    curve: const Interval(.5, 1, curve: Curves.easeInOut),
  );

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _masuk.forward();
    _lanjut();
  }

  Future<void> _lanjut() async {
    final selesai = await Prefs.onboardingSelesai();
    await Future.delayed(const Duration(milliseconds: 2300));
    if (!mounted) return;
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    widget.onSelesai(selesai);
  }

  @override
  void dispose() {
    _masuk.dispose();
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: Stack(children: [
        const Positioned.fill(child: AuroraBackground(dark: true)),
        const Positioned.fill(child: DotGrid(color: Color(0x0DFFFFFF), gap: 26)),

        // orbit dekoratif
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _orbit,
            builder: (_, __) => CustomPaint(painter: _OrbitPainter(_orbit.value)),
          ),
        ),

        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ScaleTransition(
              scale: _logoScale,
              child: FadeTransition(
                opacity: _logoScale,
                child: const XyLogo(size: 96, radius: 30),
              ),
            ),
            const SizedBox(height: 26),
            FadeTransition(
              opacity: _teks,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, .35), end: Offset.zero).animate(_teks),
                child: Column(children: [
                  ShaderMask(
                    shaderCallback: (r) => XyTheme.gradAurora.createShader(r),
                    child: const Text(
                      'XyCloudOrder',
                      style: TextStyle(
                        fontSize: 29,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cloud PC  ·  Digital Account  ·  Realtime',
                    style: TextStyle(
                      color: Colors.white.withOpacity(.52),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .6,
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),

        // progress bar bawah
        Positioned(
          left: 0,
          right: 0,
          bottom: 58,
          child: Column(children: [
            SizedBox(
              width: 132,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AnimatedBuilder(
                  animation: _bar,
                  builder: (_, __) => LinearProgressIndicator(
                    value: _bar.value,
                    minHeight: 3,
                    backgroundColor: Colors.white.withOpacity(.10),
                    valueColor: const AlwaysStoppedAnimation(XyTheme.cyan),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            FadeTransition(
              opacity: _teks,
              child: Text(
                'PREMIUM EDITION',
                style: TextStyle(
                  color: Colors.white.withOpacity(.34),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2 - 30);
    for (var i = 0; i < 3; i++) {
      final r = 110.0 + i * 58;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = Colors.white.withOpacity(.05 - i * .012)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      final a = t * math.pi * 2 * (i.isEven ? 1 : -1) + i * 2.1;
      final p = Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r);
      canvas.drawCircle(p, 3.2 - i * .5, Paint()..color = [XyTheme.cyan, XyTheme.primary, XyTheme.violet][i].withOpacity(.85));
      canvas.drawCircle(p, 9 - i * 1.5, Paint()..color = [XyTheme.cyan, XyTheme.primary, XyTheme.violet][i].withOpacity(.18));
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter old) => old.t != t;
}
