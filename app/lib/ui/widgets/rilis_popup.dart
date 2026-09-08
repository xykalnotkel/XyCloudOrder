import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../screens/pembaruan_screen.dart';
import 'common.dart';
import 'morph_bg.dart';

/// ============================================================
///  RilisPopup — banner muncul saat ada versi baru
/// ============================================================
///  Menampilkan gambar rilis (murni, tanpa teks di atas gambar) dengan
///  latar morphing elemen melayang. Tombol X → tutup popup lalu buka
///  [PembaruanScreen] untuk memperbarui langsung dari aplikasi.
Future<void> tampilkanRilisPopup(BuildContext context, AppState s) async {
  final r = s.rilisTerbaru;
  if (r == null) return;
  final hasil = await showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Rilis',
    barrierColor: Colors.black.withOpacity(.55),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, __, ___) => RilisPopup(rilis: r),
  );
  if (hasil == 'buka' && context.mounted) {
    Navigator.of(context, rootNavigator: true)
        .push(MaterialPageRoute(builder: (_) => const PembaruanScreen()));
  }
}

class RilisPopup extends StatelessWidget {
  const RilisPopup({super.key, required this.rilis});
  final Map<String, dynamic> rilis;

  @override
  Widget build(BuildContext context) {
    final versi = '${rilis['versi'] ?? ''}';
    final gambar = '${rilis['gambar'] ?? ''}';
    final skema = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(22),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Container(
          decoration: BoxDecoration(color: XyTheme.of(context).bg),
          constraints: const BoxConstraints(maxHeight: 560),
          child: Stack(children: [
            // latar elemen melayang (morphing)
            const Positioned.fill(child: IgnorePointer(child: XyMorphBg(saturasi: .7))),
            Column(mainAxisSize: MainAxisSize.min, children: [
              // gambar murni rilis (bukan placeholder teks)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: gambar.isEmpty
                    ? Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: XyTheme.gradPrimary,
                          boxShadow: XyTheme.glow(XyTheme.primary, .2),
                        ),
                        alignment: Alignment.center,
                        child: const XyIlustrasi('maintenance', tinggi: 130),
                      )
                    : Image.network(gambar,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => Container(
                              decoration: BoxDecoration(gradient: XyTheme.gradPrimary),
                            )),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: XyTheme.primary.withOpacity(.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text('Pembaruan $_versi',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              color: XyTheme.primary)),
                    ),
                    const Spacer(),
                    Text('Baru',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            color: skema ? XyTheme.lavender : XyTheme.violet)),
                  ]),
                  const SizedBox(height: 8),
                  const Text('Ada versi baru, makin mulus & cepat',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, height: 1.3)),
                  const SizedBox(height: 10),
                  const Text(
                    'Sentuh X untuk membuka layar pembaruan dan pasang versi terbaru langsung dari aplikasi.',
                    style: TextStyle(fontSize: 12.5, height: 1.5),
                  ),
                ]),
              ),
            ]),
            // tombol X (ke layar pembaruan) di pojok kanan atas gambar
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () => Navigator.pop(context, 'buka'),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.92),
                    shape: BoxShape.circle,
                    boxShadow: XyTheme.shadowXs,
                  ),
                  child: Icon(Icons.close_rounded, size: 19, color: XyTheme.ink),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
