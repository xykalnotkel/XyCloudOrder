import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';

/// ============================================================
///  Tentang aplikasi: versi, legal, lisensi, dan kontak
/// ============================================================
class TentangScreen extends StatefulWidget {
  const TentangScreen({super.key});

  @override
  State<TentangScreen> createState() => _TentangScreenState();
}

class _TentangScreenState extends State<TentangScreen> {
  String versi = '-';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((p) {
      if (mounted) setState(() => versi = '${p.version} (build ${p.buildNumber})');
    }).catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tentang Aplikasi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 34),
        children: [
          // ---- identitas ----
          Center(
            child: Column(children: [
              const XyLogo(size: 88, radius: 28),
              const SizedBox(height: 16),
              const XyWordmark(tinggi: 26),
              const SizedBox(height: 10),
              Text('Versi $versi',
                  style: const TextStyle(color: XyTheme.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text('Sewa PC Cloud dan Akun Digital',
                  style: TextStyle(color: XyTheme.muted, fontSize: 12.5)),
            ]),
          ),

          const SectionHeader('Legal'),
          _Baris(
            ikon: Icons.description_outlined,
            judul: 'Syarat dan Ketentuan',
            sub: 'Aturan pemakaian layanan',
            onTap: () => Navigator.push(context, xyRoute(const _LegalScreen(jenis: 'syarat'))),
          ),
          _Baris(
            ikon: Icons.privacy_tip_outlined,
            judul: 'Kebijakan Privasi',
            sub: 'Data apa yang kami simpan dan untuk apa',
            onTap: () => Navigator.push(context, xyRoute(const _LegalScreen(jenis: 'privasi'))),
          ),
          _Baris(
            ikon: Icons.workspace_premium_outlined,
            judul: 'Lisensi Pihak Ketiga',
            sub: 'Perangkat lunak sumber terbuka yang kami pakai',
            onTap: () => Navigator.push(context, xyRoute(const LisensiScreen())),
          ),

          const SectionHeader('Bantuan'),
          _Baris(
            ikon: Icons.forum_outlined,
            judul: 'Chat Admin',
            sub: 'Tanya langsung lewat aplikasi, dijawab realtime',
            onTap: () => Navigator.pop(context, 'chat'),
          ),

          const SectionHeader('Pengembang'),
          XyCard(
            child: Column(children: [
              Image.asset('assets/brand/xyspace_wordmark.png', height: 34),
              const SizedBox(height: 14),
              const Text(
                'XyCloudStore dikembangkan oleh XySpace, studio kecil asal Indonesia yang membangun '
                'produk digital untuk pemain dan kreator.',
                textAlign: TextAlign.center,
                style: TextStyle(color: XyTheme.muted, fontSize: 12.8, height: 1.65),
              ),
            ]),
          ),
          const SizedBox(height: 22),
          Center(
            child: Column(children: const [
              Text('Dibuat dengan sepenuh hati di Indonesia',
                  style: TextStyle(color: XyTheme.muted, fontSize: 11)),
              SizedBox(height: 4),
              Text('© 2026 XyCloudStore by XySpace', style: TextStyle(color: XyTheme.muted, fontSize: 11)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Baris extends StatelessWidget {
  const _Baris({required this.ikon, required this.judul, required this.sub, required this.onTap});
  final IconData ikon;
  final String judul;
  final String sub;
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
                Text(sub, style: const TextStyle(color: XyTheme.muted, fontSize: 11.8, height: 1.4)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: XyTheme.muted),
          ]),
        ),
      );
}

/// Menampilkan Syarat dan Ketentuan atau Kebijakan Privasi dari server.
class _LegalScreen extends StatefulWidget {
  const _LegalScreen({required this.jenis});
  final String jenis;

  @override
  State<_LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<_LegalScreen> {
  Map<String, dynamic>? data;
  String? galat;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final d = await context.read<AppState>().dokumenLegal(widget.jenis);
      if (mounted) setState(() => data = d);
    } catch (e) {
      if (mounted) setState(() => galat = 'Tidak bisa memuat dokumen. Periksa koneksi internetmu.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final judul = widget.jenis == 'privasi' ? 'Kebijakan Privasi' : 'Syarat dan Ketentuan';
    return Scaffold(
      appBar: AppBar(title: Text(judul)),
      body: galat != null
          ? Kosong(icon: Icons.wifi_off_rounded, judul: 'Gagal memuat', sub: galat, ilustrasi: 'kosong')
          : data == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 34),
                  children: [
                    Text('Pembaruan terakhir: ${data!['pembaruan']}',
                        style: const TextStyle(color: XyTheme.muted, fontSize: 12)),
                    const SizedBox(height: 18),
                    ...List.generate((data!['bagian'] as List).length, (i) {
                      final b = (data!['bagian'] as List)[i] as Map;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: XyCard(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: XyTheme.primarySoft,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Center(
                                  child: Text('${i + 1}',
                                      style: const TextStyle(
                                          color: XyTheme.primary, fontWeight: FontWeight.w800, fontSize: 12)),
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Text('${b['judul']}',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, height: 1.3)),
                              ),
                            ]),
                            const SizedBox(height: 10),
                            Text('${b['teks']}',
                                style: const TextStyle(fontSize: 13.2, height: 1.65, color: XyTheme.inkSoft)),
                          ]),
                        ),
                      );
                    }),
                  ],
                ),
    );
  }
}

/// Daftar lisensi: ringkasan dari server plus daftar resmi bawaan Flutter.
class LisensiScreen extends StatefulWidget {
  const LisensiScreen({super.key});

  @override
  State<LisensiScreen> createState() => _LisensiScreenState();
}

class _LisensiScreenState extends State<LisensiScreen> {
  List<dynamic>? lisensi;

  @override
  void initState() {
    super.initState();
    context
        .read<AppState>()
        .dokumenLegal('syarat')
        .then((d) => mounted ? setState(() => lisensi = d['lisensi'] as List?) : null)
        .catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lisensi Pihak Ketiga')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 34),
        children: [
          const Text(
            'XyCloudStore dibangun memakai perangkat lunak sumber terbuka berikut. '
            'Terima kasih kepada seluruh pembuatnya.',
            style: TextStyle(color: XyTheme.muted, fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 18),
          if (lisensi == null)
            const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
          else
            ...lisensi!.map((l) {
              final m = l as Map;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: XyCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${m['nama']}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                        const SizedBox(height: 3),
                        Text('${m['pembuat']}',
                            style: const TextStyle(color: XyTheme.muted, fontSize: 11.5)),
                      ]),
                    ),
                    Pill('${m['lisensi']}', warna: XyTheme.violet),
                  ]),
                ),
              );
            }),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'XyCloudStore',
              applicationVersion: 'Sewa PC Cloud dan Akun Digital',
              applicationLegalese: '© 2026 XyCloudStore',
            ),
            icon: const Icon(Icons.article_outlined, size: 18),
            label: const Text('Lihat teks lisensi lengkap'),
          ),
        ],
      ),
    );
  }
}
