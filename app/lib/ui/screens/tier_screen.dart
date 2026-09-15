import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';

/// ============================================================
///  Tier & Benefit — progres NYATA (Batch I)
/// ============================================================
///  Definisi tier disamakan dengan server (api/src/loyal.js):
///  basic 0 / pro 300.000 / vip 1.500.000 dari total belanja lunas.
///  Sebelumnya layar ini menampilkan Bronze/Silver/Gold/Platinum yang
///  tidak pernah ada di server — sekarang progres benefit sungguhan:
///  bar menuju tier berikutnya + benefit yang sudah/akan aktif,
///  termasuk benefit baru Batch I (banner bergerak, bingkai premium).
class _Tingkat {
  const _Tingkat(this.id, this.nama, this.min, this.warna, this.ikon,
      this.manfaat);
  final String id;
  final String nama;
  final int min;
  final Color warna;
  final IconData ikon;
  final List<String> manfaat;
}

const _tingkat = [
  _Tingkat('basic', 'Basic', 0, Color(0xFF7C7391), Icons.rocket_launch_outlined, [
    'Akses semua paket dan produk',
    'Chat admin tanpa batas',
    'Transfer saldo antar pengguna',
    '5 tema banner profil',
  ]),
  _Tingkat('pro', 'Pro', 300000, XyTheme.violet, Icons.workspace_premium_outlined, [
    'Diskon 3% tiap transaksi',
    'Antrean unit lebih dulu',
    'Lencana Pro di komunitas',
    'Banner profil GIF & video (auto-GIF)',
    'Bingkai avatar Aurora & Permata',
  ]),
  _Tingkat('vip', 'VIP', 1500000, XyTheme.goldSoft, Icons.diamond_outlined, [
    'Diskon 7% tiap transaksi',
    'Prioritas tertinggi saat unit penuh',
    'Bantuan admin didahulukan',
    'Lencana VIP di komunitas',
    'Semua benefit Pro tetap aktif',
  ]),
];

class TierScreen extends StatelessWidget {
  const TierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = XyTheme.of(context);
    final u = context.watch<AppState>().user;
    final belanja = u?.totalBelanja ?? 0;
    final tierKu = u?.tier ?? 'basic';
    final idxKu = _tingkat.indexWhere((x) => x.id == tierKu).clamp(0, 2);
    final sekarang = _tingkat[idxKu];
    final berikutnya = idxKu < _tingkat.length - 1 ? _tingkat[idxKu + 1] : null;

    // Progres menuju tier berikutnya (dari dasar tier sekarang).
    final rentang = berikutnya == null
        ? 1
        : (berikutnya.min - sekarang.min).clamp(1, 1 << 31);
    final maju = berikutnya == null
        ? 1.0
        : ((belanja - sekarang.min) / rentang).clamp(0.0, 1.0);
    final kurang = berikutnya == null ? 0 : (berikutnya.min - belanja).clamp(0, 1 << 31);

