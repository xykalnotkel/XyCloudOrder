import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../widgets/banner_slider.dart';
import '../widgets/common.dart';
import '../widgets/error_state.dart';
import 'akun_screen.dart';
import 'cs_screen.dart';
import 'order_detail_screen.dart';
import 'sewa_pc_screen.dart';
import 'wallet_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final u = s.user!;
    final aktif = s.orderAktif;

    return Scaffold(
      backgroundColor: XyTheme.bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          BilahOffline(tampil: s.offline, onCoba: s.refresh),
          Expanded(
            child: RefreshIndicator(
          color: XyTheme.primary,
          onRefresh: s.refresh,
          child: ListView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(XySpace.page, 6, XySpace.page, 120),
            children: [
              _Header(user: u, koneksi: s.koneksi, notif: s.notifBelumDibaca),
              const SizedBox(height: 20),
              FadeInUp(child: _KartuSaldo(user: u)),
              const SizedBox(height: 22),
              FadeInUp(delay: const Duration(milliseconds: 90), child: const _MenuCepat()),

              if (aktif != null) ...[
                const SectionHeader('Sesi Berjalan', sub: 'Diperbarui otomatis dari server'),
                FadeInUp(child: _KartuOrderAktif(order: aktif)),
              ],

              SectionHeader(
                'PC Siap Pakai',
                sub: 'Stok unit realtime',
                aksi: 'Semua',
                onAksi: () => Navigator.push(context, xyRoute(const SewaPcScreen())),
              ),
              SizedBox(
                height: 198,
                child: s.plans.isEmpty
                    ? _skeletonRow()
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        clipBehavior: Clip.none,
                        itemCount: s.plans.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) => FadeInUp(
                          delay: Duration(milliseconds: 60 * i),
                          child: _KartuPlanMini(plan: s.plans[i]),
                        ),
                      ),
              ),

              BannerSlider(items: s.banners),

              SectionHeader(
                'Akun Terlaris',
                sub: 'Kredensial dikirim otomatis',
                aksi: 'Semua',
                onAksi: () => Navigator.push(context, xyRoute(const AkunScreen())),
              ),
              ...s.produk.take(3).toList().asMap().entries.map(
                    (e) => FadeInUp(
                      delay: Duration(milliseconds: 60 * e.key),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 11),
                        child: _BarisProduk(produk: e.value),
                      ),
                    ),
                  ),
            ],
          ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _skeletonRow() => ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => const SizedBox(width: 214, child: Shimmer(height: 198, radius: XyRadius.lg)),
      );
}

// ------------------------------------------------------------------
class _Header extends StatelessWidget {
  const _Header({required this.user, required this.koneksi, required this.notif});
  final UserProfile user;
  final dynamic koneksi;
  final int notif;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          gradient: XyTheme.gradPrimary,
          borderRadius: BorderRadius.circular(15),
          boxShadow: XyTheme.glow(XyTheme.primary, .22),
        ),
        child: Center(
          child: Text(
            user.nama.characters.first.toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19),
          ),
        ),
      ),
      const SizedBox(width: 13),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Selamat datang', style: TextStyle(color: XyTheme.muted, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 1),
          Row(children: [
            Flexible(
              child: Text(user.nama.split(' ').first,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -.5)),
            ),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(gradient: XyTheme.gradGold, borderRadius: BorderRadius.circular(6)),
              child: Text(user.tier.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: .8)),
            ),
          ]),
        ]),
      ),
      LiveDot(state: koneksi),
      const SizedBox(width: 8),
      Pressable(
        onTap: () => ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Belum ada notifikasi baru.'))),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: XyTheme.surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: XyTheme.line),
          ),
          child: Stack(alignment: Alignment.center, children: [
            const Icon(Icons.notifications_none_rounded, size: 20),
            if (notif > 0)
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: XyTheme.danger,
                    shape: BoxShape.circle,
                    border: Border.all(color: XyTheme.surface, width: 1.4),
                  ),
                ),
              ),
          ]),
        ),
      ),
    ]);
  }
}

