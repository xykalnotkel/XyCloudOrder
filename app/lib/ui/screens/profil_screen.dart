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
import 'notifikasi_screen.dart';
import 'pengaturan_screen.dart';
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
                                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 26),
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
                            color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19, letterSpacing: -.5)),
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
                                  color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: .4)),
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
                                    fontWeight: FontWeight.w800,
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
              const SectionHeader('Aktivitas', top: 22),
              Builder(builder: (context) {
                final belum = context.watch<AppState>().notifBelum;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: XyCard(
                    padding: const EdgeInsets.all(15),
                    onTap: () => Navigator.push(context, xyRoute(const NotifikasiScreen())),
                    child: Row(children: [
                      Stack(children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                              color: XyTheme.primarySoft, borderRadius: BorderRadius.circular(13)),
                          child: const Icon(Icons.notifications_none_rounded, size: 20, color: XyTheme.primary),
                        ),
                        if (belum > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5),
                              constraints: const BoxConstraints(minWidth: 17),
                              height: 17,
                              decoration: BoxDecoration(
                                color: XyTheme.danger,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(color: XyTheme.surface, width: 1.6),
                              ),
                              child: Center(
                                child: Text('$belum',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ),
                      ]),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Pemberitahuan',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          const SizedBox(height: 3),
                          Text(
                            belum > 0 ? '$belum kabar baru menunggu' : 'Suka, balasan, pesanan, dan saldo',
                            style: const TextStyle(color: XyTheme.muted, fontSize: 11.5),
                          ),
                        ]),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: XyTheme.muted),
                    ]),
                  ),
                );
              }),

              const SectionHeader('Akun'),
              _Menu(
                ikon: Icons.badge_outlined,
                judul: 'Ubah Profil',
                sub: 'Nama, nomor WhatsApp, dan foto',
                onTap: () => Navigator.push(context, xyRoute(const UbahProfilScreen())),
              ),
              _Menu(
                ikon: Icons.lock_outline_rounded,
                judul: 'Keamanan',
                sub: 'Ganti password dan info sesi',
                onTap: () => Navigator.push(context, xyRoute(const KeamananScreen())),
              ),
              _Menu(
                ikon: Icons.account_balance_wallet_outlined,
                judul: 'Dompet dan Riwayat',
                sub: 'Saldo ${rupiah(u.saldo)}',
                onTap: () => Navigator.push(context, xyRoute(const WalletScreen())),
              ),
              _Menu(
                ikon: Icons.receipt_long_outlined,
                judul: 'Pesanan Saya',
                sub: '$jumlahOrder pesanan tercatat',
                onTap: () => Navigator.push(context, xyRoute(const OrderListScreen())),
              ),

              const SectionHeader('Aplikasi'),
              _Menu(
                ikon: Icons.tune_rounded,
                judul: 'Pengaturan',
                sub: 'Notifikasi, hemat data, penyimpanan',
                onTap: () => Navigator.push(context, xyRoute(const PengaturanScreen())),
              ),
              _Menu(
                ikon: Icons.info_outline_rounded,
                judul: 'Tentang Aplikasi',
                sub: 'Versi, syarat, privasi, lisensi',
                onTap: () => Navigator.push(context, xyRoute(const TentangScreen())),
              ),

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
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15.5, letterSpacing: -.4)),
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
              decoration: BoxDecoration(color: XyTheme.primarySoft, borderRadius: BorderRadius.circular(13)),
              child: Icon(ikon, size: 20, color: XyTheme.primary),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(judul, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 3),
                Text(sub, style: const TextStyle(color: XyTheme.muted, fontSize: 11.5)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: XyTheme.muted),
          ]),
        ),
      );
}
