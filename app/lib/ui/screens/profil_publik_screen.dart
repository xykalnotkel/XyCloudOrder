import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import 'dm_chat_screen.dart';
import 'forum_screen.dart' show LencanaTier, LencanaKhusus;
import 'pengaturan_screen.dart' as pengaturan;

/// ============================================================
///  Profil publik pengguna lain (Batch D): banner tema, bio,
///  statistik, tombol ikuti/kirim pesan.
/// ============================================================
class ProfilPublikScreen extends StatefulWidget {
  const ProfilPublikScreen({super.key, required this.userId});
  final String userId;

  @override
  State<ProfilPublikScreen> createState() => _ProfilPublikScreenState();
}

class _ProfilPublikScreenState extends State<ProfilPublikScreen> {
  ProfilPublik? _profil;
  String? _galat;
  bool _memuat = true;
  bool _sibuk = false;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() {
      _memuat = true;
      _galat = null;
    });
    try {
      final p = await context.read<AppState>().repo.profilPublik(widget.userId);
      if (!mounted) return;
      setState(() {
        _profil = p;
        _memuat = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _galat = 'Profil tidak dapat dimuat.';
        _memuat = false;
      });
    }
  }

  Future<void> _toggleIkuti() async {
    final p = _profil;
    if (p == null || _sibuk) return;
    setState(() => _sibuk = true);
    final baru = !p.sayaIkuti;
    // optimis
    setState(() {
      _profil = ProfilPublik(
        id: p.id, nama: p.nama, foto: p.foto, bio: p.bio, banner: p.banner,
        tier: p.tier, badge: p.badge,
        pengikut: p.pengikut + (baru ? 1 : -1),
        mengikuti: p.mengikuti, posting: p.posting,
        sayaIkuti: baru, saya: p.saya,
      );
    });
    try {
      await context.read<AppState>().repo.ikuti(p.id, baru);
    } catch (_) {
      if (mounted) setState(() => _profil = p); // rollback
    }
    if (mounted) setState(() => _sibuk = false);
  }

  String _inisial(String nama) {
    final bagian = nama.trim().split(RegExp(r'\s+'));
    if (bagian.isEmpty || bagian.first.isEmpty) return '?';
    if (bagian.length == 1) return bagian.first[0].toUpperCase();
    return (bagian[0][0] + bagian[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final t = XyTheme.of(context);
    final p = _profil;
    return Scaffold(
      body: _memuat
          ? const Center(child: CircularProgressIndicator(color: XyTheme.primary))
          : _galat != null
              ? Kosong(
                  icon: Icons.person_off_rounded,
                  judul: 'Waduh',
                  sub: _galat,
                  aksi: GradientButton(label: 'Coba Lagi', onPressed: _muat),
                )
              : ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // ---------- banner + avatar ----------
                    Stack(clipBehavior: Clip.none, children: [
                      Container(
                        height: 190,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: XyBannerTema.warna(p!.banner),
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const DotGrid(),
                      ),
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 6,
                        left: 8,
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withOpacity(.25),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        top: 140,
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: t.surface, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(.18),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: (p.foto ?? '').isNotEmpty
                                ? AppImage(p.foto!)
                                : Container(
                                    color: XyTheme.primarySoft,
                                    alignment: Alignment.center,
                                    child: Text(_inisial(p.nama),
                                        style: const TextStyle(
                                            fontSize: 30,
                                            fontWeight: FontWeight.w800,
                                            color: XyTheme.primary)),
                                  ),
                          ),
                        ),
                      ),
                    ]),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 56, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                            Text(p.nama,
                                style: const TextStyle(
                                    fontSize: 21, fontWeight: FontWeight.w800)),
                            LencanaTier(p.tier ?? 'basic'),
                            if (p.badge != null) LencanaKhusus(p.badge!),
                          ]),
                          if ((p.bio ?? '').isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(p.bio!,
                                style: TextStyle(
                                    fontSize: 13, height: 1.45, color: t.inkSoft)),
                          ],
                          const SizedBox(height: 16),
                          // ---------- statistik ----------
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: t.surface,
                              borderRadius: BorderRadius.circular(XyRadius.md),
                              border: Border.all(color: t.line),
                            ),
                            child: Row(children: [
                              _stat('Posting', '${p.posting}'),
                              _pisah(),
                              _stat('Pengikut', '${p.pengikut}'),
                              _pisah(),
                              _stat('Mengikuti', '${p.mengikuti}'),
                            ]),
                          ),
                          const SizedBox(height: 18),
                          // ---------- aksi ----------
                          if (p.saya)
                            GradientButton(
                              label: 'Ubah Profil Saya',
                              icon: Icons.edit_rounded,
                              onPressed: () => Navigator.push(context,
                                  xyRoute(const pengaturan.UbahProfilScreen())),
                            )
                          else
                            Row(children: [
                              Expanded(
                                flex: 3,
                                child: GradientButton(
                                  label: p.sayaIkuti ? 'Mengikuti' : 'Ikuti',
                                  icon: p.sayaIkuti
                                      ? Icons.person_remove_alt_1_rounded
                                      : Icons.person_add_alt_1_rounded,
                                  loading: _sibuk,
                                  gradient: p.sayaIkuti
                                      ? const LinearGradient(colors: [Color(0xFF94A3B8), Color(0xFF64748B)])
                                      : XyTheme.gradPrimary,
                                  glowColor: p.sayaIkuti ? const Color(0xFF64748B) : XyTheme.primary,
                                  onPressed: _toggleIkuti,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 3,
                                child: OutlinedButton.icon(
                                  onPressed: () => Navigator.push(
                                      context,
                                      xyRoute(DmChatScreen(
                                          userId: p.id, nama: p.nama, foto: p.foto))),
                                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                                  label: const Text('Kirim Pesan'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: XyTheme.primary,
                                    side: const BorderSide(color: XyTheme.primary),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(XyRadius.tombol),
                                    ),
                                  ),
                                ),
                              ),
                            ]),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _stat(String label, String nilai) => Expanded(
        child: Column(children: [
          Text(nilai,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: XyTheme.primary)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: XyTheme.of(context).muted)),
        ]),
      );

  Widget _pisah() => Container(width: 1, height: 28, color: XyTheme.of(context).line);
}
