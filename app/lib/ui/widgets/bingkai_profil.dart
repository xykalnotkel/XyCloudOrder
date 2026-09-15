import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// ============================================================
///  Bingkai avatar profil (Batch I)
/// ============================================================
///  Id bingkai harus sama dengan whitelist BINGKAI_PROFIL di
///  api/src/index.js. 'aurora' dan 'permata' khusus langganan
///  Pro/VIP (gate ditegakkan di server, di sini hanya ikon kunci).
class BingkaiInfo {
  const BingkaiInfo(this.id, this.label, {this.langganan = false, this.ikon});
  final String id;
  final String label;
  final bool langganan;
  final IconData? ikon;
}

const List<BingkaiInfo> daftarBingkai = [
  BingkaiInfo('polos', 'Polos'),
  BingkaiInfo('ungu', 'Ungu Glossy'),
  BingkaiInfo('emas', 'Emas'),
  BingkaiInfo('neon', 'Neon'),
  BingkaiInfo('aurora', 'Aurora', langganan: true),
  BingkaiInfo('permata', 'Permata', langganan: true),
  // Batch J: bingkai aset AI (assets/bingkai/*.png) + partikel melayang.
  BingkaiInfo('api', 'Api Ungu', langganan: true),
  BingkaiInfo('galaksi', 'Galaksi', langganan: true),
];

