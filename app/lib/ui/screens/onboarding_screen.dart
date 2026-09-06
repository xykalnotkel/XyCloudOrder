import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/prefs.dart';
import '../../core/theme.dart';
import '../widgets/common.dart';

class _Slide {
  const _Slide(this.judul, this.sorot, this.deskripsi, this.builder, this.warna);
  final String judul;
  final String sorot;
  final String deskripsi;
  final Widget Function(Animation<double>) builder;
  final Color warna;
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onSelesai});
  final VoidCallback onSelesai;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final _pc = PageController();
  int _i = 0;

  late final AnimationController _art =
      AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  late final List<_Slide> _slides = [
    _Slide(
      'Sewa PC kelas atas',
      'dalam hitungan detik',
      'RTX 4090, 128 GB RAM, latensi rendah dari Jakarta & Singapore. Bayar per jam, langsung nyala tanpa antre.',
      (a) => _ArtRig(a),
      XyTheme.primary,
    ),
    _Slide(
      'Akun digital resmi',
      'garansi penuh',
      'Steam, Game Pass, streaming, hingga tool produktivitas. Kredensial terkirim otomatis begitu pembayaran masuk.',
      (a) => _ArtVault(a),
      XyTheme.violet,
    ),
    _Slide(
      'Pantau semuanya',
      'secara realtime',
      'Status order, stok unit, dan chat customer service mengalir langsung dari server XyCloud. Tanpa perlu refresh.',
      (a) => _ArtPulse(a),
      XyTheme.cyan,
    ),
  ];

  Future<void> _selesai() async {
    await Prefs.tandaiOnboardingSelesai();
    if (!mounted) return;
    widget.onSelesai();
  }

  void _next() {
    if (_i == _slides.length - 1) {
      _selesai();
    } else {
      _pc.nextPage(duration: const Duration(milliseconds: 460), curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _pc.dispose();
    _art.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _slides[_i];
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [s.warna.withOpacity(.10), XyTheme.bg, XyTheme.bg],
                stops: const [0, .55, 1],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(children: [
            // ---- header ----
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(children: [
                const XyLogo(size: 34, radius: 12, glow: false),
                const SizedBox(width: 10),
                const Text('XyCloudOrder',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -.3)),
                const Spacer(),
                AnimatedOpacity(
                  opacity: _i == _slides.length - 1 ? 0 : 1,
                  duration: const Duration(milliseconds: 250),
                  child: TextButton(
                    onPressed: _i == _slides.length - 1 ? null : _selesai,
                    style: TextButton.styleFrom(foregroundColor: XyTheme.muted),
                    child: const Text('Lewati'),
                  ),
                ),
              ]),
            ),

            // ---- ilustrasi + teks ----
            Expanded(
              child: PageView.builder(
                controller: _pc,
                onPageChanged: (v) => setState(() => _i = v),
                itemCount: _slides.length,
                itemBuilder: (_, i) {
                  final sl = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(children: [
                      const Spacer(flex: 2),
                      SizedBox(height: 260, child: sl.builder(_art)),
                      const Spacer(flex: 2),
                      FadeInUp(
                        key: ValueKey('t$i$_i'),
                        child: Column(children: [
                          Text.rich(
                            TextSpan(children: [
                              TextSpan(text: '${sl.judul}\n'),
                              TextSpan(
                                text: sl.sorot,
                                style: TextStyle(color: sl.warna),
                              ),
                            ]),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 28,
                              height: 1.22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.1,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            sl.deskripsi,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: XyTheme.muted, fontSize: 14, height: 1.65, fontWeight: FontWeight.w500),
                          ),
                        ]),
                      ),
                      const Spacer(flex: 3),
                    ]),
                  );
                },
              ),
            ),

            // ---- indikator + tombol ----
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 26),
              child: Column(children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_slides.length, (i) {
                    final on = i == _i;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 3.5),
                      width: on ? 26 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: on ? s.warna : XyTheme.line,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),
                GradientButton(
                  label: _i == _slides.length - 1 ? 'Mulai Sekarang' : 'Lanjut',
                  icon: _i == _slides.length - 1 ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
                  gradient: LinearGradient(colors: [s.warna, Color.lerp(s.warna, XyTheme.violet, .45)!]),
                  glowColor: s.warna,
                  onPressed: _next,
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ============================================================
//  Ilustrasi (semua digambar sendiri, tanpa aset)
// ============================================================

class _ArtRig extends StatelessWidget {
  const _ArtRig(this.a);
  final Animation<double> a;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: a,
      builder: (_, __) {
        final t = a.value;
        return Stack(alignment: Alignment.center, children: [
          _Halo(color: XyTheme.primary, t: t),
          Transform.translate(
            offset: Offset(0, math.sin(t * math.pi * 2) * 6),
            child: Container(
              width: 210,
              height: 138,
              decoration: BoxDecoration(
                gradient: XyTheme.gradMidnight,
                borderRadius: BorderRadius.circular(18),
                boxShadow: XyTheme.glow(XyTheme.primary, .28),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  _dot(XyTheme.danger),
                  _dot(XyTheme.warning),
                  _dot(XyTheme.success),
                  const Spacer(),
                  Text('XyUltra',
                      style: TextStyle(color: Colors.white.withOpacity(.5), fontSize: 9, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 14),
                ...List.generate(3, (i) {
                  final v = (math.sin(t * math.pi * 2 + i) + 1) / 2;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Row(children: [
                      Text(['GPU', 'CPU', 'RAM'][i],
                          style: TextStyle(color: Colors.white.withOpacity(.45), fontSize: 8.5, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: .35 + v * .55,
                            minHeight: 5,
                            backgroundColor: Colors.white.withOpacity(.09),
                            valueColor: AlwaysStoppedAnimation(
                                [XyTheme.cyan, XyTheme.primary, XyTheme.violet][i]),
                          ),
                        ),
                      ),
                    ]),
                  );
                }),
              ]),
            ),
          ),
          Positioned(
            right: 14,
            top: 22,
            child: _FloatChip(t: t, phase: .2, icon: Icons.bolt_rounded, teks: 'Instant On', warna: XyTheme.cyan),
          ),
          Positioned(
            left: 6,
            bottom: 34,
            child: _FloatChip(t: t, phase: .7, icon: Icons.speed_rounded, teks: '12 ms', warna: XyTheme.primary),
          ),
        ]);
      },
    );
  }

  Widget _dot(Color c) => Container(
        width: 7,
        height: 7,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(color: c.withOpacity(.85), shape: BoxShape.circle),
      );
}

