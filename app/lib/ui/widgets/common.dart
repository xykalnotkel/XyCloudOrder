import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../data/realtime_service.dart';

// ============================================================
//  Kartu & permukaan
// ============================================================

/// Kartu premium: border tipis + shadow berlapis + efek tekan.
class XyCard extends StatefulWidget {
  const XyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.radius = XyRadius.lg,
    this.color,
    this.border = true,
    this.elevated = true,
    this.gradient,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final double radius;
  final Color? color;
  final bool border;
  final bool elevated;
  final Gradient? gradient;

  @override
  State<XyCard> createState() => _XyCardState();
}

class _XyCardState extends State<XyCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final body = AnimatedScale(
      scale: _down ? .975 : 1,
      duration: const Duration(milliseconds: 130),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: widget.padding,
        decoration: BoxDecoration(
          color: widget.gradient == null ? (widget.color ?? XyTheme.surface) : null,
          gradient: widget.gradient,
          borderRadius: BorderRadius.circular(widget.radius),
          border: widget.border ? Border.all(color: XyTheme.line) : null,
          boxShadow: widget.elevated ? (_down ? XyTheme.shadowXs : XyTheme.shadowSm) : null,
        ),
        child: widget.child,
      ),
    );

    if (widget.onTap == null) return body;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: body,
    );
  }
}

/// Wrapper agar widget apa pun punya feedback tekan yang halus.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = .96});
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _d = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _d = true),
      onTapUp: (_) => setState(() => _d = false),
      onTapCancel: () => setState(() => _d = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _d ? widget.scale : 1,
        duration: const Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}

// ============================================================
//  Tombol
// ============================================================

class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.gradient = XyTheme.gradPrimary,
    this.loading = false,
    this.height = 56,
    this.glowColor = XyTheme.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Gradient gradient;
  final bool loading;
  final double height;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    final mati = onPressed == null || loading;
    return Pressable(
      onTap: mati ? null : onPressed,
      scale: .975,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: height,
        decoration: BoxDecoration(
          gradient: mati ? null : gradient,
          color: mati ? const Color(0xFFE3DAF5) : null,
          borderRadius: BorderRadius.circular(XyRadius.tombol),
          boxShadow: mati ? null : XyTheme.glow(glowColor, .30),
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 19, color: mati ? XyTheme.muted : Colors.white),
                      const SizedBox(width: 9),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        color: mati ? XyTheme.muted : Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: -.1,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ============================================================
//  Label & indikator
// ============================================================

class Pill extends StatelessWidget {
  const Pill(this.teks, {super.key, this.warna = XyTheme.primary, this.icon, this.solid = false});
  final String teks;
  final Color warna;
  final IconData? icon;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
      decoration: BoxDecoration(
        color: solid ? warna : warna.withOpacity(.10),
        borderRadius: BorderRadius.circular(XyRadius.pill),
        border: solid ? null : Border.all(color: warna.withOpacity(.18)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 12.5, color: solid ? Colors.white : warna),
          const SizedBox(width: 4),
        ],
        Text(teks,
            style: TextStyle(
              color: solid ? Colors.white : warna,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: .1,
            )),
      ]),
    );
  }
}

/// Indikator koneksi realtime dengan pulse ring.
class LiveDot extends StatefulWidget {
  const LiveDot({super.key, required this.state, this.compact = false});
  final RealtimeState state;
  final bool compact;

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final online = widget.state == RealtimeState.online;
    final warna = online
        ? XyTheme.success
        : widget.state == RealtimeState.connecting
            ? XyTheme.warning
            : XyTheme.muted;
    final label = online
        ? 'Realtime'
        : widget.state == RealtimeState.connecting
            ? 'Menyambung'
            : 'Offline';

    final dot = SizedBox(
      width: 14,
      height: 14,
      child: Stack(alignment: Alignment.center, children: [
        if (online)
          AnimatedBuilder(
            animation: c,
            builder: (_, __) => Container(
              width: 6 + c.value * 8,
              height: 6 + c.value * 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: warna.withOpacity((1 - c.value) * .35),
              ),
            ),
          ),
        Container(width: 7, height: 7, decoration: BoxDecoration(color: warna, shape: BoxShape.circle)),
      ]),
    );

    if (widget.compact) return dot;

    return Container(
      padding: const EdgeInsets.fromLTRB(7, 5, 11, 5),
      decoration: BoxDecoration(
        color: warna.withOpacity(.09),
        borderRadius: BorderRadius.circular(XyRadius.pill),
        border: Border.all(color: warna.withOpacity(.16)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        dot,
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: warna, fontSize: 11, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.judul, {super.key, this.sub, this.aksi, this.onAksi, this.top = 26});
  final String judul;
  final String? sub;
  final String? aksi;
  final VoidCallback? onAksi;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, top, 0, 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(judul, style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800, letterSpacing: -.45)),
            if (sub != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(sub!, style: const TextStyle(fontSize: 12.5, color: XyTheme.muted)),
              ),
          ]),
        ),
        if (aksi != null)
          Pressable(
            onTap: onAksi,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Row(children: [
                Text(aksi!,
                    style: const TextStyle(color: XyTheme.primary, fontWeight: FontWeight.w800, fontSize: 13)),
                const Icon(Icons.chevron_right_rounded, size: 18, color: XyTheme.primary),
              ]),
            ),
          ),
      ]),
    );
  }
}

