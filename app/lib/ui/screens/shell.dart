import '../widgets/promo_overlay.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../../core/motion.dart';
import '../../data/push_service.dart';
import 'akun_screen.dart';
import 'cs_screen.dart';
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
    if (aksi == 'balas') {
      Navigator.push(context, xyRoute(const CsScreen()));
      context.read<AppState>().muatNotifikasi();
      return;
    }
    if (aksi == 'mulai') {
      Navigator.push(context, xyRoute(const OrderListScreen()));
      context.read<AppState>().muatNotifikasi();
      return;
    }

    switch (tipe) {
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
    final pad = MediaQuery.of(context).padding.bottom;

    return PromoLayer(child: Scaffold(
      extendBody: true,
      body: IndexedStack(index: idx, children: _pages),
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
          children: List.generate(_items.length, (i) {
            final on = i == idx;
            final it = _items[i];
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() => idx = i);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      height: 46,
                      width: on ? 70 : 50,
                      decoration: BoxDecoration(
                        gradient: on ? XyTheme.gradPrimary : null,
                        borderRadius: BorderRadius.circular(XyRadius.pill),
                        boxShadow: on ? XyTheme.glow(XyTheme.primary, .28) : null,
                      ),
                      child: Stack(alignment: Alignment.center, children: [
                        Icon(on ? it.$2 : it.$1, size: 23, color: on ? Colors.white : XyTheme.of(context).muted),
                      ]),
                    ),
                    const SizedBox(height: 6),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: on ? FontWeight.w800 : FontWeight.w600,
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
