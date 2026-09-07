import 'dart:async';
import 'package:flutter/material.dart';
import 'tautan_promo.dart';
import '../../core/theme.dart';
import '../../models/models.dart';

/// Slider banner promo di beranda.
/// Isi banner diambil dari server (tabel `banners`) dan bisa diubah kapan saja
/// lewat dashboard admin tanpa perlu update aplikasi.
class BannerSlider extends StatefulWidget {
  const BannerSlider({super.key, required this.items, this.tinggi = 244});
  final List<PromoBanner> items;
  final double tinggi;

  @override
  State<BannerSlider> createState() => _BannerSliderState();
}

class _BannerSliderState extends State<BannerSlider> {
  late final PageController _pc = PageController(viewportFraction: .96);
  Timer? _auto;
  int _index = 0;
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _pc.addListener(() => setState(() => _page = _pc.page ?? 0));
    _mulaiAuto();
  }

  void _mulaiAuto() {
    _auto?.cancel();
    if (widget.items.length < 2) return;
    _auto = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_pc.hasClients) return;
      final next = (_index + 1) % widget.items.length;
      _pc.animateToPage(
        next,
        duration: const Duration(milliseconds: 620),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void didUpdateWidget(covariant BannerSlider old) {
    super.didUpdateWidget(old);
    if (old.items.length != widget.items.length) _mulaiAuto();
  }

  @override
  void dispose() {
    _auto?.cancel();
    _pc.dispose();
    super.dispose();
  }

  void _buka(PromoBanner b) => bukaTujuanPromo(context, b.aksi, b.target);

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final tinggi = widget.tinggi.clamp(244.0, 400.0) * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5);

    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(children: [
        SizedBox(
          height: tinggi,
          child: PageView.builder(
            controller: _pc,
            physics: const BouncingScrollPhysics(),
            padEnds: false,
            onPageChanged: (i) {
              setState(() => _index = i);
              _mulaiAuto();
            },
            itemCount: widget.items.length,
            itemBuilder: (_, i) {
              final jarak = (_page - i).abs().clamp(0.0, 1.0);
              final skala = 1 - (jarak * .055);
              return Padding(
                padding: const EdgeInsets.only(right: 11),
                child: Transform.scale(
                  scale: skala,
                  child: Opacity(
                    opacity: 1 - (jarak * .22),
                    child: _KartuBanner(banner: widget.items[i], onTap: () => _buka(widget.items[i])),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.items.length, (i) {
            final aktif = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: aktif ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: aktif ? XyTheme.primary : XyTheme.of(context).muted.withOpacity(.28),
                borderRadius: BorderRadius.circular(6),
              ),
            );
          }),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------
class _KartuBanner extends StatelessWidget {
  const _KartuBanner({required this.banner, required this.onTap});
  final PromoBanner banner;
  final VoidCallback onTap;

  static Color _hex(String v, Color fallback) {
    var h = v.replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    final n = int.tryParse(h, radix: 16);
    return n == null ? fallback : Color(n);
  }

  static IconData _ikon(String nama) {
    switch (nama) {
      case 'gpu':
        return Icons.memory_rounded;
      case 'shield':
        return Icons.verified_user_rounded;
      case 'wallet':
        return Icons.account_balance_wallet_rounded;
      case 'crown':
        return Icons.workspace_premium_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'tag':
        return Icons.local_offer_rounded;
      case 'rocket':
        return Icons.rocket_launch_rounded;
      case 'key':
        return Icons.vpn_key_rounded;
      case 'store':
        return Icons.storefront_rounded;
      default:
        return Icons.bolt_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c1 = _hex(banner.warna1, XyTheme.primary);
    final c2 = _hex(banner.warna2, XyTheme.violet);
    final adaGambar = banner.gambar.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [c1, c2], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(XyRadius.xl),
          boxShadow: XyTheme.glow(c1, .28),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(XyRadius.xl),
          child: Stack(children: [
            // latar gambar kustom (opsional) dengan lapisan gelap agar teks terbaca
            if (adaGambar)
              Positioned.fill(
                child: Image.network(
                  banner.gambar,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  loadingBuilder: (_, anak, kemajuan) =>
                      kemajuan == null ? anak : const SizedBox.shrink(),
                ),
              ),
            if (adaGambar)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [c1.withOpacity(.88), c2.withOpacity(.62), Colors.transparent],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
              ),
            // ornamen lingkaran lembut
            Positioned(
              right: -34,
              top: -42,
              child: Container(
                width: 148,
                height: 148,
                decoration: BoxDecoration(color: Colors.white.withOpacity(.12), shape: BoxShape.circle),
              ),
            ),
            Positioned(
              right: 44,
              bottom: -58,
              child: Container(
                width: 116,
                height: 116,
                decoration: BoxDecoration(color: Colors.white.withOpacity(.08), shape: BoxShape.circle),
              ),
            ),
            Positioned(
              right: 18,
              top: 26,
              child: Icon(_ikon(banner.ikon), size: 62, color: Colors.white.withOpacity(.24)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (banner.label.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.22),
                        borderRadius: BorderRadius.circular(XyRadius.pill),
                      ),
                      child: Text(
                        banner.label,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Text(
                      banner.judul,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        height: 1.22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.4,
                      ),
                    ),
                  ),
                  if (banner.subjudul.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: Text(
                        banner.subjudul,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withOpacity(.86), fontSize: 11.8, height: 1.35),
                      ),
                    ),
                  ],
                  const SizedBox(height: 13),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 8, 11, 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(XyRadius.pill),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Flexible(child: Text(
                        banner.cta,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c1, fontSize: 11.8, fontWeight: FontWeight.w800),
                      )),
                      const SizedBox(width: 3),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: c1),
                    ]),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
