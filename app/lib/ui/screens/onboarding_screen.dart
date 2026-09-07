import 'package:flutter/material.dart';
import '../../core/prefs.dart';
import '../../core/theme.dart';
import '../widgets/common.dart';

/// Ilustrasi 3D (hasil generate AI, latar sudah dibersihkan) dengan lingkaran ungu lembut.
class _Art extends StatelessWidget {
  const _Art(this.nama);
  final String nama;

  @override
  Widget build(BuildContext context) {
    return Stack(alignment: Alignment.center, children: [
      Container(
        width: 250,
        height: 250,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            XyTheme.violet.withOpacity(.18),
            XyTheme.violet.withOpacity(.04),
            Colors.transparent,
          ]),
        ),
      ),
      XyIlustrasi(nama, tinggi: 238),
    ]);
  }
}

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
      (a) => const _Art('sewa'),
      XyTheme.primary,
    ),
    _Slide(
      'Akun digital resmi',
      'garansi penuh',
      'Steam, Game Pass, streaming, hingga tool produktivitas. Kredensial terkirim otomatis begitu pembayaran masuk.',
      (a) => const _Art('akun'),
      XyTheme.violet,
    ),
    _Slide(
      'Pantau semuanya',
      'langsung',
      'Status order, stok unit, dan chat customer service mengalir langsung dari server XyCloud. Tanpa perlu refresh.',
      (a) => const _Art('cs'),
      XyTheme.plum,
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
                colors: [s.warna.withOpacity(.10), XyTheme.of(context).bg, XyTheme.of(context).bg],
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
                const XyWordmark(tinggi: 26),
                const Spacer(),
                AnimatedOpacity(
                  opacity: _i == _slides.length - 1 ? 0 : 1,
                  duration: const Duration(milliseconds: 250),
                  child: TextButton(
                    onPressed: _i == _slides.length - 1 ? null : _selesai,
                    style: TextButton.styleFrom(foregroundColor: XyTheme.of(context).muted),
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
                            style:  TextStyle(
                                color: XyTheme.of(context).muted, fontSize: 14, height: 1.65, fontWeight: FontWeight.w500),
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
                        color: on ? s.warna : XyTheme.of(context).line,
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
