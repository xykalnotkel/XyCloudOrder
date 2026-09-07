import 'dart:async';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import '../widgets/error_state.dart';

/// ============================================================
///  Layar sesi main: menyiapkan PC, memasangkan perangkat,
///  lalu membuka streaming.
/// ============================================================
class SesiScreen extends StatefulWidget {
  const SesiScreen({super.key, required this.order});
  final RentOrder order;

  @override
  State<SesiScreen> createState() => _SesiScreenState();
}

class _SesiScreenState extends State<SesiScreen> {
  static const _paketStreaming = [
    ('com.limelight.noir', 'Artemis'),
    ('com.limelight', 'Moonlight'),
  ];

  SesiMain? sesi;
  String? galat;
  bool sibuk = false;
  Timer? _pantau;

  final _pin = TextEditingController();

  @override
  void initState() {
    super.initState();
    _mulai();
  }

  @override
  void dispose() {
    _pantau?.cancel();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _mulai() async {
    setState(() {
      sibuk = true;
      galat = null;
    });
    final s = context.read<AppState>();
    final hasil = await s.mulaiSesi(widget.order.id);
    if (!mounted) return;
    setState(() {
      sibuk = false;
      if (hasil == null) {
        galat = s.error ?? 'Tidak bisa menyiapkan sesi.';
      } else {
        sesi = hasil;
      }
    });
    if (hasil != null) _pantauBerkala();
  }

  void _pantauBerkala() {
    _pantau?.cancel();
    _pantau = Timer.periodic(const Duration(seconds: 4), (_) async {
      final id = sesi?.id;
      if (id == null || !mounted) return;
      final baru = await context.read<AppState>().statusSesi(id);
      if (!mounted || baru == null) return;
      setState(() => sesi = baru);
      if (baru.status == 'selesai' || baru.status == 'gagal') _pantau?.cancel();
    });
  }

  Future<void> _bukaStreaming() async {
    final host = sesi?.host ?? '';
    for (final (paket, nama) in _paketStreaming) {
      try {
        await AndroidIntent(
          action: 'action_main',
          package: paket,
          flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
        ).launch();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$nama dibuka. Tambahkan host $host lalu catat PIN-nya.')),
          );
        }
        return;
      } catch (_) {
        continue;
      }
    }

