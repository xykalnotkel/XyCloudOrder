import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import 'akun_screen.dart';
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

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: idx, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: XyTheme.surface,
          border: const Border(top: BorderSide(color: XyTheme.line)),
          boxShadow: [
            BoxShadow(color: XyTheme.ink.withOpacity(.06), blurRadius: 24, offset: const Offset(0, -6)),
          ],
        ),
        padding: EdgeInsets.only(bottom: pad > 0 ? pad - 4 : 8, top: 8, left: 6, right: 6),
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
                      height: 32,
                      width: on ? 56 : 40,
                      decoration: BoxDecoration(
                        gradient: on ? XyTheme.gradPrimary : null,
                        borderRadius: BorderRadius.circular(XyRadius.pill),
                        boxShadow: on ? XyTheme.glow(XyTheme.primary, .28) : null,
                      ),
                      child: Stack(alignment: Alignment.center, children: [
                        Icon(on ? it.$2 : it.$1, size: 19, color: on ? Colors.white : XyTheme.muted),
                      ]),
                    ),
                    const SizedBox(height: 5),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      style: TextStyle(
                        fontSize: 10.4,
                        fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                        color: on ? XyTheme.primary : XyTheme.muted,
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
    );
  }
}
