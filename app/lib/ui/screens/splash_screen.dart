import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/prefs.dart';
import '../../core/theme.dart';
import '../widgets/common.dart';

/// ============================================================
///  Splash bermerek XyCloudStore
/// ============================================================
///  Menyambung mulus dari splash bawaan Android: latar dan posisi
///  logonya sama, jadi tidak ada kedipan saat aplikasi dibuka.
///
///  Kalau [onSelesai] kosong, layar ini terus tampil (dipakai saat
///  aplikasi sedang memeriksa sesi login yang tersimpan).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.onSelesai, this.pesan});

  final void Function(bool onboardingSelesai)? onSelesai;
  final String? pesan;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _masuk =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1250));
  late final AnimationController _nafas =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat(reverse: true);

  late final Animation<double> _logo = CurvedAnimation(
    parent: _masuk,
    curve: const Interval(0, .5, curve: Curves.easeOutBack),
  );
  late final Animation<double> _teks = CurvedAnimation(
    parent: _masuk,
    curve: const Interval(.32, .78, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _bawah = CurvedAnimation(
    parent: _masuk,
    curve: const Interval(.55, 1, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: XyTheme.ink,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
    _masuk.forward();
    if (widget.onSelesai != null) _lanjut();
  }

  Future<void> _lanjut() async {
    final selesai = await Prefs.onboardingSelesai();
    await Future.delayed(const Duration(milliseconds: 1900));
    if (!mounted) return;
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
    widget.onSelesai!(selesai);
  }

  @override
  void dispose() {
    _masuk.dispose();
    _nafas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XyTheme.ink,
      body: Stack(children: [
        // ---- latar ungu berlapis ----
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A1033), Color(0xFF2E1065), Color(0xFF1A1033)],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _nafas,
            builder: (_, __) => CustomPaint(painter: _CahayaPainter(_nafas.value)),
          ),
        ),
        const Positioned.fill(child: DotGrid(color: Color(0x0DFFFFFF), gap: 30)),

        // ---- isi ----
        SafeArea(
          child: Column(children: [
            const Spacer(flex: 5),

            // logo dengan lingkaran nafas
            AnimatedBuilder(
              animation: Listenable.merge([_logo, _nafas]),
              builder: (_, __) {
                final skala = _logo.value;
                final nafas = 1 + math.sin(_nafas.value * math.pi) * .035;
                return Opacity(
                  opacity: _logo.value.clamp(0, 1),
                  child: Transform.scale(
                    scale: skala * nafas,
                    child: Stack(alignment: Alignment.center, children: [
                      Container(
                        width: 190,
                        height: 190,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            XyTheme.violet.withOpacity(.30),
                            XyTheme.violet.withOpacity(.06),
                            Colors.transparent,
                          ]),
                        ),
                      ),
                      Container(
                        width: 118,
                        height: 118,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(34),
                          boxShadow: [
                            BoxShadow(
                              color: XyTheme.violet.withOpacity(.45),
                              blurRadius: 46,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Image.asset('assets/brand/logo_icon.png', width: 82, height: 82),
                        ),
                      ),
                    ]),
                  ),
                );
              },
            ),

            const SizedBox(height: 30),

            FadeTransition(
              opacity: _teks,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, .3), end: Offset.zero).animate(_teks),
                child: Column(children: [
                  const XyWordmark(tinggi: 32, putih: true),
                  const SizedBox(height: 12),
                  Text(
                    'Sewa PC Cloud  ·  Akun Digital',
                    style: TextStyle(
                      color: Colors.white.withOpacity(.55),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .8,
                    ),
                  ),
                ]),
              ),
            ),

            const Spacer(flex: 5),

            // indikator halus di bawah
            FadeTransition(
              opacity: _bawah,
              child: Column(children: [
                SizedBox(
                  width: 128,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: Colors.white.withOpacity(.10),
                      valueColor: AlwaysStoppedAnimation(Colors.white.withOpacity(.75)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.pesan ?? 'Menyiapkan aplikasi',
                  style: TextStyle(
                    color: Colors.white.withOpacity(.42),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 42),
          ]),
        ),
      ]),
    );
  }
}

/// Dua bola cahaya lembut yang bergerak pelan di latar.
class _CahayaPainter extends CustomPainter {
  _CahayaPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final geser = math.sin(t * math.pi * 2) * 22;

    void bola(Offset pusat, double jari, Color warna) {
      canvas.drawCircle(
        pusat,
        jari,
        Paint()
          ..shader = RadialGradient(colors: [warna, warna.withOpacity(0)])
              .createShader(Rect.fromCircle(center: pusat, radius: jari)),
      );
    }

    bola(Offset(size.width * .18, size.height * .22 + geser), 190, XyTheme.violet.withOpacity(.22));
    bola(Offset(size.width * .86, size.height * .30 - geser), 160, XyTheme.primary.withOpacity(.24));
    bola(Offset(size.width * .70, size.height * .84 + geser * .6), 210, XyTheme.plum.withOpacity(.16));
  }

  @override
  bool shouldRepaint(covariant _CahayaPainter old) => old.t != t;
}
