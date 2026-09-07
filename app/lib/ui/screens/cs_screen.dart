import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import '../widgets/lembar.dart';
import 'dart:async';

/// Live chat CS — pesan masuk lewat WebSocket (atau simulasi di mode mock).
class CsScreen extends StatefulWidget {
  const CsScreen({super.key});
  @override
  State<CsScreen> createState() => _CsScreenState();
}

class _CsScreenState extends State<CsScreen> {
  final ctrl = TextEditingController();
  final scroll = ScrollController();
  bool _sending = false;
  Timer? _retensi;

  static const cepat = [
    'Halo Kirana, aku mau tanya',
    'Cara isi saldo gimana?',
    'PC-nya lag, tolong dicek',
    'Akun yang aku beli bermasalah',
    'Berapa lama garansinya?',
    'Mau minta refund pesanan',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().muatChat();
      _keBawah();
    });
    _retensi = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) context.read<AppState>().muatChat();
    });
  }

  void _keBawah({bool animasi = true}) {
    if (!scroll.hasClients) return;
    final tujuan = scroll.position.maxScrollExtent;
    if (animasi) {
      scroll.animateTo(tujuan,
          duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
    } else {
      scroll.jumpTo(tujuan);
    }
  }

  /// Ambil gambar dari galeri lalu kirim sebagai lampiran chat.
  Future<void> _kirimGambar() async {
    final f = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1400, imageQuality: 78);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    final tipe = f.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
    final dataUri = 'data:image/$tipe;base64,${base64Encode(bytes)}';
    if (!mounted) return;
    await context
        .read<AppState>()
        .kirimChat('', gambar: dataUri, pratinjau: dataUri);
    if (mounted) _keBawah();
  }

  Future<void> _kirim([String? teks]) async {
    final t = (teks ?? ctrl.text).trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    final e = await context.read<AppState>().kirimChat(t);
    if (!mounted) return;
    setState(() => _sending = false);
    if (e == null)
      ctrl.clear();
    else
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e)));
    _keBawah();
  }

  /// Menu saat pesan ditekan lama: salin atau hapus.
  Future<void> _menuPesan(BuildContext context, ChatMessage m) async {
    if (m.teks.isEmpty && m.gambar == null) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (d) => Container(
        padding: EdgeInsets.fromLTRB(
            20, 14, 20, MediaQuery.of(d).padding.bottom + 18),
        decoration: BoxDecoration(
          color: XyTheme.of(context).bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 44,
            height: 4.5,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                color: XyTheme.of(context).line,
                borderRadius: BorderRadius.circular(10)),
          ),
          if (m.teks.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: XyTheme.primary),
              title: const Text('Salin pesan',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              onTap: () {
                Clipboard.setData(ClipboardData(text: m.teks));
                Navigator.pop(d);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Pesan disalin'),
                      duration: Duration(seconds: 1)),
                );
              },
            ),
          if (m.milikSaya)
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: XyTheme.danger),
              title: const Text('Hapus pesan',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: XyTheme.danger)),
              onTap: () async {
                Navigator.pop(d);
                final pesan = await context.read<AppState>().hapusPesan(m.id);
                if (pesan != null && context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(pesan)));
                }
              },
            ),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    _retensi?.cancel();
    ctrl.dispose();
    scroll.dispose();
    super.dispose();
  }

  int _jumlahTerakhir = 0;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    // hanya gulir ketika ada pesan baru, supaya layar tidak berkedut
    if (s.chat.length != _jumlahTerakhir) {
      _jumlahTerakhir = s.chat.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _keBawah());
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(children: [
          Stack(children: [
            const CircleAvatar(
              radius: 20,
              backgroundColor: XyTheme.primary,
              child: Icon(Icons.support_agent_rounded,
                  color: Colors.white, size: 22),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: XyTheme.of(context).muted,
                  shape: BoxShape.circle,
                  border: Border.all(color: XyTheme.of(context).bg, width: 2),
                ),
              ),
            ),
          ]),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Bantuan XyCloud',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                Text(
                    s.csMengetik
                        ? 'sedang mengetik...'
                        : 'Riwayat disimpan 7 hari',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: XyTheme.of(context).muted,
                        fontWeight: FontWeight.w600)),
              ])),
        ]),
        actions: [
          IconButton(
            onPressed: () => context.read<AppState>().muatChat(),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Muat ulang percakapan',
          ),
          IconButton(
            tooltip: 'Bersihkan pesanku',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () async {
              final yakin = await konfirmasi(
                context,
                judul: 'Bersihkan pesanmu?',
                pesan:
                    'Semua pesan yang pernah kamu kirim akan dihapus dari percakapan ini. '
                    'Balasan Kirana tetap tersimpan.',
                tombolYa: 'Bersihkan',
                ikon: Icons.delete_sweep_outlined,
                bahaya: true,
              );
              if (!yakin || !context.mounted) return;
              final pesan = await context.read<AppState>().hapusSemuaPesan();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(pesan ?? 'Pesanmu sudah dibersihkan.')),
                );
              }
            },
          ),
        ],
      ),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: Text(
                'Pesan yang lebih tua dari 7 hari dihapus otomatis. Simpan informasi penting sebelum kedaluwarsa.',
                style: TextStyle(
                    color: XyTheme.of(context).muted,
                    fontSize: 11,
                    height: 1.4))),
        if (s.chat.isEmpty)
          const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                  'Belum ada percakapan aktif. Kirim pesan untuk memulai obrolan baru.')),
        Expanded(
          child: ListView.builder(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            itemCount: s.chat.length + (s.csMengetik ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == s.chat.length) return const _Mengetik();
              final m = s.chat[i];
              return GestureDetector(
                onLongPress: () => _menuPesan(context, m),
                onTap: m.gagal
                    ? () => context.read<AppState>().kirimChat(m.teks,
                        gambar: m.gambar,
                        pratinjau: m.gambar,
                        ulangId: m.clientId)
                    : null,
                child: _Gelembung(msg: m),
              );
            },
          ),
        ),
        if (s.chat.length < 4)
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: cepat.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ActionChip(
                label: Text(cepat[i],
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                onPressed: () => _kirim(cepat[i]),
                backgroundColor: XyTheme.of(context).surface,
                side: BorderSide(color: XyTheme.of(context).line),
              ),
            ),
          ),
        Container(
          padding: EdgeInsets.fromLTRB(
              12, 10, 12, MediaQuery.of(context).padding.bottom + 10),
          decoration: BoxDecoration(
              color: XyTheme.of(context).surface, boxShadow: XyTheme.shadowMd),
          child: Row(children: [
            IconButton(
              onPressed: _kirimGambar,
              icon: const Icon(Icons.image_outlined, color: XyTheme.primary),
              tooltip: 'Kirim gambar',
            ),
            Expanded(
              child: TextField(
                controller: ctrl,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _kirim(),
                onChanged: (v) =>
                    context.read<AppState>().ketikCs(v.isNotEmpty),
                decoration: InputDecoration(
                  hintText: 'Tulis pesan untuk tim CS…',
                  fillColor: XyTheme.of(context).bg,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide:
                          const BorderSide(color: XyTheme.primary, width: 1.4)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: XyTheme.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _kirim(),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child:
                      Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Gelembung extends StatelessWidget {
  const _Gelembung({required this.msg});
  final ChatMessage msg;

  @override
  Widget build(BuildContext context) {
    if (msg.dari == 'system') {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
              color: XyTheme.of(context).line.withOpacity(.6),
              borderRadius: BorderRadius.circular(20)),
          child: Text(msg.teks,
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 11.5, color: XyTheme.of(context).muted)),
        ),
      );
    }
    final saya = msg.milikSaya;
    return Align(
      alignment: saya ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .76),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: saya ? XyTheme.primary : XyTheme.of(context).surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(saya ? 18 : 4),
            bottomRight: Radius.circular(saya ? 4 : 18),
          ),
          border: saya ? null : Border.all(color: XyTheme.of(context).line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (msg.gambar != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: msg.gambar!.startsWith('data:')
                  ? Image.memory(
                      base64Decode(msg.gambar!.split(',').last),
                      width: 210,
                      fit: BoxFit.cover,
                    )
                  : Image.network(
                      msg.gambar!,
                      width: 210,
                      fit: BoxFit.cover,
                      cacheWidth: 640,
                      loadingBuilder: (_, anak, p) => p == null
                          ? anak
                          : Container(
                              width: 210,
                              height: 150,
                              color: XyTheme.of(context).lineSoft,
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.2),
                                ),
                              ),
                            ),
                    ),
            ),
            if (msg.teks.isNotEmpty) const SizedBox(height: 8),
          ],
          if (msg.teks.isNotEmpty)
            Text(msg.teks,
                style: TextStyle(
                    color: saya ? Colors.white : XyTheme.of(context).ink,
                    fontSize: 13.8,
                    height: 1.42)),
          const SizedBox(height: 3),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(jam(msg.waktu),
                style: TextStyle(
                    fontSize: 10,
                    color: saya ? Colors.white70 : XyTheme.of(context).muted)),
            if (saya) ...[
              const SizedBox(width: 4),
              Icon(
                msg.gagal
                    ? Icons.error_outline_rounded
                    : msg.terkirim
                        ? Icons.done_all_rounded
                        : Icons.schedule_rounded,
                size: 13,
                color: msg.gagal
                    ? const Color(0xFFFCA5A5)
                    : msg.dibaca
                        ? const Color(0xFF7DD3FC)
                        : Colors.white70,
              ),
            ],
          ]),
        ]),
      ),
    );
  }
}

class _Mengetik extends StatefulWidget {
  const _Mengetik();
  @override
  State<_Mengetik> createState() => _MengetikState();
}

class _MengetikState extends State<_Mengetik>
    with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: XyTheme.of(context).surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: XyTheme.of(context).line),
        ),
        child: AnimatedBuilder(
          animation: c,
          builder: (_, __) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final t = ((c.value + i * .22) % 1);
              final naik = (t < .5 ? t : 1 - t) * 2;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: 7,
                height: 7,
                transform: Matrix4.translationValues(0, -naik * 4, 0),
                decoration: BoxDecoration(
                  color: XyTheme.of(context).muted.withOpacity(.4 + naik * .5),
                  shape: BoxShape.circle,
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
