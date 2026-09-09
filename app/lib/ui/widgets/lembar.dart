import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'common.dart';

/// ============================================================
///  Lembar bawah pengganti popup bawaan sistem
/// ============================================================
///  Dipakai supaya semua konfirmasi dan formulir singkat memakai
///  gaya XyCloudStore, bukan kotak dialog abu-abu bawaan Android.

/// Konfirmasi ya/tidak. Mengembalikan true kalau pengguna setuju.
Future<bool> konfirmasi(
  BuildContext context, {
  required String judul,
  required String pesan,
  String tombolYa = 'Lanjutkan',
  String tombolTidak = 'Batal',
  IconData ikon = Icons.help_outline_rounded,
  bool bahaya = false,
}) async {
  final hasil = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (d) => _Bingkai(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: (bahaya ? XyTheme.danger : XyTheme.primary).withOpacity(.10),
            shape: BoxShape.circle,
          ),
          child: Icon(ikon, color: bahaya ? XyTheme.danger : XyTheme.primary, size: 26),
        ),
        const SizedBox(height: 16),
        Text(judul,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, letterSpacing: -.4)),
        const SizedBox(height: 8),
        Text(pesan,
            textAlign: TextAlign.center,
            style:  TextStyle(color: XyTheme.of(context).muted, fontSize: 13.2, height: 1.6)),
        const SizedBox(height: 22),
        Row(children: [
          Expanded(
            child: SizedBox(
              height: 50,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(d, false),
                child: Text(tombolTidak),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GradientButton(
              label: tombolYa,
              height: 50,
              gradient: bahaya
                  ? const LinearGradient(colors: [Color(0xFFE05B5B), Color(0xFFC81E1E)])
                  : XyTheme.gradPrimary,
              glowColor: bahaya ? XyTheme.danger : XyTheme.primary,
              onPressed: () => Navigator.pop(d, true),
            ),
          ),
        ]),
      ]),
    ),
  );
  return hasil ?? false;
}

/// Pemberitahuan singkat dengan satu tombol.
Future<void> beritahu(
  BuildContext context, {
  required String judul,
  required String pesan,
  IconData ikon = Icons.info_outline_rounded,
  String tombol = 'Mengerti',
}) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (d) => _Bingkai(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(color: XyTheme.of(context).primarySoft, shape: BoxShape.circle),
          child: Icon(ikon, color: XyTheme.primary, size: 26),
        ),
        const SizedBox(height: 16),
        Text(judul,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, letterSpacing: -.4)),
        const SizedBox(height: 8),
        Text(pesan,
            textAlign: TextAlign.center,
            style:  TextStyle(color: XyTheme.of(context).muted, fontSize: 13.2, height: 1.6)),
        const SizedBox(height: 20),
        GradientButton(label: tombol, height: 50, onPressed: () => Navigator.pop(d)),
      ]),
    ),
  );
}

/// Lembar isian sederhana. Kembalikan null kalau dibatalkan.
Future<String?> tanyaTeks(
  BuildContext context, {
  required String judul,
  String? keterangan,
  String? nilaiAwal,
  String petunjuk = '',
  int maksBaris = 1,
  TextInputType tipe = TextInputType.text,
  String tombol = 'Simpan',
}) async {
  final ctrl = TextEditingController(text: nilaiAwal ?? '');
  final hasil = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (d) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(d).viewInsets.bottom),
      child: _Bingkai(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(judul, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, letterSpacing: -.4)),
          if (keterangan != null) ...[
            const SizedBox(height: 6),
            Text(keterangan, style:  TextStyle(color: XyTheme.of(context).muted, fontSize: 12.8, height: 1.5)),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            autofocus: true,
            maxLines: maksBaris,
            keyboardType: tipe,
            decoration: InputDecoration(hintText: petunjuk),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton(onPressed: () => Navigator.pop(d), child: const Text('Batal')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GradientButton(
                label: tombol,
                height: 50,
                onPressed: () => Navigator.pop(d, ctrl.text.trim()),
              ),
            ),
          ]),
        ]),
      ),
    ),
  );
  return hasil;
}

class _Bingkai extends StatelessWidget {
  const _Bingkai({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(22, 14, 22, MediaQuery.of(context).padding.bottom + 22),
        decoration:  BoxDecoration(
          color: XyTheme.of(context).bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 44,
            height: 4.5,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: XyTheme.of(context).line, borderRadius: BorderRadius.circular(10)),
          ),
          child,
        ]),
      );
}

/// Pilihan alasan saat melaporkan konten.
Future<String?> pilihAlasanLaporan(BuildContext context) async {
  const alasan = [
    'Konten dewasa atau vulgar',
    'Penipuan atau penjualan ilegal',
    'Kata kasar atau melecehkan',
    'Spam atau iklan berulang',
    'Alasan lain',
  ];

  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (d) => _Bingkai(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Laporkan konten',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, letterSpacing: -.4)),
        const SizedBox(height: 6),
         Text('Pilih alasannya. Admin akan meninjau dalam waktu singkat.',
            style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12.8, height: 1.5)),
        const SizedBox(height: 14),
        ...alasan.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Pressable(
                onTap: () => Navigator.pop(d, a),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
                  decoration: BoxDecoration(
                    color: XyTheme.of(context).surface,
                    borderRadius: BorderRadius.circular(XyRadius.md),
                    border: Border.all(color: XyTheme.of(context).line),
                  ),
                  child: Row(children: [
                    Expanded(child: Text(a, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
                     Icon(Icons.chevron_right_rounded, size: 18, color: XyTheme.of(context).muted),
                  ]),
                ),
              ),
            )),
      ]),
    ),
  );
}