class SpecChip extends StatelessWidget {
  const SpecChip(this.icon, this.teks, {super.key});
  final IconData icon;
  final String teks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(color: XyTheme.lineSoft, borderRadius: BorderRadius.circular(9)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: XyTheme.muted),
        const SizedBox(width: 5),
        Text(teks, style: const TextStyle(fontSize: 11.5, color: XyTheme.inkSoft, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ============================================================
//  Thumbnail generatif (tanpa aset eksternal)
// ============================================================

class GradientThumb extends StatelessWidget {
  const GradientThumb({
    super.key,
    required this.seed,
    this.icon,
    this.size = 56,
    this.height,
    this.radius = XyRadius.md,
  });

  final String seed;
  final IconData? icon;
  final double size;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final h = seed.codeUnits.fold<int>(0, (a, b) => a + b * 7);
    final hue = (h * 23 % 360).toDouble();
    final c1 = HSLColor.fromAHSL(1, hue, .68, .60).toColor();
    final c2 = HSLColor.fromAHSL(1, (hue + 38) % 360, .70, .44).toColor();
    final tinggi = height ?? size;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: tinggi,
        child: Stack(fit: StackFit.expand, children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [c1, c2], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
          ),
          CustomPaint(painter: _MeshPainter(hue)),
          Center(
            child: Icon(icon ?? Icons.memory_rounded,
                color: Colors.white.withOpacity(.95), size: tinggi * .40),
          ),
        ]),
      ),
    );
  }
}

class _MeshPainter extends CustomPainter {
  _MeshPainter(this.hue);
  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(.10);
    canvas.drawCircle(Offset(size.width * .82, size.height * .18), size.shortestSide * .42, p);
    canvas.drawCircle(Offset(size.width * .12, size.height * .92), size.shortestSide * .34,
        Paint()..color = Colors.black.withOpacity(.07));
    final path = Path()
      ..moveTo(0, size.height * .74)
      ..quadraticBezierTo(size.width * .4, size.height * .5, size.width, size.height * .88)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white.withOpacity(.06));
  }

  @override
  bool shouldRepaint(covariant _MeshPainter old) => old.hue != hue;
}

// ============================================================
//  Skeleton / shimmer
// ============================================================

class Shimmer extends StatefulWidget {
  const Shimmer({super.key, this.width = double.infinity, this.height = 16, this.radius = 8});
  final double width, height, radius;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(-1 + c.value * 3, 0),
            end: Alignment(c.value * 3, 0),
            colors: const [Color(0xFFF1EAFF), Color(0xFFFBF8FF), Color(0xFFF1EAFF)],
          ),
        ),
      ),
    );
  }
}

// ============================================================
//  Empty state
// ============================================================

class Kosong extends StatelessWidget {
  const Kosong({super.key, required this.icon, required this.judul, this.sub, this.aksi, this.ilustrasi = 'kosong'});

  /// Nama berkas ilustrasi di assets/ilustrasi (tanpa .png). Kosongkan untuk memakai ikon saja.
  final String ilustrasi;
  final IconData icon;
  final String judul;
  final String? sub;
  final Widget? aksi;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
          if (ilustrasi.isEmpty)
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [XyTheme.primary.withOpacity(.10), XyTheme.violet.withOpacity(.10)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(icon, size: 34, color: XyTheme.primary),
            )
          else
            Stack(alignment: Alignment.center, children: [
              Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    XyTheme.violet.withOpacity(.14),
                    XyTheme.violet.withOpacity(.03),
                    Colors.transparent,
                  ]),
                ),
              ),
              XyIlustrasi(ilustrasi, tinggi: 168),
            ]),
          const SizedBox(height: 14),
          Text(judul, textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, letterSpacing: -.2)),
          if (sub != null) ...[
            const SizedBox(height: 7),
            Text(sub!, textAlign: TextAlign.center,
                style: const TextStyle(color: XyTheme.muted, fontSize: 13, height: 1.55)),
          ],
          if (aksi != null) ...[const SizedBox(height: 20), aksi!],
        ]),
      ),
    );
  }
}

// ============================================================
//  Logo
// ============================================================

/// Logo resmi XyCloudStore (ikon awan-X ungu).
class XyLogo extends StatelessWidget {
  const XyLogo({super.key, this.size = 64, this.radius = 22, this.putih = false, this.kotak = true, this.glow = true});
  final double size;
  final double radius;

  /// Pakai versi putih untuk latar ungu gelap.
  final bool putih;

