import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/motion.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme.dart';
import '../../data/realtime_service.dart';

// ============================================================
//  Gambar jaringan dengan cache disk di perangkat
// ============================================================
/// Muat gambar dari CDN lalu SIMPAN di penyimpanan lokal (disk cache)
/// supaya membuka ulang instan dan tidak mengunduh tiap kali.
/// Tetap tampil utuh di tengah loading & saat error.
class AppImage extends StatelessWidget {
  const AppImage(this.url,
      {super.key,
      this.tinggi,
      this.lebar,
      this.fit = BoxFit.cover,
      this.radius,
      this.placeholderKet = false});
  final String url;
  final double? tinggi, lebar;
  final BoxFit fit;
  final double? radius;
  final bool placeholderKet;

  @override
  Widget build(BuildContext context) {
    Widget isi() => CachedNetworkImage(
          imageUrl: url,
          height: tinggi,
          width: lebar,
          fit: fit,
          memCacheWidth: (tinggi ?? 200).toInt() * 3,
          fadeInDuration: const Duration(milliseconds: 150),
          placeholder: (_, __) => placeholderKet
              ? const Shimmer()
              : const SizedBox.shrink(),
          errorWidget: (_, __, ___) => Container(
            color: XyTheme.of(context).primarySoft,
            child: const Icon(Icons.broken_image_outlined,
                color: XyTheme.muted),
          ),
        );
    if (radius == null) return isi();
    return ClipRRect(
        borderRadius: BorderRadius.circular(radius!), child: isi());
  }
}

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
          color: widget.gradient == null ? (widget.color ?? XyTheme.of(context).surface) : null,
          gradient: widget.gradient,
          borderRadius: BorderRadius.circular(widget.radius),
          border: widget.border ? Border.all(color: XyTheme.of(context).line) : null,
          boxShadow: widget.elevated ? (_down ? XyTheme.shadowXs : XyTheme.shadowSm) : null,
        ),
        child: RepaintBoundary(child: widget.child),
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

class GradientButton extends StatefulWidget {
  GradientButton({
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
  State<GradientButton> createState() => _GradientButtonState();
}

/// Tombol aksen “3D tapi 2D”: bidang solid + tepi bawah tegas (bayangan keras
/// tanpa blur) + saat ditekan turun 3px. Dipakai konsisten di seluruh aplikasi.
class _GradientButtonState extends State<GradientButton> {
  bool _tekan = false;

  Color get _tepi => Color.lerp(widget.glowColor, Colors.black, .34)!;
  Color get _atas => Color.lerp(widget.glowColor, Colors.white, .10)!;

  @override
  Widget build(BuildContext context) {
    final mati = widget.onPressed == null || widget.loading;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: mati ? null : (_) => setState(() => _tekan = true),
      onTapUp: mati ? null : (_) => setState(() => _tekan = false),
      onTapCancel: () => setState(() => _tekan = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        height: widget.height,
        transform: Matrix4.translationValues(0, _tekan ? 3 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(XyRadius.tombol),
          gradient: mati
              ? null
              : LinearGradient(
                  colors: [_atas, widget.glowColor, widget.glowColor],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, .42, 1],
                ),
          color: mati ? XyTheme.of(context).primarySoft : null,
          boxShadow: mati
              ? null
              : [
                  // Tepi bawah “3D”: bayangan keras tanpa blur, hilang saat ditekan.
                  BoxShadow(
                    color: _tepi,
                    offset: Offset(0, _tekan ? 1 : 4),
                    blurRadius: 0,
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.transparent,
                    offset: Offset(0, 0),
                    blurRadius: 0,
                  ),
                ],
        ),
        child: Center(
          child: widget.loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: Colors.white))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon,
                          size: 19,
                          color: mati ? XyTheme.of(context).muted : Colors.white),
                      const SizedBox(width: 9),
                    ],
                    Text(
                      widget.label,
                      style: TextStyle(
                        color:
                            mati ? XyTheme.of(context).muted : Colors.white,
                        fontWeight: FontWeight.w700,
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
  Pill(this.teks, {super.key, this.warna = XyTheme.primary, this.icon, this.solid = false});
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
              fontWeight: FontWeight.w700,
              letterSpacing: .1,
            )),
      ]),
    );
  }
}

