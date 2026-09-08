import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// ============================================================
///  XyMorphBg — latar "morphing" dengan gumpalan kabur melayang
/// ============================================================
///  Elemen elips/lingkaran blur yang bergerak perlahan (tanpa henti)
///  untuk kesan elemen "melayang seperti bergerak" — dipakai di layar
///  pembaruan & popup rilis. Ringan: hanya beberapa lingkaran + blur,
///  dihentikan otomatis bila tab tidak terlihat (via TickerMode).
class XyMorphBg extends StatefulWidget {
  const XyMorphBg({super.key, this.jumlah = 6, this.saturasi = 1.0});
  final int jumlah;
  final double saturasi;

  @override
  State<XyMorphBg> createState() => _XyMorphBgState();
}

class _XyMorphBgState extends State<XyMorphBg>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
      repeat: true,
      repeatReverse: true);
  late final List<_Gumpal> _b;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random(7);
    const pal = [Color(0xFFB492DF), Color(0xFFE0C9EF), Color(0xFFD9A6E8)];
    _b = List.generate(widget.jumlah, (i) {
      return _Gumpal(
        warna: pal[i % pal.length],
        r: 60 + rnd.nextInt(70),
        dx: rnd.nextDouble() * 1.2,
        dy: rnd.nextDouble() * 1.2,
        base: (i * 0.37 + rnd.nextDouble() * .3),
      );
    });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        return Stack(
          clipBehavior: Clip.none,
          children: _b.map((b) {
            // lintasan lingkar perlahan + naik/turun, agar "melayang".
            final x = ((b.dx + math.sin(t * 2 * math.pi + b.base)) / 2) * 1;
            final y = ((b.dy + math.cos(t * 2 * math.pi + b.base * 2)) / 2);
            return Positioned(
              left: (x * MediaQuery.of(context).size.width) - b.r / 2,
              top: (y * 200 + 40) - b.r / 2 + math.sin(t * math.pi) * 14,
              child: Transform.scale(
                scale: 1 + math.sin(t * 2 * math.pi + b.base) * .08,
                child: Container(
                  width: b.r,
                  height: b.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      b.warna.withOpacity(.38 * widget.saturasi),
                      b.warna.withOpacity(.06),
                      Colors.transparent,
                    ]),
                    boxShadow: [
                      BoxShadow(
                          color: b.warna.withOpacity(.25),
                          blurRadius: 40),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _Gumpal {
  final Color warna;
  final double r, dx, dy, base;
  _Gumpal(
      {required this.warna,
      required this.r,
      required this.dx,
      required this.dy,
      required this.base});
}

/// Sedikit overlay noise agar terasa "elemen banyak melayang" tanpa berat.
class XyGlowDot extends StatelessWidget {
  const XyGlowDot({super.key, this.size = 6, this.color = XyTheme.lavender});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: color.withOpacity(.5), shape: BoxShape.circle),
    );
  }
}
