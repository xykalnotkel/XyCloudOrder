import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import 'common.dart';

/// ============================================================
///  Alur isi saldo yang sungguhan:
///  1. pilih nominal
///  2. server memberi total unik + rekening tujuan
///  3. pengguna transfer lalu mengunggah bukti
///  4. admin menyetujui, saldo bertambah otomatis
/// ============================================================
Future<void> bukaTopup(BuildContext context, {int? nominalAwal}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SheetTopup(nominalAwal: nominalAwal),
  );
}

class _SheetTopup extends StatefulWidget {
  const _SheetTopup({this.nominalAwal});
  final int? nominalAwal;

  @override
  State<_SheetTopup> createState() => _SheetTopupState();
}

class _SheetTopupState extends State<_SheetTopup> {
  static const List<int> pilihan = [25000, 50000, 100000, 250000, 500000, 1000000];

  late int nominal = widget.nominalAwal ?? 50000;
  final _lain = TextEditingController();
  String metode = 'transfer';

  PermintaanTopup? dibuat;
  bool mengunggah = false;

  @override
  void dispose() {
    _lain.dispose();
    super.dispose();
  }

  Future<void> _buat() async {
    final s = context.read<AppState>();
    final t = await s.buatTopup(nominal, metode);
    if (!mounted) return;
    if (t == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.error ?? 'Gagal membuat permintaan top up.')),
      );
      return;
    }
    setState(() => dibuat = t);
  }

  Future<void> _unggahBukti() async {
    final berkas = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1400,
      imageQuality: 78,
    );
    if (berkas == null) return;

    setState(() => mengunggah = true);
    final bytes = await berkas.readAsBytes();
    final tipe = berkas.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
    final dataUri = 'data:image/$tipe;base64,${base64Encode(bytes)}';

    final s = context.read<AppState>();
    final galat = await s.unggahBukti(dibuat!.id, dataUri);
    if (!mounted) return;
    setState(() => mengunggah = false);

    if (galat != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(galat)));
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bukti terkirim. Saldo masuk setelah admin memeriksa, biasanya kurang dari 10 menit.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final rek = dibuat?.rekening.isNotEmpty == true ? dibuat!.rekening : s.konfigurasi.rekening;

    return DraggableScrollableSheet(
      initialChildSize: dibuat == null ? .70 : .82,
      maxChildSize: .95,
      minChildSize: .5,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: XyTheme.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          Container(
            width: 44,
            height: 4.5,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: XyTheme.line, borderRadius: BorderRadius.circular(10)),
          ),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: dibuat == null ? _langkahPilih(s) : _langkahBayar(rek),
            ),
          ),
        ]),
      ),
    );
  }

  // ---------------- langkah 1: pilih nominal ----------------
  List<Widget> _langkahPilih(AppState s) => [
        const Text('Isi Saldo',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -.8)),
        const SizedBox(height: 6),
        Text('Minimal ${rupiah(s.konfigurasi.minTopup)}. Saldo dipakai untuk sewa PC dan beli akun.',
            style: const TextStyle(color: XyTheme.muted, fontSize: 13, height: 1.5)),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: pilihan.map((n) {
            final aktif = n == nominal;
            return Pressable(
              onTap: () => setState(() {
                nominal = n;
                _lain.clear();
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: (MediaQuery.of(context).size.width - 60) / 2,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: aktif ? XyTheme.primary : XyTheme.surface,
                  borderRadius: BorderRadius.circular(XyRadius.tombol),
                  border: Border.all(color: aktif ? XyTheme.primary : XyTheme.line),
                  boxShadow: aktif ? XyTheme.glow(XyTheme.primary, .22) : null,
                ),
                child: Center(
                  child: Text(rupiah(n),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: aktif ? Colors.white : XyTheme.ink,
                      )),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _lain,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) => setState(() => nominal = int.tryParse(v) ?? nominal),
          decoration: const InputDecoration(
            hintText: 'Nominal lain, contoh 75000',
            prefixIcon: Icon(Icons.edit_rounded),
          ),
        ),
        const SizedBox(height: 18),
        const Text('Metode Pembayaran',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
        const SizedBox(height: 10),
        if (s.konfigurasi.metodeBayar.isEmpty)
          Row(children: [
            Expanded(child: _pilihMetode('transfer', 'Transfer Bank', Icons.account_balance_rounded)),
            const SizedBox(width: 10),
            Expanded(child: _pilihMetode('qris', 'QRIS', Icons.qr_code_2_rounded)),
          ])
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: s.konfigurasi.metodeBayar.map((m) {
              final kode = '${m['kode']}';
              return SizedBox(
                width: (MediaQuery.of(context).size.width - 60) / 2,
                child: _pilihMetode(kode, '${m['nama']}', _ikonMetode(kode)),
              );
            }).toList(),
          ),
        if (s.konfigurasi.bayarOtomatis) ...[
          const SizedBox(height: 12),
          Row(children: const [
            Icon(Icons.flash_on_rounded, size: 15, color: XyTheme.success),
            SizedBox(width: 7),
            Expanded(
              child: Text('Saldo masuk otomatis begitu pembayaran berhasil, tanpa menunggu admin.',
                  style: TextStyle(color: XyTheme.success, fontSize: 11.8, fontWeight: FontWeight.w600)),
            ),
          ]),
        ],
        const SizedBox(height: 22),
        GradientButton(
          label: 'Lanjut Bayar ${rupiah(nominal)}',
          icon: Icons.arrow_forward_rounded,
          loading: s.loading,
          onPressed: nominal < s.konfigurasi.minTopup ? null : _buat,
        ),
        const SizedBox(height: 10),
        const Center(
          child: Text('Saldo masuk setelah admin memverifikasi bukti transfer.',
              style: TextStyle(color: XyTheme.muted, fontSize: 11.5)),
        ),
      ];

  IconData _ikonMetode(String kode) {
    final k = kode.toUpperCase();
    if (k.contains('QRIS')) return Icons.qr_code_2_rounded;
    if (k.contains('DANA') || k.contains('OVO') || k.contains('SHOPEE')) return Icons.account_balance_wallet_rounded;
    if (k.contains('VA')) return Icons.account_balance_rounded;
    if (k == 'SNAP') return Icons.payments_rounded;
    return Icons.credit_card_rounded;
  }

  Widget _pilihMetode(String id, String label, IconData ikon) {
    final aktif = metode == id;
    return Pressable(
      onTap: () => setState(() => metode = id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: aktif ? XyTheme.primarySoft : XyTheme.surface,
          borderRadius: BorderRadius.circular(XyRadius.lg),
          border: Border.all(color: aktif ? XyTheme.primary : XyTheme.line, width: aktif ? 1.6 : 1),
        ),
        child: Column(children: [
          Icon(ikon, size: 22, color: aktif ? XyTheme.primary : XyTheme.muted),
          const SizedBox(height: 7),
          Text(label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: aktif ? XyTheme.primary : XyTheme.inkSoft,
              )),
        ]),
      ),
    );
  }

  // ---------------- langkah 2: bayar dan unggah bukti ----------------
  List<Widget> _langkahBayar(Map<String, dynamic> rek) {
    final t = dibuat!;

    // jalur otomatis: cukup buka tautan pembayaran
    if (t.otomatis && (t.bayar['url'] != null || t.bayar['qr'] != null)) {
      return [
        Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(color: XyTheme.primarySoft, shape: BoxShape.circle),
            child: const Icon(Icons.bolt_rounded, color: XyTheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Bayar Sekarang',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -.5)),
          ),
        ]),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: XyTheme.gradPrimary,
            borderRadius: BorderRadius.circular(XyRadius.xl),
            boxShadow: XyTheme.glow(XyTheme.primary, .22),
          ),
          child: Column(children: [
            const Text('Total pembayaran', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 6),
            Text(rupiah(t.total),
                style: const TextStyle(
                    color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1)),
          ]),
        ),
        if (t.bayar['qr'] != null) ...[
          const SizedBox(height: 16),
          XyCard(
            child: Column(children: [
              const Text('Pindai QRIS di bawah ini',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(XyRadius.md),
                child: Image.network('${t.bayar['qr']}', height: 250, fit: BoxFit.contain),
              ),
            ]),
          ),
        ],
        if (t.bayar['kode'] != null) ...[
          const SizedBox(height: 14),
          XyCard(child: _barisRek('Kode pembayaran', '${t.bayar['kode']}', salin: true)),
        ],
        const SizedBox(height: 18),
        if (t.bayar['url'] != null)
          GradientButton(
            label: 'Buka Halaman Pembayaran',
            icon: Icons.open_in_new_rounded,
            onPressed: () => _bukaTautan('${t.bayar['url']}'),
          ),
        const SizedBox(height: 12),
        const Center(
          child: Text('Saldo bertambah otomatis setelah pembayaran berhasil.\nHalaman ini boleh ditutup.',
              textAlign: TextAlign.center,
              style: TextStyle(color: XyTheme.muted, fontSize: 11.8, height: 1.5)),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
        ),
      ];
    }

    return [
      Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: XyTheme.primarySoft, shape: BoxShape.circle),
          child: const Icon(Icons.receipt_long_rounded, color: XyTheme.primary, size: 21),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text('Selesaikan Pembayaran',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -.5)),
        ),
      ]),
      const SizedBox(height: 18),

      // total yang harus ditransfer
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: XyTheme.gradPrimary,
          borderRadius: BorderRadius.circular(XyRadius.xl),
          boxShadow: XyTheme.glow(XyTheme.primary, .22),
        ),
        child: Column(children: [
          const Text('Transfer tepat sejumlah',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          Text(rupiah(t.total),
              style: const TextStyle(
                  color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1)),
          const SizedBox(height: 6),
          Text('Termasuk kode unik ${t.kodeUnik} untuk pencocokan otomatis',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.4)),
          const SizedBox(height: 14),
          Pressable(
            onTap: () {
              Clipboard.setData(ClipboardData(text: '${t.total}'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Nominal disalin'), duration: Duration(seconds: 1)),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.18),
                borderRadius: BorderRadius.circular(XyRadius.pill),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.copy_rounded, size: 15, color: Colors.white),
                SizedBox(width: 7),
                Text('Salin nominal',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
              ]),
            ),
          ),
        ]),
      ),

      const SizedBox(height: 16),
      XyCard(
        child: Column(children: [
          _barisRek('Metode', t.metode == 'qris' ? 'QRIS' : 'Transfer Bank'),
          const Divider(height: 20),
          _barisRek('Bank', '${rek['bank'] ?? '-'}'),
          const Divider(height: 20),
          _barisRek('Nomor Rekening', '${rek['nomor'] ?? '-'}', salin: true),
          const Divider(height: 20),
          _barisRek('Atas Nama', '${rek['atasNama'] ?? '-'}'),
        ]),
      ),

      if (t.metode == 'qris' && '${rek['qris'] ?? ''}'.isNotEmpty) ...[
        const SizedBox(height: 14),
        XyCard(
          child: Column(children: [
            const Text('Pindai QRIS di bawah ini',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(XyRadius.md),
              child: Image.network('${rek['qris']}', height: 240, fit: BoxFit.contain),
            ),
          ]),
        ),
      ],

      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: XyTheme.warning.withOpacity(.08),
          borderRadius: BorderRadius.circular(XyRadius.md),
          border: Border.all(color: XyTheme.warning.withOpacity(.25)),
        ),
        child: const Row(children: [
          Icon(Icons.info_outline_rounded, color: XyTheme.warning, size: 19),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Transfer sampai 3 angka terakhir persis, lalu unggah bukti supaya admin bisa langsung memverifikasi.',
              style: TextStyle(fontSize: 12.3, height: 1.5, fontWeight: FontWeight.w600, color: XyTheme.inkSoft),
            ),
          ),
        ]),
      ),

      const SizedBox(height: 18),
      GradientButton(
        label: mengunggah ? 'Mengunggah...' : 'Unggah Bukti Transfer',
        icon: Icons.upload_rounded,
        loading: mengunggah,
        onPressed: mengunggah ? null : _unggahBukti,
      ),
      const SizedBox(height: 10),
      Center(
        child: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Nanti saja, saya sudah catat nominalnya'),
        ),
      ),
    ];
  }

  Future<void> _bukaTautan(String url) async {
    try {
      await AndroidIntent(
        action: 'action_view',
        data: url,
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      ).launch();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak bisa membuka halaman pembayaran.')),
        );
      }
    }
  }

  Widget _barisRek(String k, String v, {bool salin = false}) => Row(children: [
        Text(k, style: const TextStyle(color: XyTheme.muted, fontSize: 12.5)),
        const Spacer(),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
        if (salin) ...[
          const SizedBox(width: 8),
          Pressable(
            onTap: () {
              Clipboard.setData(ClipboardData(text: v));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Nomor rekening disalin'), duration: Duration(seconds: 1)),
              );
            },
            child: const Icon(Icons.copy_rounded, size: 16, color: XyTheme.primary),
          ),
        ],
      ]);
}

/// Kartu status permintaan top up di layar dompet.
class KartuTopup extends StatelessWidget {
  const KartuTopup(this.t, {super.key});
  final PermintaanTopup t;

  @override
  Widget build(BuildContext context) {
    final (warna, label, ikon) = switch (t.status) {
      'disetujui' => (XyTheme.success, 'Saldo sudah masuk', Icons.check_circle_rounded),
      'ditolak' => (XyTheme.danger, 'Ditolak', Icons.cancel_rounded),
      'diperiksa' => (XyTheme.warning, 'Sedang diperiksa admin', Icons.hourglass_bottom_rounded),
      _ => (XyTheme.muted, 'Menunggu pembayaran', Icons.schedule_rounded),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: XyCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: warna.withOpacity(.10), shape: BoxShape.circle),
            child: Icon(ikon, color: warna, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Top up ${rupiah(t.nominal)}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.8)),
              const SizedBox(height: 3),
              Text(t.catatan ?? label,
                  style: TextStyle(color: warna, fontSize: 11.8, fontWeight: FontWeight.w600)),
            ]),
          ),
          Text(tanggal(t.dibuat),
              style: const TextStyle(color: XyTheme.muted, fontSize: 11)),
        ]),
      ),
    );
  }
}
