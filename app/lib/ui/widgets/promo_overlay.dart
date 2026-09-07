import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/promosi.dart';
import '../../providers/app_state.dart';
import 'tautan_promo.dart';

/// Promo hanya melapisi shell, bukan login, pembayaran, atau editor komentar.
/// Popup maksimal satu per sesi, sekali per revisi promo di perangkat ini.
class PromoLayer extends StatefulWidget {
  const PromoLayer({super.key, required this.child});
  final Widget child;
  @override
  State<PromoLayer> createState() => _PromoLayerState();
}

class _PromoLayerState extends State<PromoLayer> {
  SharedPreferences? _prefs;
  final _pos = <String, Offset>{};
  final _closed = <String>{}, _attempted = <String>{};
  bool _popupBusy = false, _popupShown = false;
  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _prefs = p);
    });
  }

  String _seen(Promosi p) => 'xy_promo_seen_${p.versiKey}';
  String _hide(Promosi p) => 'xy_promo_hide_${p.versiKey}';
  Future<void> _popup(Promosi p) async {
    if (_popupBusy ||
        _popupShown ||
        !mounted ||
        _attempted.contains(p.versiKey)) return;
    if (ModalRoute.of(context)?.isCurrent != true ||
        MediaQuery.viewInsetsOf(context).bottom > 0) return;
    _popupBusy = true;
    _attempted.add(p.versiKey);
    try {
      var gambarSiap = true;
      await precacheImage(NetworkImage(p.gambar), context,
          onError: (_, __) { gambarSiap = false; })
          .timeout(const Duration(seconds: 12));
      if (!gambarSiap) return;
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      _popupShown = true;
      await _prefs!.setBool(_seen(p), true);
      if (!mounted) return;
      final buka = await showDialog<bool>(
          context: context,
          barrierColor: Colors.black.withOpacity(.72),
          builder: (ctx) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: 420,
                      maxHeight: MediaQuery.sizeOf(ctx).height * .74),
                  child: Stack(alignment: Alignment.topRight, children: [
                    Padding(
                        padding: const EdgeInsets.only(top: 18, right: 12),
                        child: GestureDetector(
                            onTap: () => Navigator.pop(ctx, true),
                            child: Semantics(
                                button: true,
                                label: p.nama,
                                child: ClipRRect(
                                    borderRadius: BorderRadius.circular(22),
                                    child: Image.network(p.gambar,
                                        fit: BoxFit.contain))))),
                    IconButton.filled(
                        tooltip: 'Tutup promo',
                        onPressed: () => Navigator.pop(ctx, false),
                        style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87),
                        icon: const Icon(Icons.close_rounded, size: 22)),
                  ]))));
      if (buka == true && mounted)
        await bukaTujuanPromo(context, p.aksi, p.target);
    } catch (_) {
      /* Tidak menutup konten utama ketika media tidak tersedia. */
    } finally {
      _popupBusy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = context.watch<AppState>().promosi;
    final prefs = _prefs;
    if (prefs == null) return widget.child;
    final pop = all.where((p) =>
        p.jenis == 'popup' &&
        prefs.getBool(_seen(p)) != true &&
        !_attempted.contains(p.versiKey));
    if (pop.isNotEmpty && !_popupBusy && !_popupShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _popup(pop.first);
      });
    }
    final floating = all
        .where((p) =>
            p.jenis == 'floating' &&
            !_closed.contains(p.versiKey) &&
            prefs.getBool(_hide(p)) != true)
        .take(2)
        .toList();
    return LayoutBuilder(builder: (ctx, c) {
      final minY = MediaQuery.paddingOf(ctx).top + 8;
      final maxX = math.max(8.0, c.maxWidth - 120);
      final maxY =
          math.max(minY, c.maxHeight - MediaQuery.paddingOf(ctx).bottom - 222);
      return Stack(fit: StackFit.expand, children: [
        widget.child,
        if (MediaQuery.viewInsetsOf(ctx).bottom == 0)
          for (var i = 0; i < floating.length; i++)
            Builder(builder: (ctx) {
              final p = floating[i];
              final savedX = prefs.getDouble('xy_promo_x_${p.id}');
              final savedY = prefs.getDouble('xy_promo_y_${p.id}');
              final initial = Offset(
                  savedX == null
                      ? (p.posisi == 'kiri' ? 8 : maxX)
                      : 8 + savedX * (maxX - 8),
                  savedY == null
                      ? (maxY - i * 138).clamp(minY, maxY)
                      : minY + savedY * (maxY - minY));
              final xy = _pos[p.id] ?? initial;
              final x = xy.dx.clamp(8.0, maxX), y = xy.dy.clamp(minY, maxY);
              return Positioned(
                  left: x,
                  top: y,
                  width: 112,
                  height: 126,
                  child: Stack(children: [
                    Positioned.fill(
                        top: 14,
                        right: 8,
                        child: GestureDetector(
                          onTap: () =>
                              bukaTujuanPromo(context, p.aksi, p.target),
                          onPanUpdate: (d) => setState(() => _pos[p.id] =
                              Offset((x + d.delta.dx).clamp(8.0, maxX),
                                  (y + d.delta.dy).clamp(minY, maxY))),
                          onPanEnd: (_) async {
                            final z = _pos[p.id] ?? initial;
                            await prefs.setDouble('xy_promo_x_${p.id}',
                                (z.dx - 8) / math.max(1, maxX - 8));
                            await prefs.setDouble('xy_promo_y_${p.id}',
                                (z.dy - minY) / math.max(1, maxY - minY));
                          },
                          child: Semantics(
                              button: true,
                              label: '${p.nama}. Dapat digeser.',
                              child: Image.network(p.gambar,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink())),
                        )),
                    Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton.filled(
                            tooltip: 'Tutup promo melayang',
                            visualDensity: VisualDensity.compact,
                            style: IconButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black87),
                            icon: const Icon(Icons.close_rounded, size: 16),
                            onPressed: () async {
                              setState(() => _closed.add(p.versiKey));
                              await prefs.setBool(_hide(p), true);
                            })),
                  ]));
            }),
      ]);
    });
  }
}
