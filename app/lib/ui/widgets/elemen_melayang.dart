import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// ============================================================
///  Elemen melayang (Batch L)
/// ============================================================
///  Overlay partikel apung halus — ikon/gelembung kecil yang
///  bergerak naik pelan dengan goyangan sinus. Dipakai untuk
///  mempercantik login, register, blokir, dan halaman hero lain.
///  Ringan: satu AnimationController, tanpa rebuild layout.
class ElemenMelayang extends StatefulWidget {
  const ElemenMelayang({
    super.key,
    required this.child,
    this.jumlah = 9,
    this.ikon = const [Icons.auto_awesome_rounded, Icons.circle],
    this.warna,
    this.aktif = true,
  });

  final Widget child;
  final int jumlah;
  final List<IconData> ikon;
  final List<Color>? warna;
  final bool aktif;

  @override
  State<ElemenMelayang> createState() => _ElemenMelayangState();
}

class _ElemenMelayangState extends State<ElemenMelayang>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );
  late final List<_Partikel> _p;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random(7);
    _p = List.generate(widget.jumlah, (i) {
      return _Partikel(
        x: rnd.nextDouble(),
        fase: rnd.nextDouble(),
        ukuran: 6 + rnd.nextDouble() * 12,
        goyang: .02 + rnd.nextDouble() * .05,
        kecepatan: .6 + rnd.nextDouble() * .8,
        ikon: widget.ikon[i % widget.ikon.length],
      );
    });
    if (widget.aktif) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final warna = widget.warna ??
        [
          XyTheme.primary.withOpacity(.18),
          XyTheme.violet.withOpacity(.16),
          const Color(0xFF22D3EE).withOpacity(.14),
        ];
    return Stack(children: [
      widget.child,
      // Partikel di atas konten tapi menembus sentuhan.
      Positioned.fill(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => LayoutBuilder(
              builder: (_, box) => Stack(
                children: [
                  for (var i = 0; i < _p.length; i++)
                    Builder(builder: (_) {
                      final pt = _p[i];
                      final t = (_c.value * pt.kecepatan + pt.fase) % 1.0;
                      final y = box.maxHeight * (1.05 - t * 1.1);
                      final x = box.maxWidth *
                          (pt.x +
                              math.sin(t * 2 * math.pi * 2 + i) * pt.goyang);
                      final alpha =
                          math.sin(t * math.pi).clamp(0.0, 1.0);
                      return Positioned(
                        left: x,
                        top: y,
                        child: Opacity(
                          opacity: alpha,
                          child: Icon(pt.ikon,
                              size: pt.ukuran,
                              color: warna[i % warna.length]),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _Partikel {
  const _Partikel({
    required this.x,
    required this.fase,
    required this.ukuran,
    required this.goyang,
    required this.kecepatan,
    required this.ikon,
  });
  final double x;
  final double fase;
  final double ukuran;
  final double goyang;
  final double kecepatan;
  final IconData ikon;
}