/// Cincin gradasi statis untuk bingkai non-animasi.
Gradient? _gradBingkai(String? id) => switch (id) {
      'ungu' => const LinearGradient(
          colors: [Color(0xFFD6C8FF), XyTheme.violet, Color(0xFF3B1188)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
      'emas' => const LinearGradient(
          colors: [Color(0xFFF7E7B3), Color(0xFFD3A625), Color(0xFF7A5A10)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
      'neon' => const LinearGradient(
          colors: [Color(0xFF22D3EE), Color(0xFF8B5CF6), Color(0xFFF472B6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
      _ => null,
    };

/// Avatar dengan bingkai. `child` biasanya Container bulat berisi foto/inisial.
/// Untuk 'aurora' cincin berputar halus (khusus pelanggan, sudah digate server).
/// Untuk 'permata' cincin emas-ungu + empat titik permata di diagonal.
class AvatarBingkai extends StatefulWidget {
  const AvatarBingkai({
    super.key,
    required this.child,
    required this.size,
    this.bingkai,
    this.tebal,
  });

  final Widget child;
  final double size;
  final String? bingkai;

  /// Ketebalan cincin; default proporsional terhadap ukuran.
  final double? tebal;

  @override
  State<AvatarBingkai> createState() => _AvatarBingkaiState();
}

class _AvatarBingkaiState extends State<AvatarBingkai>
    with TickerProviderStateMixin {
  late final AnimationController _putar = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );

  /// Partikel melayang untuk bingkai aset AI (bara api naik / bintang mengorbit).
  late final AnimationController _apung = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  bool get _animasi =>
      widget.bingkai == 'aurora' ||
      widget.bingkai == 'galaksi' ||
      widget.bingkai == 'api';

  bool get _asetAi => widget.bingkai == 'galaksi' || widget.bingkai == 'api';

  @override
  void initState() {
    super.initState();
    if (_animasi) _putar.repeat();
    if (widget.bingkai == 'api') _apung.repeat();
  }

  @override
  void didUpdateWidget(covariant AvatarBingkai old) {
    super.didUpdateWidget(old);
    if (_animasi && !_putar.isAnimating) {
      _putar.repeat();
    } else if (!_animasi && _putar.isAnimating) {
      _putar.stop();
    }
    if (widget.bingkai == 'api' && !_apung.isAnimating) {
      _apung.repeat();
    } else if (widget.bingkai != 'api' && _apung.isAnimating) {
      _apung.stop();
    }
  }

  @override
  void dispose() {
    _putar.dispose();
    _apung.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.bingkai ?? 'polos';
    if (id == 'polos' || id.isEmpty) {
      return SizedBox(width: widget.size, height: widget.size, child: widget.child);
    }
    // Bingkai aset AI punya cincin tebal yang menyatu dengan artwork-nya.
    final tebal = widget.tebal ??
        (_asetAi ? math.max(6.0, widget.size * .13) : math.max(2.6, widget.size * .055));
    final grad = _gradBingkai(id);

    Widget cincin() {
      if (_asetAi) {
        // Ring artwork hasil generate AI (chroma-key hijau → transparan).
        return Image.asset(
          'assets/bingkai/$id.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: id == 'api'
                    ? [const Color(0xFFF472B6), XyTheme.violet, const Color(0xFF7C2D12)]
                    : [const Color(0xFF22D3EE), XyTheme.violet, const Color(0xFF312E81)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        );
      }
      if (id == 'aurora') {
        return RotationTransition(
          turns: _putar,
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  Color(0xFF22D3EE),
                  XyTheme.violet,
                  Color(0xFFF472B6),
                  Color(0xFFA78BFA),
                  Color(0xFF22D3EE),
                ],
                stops: [0, .28, .52, .78, 1],
              ),
            ),
          ),
        );
      }
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: id == 'permata'
              ? const LinearGradient(
                  colors: [
                    Color(0xFFF7E7B3),
                    Color(0xFF8B5CF6),
                    Color(0xFFD3A625),
                    Color(0xFF4C1D95),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight)
              : grad,
          color: grad == null && id != 'permata' ? XyTheme.lavender : null,
        ),
      );
    }

    Widget hasil = SizedBox(
      width: widget.size + tebal * 2,
      height: widget.size + tebal * 2,
      child: Stack(alignment: Alignment.center, children: [
        Positioned.fill(child: cincin()),
        // Kilau kaca tipis di setengah atas cincin.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [Colors.white.withOpacity(.30), Colors.white.withOpacity(0)],
              ),
            ),
          ),
        ),
        Container(
          width: widget.size,
          height: widget.size,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          clipBehavior: Clip.antiAlias,
          child: widget.child,
        ),
        // Batch J: elemen melayang untuk bingkai aset AI.
        if (id == 'galaksi')
          Positioned.fill(
              child: _BintangOrbit(size: widget.size, tebal: tebal, putar: _putar)),
        if (id == 'api')
          Positioned.fill(
              child: _BaraNaik(size: widget.size, tebal: tebal, apung: _apung)),
        if (id == 'permata')
          ...List.generate(4, (i) {
            final sudut = math.pi / 4 + i * math.pi / 2;
            final r = widget.size / 2 + tebal;
            return Positioned(
              left: r + r * math.cos(sudut) - tebal * .55,
              top: r + r * math.sin(sudut) - tebal * .55,
              child: Container(
                width: tebal * 1.1,
                height: tebal * 1.1,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFDF3D7),
                  boxShadow: [
                    BoxShadow(
                        color: XyTheme.goldSoft.withOpacity(.8), blurRadius: 6),
                  ],
                ),
              ),
            );
          }),
      ]),
    );

    return hasil;
  }
}

/// Pemilih bingkai horizontal untuk layar Ubah Profil.
class PilihBingkai extends StatelessWidget {
  const PilihBingkai({
    super.key,
    required this.nilai,
    required this.onPilih,
    required this.foto,
    required this.tier,
  });

  final String? nilai;
  final ValueChanged<String?> onPilih;
  final String? foto;
  final String tier;