/// Indikator koneksi realtime dengan pulse ring.
class LiveDot extends StatelessWidget {
  const LiveDot({super.key,required this.state,this.compact=true});
  final RealtimeState state;
  final bool compact;
  @override Widget build(BuildContext context) {
    final online=state==RealtimeState.online;
    final color=online?XyTheme.success:state==RealtimeState.connecting?XyTheme.warning:XyTheme.of(context).muted;
    return Tooltip(message:online?'Terhubung ke server':state==RealtimeState.connecting?'Menghubungkan server':'Koneksi terputus',
      child:Padding(padding:const EdgeInsets.all(4),child:Container(width:8,height:8,decoration:BoxDecoration(color:color,shape:BoxShape.circle))));
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
            Text(judul, style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.w700, letterSpacing: -.45)),
            if (sub != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(sub!, style:  TextStyle(fontSize: 12.5, color: XyTheme.of(context).muted)),
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
                    style: const TextStyle(color: XyTheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                Icon(Icons.chevron_right_rounded, size: 18, color: XyTheme.primary),
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
      decoration: BoxDecoration(color: XyTheme.of(context).lineSoft, borderRadius: BorderRadius.circular(9)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: XyTheme.of(context).muted),
        const SizedBox(width: 5),
        Text(teks, style:  TextStyle(fontSize: 11.5, color: XyTheme.of(context).inkSoft, fontWeight: FontWeight.w700)),
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
  Widget build(BuildContext context) => Container(
    width:size,height:height??size,
    decoration:BoxDecoration(color:XyTheme.of(context).primarySoft,borderRadius:BorderRadius.circular(radius)),
    alignment:Alignment.center,
    child:Icon(icon??Icons.memory_rounded,color:XyTheme.of(context).accent,size:(height??size)*.40),
  );
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
            colors: [XyTheme.shimmerA, XyTheme.shimmerB, XyTheme.shimmerA],
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
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, letterSpacing: -.2)),
          if (sub != null) ...[
            const SizedBox(height: 7),
            Text(sub!, textAlign: TextAlign.center,
                style:  TextStyle(color: XyTheme.of(context).muted, fontSize: 13, height: 1.55)),
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
        border: putih ? Border.all(color: Colors.white.withOpacity(.18)) : Border.all(color: XyTheme.of(context).line),
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
  const AuroraBackground({super.key,this.child,this.dark=false});
  final Widget? child;final bool dark;
  @override Widget build(BuildContext context)=>SizedBox.expand(child:ColoredBox(color:dark?XyTheme.ink:XyTheme.of(context).bg,child:child));
}
class DotGrid extends StatelessWidget {
  const DotGrid({super.key,this.color=const Color(0x14FFFFFF),this.gap=22});
  final Color color;final double gap;
  @override Widget build(BuildContext context)=>const SizedBox.shrink();
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
  ProgressRing({super.key, required this.value, this.size = 74, this.color = XyTheme.primary, this.label});
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
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: size * .21, letterSpacing: -.4)),
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

/// ------------------------------------------------------------
///  XyBarisMenu — baris menu berkartu (ikon bulat + judul + sub).
/// ------------------------------------------------------------
///  Sebelumnya disalin tiga kali sebagai `_Baris`/`_Menu` di berkas
///  pengaturan, tentang, dan profil dengan ukuran teks yang berbeda-beda.
///  Sekarang satu widget supaya jarak, ukuran ikon, dan tipografinya sama.
class XyBarisMenu extends StatelessWidget {
  const XyBarisMenu({
    super.key,
    required this.ikon,
    required this.judul,
    required this.sub,
    this.onTap,
    this.tujuan,
    this.ikonWarna,
  }) : assert(onTap != null || tujuan != null, 'Isi onTap atau tujuan.');

  final IconData ikon;
  final String judul;
  final String sub;
  final VoidCallback? onTap;
  final Widget? tujuan;
  final Color? ikonWarna;

  @override
  Widget build(BuildContext context) {
    final warna = ikonWarna ?? XyTheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: XyCard(
        padding: const EdgeInsets.all(15),
        onTap: onTap ?? () => Navigator.push(context, xyRoute(tujuan!)),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: warna.withOpacity(.11),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(ikon, size: 20, color: warna),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(judul, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 3),
              Text(sub,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: XyTheme.of(context).muted),
        ]),
      ),
    );
  }
}

/// ------------------------------------------------------------
///  XyLabel — judul kecil di atas bidang input atau kelompok.
/// ------------------------------------------------------------
class XyLabel extends StatelessWidget {
  const XyLabel(this.teks, {super.key});
  final String teks;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9, left: 2),
        child: Text(teks,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, letterSpacing: -.1)),
      );
}
