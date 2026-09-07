import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/cache.dart';
import '../../core/format.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import '../widgets/lembar.dart';
import 'order_list_screen.dart';
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
  int cacheKb = 0;

  @override
  void initState() {
    super.initState();
    _hitungCache();
  }

  Future<void> _hitungCache() async {
    final n = await Cache.ukuranKb();
    if (mounted) setState(() => cacheKb = n);
  }

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
              const SectionHeader('Akun', top: 22),
              _Menu(
                ikon: Icons.badge_outlined,
                judul: 'Ubah Profil',
                sub: 'Nama dan nomor WhatsApp',
                onTap: () => _dialogUbahProfil(context),
              ),
              _Menu(
                ikon: Icons.lock_outline_rounded,
                judul: 'Ganti Password',
                sub: 'Amankan akunmu secara berkala',
                onTap: () => _dialogGantiPassword(context),
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

              const SectionHeader('Notifikasi'),
              XyCard(
                padding: const EdgeInsets.fromLTRB(15, 6, 8, 6),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: XyTheme.primarySoft, borderRadius: BorderRadius.circular(13)),
                    child: const Icon(Icons.notifications_active_outlined, size: 20, color: XyTheme.primary),
                  ),
                  const SizedBox(width: 13),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Notifikasi Komunitas', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      SizedBox(height: 3),
                      Text('Balasan diskusi, suka, dan pengumuman admin',
                          style: TextStyle(color: XyTheme.muted, fontSize: 11.5)),
                    ]),
                  ),
                  Switch(
                    value: u.notifForum,
                    activeColor: XyTheme.primary,
                    onChanged: (v) async {
                      final galat = await s.perbaruiProfil(notifForum: v);
                      if (galat != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(galat)));
                      }
                    },
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              _Menu(
                ikon: Icons.notifications_none_rounded,
                judul: 'Pemberitahuan Pesanan',
                sub: 'Status order, chat admin, dan saldo selalu aktif',
                onTap: () => beritahu(
                  context,
                  judul: 'Selalu aktif',
                  pesan: 'Pemberitahuan pesanan, chat, dan saldo bersifat penting sehingga tidak bisa '
                      'dimatikan dari sini. Kamu tetap bisa mengaturnya lewat pengaturan Android.',
                  ikon: Icons.notifications_active_outlined,
                ),
              ),

              const SectionHeader('Aplikasi'),
              XyCard(
                padding: const EdgeInsets.fromLTRB(15, 6, 8, 6),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: XyTheme.primarySoft, borderRadius: BorderRadius.circular(13)),
                    child: const Icon(Icons.data_saver_on_rounded, size: 20, color: XyTheme.primary),
                  ),
                  const SizedBox(width: 13),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Mode Hemat Data', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      SizedBox(height: 3),
                      Text('Gambar produk tidak diunduh otomatis',
                          style: TextStyle(color: XyTheme.muted, fontSize: 11.5)),
                    ]),
                  ),
                  Switch(
                    value: s.hematData,
                    activeColor: XyTheme.primary,
                    onChanged: (v) => s.setHematData(v),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              _Menu(
                ikon: Icons.cleaning_services_outlined,
                judul: 'Bersihkan Data Tersimpan',
                sub: cacheKb > 0 ? 'Sekitar $cacheKb KB tersimpan di perangkat' : 'Tidak ada data tersimpan',
                onTap: () async {
                  await Cache.bersihkan();
                  await _hitungCache();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Data tersimpan dibersihkan.')),
                    );
                  }
                },
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

// ---------------- lembar bawah, bukan popup ----------------
Future<void> _dialogUbahProfil(BuildContext context) async {
  final s = context.read<AppState>();

  final nama = await tanyaTeks(
    context,
    judul: 'Ubah nama',
    keterangan: 'Nama ini yang tampil di komunitas dan pada struk pembelian.',
    nilaiAwal: s.user?.nama,
    petunjuk: 'Nama lengkap',
  );
  if (nama == null || !context.mounted) return;

  final phone = await tanyaTeks(
    context,
    judul: 'Nomor WhatsApp',
    keterangan: 'Dipakai admin untuk menghubungi kamu soal pesanan.',
    nilaiAwal: s.user?.phone,
    petunjuk: '08xxxxxxxxxx',
    tipe: TextInputType.phone,
  );
  if (!context.mounted) return;

  final galat = await s.perbaruiProfil(nama: nama, phone: phone ?? s.user?.phone);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(galat ?? 'Profil diperbarui.')),
  );
}

Future<void> _dialogGantiPassword(BuildContext context) async {
  final s = context.read<AppState>();

  final lama = await tanyaTeks(
    context,
    judul: 'Password lama',
    keterangan: 'Kosongkan kalau kamu mendaftar lewat Google.',
    petunjuk: 'Password sekarang',
  );
  if (lama == null || !context.mounted) return;

  final baru = await tanyaTeks(
    context,
    judul: 'Password baru',
    keterangan: 'Minimal 6 karakter. Gunakan kombinasi huruf dan angka.',
    petunjuk: 'Password baru',
  );
  if (baru == null || !context.mounted) return;

  final galat = await s.gantiPassword(lama, baru);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(galat ?? 'Password berhasil diganti.')),
  );
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