  bool get _langganan => tier == 'pro' || tier == 'vip';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: daftarBingkai.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final b = daftarBingkai[i];
          final terpilih = (nilai ?? 'polos') == b.id;
          final terkunci = b.langganan && !_langganan;
          return GestureDetector(
            onTap: () {
              if (terkunci) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'Bingkai animasi premium (Aurora, Permata, Api, Galaksi) khusus pelanggan Pro/VIP. Naikkan tier dulu ya.')));
                return;
              }
              onPilih(b.id);
            },
            child: Column(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.all(terpilih ? 3 : 0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: terpilih ? XyTheme.violet : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Stack(alignment: Alignment.center, children: [
                  AvatarBingkai(
                    bingkai: b.id,
                    size: 52,
                    child: _AvatarIsi(foto: foto),
                  ),
                  if (terkunci)
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(.45),
                      ),
                      child: const Icon(Icons.lock_rounded,
                          size: 18, color: Colors.white),
                    ),
                ]),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 74,
                child: Text(
                  b.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: terpilih ? FontWeight.w800 : FontWeight.w600,
                    color: terpilih
                        ? XyTheme.of(context).ink
                        : XyTheme.of(context).muted,
                  ),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _AvatarIsi extends StatelessWidget {
  const _AvatarIsi({this.foto});
  final String? foto;

  @override
  Widget build(BuildContext context) {
    if ((foto ?? '').isNotEmpty) {
      return Image.network(
        foto!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _AvatarJatuh(),
      );
    }
    return const _AvatarJatuh();
  }
}

class _AvatarJatuh extends StatelessWidget {
  const _AvatarJatuh();
  @override
  Widget build(BuildContext context) => Container(
        color: XyTheme.of(context).primarySoft,
        alignment: Alignment.center,
        child: Icon(Icons.person_rounded,
            color: XyTheme.of(context).muted, size: 26),
      );
}

/// Bintang kecil mengorbit mengelilingi bingkai Galaksi (Batch J).
class _BintangOrbit extends StatelessWidget {
  const _BintangOrbit({required this.size, required this.tebal, required this.putar});
  final double size;
  final double tebal;
  final Animation<double> putar;

  static const _warna = [Colors.white, XyTheme.goldSoft, Color(0xFFBFD9FF)];

  @override
  Widget build(BuildContext context) {
    final r = size / 2 + tebal * .5;
    return AnimatedBuilder(
      animation: putar,
      builder: (_, __) => Stack(children: [
        for (var i = 0; i < 3; i++)
          Builder(builder: (_) {
            final sudut = putar.value * 2 * math.pi + i * 2 * math.pi / 3;
            final denyut = .75 + .25 * math.sin(putar.value * 6 * math.pi + i);
            final s = (i == 0 ? 13.0 : 9.0) * denyut;
            return Positioned(
              left: r + r * math.cos(sudut) - s / 2,
              top: r + r * math.sin(sudut) - s / 2,
              child: Icon(Icons.auto_awesome_rounded,
                  size: s,
                  color: _warna[i].withOpacity(.95)),
            );
          }),
      ]),
    );
  }
}

/// Bara api ungu-emas melayang naik di sekeliling bingkai Api (Batch J).
class _BaraNaik extends StatelessWidget {
  const _BaraNaik({required this.size, required this.tebal, required this.apung});
  final double size;
  final double tebal;
  final Animation<double> apung;

  static const _bara = [
    Color(0xFFFBBF24),
    Color(0xFFF472B6),
    Color(0xFFA78BFA),
    Color(0xFFFDE68A),
    Color(0xFFF97316),
  ];

  @override
  Widget build(BuildContext context) {
    final tinggi = size + tebal * 2;
    return AnimatedBuilder(
      animation: apung,
      builder: (_, __) => Stack(clipBehavior: Clip.none, children: [
        for (var i = 0; i < 5; i++)
          Builder(builder: (_) {
            final p = (apung.value + i / 5) % 1.0;
            final naik = tinggi * (1 - p) - tebal;
            final goyang = math.sin(p * 4 * math.pi + i * 1.7) * size * .16;
            final alpha = math.sin(p * math.pi).clamp(0.0, 1.0) * .9;
            final s = 3.0 + (i % 3) * 1.6;
            return Positioned(
              left: tinggi / 2 + goyang + (i - 2) * size * .17 - s / 2,
              top: naik,
              child: Opacity(
                opacity: alpha,
                child: Container(
                  width: s,
                  height: s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _bara[i],
                    boxShadow: [
                      BoxShadow(color: _bara[i].withOpacity(.75), blurRadius: 5),
                    ],
                  ),
                ),
              ),
            );
          }),
      ]),
    );
  }
}