    return Scaffold(
      appBar: AppBar(title: const Text('Tier & Benefit')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          // ---------- kartu progres ----------
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [XyTheme.bgGelap2, XyTheme.primaryDark, sekarang.warna],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(XyRadius.lg),
              boxShadow: XyTheme.glow(sekarang.warna, .22),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.14),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withOpacity(.25)),
                  ),
                  child: Icon(sekarang.ikon, color: Colors.white, size: 27),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tier ${sekarang.nama}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              letterSpacing: -.4)),
                      const SizedBox(height: 3),
                      Text(
                        berikutnya == null
                            ? 'Tier tertinggi — semua benefit aktif!'
                            : 'Belanja ${rupiah(kurang)} lagi menuju ${berikutnya.nama}',
                        style: TextStyle(
                            color: Colors.white.withOpacity(.78),
                            fontSize: 11.8,
                            height: 1.4),
                      ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 18),
              // Bar progres benefit.
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: Stack(children: [
                  Container(
                    height: 12,
                    color: Colors.white.withOpacity(.16),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: maju),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => FractionallySizedBox(
                      widthFactor: v,
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD8C9FF), Colors.white],
                          ),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Text(rupiah(belanja),
                    style: TextStyle(
                        color: Colors.white.withOpacity(.85),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                if (berikutnya != null)
                  Text(rupiah(berikutnya.min),
                      style: TextStyle(
                          color: Colors.white.withOpacity(.85),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.10),
                    borderRadius: BorderRadius.circular(13)),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Colors.white70, size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Total belanja kamu dihitung dari pesanan sewa & akun yang lunas — tanpa batas waktu.',
                      style: TextStyle(
                          color: Colors.white.withOpacity(.82),
                          fontSize: 10.8,
                          height: 1.4),
                    ),
                  ),
                ]),
              ),
            ]),
          ),

          const SectionHeader('Level & Benefit'),
          ..._tingkat.map((x) {
            final tercapai = belanja >= x.min || tierKu == x.id ||
                _tingkat.indexWhere((e) => e.id == tierKu) >=
                    _tingkat.indexOf(x);
            final aktif = tierKu == x.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: XyCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: x.warna.withOpacity(.15),
                            borderRadius: BorderRadius.circular(14),
                            border:
                                Border.all(color: x.warna.withOpacity(.3)),
                          ),
                          child: Icon(x.ikon, color: x.warna, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Text(x.nama,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16)),
                                  if (aktif) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        gradient: XyTheme.gradPrimary,
                                        borderRadius: BorderRadius.circular(
                                            XyRadius.pill),
                                      ),
                                      child: const Text('TIER KAMU',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: .6)),
                                    ),
                                  ],
                                ]),
                                const SizedBox(height: 2),
                                Text(
                                    x.min == 0
                                        ? 'Langsung aktif saat mendaftar'
                                        : 'Minimal total belanja ${rupiah(x.min)}',
                                    style: TextStyle(
                                        color: t.muted, fontSize: 11.5)),
                              ]),
                        ),
                        if (x.id != 'basic')
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: x.warna.withOpacity(.14),
                              borderRadius:
                                  BorderRadius.circular(XyRadius.pill),
                            ),
                            child: Text(
                              'HEMAT ${x.id == 'pro' ? 3 : 7}%',
                              style: TextStyle(
                                  color: x.warna,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10),
                            ),
                          ),
                      ]),
                      const SizedBox(height: 14),
                      ...x.manfaat.map((m) {
                        final baru = m.contains('Banner profil GIF') ||
                            m.contains('Bingkai avatar');
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  tercapai
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked,
                                  size: 15,
                                  color: tercapai ? x.warna : t.line,
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(children: [
                                      TextSpan(
                                        text: m,
                                        style: TextStyle(
                                            color: t.inkSoft.withOpacity(.9),
                                            fontSize: 12.4,
                                            height: 1.4),
                                      ),
                                      if (baru)
                                        WidgetSpan(
                                          alignment:
                                              PlaceholderAlignment.middle,
                                          child: Container(
                                            margin: const EdgeInsets.only(
                                                left: 6),
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: XyTheme.plum
                                                  .withOpacity(.14),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      XyRadius.pill),
                                            ),
                                            child: const Text('BARU',
                                                style: TextStyle(
                                                    color: XyTheme.plum,
                                                    fontSize: 7.5,
                                                    fontWeight:
                                                        FontWeight.w800,
                                                    letterSpacing: .5)),
                                          ),
                                        ),
                                    ]),
                                  ),
                                ),
                              ]),
                        );
                      }),
                    ]),
              ),
            );
          }),
          XyCard(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cara Naik Tier Cepat',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    '• Sewa paket mingguan/bulanan (nilai besar langsung dihitung)\n'
                    '• Beli akun digital premium\n'
                    '• Diskon tier otomatis terpakai di checkout\n'
                    '• Tier hanya naik, tidak pernah turun otomatis',
                    style: TextStyle(color: t.muted, fontSize: 12.3, height: 1.65),
                  ),
                ]),
          ),
        ],
      ),
    );
  }
}