// ------------------------------------------------------------------
class _KartuSaldo extends StatelessWidget {
  const _KartuSaldo({required this.user});
  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: XyTheme.gradMidnight,
        borderRadius: BorderRadius.circular(XyRadius.xl),
        boxShadow: XyTheme.glow(XyTheme.primaryDark, .35),
      ),
      child: Stack(children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(XyRadius.xl),
            child: Stack(children: [
              const Positioned.fill(child: DotGrid(color: Color(0x0AFFFFFF), gap: 20)),
              Positioned(
                right: -50,
                top: -60,
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [XyTheme.primary.withOpacity(.42), XyTheme.primary.withOpacity(0)],
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.account_balance_wallet_rounded, size: 15, color: Colors.white.withOpacity(.55)),
              const SizedBox(width: 7),
              Text('Saldo XyCloudStore',
                  style: TextStyle(color: Colors.white.withOpacity(.62), fontSize: 12.5, fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.10),
                  borderRadius: BorderRadius.circular(XyRadius.pill),
                  border: Border.all(color: Colors.white.withOpacity(.14)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.shield_rounded, size: 11, color: XyTheme.cyan),
                  const SizedBox(width: 4),
                  Text('Terlindungi',
                      style: TextStyle(color: Colors.white.withOpacity(.75), fontSize: 10, fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            AnimatedRupiah(
              user.saldo,
              format: rupiah,
              style: const TextStyle(
                  color: Colors.white, fontSize: 33, fontWeight: FontWeight.w800, letterSpacing: -1.4),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: _MiniBtn(
                  icon: Icons.add_rounded,
                  label: 'Top Up',
                  utama: true,
                  onTap: () => Navigator.push(context, xyRoute(const WalletScreen())),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniBtn(
                  icon: Icons.receipt_long_rounded,
                  label: 'Riwayat',
                  onTap: () => Navigator.push(context, xyRoute(const WalletScreen())),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  const _MiniBtn({required this.icon, required this.label, required this.onTap, this.utama = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool utama;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          gradient: utama ? XyTheme.gradPrimary : null,
          color: utama ? null : Colors.white.withOpacity(.10),
          borderRadius: BorderRadius.circular(XyRadius.sm),
          border: utama ? null : Border.all(color: Colors.white.withOpacity(.14)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 17),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5)),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------
class _MenuCepat extends StatelessWidget {
  const _MenuCepat();

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, Color, Widget)>[
      (Icons.rocket_launch_rounded, 'Sewa PC', XyTheme.primary, const SewaPcScreen()),
      (Icons.shopping_bag_rounded, 'Beli Akun', XyTheme.violet, const AkunScreen()),
      (Icons.credit_card_rounded, 'Top Up', XyTheme.success, const WalletScreen()),
      (Icons.headset_mic_rounded, 'Bantuan', XyTheme.warning, const CsScreen()),
    ];

    return Row(
      children: items.map((it) {
        return Expanded(
          child: Pressable(
            onTap: () => Navigator.push(context, xyRoute(it.$4)),
            child: Column(children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: XyTheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: XyTheme.line),
                  boxShadow: XyTheme.shadowXs,
                ),
                child: Icon(it.$1, color: it.$3, size: 23),
              ),
              const SizedBox(height: 9),
              Text(it.$2, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

// ------------------------------------------------------------------
class _KartuOrderAktif extends StatelessWidget {
  const _KartuOrderAktif({required this.order});
  final RentOrder order;

  @override
  Widget build(BuildContext context) {
    final aktif = order.status == OrderStatus.aktif;
    final warna = aktif ? XyTheme.success : XyTheme.warning;

    return XyCard(
      onTap: () => Navigator.push(context, xyRoute(OrderDetailScreen(orderId: order.id))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GradientThumb(seed: order.planId, icon: Icons.memory_rounded, size: 46, radius: 14),
          const SizedBox(width: 13),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(order.planNama, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              const SizedBox(height: 2),
              Text('${order.kode} · ${order.durasiJam} jam',
                  style: const TextStyle(color: XyTheme.muted, fontSize: 12)),
            ]),
          ),
          Pill(order.status.label,
              warna: warna, icon: aktif ? Icons.play_circle_fill_rounded : Icons.autorenew_rounded),
        ]),
        const SizedBox(height: 16),
        if (order.status == OrderStatus.provisioning)
          Row(children: [
            ProgressRing(value: order.progress / 100, size: 58),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Menyiapkan mesin', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                SizedBox(height: 3),
                Text('Boot image, mount storage, cek driver GPU.',
                    style: TextStyle(color: XyTheme.muted, fontSize: 12, height: 1.45)),
              ]),
            ),
          ])
        else if (aktif) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: XyTheme.lineSoft,
              borderRadius: BorderRadius.circular(XyRadius.sm),
            ),
            child: Row(children: [
              const Icon(Icons.timer_outlined, size: 17, color: XyTheme.primary),
              const SizedBox(width: 9),
              const Text('Sisa waktu sesi', style: TextStyle(fontSize: 12.5, color: XyTheme.muted, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(order.berakhir == null ? '-' : durasiSisa(order.berakhir!),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, letterSpacing: -.3)),
            ]),
          ),
          const SizedBox(height: 13),
          GradientButton(
            label: 'Buka Kredensial Remote',
            icon: Icons.vpn_lock_rounded,
            height: 48,
            onPressed: () => Navigator.push(context, xyRoute(OrderDetailScreen(orderId: order.id))),
          ),
        ] else
          Text('Status saat ini: ${order.status.label}',
              style: const TextStyle(fontSize: 12.5, color: XyTheme.muted)),
      ]),
    );
  }
}

// ------------------------------------------------------------------
class _KartuPlanMini extends StatelessWidget {
  const _KartuPlanMini({required this.plan});
  final PcPlan plan;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 214,
      child: XyCard(
        padding: const EdgeInsets.all(15),
        onTap: () => Navigator.push(context, xyRoute(SewaPcScreen(fokusId: plan.id))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            GradientThumb(seed: plan.id, icon: Icons.memory_rounded, size: 40, radius: 12),
            const Spacer(),
            Pill(plan.ready ? '${plan.unitTersedia} unit' : 'Penuh',
                warna: plan.ready ? XyTheme.success : XyTheme.danger),
          ]),
          const SizedBox(height: 14),
          Text(plan.nama, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, letterSpacing: -.3)),
          const SizedBox(height: 3),
          Text(plan.gpu,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: XyTheme.muted, fontSize: 12)),
          const SizedBox(height: 11),
          Row(children: [
            SpecChip(Icons.memory_outlined, '${plan.ramGb}GB'),
            const SizedBox(width: 6),
            SpecChip(Icons.public_rounded, plan.region),
          ]),
          const Spacer(),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(rupiah(plan.hargaPerJam),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: XyTheme.primary, letterSpacing: -.5)),
            const Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Text(' /jam', style: TextStyle(color: XyTheme.muted, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------
class _BarisProduk extends StatelessWidget {
  const _BarisProduk({required this.produk});
  final AkunProduk produk;

  @override
  Widget build(BuildContext context) {
    return XyCard(
      padding: const EdgeInsets.all(13),
      onTap: () => Navigator.push(context, xyRoute(AkunScreen(fokusId: produk.id))),
      child: Row(children: [
        GradientThumb(seed: produk.id, icon: Icons.vpn_key_rounded, size: 54, radius: 14),
        const SizedBox(width: 13),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(produk.nama,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.8)),
            const SizedBox(height: 5),
            Row(children: [
              const Icon(Icons.star_rounded, size: 13.5, color: XyTheme.gold),
              Text(' ${produk.rating}',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
              Text('  ·  ${produk.terjual} terjual',
                  style: const TextStyle(fontSize: 11.5, color: XyTheme.muted)),
            ]),
            const SizedBox(height: 6),
            Text(rupiah(produk.harga),
                style: const TextStyle(fontWeight: FontWeight.w800, color: XyTheme.primary, fontSize: 14.5)),
          ]),
        ),
        Pill(produk.stok > 0 ? 'Stok ${produk.stok}' : 'Habis',
            warna: produk.stok > 0 ? XyTheme.success : XyTheme.danger),
      ]),
    );
  }
}