    if (!mounted) return;
    // belum terpasang: arahkan ke Play Store
    try {
      await AndroidIntent(
        action: 'action_view',
        data: 'https://play.google.com/store/apps/details?id=com.limelight',
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      ).launch();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pasang dulu aplikasi Moonlight dari Play Store.')),
        );
      }
    }
  }

  Future<void> _kirimPin() async {
    final kode = _pin.text.trim();
    if (kode.length != 4) {
      setState(() => galat = 'PIN harus 4 angka, sesuai yang muncul di aplikasi streaming.');
      return;
    }
    setState(() {
      sibuk = true;
      galat = null;
    });
    final pesan = await context.read<AppState>().kirimPinSesi(sesi!.id, kode);
    if (!mounted) return;
    setState(() {
      sibuk = false;
      if (pesan != null) galat = pesan;
    });
    if (pesan == null) {
      _pin.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN dikirim ke PC. Layar akan tersambung sebentar lagi.')),
      );
    }
  }

  Future<void> _akhiri() async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Akhiri sesi sekarang?'),
        content: const Text('PC akan dibersihkan dan sisa waktu sewa tidak dapat dilanjutkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Akhiri', style: TextStyle(color: XyTheme.danger)),
          ),
        ],
      ),
    );
    if (yakin != true || !mounted) return;
    await context.read<AppState>().akhiriSesi(sesi!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final status = sesi?.status ?? 'menyiapkan';

    return Scaffold(
      appBar: AppBar(title: const Text('Sesi Main')),
      body: galat != null && sesi == null
          ? GagalMuat(
              judul: 'Belum bisa mulai',
              pesan: galat!,
              ilustrasi: 'error',
              onCoba: _mulai,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              children: [
                _KartuStatus(status: status, order: widget.order, sesi: sesi),
                const SizedBox(height: 18),

                if (status == 'menyiapkan') ...[
                  _Langkah(
                    nomor: 1,
                    judul: 'Menyiapkan unit',
                    isi: 'Kami sedang menyalakan PC, membuat layar virtual, dan membersihkan sisa pemakaian '
                        'sebelumnya. Biasanya butuh 20 sampai 60 detik.',
                    aktif: true,
                    child: const Padding(
                      padding: EdgeInsets.only(top: 14),
                      child: LinearProgressIndicator(minHeight: 4),
                    ),
                  ),
                ],

                if (status == 'siap' || status == 'pairing') ...[
                  _Langkah(
                    nomor: 1,
                    judul: 'Unit siap',
                    isi: 'PC sudah menyala dan menunggu sambungan.',
                    selesai: true,
                  ),
                  _Langkah(
                    nomor: 2,
                    judul: 'Buka aplikasi streaming',
                    isi: 'Tekan tombol di bawah untuk membuka Moonlight atau Artemis, lalu tambahkan host:',
                    aktif: true,
                    child: Column(children: [
                      const SizedBox(height: 12),
                      _BarisSalin(label: 'Alamat host', nilai: sesi?.host ?? '-'),
                      const SizedBox(height: 12),
                      GradientButton(
                        label: 'Buka Aplikasi Streaming',
                        icon: Icons.sports_esports_rounded,
                        onPressed: _bukaStreaming,
                      ),
                    ]),
                  ),
                  _Langkah(
                    nomor: 3,
                    judul: 'Masukkan PIN pairing',
                    isi: 'Aplikasi streaming akan menampilkan 4 angka. Ketik angka itu di sini, '
                        'jangan di mana pun selain aplikasi ini.',
                    aktif: true,
                    child: Column(children: [
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _pin,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 8),
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(counterText: '', hintText: '0000'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 120,
                          child: GradientButton(
                            label: 'Kirim',
                            height: 52,
                            loading: sibuk,
                            onPressed: sibuk ? null : _kirimPin,
                          ),
                        ),
                      ]),
                      if (status == 'pairing')
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Row(children: [
                            SizedBox(
                                width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 10),
                            Text('Memasangkan perangkat...',
                                style: TextStyle(fontSize: 12, color: XyTheme.muted)),
                          ]),
                        ),
                    ]),
                  ),
                ],

                if (status == 'berjalan') ...[
                  _Langkah(
                    nomor: 1,
                    judul: 'Tersambung',
                    isi: 'Perangkatmu sudah dipasangkan. Buka aplikasi streaming dan pilih desktop '
                        'untuk mulai bermain. Sesi berhenti otomatis saat waktu habis.',
                    selesai: true,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: GradientButton(
                        label: 'Lanjut Main',
                        icon: Icons.play_arrow_rounded,
                        onPressed: _bukaStreaming,
                      ),
                    ),
                  ),
                ],

                if (status == 'gagal')
                  GagalMuat(
                    judul: 'Unit bermasalah',
                    pesan: sesi?.catatan ?? 'PC tidak merespons. Hubungi admin lewat Chat, saldo kamu aman.',
                    ilustrasi: 'error',
                    rapat: true,
                    onCoba: _mulai,
                  ),

                if (galat != null && sesi != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: XyTheme.danger.withOpacity(.07),
                      borderRadius: BorderRadius.circular(XyRadius.sm),
                      border: Border.all(color: XyTheme.danger.withOpacity(.22)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded, size: 18, color: XyTheme.danger),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(galat!,
                            style: const TextStyle(
                                color: XyTheme.danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),
                ],

                const SizedBox(height: 22),
                if (sesi != null && status != 'selesai')
                  OutlinedButton.icon(
                    onPressed: _akhiri,
                    icon: const Icon(Icons.stop_circle_outlined, size: 18, color: XyTheme.danger),
                    label: const Text('Akhiri Sesi',
                        style: TextStyle(color: XyTheme.danger, fontWeight: FontWeight.w700)),
                  ),

                const SizedBox(height: 20),
                XyCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                    Row(children: [
                      Icon(Icons.tips_and_updates_outlined, size: 18, color: XyTheme.primary),
                      SizedBox(width: 9),
                      Text('Biar lancar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                    ]),
                    SizedBox(height: 10),
                    Text(
                      'Pakai WiFi 5 GHz atau sinyal 4G penuh, minimal 15 Mbps. '
                      'Gamepad Bluetooth langsung terbaca. Kalau gambar patah-patah, turunkan bitrate '
                      'di pengaturan aplikasi streaming ke 10 Mbps.',
                      style: TextStyle(fontSize: 12.5, height: 1.6, color: XyTheme.muted),
                    ),
                  ]),
                ),
              ],
            ),
    );
  }
}

