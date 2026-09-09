import 'hapus_akun_screen.dart';
import 'voucher_screen.dart';
import 'leaderboard_screen.dart';
import 'live_unit_screen.dart';
import 'bantuan_screen.dart';
import 'pembaruan_screen.dart';
import 'favorit_screen.dart';
import 'statistik_screen.dart';
import 'tier_screen.dart';
import 'aktivitas_screen.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import '../widgets/lembar.dart';
import 'order_list_screen.dart';
import 'pengaturan_screen.dart' as pengaturan;
import 'referral_screen.dart';
import 'tentang_screen.dart';
import 'wallet_screen.dart';

/// ============================================================
///  Profil pengguna: identitas, ringkasan, dan pengaturan
/// ============================================================
class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  Future<void> _gantiFoto() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 700, imageQuality: 80);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    final tipe = f.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
    if (!mounted) return;

    final s = context.read<AppState>();
    final galat = await s.perbaruiProfil(foto: 'data:image/$tipe;base64,${base64Encode(bytes)}');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(galat ?? 'Foto profil diperbarui.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final u = s.user;
    if (u == null) return const SizedBox.shrink();

    final jumlahOrder = s.orders.length;
    final jumlahAktif = s.orders.where((o) => o.status.name == 'aktif').length;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ---------- kepala ----------
          Container(
            padding: EdgeInsets.fromLTRB(22, MediaQuery.of(context).padding.top + 22, 22, 26),
            decoration: const BoxDecoration(
              gradient: XyTheme.gradDeep,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: Column(children: [
              Row(children: [
                Stack(children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(.16),
                      border: Border.all(color: Colors.white.withOpacity(.32), width: 2),
                      image: (u.foto ?? '').isNotEmpty
                          ? DecorationImage(image: NetworkImage(u.foto!), fit: BoxFit.cover)
                          : null,
                    ),
                    child: (u.foto ?? '').isEmpty
                        ? Center(
                            child: Text(
                              u.nama.isEmpty ? 'X' : u.nama[0].toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 26),
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Pressable(
                      onTap: _gantiFoto,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: XyTheme.shadowSm,
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 14, color: XyTheme.primary),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u.nama,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 19, letterSpacing: -.5)),
                    const SizedBox(height: 4),
                    Text(u.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withOpacity(.62), fontSize: 12.5)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 7, runSpacing: 6, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.16),
                          borderRadius: BorderRadius.circular(XyRadius.pill),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.workspace_premium_rounded, size: 13, color: Color(0xFFE8C07A)),
                          const SizedBox(width: 5),
                          Text('Member ${u.tier.toUpperCase()}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: .4)),
                        ]),
                      ),
                      if (u.badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(XyRadius.pill),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.verified_rounded, size: 13, color: XyTheme.primary),
                            const SizedBox(width: 5),
                            Text(u.badge!.toUpperCase(),
                                style: const TextStyle(
                                    color: XyTheme.primary,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: .4)),
                          ]),
                        ),
                    ]),
                  ]),
                ),
              ]),
              const SizedBox(height: 22),
              Row(children: [
                _Statistik('Saldo', rupiah(u.saldo)),
                _Pemisah(),
                _Statistik('Order', '$jumlahOrder'),
                _Pemisah(),
                _Statistik('Aktif', '$jumlahAktif'),
              ]),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
            child: Column(children: [
              // Pemberitahuan kini ada di tombol lonceng pada bar atas beranda,
              // supaya selalu terlihat dan cepat dijangkau dari mana pun.

              const SectionHeader('Akun'),
              _Menu(
                ikon: Icons.badge_outlined,
                judul: 'Ubah Profil',
                sub: 'Nama, nomor WhatsApp, dan foto',
                onTap: () => Navigator.push(context, xyRoute(const pengaturan.UbahProfilScreen())),
              ),
              _Menu(
                ikon: Icons.lock_outline_rounded,
                judul: 'Keamanan',
                sub: 'Ganti password dan info sesi',
                onTap: () => Navigator.push(context, xyRoute(const pengaturan.KeamananScreen())),
              ),
              _Menu(
                ikon: Icons.account_balance_wallet_outlined,
                judul: 'Dompet dan Riwayat',
                sub: 'Saldo ${rupiah(u.saldo)}',
                onTap: () => Navigator.push(context, xyRoute(const WalletScreen())),
              ),
              _Menu(
                ikon: Icons.card_giftcard_rounded,
                judul: 'Undang Teman',
                sub: 'Bagi kode, kalian berdua dapat saldo',
                onTap: () => Navigator.push(context, xyRoute(const ReferralScreen())),
              ),
              _Menu(
                ikon: Icons.receipt_long_outlined,
                judul: 'Pesanan Saya',
                sub: '$jumlahOrder pesanan tercatat',
                onTap: () => Navigator.push(context, xyRoute(const OrderListScreen())),
              ),
              _Menu(
                ikon: Icons.local_offer_rounded,
                judul: 'Voucher Saya',
                sub: 'Klaim & pakai potongan',
                onTap: () => Navigator.push(context, xyRoute(const VoucherScreen())),
              ),
              _Menu(
                ikon: Icons.leaderboard_rounded,
                judul: 'Leaderboard',
                sub: 'Top spender & poin',
                onTap: () => Navigator.push(context, xyRoute(const LeaderboardScreen())),
              ),
              _Menu(
                ikon: Icons.sensors_rounded,
                judul: 'Status Unit Live',
                sub: '${s.orders.isEmpty ? '' : s.plans.fold(0, (a, p) => a + p.unitTersedia)} unit ready — realtime',
                onTap: () => Navigator.push(context, xyRoute(const LiveUnitScreen())),
              ),
              _Menu(
                ikon: Icons.favorite_rounded,
                judul: 'Favorit Saya',
                sub: '${s.favorit.length} produk disukai',
                onTap: () => Navigator.push(context, xyRoute(const FavoritScreen())),
              ),
              _Menu(
                ikon: Icons.bar_chart_rounded,
                judul: 'Statistik & Pengeluaran',
                sub: 'Ringkasan belanja & hemat tier',
                onTap: () => Navigator.push(context, xyRoute(const StatistikScreen())),
              ),
              _Menu(
                ikon: Icons.diamond_outlined,
                judul: 'Tier & Benefit',
                sub: 'Bronze → Platinum benefit',
                onTap: () => Navigator.push(context, xyRoute(const TierScreen())),
              ),
              _Menu(
                ikon: Icons.security_rounded,
                judul: 'Aktivitas & Keamanan',
                sub: 'Device, login history, anti-abuse',
                onTap: () => Navigator.push(context, xyRoute(const AktivitasScreen())),
              ),
              _Menu(
                ikon: Icons.help_center_rounded,
                judul: 'Pusat Bantuan',
                sub: 'FAQ, tutorial, CS',
                onTap: () => Navigator.push(context, xyRoute(const BantuanScreen())),
              ),

              const SectionHeader('Aplikasi'),
              _Menu(
                ikon: Icons.tune_rounded,
                judul: 'Pengaturan',
                sub: 'Notifikasi, hemat data, penyimpanan',
                onTap: () => Navigator.push(context, xyRoute(const pengaturan.PengaturanScreen())),
              ),
              _Menu(
                ikon: Icons.info_outline_rounded,
                judul: 'Tentang Aplikasi',
                sub: 'Versi, syarat, privasi, lisensi',
                onTap: () => Navigator.push(context, xyRoute(const TentangScreen())),
              ),

              _Menu(ikon: Icons.system_update_rounded, judul: 'Pembaruan Aplikasi', sub: 'Cek versi & update APK', onTap: () => Navigator.push(context, xyRoute(const PembaruanScreen()))),
              _Menu(ikon: Icons.dark_mode_outlined, judul: 'Tema Aplikasi', sub: 'Terang, gelap, atau ikuti sistem', onTap: () => Navigator.push(context, xyRoute(const pengaturan.TemaScreen()))),
              _Menu(ikon: Icons.delete_forever_outlined, judul: 'Hapus Akun', sub: 'Kelola penghapusan akun secara aman', onTap: () => Navigator.push(context, xyRoute(const HapusAkunScreen()))),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () async {
                  final yakin = await konfirmasi(
                    context,
                    judul: 'Keluar dari akun?',
                    pesan: 'Kamu perlu masuk lagi untuk memakai aplikasi.',
                    tombolYa: 'Keluar',
                    ikon: Icons.logout_rounded,
                    bahaya: true,
                  );
                  if (yakin && context.mounted) context.read<AppState>().logout();
                },
                icon: const Icon(Icons.logout_rounded, size: 18, color: XyTheme.danger),
                label: const Text('Keluar',
                    style: TextStyle(color: XyTheme.danger, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ---------------- potongan kecil ----------------
class _Statistik extends StatelessWidget {
  const _Statistik(this.label, this.nilai);
  final String label, nilai;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(nilai,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15.5, letterSpacing: -.4)),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(.55), fontSize: 11)),
        ]),
      );
}

class _Pemisah extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 26, color: Colors.white.withOpacity(.16));
}

class _Menu extends StatelessWidget {
  const _Menu({required this.ikon, required this.judul, required this.sub, required this.onTap});
  final IconData ikon;
  final String judul, sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: XyCard(
          padding: const EdgeInsets.all(15),
          onTap: onTap,
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: XyTheme.of(context).primarySoft, borderRadius: BorderRadius.circular(13)),
              child: Icon(ikon, size: 20, color: XyTheme.primary),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(judul, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 3),
                Text(sub, style:  TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5)),
              ]),
            ),
             Icon(Icons.chevron_right_rounded, color: XyTheme.of(context).muted),
          ]),
        ),
      );
}
