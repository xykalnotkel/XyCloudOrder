import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import 'akun_screen.dart';
import 'cs_screen.dart';
import 'home_screen.dart';
import 'order_list_screen.dart';
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
    OrderListScreen(),
    CsScreen(),
  ];

  static const _items = [
    (Icons.grid_view_rounded, Icons.grid_view_rounded, 'Beranda'),
    (Icons.desktop_windows_outlined, Icons.desktop_windows_rounded, 'Sewa PC'),
    (Icons.storefront_outlined, Icons.storefront_rounded, 'Akun'),
    (Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Order'),
    (Icons.support_agent_outlined, Icons.support_agent_rounded, 'Bantuan'),
  ];

  @override
  Widget build(BuildContext context) {
    final belum = context.select<AppState, int>((s) => s.notifBelumDibaca);
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
                  if (i == 4) context.read<AppState>().bacaNotif();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      height: 32,
                      width: on ? 58 : 40,
                      decoration: BoxDecoration(
                        gradient: on ? XyTheme.gradPrimary : null,
                        borderRadius: BorderRadius.circular(XyRadius.pill),
                        boxShadow: on ? XyTheme.glow(XyTheme.primary, .28) : null,
                      ),
                      child: Stack(alignment: Alignment.center, children: [
                        Icon(on ? it.$2 : it.$1, size: 20, color: on ? Colors.white : XyTheme.muted),
                        if (i == 4 && belum > 0)
                          Positioned(
                            right: on ? 9 : 4,
                            top: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              constraints: const BoxConstraints(minWidth: 15),
                              height: 15,
                              decoration: BoxDecoration(
                                color: XyTheme.danger,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: Center(
                                child: Text('$belum',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ),
                      ]),
                    ),
                    const SizedBox(height: 5),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      style: TextStyle(
                        fontSize: 10.5,
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
