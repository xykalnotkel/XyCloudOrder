import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import 'cs_screen.dart';

/// ============================================================
///  BantuanScreen — satu sumber pusat bantuan.
/// ============================================================
///  Sebelumnya ada dua versi (salinan di pengaturan_screen.dart) dengan
///  daftar FAQ dan nomor WA yang berbeda. Sekarang hanya berkas ini yang
///  dipakai, isinya gabungan: FAQ terlengkap + aksi chat/WA dari server.
class BantuanScreen extends StatelessWidget {
  const BantuanScreen({super.key});

  static const _tanya = [
    ('Bagaimana cara mengisi saldo?',
      'Buka Dompet lalu Isi Saldo, pilih nominal, transfer sesuai instruksi, dan unggah bukti. '
      'Kalau pembayaran otomatis aktif, saldo masuk sendiri dalam hitungan detik.'),
    ('Bagaimana cara sewa PC?',
      'Pilih paket di menu Sewa PC, tentukan durasi, lalu pilih metode bayar (saldo atau transfer). '
      'Setelah dibayar, unit disiapkan otomatis dan kredensial muncul di Pesanan Saya.'),
    ('PC saya tidak bisa konek?',
      'Cek unit masih berstatus aktif di Pesanan Saya, lalu pastikan internetmu stabil. '
      'Kalau masih gagal, buka Chat Kirana supaya admin bisa cek unitnya langsung.'),
    ('Akun digital saya bermasalah, bagaimana?',
      'Buka Chat Kirana dan sebutkan kode pesanannya. Selama masih dalam masa garansi, akun diganti gratis.'),
    ('Voucher tidak bisa dipakai?',
      'Cek minimal belanja dan masa berlakunya. Satu voucher hanya bisa dipakai sekali per pengguna '
      'dan tidak bisa digabung dengan voucher lain.'),
    ('Kenapa kode verifikasi tidak masuk?',
      'Cek folder spam atau promosi. Kalau masih belum ada, tekan Kirim ulang kode setelah 60 detik.'),
    ('Update aplikasi tidak muncul?',
      'Buka Pembaruan, lalu tekan Periksa Lagi. Pastikan izin memasang aplikasi dari sumber '
      'tidak dikenal aktif supaya APK baru bisa dipasang.'),
    ('Bisakah saya menghapus akun?',
      'Bisa. Hubungi admin lewat Chat Kirana, akun beserta datanya kami hapus paling lambat tujuh hari kerja.'),
    ('Apakah aman menyimpan saldo di sini?',
      'Saldo tersimpan di server kami dan setiap perubahan tercatat di riwayat transaksi. '
      'Password disimpan terenkripsi dan sesi kedaluwarsa otomatis.'),
  ];

  Future<void> _wa(BuildContext context) async {
    final dariServer = context.read<AppState>().konfigurasi.whatsapp.trim();
    final nomor = dariServer.isNotEmpty ? dariServer : XyConfig.waCs;
    final uri = Uri.parse('https://wa.me/$nomor?text=Halo%20admin%20XyCloudStore');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XyTheme.of(context).bg,
      appBar: AppBar(title: const Text('Pusat Bantuan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          const Center(child: XyIlustrasi('cs', tinggi: 150)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: _Aksi(
                ikon: Icons.forum_outlined,
                label: 'Chat Kirana',
                onTap: () => Navigator.push(context, xyRoute(const CsScreen())),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Aksi(
                ikon: Icons.call_outlined,
                label: 'WA Admin',
                onTap: () => _wa(context),
              ),
            ),
          ]),
          const SizedBox(height: 18),
          const Text('Pertanyaan yang sering ditanyakan',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: -.3)),
          const SizedBox(height: 14),
          ..._tanya.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: XyCard(
                  padding: EdgeInsets.zero,
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      iconColor: XyTheme.primary,
                      collapsedIconColor: XyTheme.of(context).muted,
                      title: Text(t.$1,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.8, height: 1.4)),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(t.$2,
                              style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12.8, height: 1.65)),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
          const SizedBox(height: 4),
          XyCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Video Tutorial', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Segera hadir: cara sewa PC, cara pakai RDP, dan cara beli akun.',
                  style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12.5, height: 1.55)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Aksi extends StatelessWidget {
  const _Aksi({required this.ikon, required this.label, required this.onTap});
  final IconData ikon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: XyTheme.of(context).primarySoft,
          borderRadius: BorderRadius.circular(XyRadius.sm),
          border: Border.all(color: XyTheme.of(context).line),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(ikon, size: 18, color: XyTheme.primary),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
      ),
    );
  }
}
