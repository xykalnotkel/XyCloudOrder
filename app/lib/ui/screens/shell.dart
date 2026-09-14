import '../widgets/promo_overlay.dart';
import '../widgets/rilis_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/pengaturan.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../../core/motion.dart';
import '../../data/push_service.dart';
import 'akun_screen.dart';
import 'cs_screen.dart';
import 'dm_chat_screen.dart';
import 'notifikasi_screen.dart';
import 'order_list_screen.dart';
import 'wallet_screen.dart';
import 'home_screen.dart';
import 'forum_screen.dart';
import 'profil_screen.dart';
import 'sewa_pc_screen.dart';

class XyShell extends StatefulWidget {
  const XyShell({super.key});
  @override
  State<XyShell> createState() => _XyShellState();
}

class _XyShellState extends State<XyShell> {
  int idx = 0;

  @override
  void initState() {
    super.initState();
    // buka halaman yang sesuai ketika notifikasi diketuk
    PushService.saatDiketuk = _tanganiNotif;
    final tertunda = PushService.tertunda;
    if (tertunda != null) {
      PushService.tertunda = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _tanganiNotif(tertunda));
    }
    // popup rilis (muncul otomatis bila ada versi baru; aman tampil sekali)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) _mungkinTampilkanRilis();
      });
    });
  }

  int _cobaRilis = 0;
  Future<void> _mungkinTampilkanRilis() async {
    if (!mounted) return;
    final s = context.read<AppState>();
    // tunggu data versi selesai dimuat (periksaPembaruan jalan di latar)
    if ((s.rilisTerbaru == null || s.versiSekarang.isEmpty) && _cobaRilis < 6) {
      _cobaRilis++;
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _mungkinTampilkanRilis();
      });
      return;
    }
    if (s.tampilkanBannerRilis && mounted) {
      s.tandaiBannerRilis();
      await tampilkanRilisPopup(context, s);
    }
  }

  @override
  void dispose() {
    PushService.saatDiketuk = null;
    super.dispose();
  }

  void _tanganiNotif(Map<String, dynamic> data) {
    if (!mounted) return;
    final tipe = '${data['tipe'] ?? ''}';
    final aksi = '${data['aksi'] ?? ''}';

    // tombol aksi dari notifikasi Android (lihat api/src/push.js)
    if (aksi == 'bisukan') {
      // Bisukan thread 1 jam di server supaya push thread ini berhenti.
      final thread = tipe == 'dm'
          ? 'dm:${data['dari'] ?? ''}'
          : (tipe == 'cs'
              ? 'cs'
              : 'forum:${data['post_id'] ?? data['id'] ?? ''}');
      context.read<AppState>().bisukanThread(thread, 60);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Notifikasi thread ini dibisukan selama 1 jam.')));
      context.read<AppState>().muatNotifikasi();
      return;
    }
    if (aksi == 'baca') {
      if (tipe == 'dm' && data['dari'] != null) {
        context.read<AppState>().repo.dmBaca('${data['dari']}').catchError((_) => <String, dynamic>{});
      }
      context.read<AppState>().muatNotifikasi();
      return;
    }
    if (aksi == 'balas') {
      if (tipe == 'dm' && data['dari'] != null) {
        Navigator.push(context,
            xyRoute(DmChatScreen(userId: '${data['dari']}', nama: data['nama'] as String?)));
      } else {
        Navigator.push(context, xyRoute(const CsScreen()));
      }
      context.read<AppState>().muatNotifikasi();
      return;
    }
    if (aksi == 'mulai') {
      Navigator.push(context, xyRoute(const OrderListScreen()));
      context.read<AppState>().muatNotifikasi();
      return;
    }

    switch (tipe) {
      case 'dm':
        Navigator.push(context,
            xyRoute(DmChatScreen(userId: '${data['dari'] ?? ''}', nama: data['nama'] as String?)));
        break;
      case 'cs':
        Navigator.push(context, xyRoute(const CsScreen()));
        break;
      case 'forum':
      case 'suka':
      case 'balasan':
      case 'komunitas':
        setState(() => idx = 3);
        context.read<AppState>().muatForum(paksa: true);
        break;
      case 'order':
      case 'sesi':
        Navigator.push(context, xyRoute(const OrderListScreen()));
        break;
      case 'wallet':
        Navigator.push(context, xyRoute(const WalletScreen()));
        break;
      case 'peringatan':
      case 'sistem':
        Navigator.push(context, xyRoute(const NotifikasiScreen()));
        break;
      default:
        setState(() => idx = 4);
    }
    context.read<AppState>().muatNotifikasi();
  }

  static const _pages = [
    HomeScreen(),
    SewaPcScreen(),
    AkunScreen(),
    ForumScreen(),
    ProfilScreen(),
  ];

  static const _items = [
    (Icons.grid_view_rounded, Icons.grid_view_rounded, 'Beranda'),
    (Icons.desktop_windows_outlined, Icons.desktop_windows_rounded, 'Sewa PC'),
    (Icons.storefront_outlined, Icons.storefront_rounded, 'Akun'),
    (Icons.groups_2_outlined, Icons.groups_2_rounded, 'Komunitas'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    // Rebuild saat pengaturan tampilan (mis. tombol tengah nav) berubah.
    context.watch<AppState>();
    final pad = MediaQuery.of(context).padding.bottom;
    // Halaman mana yang duduk di tombol tengah besar (bisa dipilih pengguna).
    final tengah =
        ((PengaturanLokal.nilai['navTengah'] as num?)?.toInt() ?? 2).clamp(0, 4);
    final urutan = [0, 1, 2, 3, 4];
    if (tengah != 2) {
      final t = urutan[2];
      urutan[2] = urutan[tengah];
      urutan[tengah] = t;
    }
    final posisi = urutan.indexOf(idx);

    return PromoLayer(child: Scaffold(
      extendBody: true,
      body: GestureDetector(
        // Swipe kiri/kanan di body = pindah tab (mengikuti urutan tombol nav).
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v.abs() < 260) return;
          final baru = v < 0 ? posisi + 1 : posisi - 1;
          if (baru < 0 || baru >= urutan.length) return;
          HapticFeedback.selectionClick();
          setState(() => idx = urutan[baru]);
        },
        child: IndexedStack(index: idx, children: _pages),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: XyTheme.of(context).surface,
          border:  Border(top: BorderSide(color: XyTheme.of(context).line)),
          boxShadow: [
            BoxShadow(color: XyTheme.of(context).ink.withOpacity(.06), blurRadius: 24, offset: const Offset(0, -6)),
          ],
        ),
        padding: EdgeInsets.only(bottom: pad > 0 ? pad - 2 : 11, top: 11, left: 6, right: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(_items.length, (i) {
            final pageIdx = urutan[i];
            final on = pageIdx == idx;
            final it = _items[pageIdx];
            final isTengah = i == 2;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() => idx = pageIdx);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      height: isTengah ? 56 : 46,
                      width: isTengah ? (on ? 92 : 72) : (on ? 70 : 50),
                      decoration: BoxDecoration(
                        gradient: on ? XyTheme.gradPrimary : null,
                        borderRadius: BorderRadius.circular(XyRadius.pill),
                        border: isTengah && !on
                            ? Border.all(
                                color: XyTheme.primary.withOpacity(.45), width: 1.6)
                            : null,
                        boxShadow: on
                            ? XyTheme.glow(
                                XyTheme.primary, isTengah ? .38 : .28)
                            : null,
                      ),
                      child: Stack(alignment: Alignment.center, children: [
                        Icon(on ? it.$2 : it.$1,
                            size: isTengah ? 27 : 23,
                            color: on
                                ? Colors.white
                                : (isTengah
                                    ? XyTheme.primary
                                    : XyTheme.of(context).muted)),
                      ]),
                    ),
                    const SizedBox(height: 6),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      style: TextStyle(
                        fontSize: isTengah ? 12.5 : 12,
                        fontWeight:
                            (on || isTengah) ? FontWeight.w700 : FontWeight.w600,
                        color: on ? XyTheme.primary : XyTheme.of(context).muted,
                      ),
                      child: Text(it.$3),
                    ),
                  ]),
                ),
              ),
            );
          }),
        ),
      ),
    ));
  }
}