// ---------------- potongan tampilan ----------------
class _KartuStatus extends StatelessWidget {
  const _KartuStatus({required this.status, required this.order, this.sesi});
  final String status;
  final RentOrder order;
  final SesiMain? sesi;

  @override
  Widget build(BuildContext context) {
    final (warna, label) = switch (status) {
      'siap' => (XyTheme.success, 'Unit siap'),
      'pairing' => (XyTheme.warning, 'Memasangkan'),
      'berjalan' => (XyTheme.success, 'Sedang berjalan'),
      'gagal' => (XyTheme.danger, 'Bermasalah'),
      'selesai' => (XyTheme.muted, 'Selesai'),
      _ => (XyTheme.primary, 'Menyiapkan'),
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: XyTheme.gradDeep,
        borderRadius: BorderRadius.circular(XyRadius.xl),
        boxShadow: XyTheme.glow(XyTheme.primary, .22),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: warna.withOpacity(.22),
              borderRadius: BorderRadius.circular(XyRadius.pill),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: warna, shape: BoxShape.circle)),
              const SizedBox(width: 7),
              Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
            ]),
          ),
          const Spacer(),
          Text(order.kode, style: TextStyle(color: Colors.white.withOpacity(.6), fontSize: 12)),
        ]),
        const SizedBox(height: 16),
        Text(order.planNama,
            style: const TextStyle(
                color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -.6)),
        const SizedBox(height: 6),
        Text('Durasi sewa ${order.durasiJam} jam',
            style: TextStyle(color: Colors.white.withOpacity(.62), fontSize: 12.5)),
      ]),
    );
  }
}

class _Langkah extends StatelessWidget {
  const _Langkah({
    required this.nomor,
    required this.judul,
    required this.isi,
    this.aktif = false,
    this.selesai = false,
    this.child,
  });

  final int nomor;
  final String judul, isi;
  final bool aktif, selesai;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final warna = selesai ? XyTheme.success : (aktif ? XyTheme.primary : XyTheme.muted);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: XyCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: warna.withOpacity(.12), shape: BoxShape.circle),
              child: Center(
                child: selesai
                    ? const Icon(Icons.check_rounded, size: 16, color: XyTheme.success)
                    : Text('$nomor',
                        style: TextStyle(color: warna, fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(judul, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                const SizedBox(height: 5),
                Text(isi, style: const TextStyle(fontSize: 12.8, height: 1.55, color: XyTheme.muted)),
              ]),
            ),
          ]),
          if (child != null) child!,
        ]),
      ),
    );
  }
}

class _BarisSalin extends StatelessWidget {
  const _BarisSalin({required this.label, required this.nilai});
  final String label, nilai;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
        decoration: BoxDecoration(
          color: XyTheme.lineSoft,
          borderRadius: BorderRadius.circular(XyRadius.md),
        ),
        child: Row(children: [
          Text(label, style: const TextStyle(color: XyTheme.muted, fontSize: 12)),
          const Spacer(),
          Text(nilai, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 17, color: XyTheme.primary),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: nilai));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label disalin'), duration: const Duration(seconds: 1)),
              );
            },
          ),
        ]),
      );
}