class _ArtVault extends StatelessWidget {
  const _ArtVault(this.a);
  final Animation<double> a;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: a,
      builder: (_, __) {
        final t = a.value;
        return Stack(alignment: Alignment.center, children: [
          _Halo(color: XyTheme.violet, t: t),
          ...List.generate(3, (i) {
            final off = (i - 1) * 1.0;
            return Transform.translate(
              offset: Offset(off * 26, off * 16 + math.sin(t * math.pi * 2 + i) * 4),
              child: Transform.rotate(
                angle: off * .09,
                child: Container(
                  width: 176,
                  height: 108,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: i == 1
                          ? [XyTheme.violet, XyTheme.primary]
                          : [Colors.white, const Color(0xFFF2F5FB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: i == 1 ? Colors.transparent : XyTheme.line),
                    boxShadow: i == 1 ? XyTheme.glow(XyTheme.violet, .30) : XyTheme.shadowSm,
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.vpn_key_rounded,
                          size: 16, color: i == 1 ? Colors.white : XyTheme.muted),
                      const Spacer(),
                      Icon(Icons.verified_rounded,
                          size: 15, color: i == 1 ? Colors.white70 : XyTheme.success),
                    ]),
                    const Spacer(),
                    Container(
                      width: 88,
                      height: 7,
                      decoration: BoxDecoration(
                        color: (i == 1 ? Colors.white : XyTheme.line).withOpacity(i == 1 ? .8 : 1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      width: 54,
                      height: 7,
                      decoration: BoxDecoration(
                        color: (i == 1 ? Colors.white : XyTheme.line).withOpacity(i == 1 ? .45 : 1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ]),
                ),
              ),
            );
          }),
          Positioned(
            top: 30,
            right: 2,
            child: _FloatChip(t: t, phase: .1, icon: Icons.shield_rounded, teks: 'Garansi 30 hari', warna: XyTheme.success),
          ),
        ]);
      },
    );
  }
}

class _ArtPulse extends StatelessWidget {
  const _ArtPulse(this.a);
  final Animation<double> a;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: a,
      builder: (_, __) {
        final t = a.value;
        return Stack(alignment: Alignment.center, children: [
          _Halo(color: XyTheme.cyan, t: t),
          CustomPaint(size: const Size(250, 210), painter: _WavePainter(t)),
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: XyTheme.gradAurora,
              boxShadow: XyTheme.glow(XyTheme.cyan, .40),
            ),
            child: const Icon(Icons.sync_rounded, color: Colors.white, size: 38),
          ),
          Positioned(
            left: 0,
            top: 26,
            child: _FloatChip(t: t, phase: .0, icon: Icons.headset_mic_rounded, teks: 'CS Online', warna: XyTheme.success),
          ),
          Positioned(
            right: 0,
            bottom: 36,
            child: _FloatChip(t: t, phase: .5, icon: Icons.notifications_active_rounded, teks: 'Order Aktif', warna: XyTheme.primary),
          ),
        ]);
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 4; i++) {
      final p = ((t + i * .25) % 1);
      canvas.drawCircle(
        c,
        50 + p * 92,
        Paint()
          ..color = XyTheme.cyan.withOpacity((1 - p) * .30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => old.t != t;
}

class _Halo extends StatelessWidget {
  const _Halo({required this.color, required this.t});
  final Color color;
  final double t;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250 + math.sin(t * math.pi * 2) * 8,
      height: 250 + math.sin(t * math.pi * 2) * 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color.withOpacity(.16), color.withOpacity(0)]),
      ),
    );
  }
}

class _FloatChip extends StatelessWidget {
  const _FloatChip({required this.t, required this.phase, required this.icon, required this.teks, required this.warna});
  final double t, phase;
  final IconData icon;
  final String teks;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, math.sin((t + phase) * math.pi * 2) * 7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(XyRadius.pill),
          border: Border.all(color: XyTheme.line),
          boxShadow: XyTheme.shadowSm,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: warna),
          const SizedBox(width: 6),
          Text(teks, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}
