import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// ============================================================
///  XyMorphBg — latar "morphing" violet-indigo glossy v3.2
/// ============================================================
///  Elemen elips/lingkaran blur yang bergerak perlahan
///  untuk kesan elemen "melayang seperti bergerak" — dipakai di layar
///  pembaruan & popup rilis. Palet disesuaikan ke referensi popup:
///  #100030 (indigo tua) + #8B5CF6 / #A855F7 / #7C3AED
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
      duration: const Duration(seconds: 9));
  late final List<_Gumpal> _b;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random(7);
    // Palet baru: violet-indigo glossy (sesuai PopupUpdate.md)
    const pal = [
      Color(0xFF8B5CF6), // violet terang #8B5CF6
      Color(0xFFA855F7), // plum/magenta-violet #A855F7
      Color(0xFF7C3AED), // primary #7C3AED
      Color(0xFFC4B5FD), // lavender lembut
    ];
    _b = List.generate(widget.jumlah, (i) {
      return _Gumpal(
        warna: pal[i % pal.length],
        r: (60 + rnd.nextInt(90)).toDouble(),
        dx: rnd.nextDouble() * 1.2,
        dy: rnd.nextDouble() * 1.2,
        base: (i * 0.37 + rnd.nextDouble() * .3),
      );
    });
    _c.repeat(reverse: true); // repeat+reverse via method, bukan parameter konstruktor
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
                      b.warna.withOpacity(.42 * widget.saturasi),
                      b.warna.withOpacity(.08),
                      Colors.transparent,
                    ]),
                    boxShadow: [
                      BoxShadow(
                          color: b.warna.withOpacity(.30),
                          blurRadius: 44),
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

/// Dot glow kecil untuk aksen.
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
          color: color.withOpacity(.55), shape: BoxShape.circle),
    );
  }
}