  /// Tampilkan kartu berlatar; kalau false hanya gambar logonya.
  final bool kotak;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final gambar = Image.asset(
      putih ? 'assets/brand/logo_icon_putih.png' : 'assets/brand/logo_icon.png',
      width: size * (kotak ? .74 : 1),
      height: size * (kotak ? .74 : 1),
      filterQuality: FilterQuality.high,
    );
    if (!kotak) return SizedBox(width: size, height: size, child: Center(child: gambar));

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: putih ? Colors.white.withOpacity(.12) : Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: putih ? Border.all(color: Colors.white.withOpacity(.18)) : Border.all(color: XyTheme.line),
        boxShadow: glow && !putih ? XyTheme.glow(XyTheme.primary, .16) : null,
      ),
      child: Center(child: gambar),
    );
  }
}

/// Wordmark resmi XyCloudStore.
class XyWordmark extends StatelessWidget {
  const XyWordmark({super.key, this.tinggi = 30, this.putih = false});
  final double tinggi;
  final bool putih;

  @override
  Widget build(BuildContext context) => Image.asset(
        putih ? 'assets/brand/wordmark_putih.png' : 'assets/brand/wordmark.png',
        height: tinggi,
        filterQuality: FilterQuality.high,
      );
}

/// Ilustrasi 3D bawaan aplikasi (hasil generate, latar sudah transparan).
class XyIlustrasi extends StatelessWidget {
  const XyIlustrasi(this.nama, {super.key, this.tinggi = 200});
  final String nama; // sewa | akun | cs | dompet | kosong | sukses
  final double tinggi;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/ilustrasi/$nama.png',
        height: tinggi,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      );
}


// ============================================================
//  Latar dekoratif
// ============================================================

/// Blob gradien lembut untuk latar layar onboarding / welcome.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, this.child, this.dark = false});
  final Widget? child;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: dark ? XyTheme.gradMidnight : const LinearGradient(
              colors: [Color(0xFFFDFBFF), Color(0xFFF4EEFF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      Positioned(
        top: -110,
        right: -80,
        child: _Blob(color: XyTheme.primary.withOpacity(dark ? .38 : .16), size: 300),
      ),
      Positioned(
        top: 140,
        left: -120,
        child: _Blob(color: XyTheme.violet.withOpacity(dark ? .30 : .13), size: 280),
      ),
      Positioned(
        bottom: -90,
        right: -60,
        child: _Blob(color: XyTheme.cyan.withOpacity(dark ? .26 : .12), size: 260),
      ),
      if (child != null) Positioned.fill(child: child!),
    ]);
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
      ),
    );
  }
}

/// Grid titik halus ala dashboard premium.
class DotGrid extends StatelessWidget {
  const DotGrid({super.key, this.color = const Color(0x14FFFFFF), this.gap = 22});
  final Color color;
  final double gap;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _DotPainter(color, gap), size: Size.infinite);
}

class _DotPainter extends CustomPainter {
  _DotPainter(this.color, this.gap);
  final Color color;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    for (double y = 0; y < size.height; y += gap) {
      for (double x = 0; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 1.1, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotPainter old) => false;
}

/// Animasi masuk berurutan untuk daftar item.
class FadeInUp extends StatefulWidget {
  const FadeInUp({super.key, required this.child, this.delay = Duration.zero, this.offset = 18});
  final Widget child;
  final Duration delay;
  final double offset;

  @override
  State<FadeInUp> createState() => _FadeInUpState();
}

class _FadeInUpState extends State<FadeInUp> with SingleTickerProviderStateMixin {
  late final AnimationController c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) c.forward();
    });
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: c, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: curve,
      builder: (_, child) => Opacity(
        opacity: curve.value,
        child: Transform.translate(offset: Offset(0, (1 - curve.value) * widget.offset), child: child),
      ),
      child: widget.child,
    );
  }
}

/// Angka yang menghitung naik saat berubah (untuk saldo).
class AnimatedRupiah extends StatelessWidget {
  const AnimatedRupiah(this.nilai, {super.key, required this.style, required this.format});
  final int nilai;
  final TextStyle style;
  final String Function(num) format;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: nilai.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(format(v.round()), style: style),
    );
  }
}

/// Ring progres melingkar untuk provisioning.
class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.value, this.size = 74, this.color = XyTheme.primary, this.label});
  final double value;
  final double size;
  final Color color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0, 1)),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(v, color),
          ),
        ),
        Text(label ?? '${(value * 100).round()}%',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: size * .21, letterSpacing: -.4)),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.color);
  final double v;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * .10;
    canvas.drawArc(rect.deflate(stroke / 2), 0, math.pi * 2, false,
        Paint()..color = XyTheme.line..strokeWidth = stroke..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    canvas.drawArc(
      rect.deflate(stroke / 2),
      -math.pi / 2,
      math.pi * 2 * v,
      false,
      Paint()
        ..shader = LinearGradient(colors: [color, XyTheme.violet]).createShader(rect)
        ..strokeWidth = stroke
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.v != v;
}
