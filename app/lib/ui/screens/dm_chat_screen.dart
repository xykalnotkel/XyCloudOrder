import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import 'profil_publik_screen.dart';

/// ============================================================
///  Pesan langsung (DM) antar pengguna — Batch D.
///  Teks, gambar, dan pesan suara (tekan-tahan mic, geser ke
///  atas untuk membatalkan — pola sama dengan chat CS).
/// ============================================================
class DmChatScreen extends StatefulWidget {
  const DmChatScreen({super.key, required this.userId, this.nama, this.foto});
  final String userId;
  final String? nama;
  final String? foto;

  @override
  State<DmChatScreen> createState() => _DmChatScreenState();
}

class _DmChatScreenState extends State<DmChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _rec = AudioRecorder();

  List<DmPesan> _pesan = [];
  bool _memuat = true;
  bool _kirim = false;
  String? _galat;
  Timer? _poll;

  // rekam suara
  bool _rekam = false;
  double _angkat = 0;
  int _detik = 0;
  Timer? _stopwatch;

  @override
  void initState() {
    super.initState();
    _muat();
    _poll = Timer.periodic(const Duration(seconds: 6), (_) => _muat(sunyi: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _stopwatch?.cancel();
    _rec.dispose();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _muat({bool sunyi = false}) async {
    try {
      final s = context.read<AppState>();
      final daftar = await s.repo.dmAmbil(widget.userId);
      if (!mounted) return;
      final adaBaru = daftar.any((m) =>
          !m.dariSaya(s.user?.id ?? '') &&
          !m.dibaca &&
          !_pesan.any((l) => l.id == m.id));
      setState(() {
        _pesan = daftar;
        _memuat = false;
        _galat = null;
      });
      if (adaBaru || daftar.any((m) => !m.dariSaya(s.user?.id ?? '') && !m.dibaca)) {
        unawaited(s.repo.dmBaca(widget.userId).catchError((_) => <String, dynamic>{}));
      }
    } catch (e) {
      if (!mounted || sunyi) return;
      setState(() {
        _memuat = false;
        _galat = 'Tidak bisa memuat percakapan.';
      });
    }
  }

  Future<void> _kirimTeks() async {
    final teks = _ctrl.text.trim();
    if (teks.isEmpty || _kirim) return;
    setState(() => _kirim = true);
    _ctrl.clear();
    try {
      await context.read<AppState>().repo.dmKirim(widget.userId, teks: teks);
      if (mounted) await _muat(sunyi: true);
    } catch (e) {
      if (mounted) {
        _ctrl.text = teks;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Gagal mengirim pesan.')));
      }
    }
    if (mounted) setState(() => _kirim = false);
  }

  Future<void> _kirimGambar() async {
    final f = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 82);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    final tipe = f.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
    if (!mounted) return;
    setState(() => _kirim = true);
    try {
      await context.read<AppState>().repo.dmKirim(widget.userId,
          gambar: 'data:image/$tipe;base64,${base64Encode(bytes)}');
      if (mounted) await _muat(sunyi: true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Gagal mengirim gambar.')));
      }
    }
    if (mounted) setState(() => _kirim = false);
  }

  // ---------- pesan suara (pola cs_screen) ----------
  Future<void> _mulaiRekam() async {
    try {
      if (!await _rec.hasPermission()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Izinkan akses mikrofon untuk mengirim pesan suara.')));
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/xy_dm_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _rec.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 32000,
          sampleRate: 44100,
          numChannels: 1,
          autoGain: true,
        ),
        path: path,
      );
      if (!mounted) return;
      setState(() {
        _rekam = true;
        _angkat = 0;
        _detik = 0;
      });
      _stopwatch?.cancel();
      _stopwatch = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _rekam) setState(() => _detik++);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Tidak bisa mulai merekam. Coba periksa mikrofon.')));
    }
  }

  Future<void> _hentiRekam({required bool batal}) async {
    _stopwatch?.cancel();
    String? jalur;
    try {
      if (batal) {
        await _rec.cancel();
      } else {
        jalur = await _rec.stop();
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _rekam = false;
      _angkat = 0;
    });
    if (batal || jalur == null) return;
    final detik = _detik < 1 ? 1 : _detik;
    try {
      final bytes = await File(jalur).readAsBytes();
      if (bytes.isEmpty) return;
      final dataUri = 'data:audio/mp4;base64,${base64Encode(bytes)}';
      if (!mounted) return;
      await context
          .read<AppState>()
          .repo
          .dmKirim(widget.userId, audio: dataUri, durasi: detik.toDouble());
      if (mounted) await _muat(sunyi: true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Gagal mengirim pesan suara.')));
      }
    }
  }

  String _inisial(String nama) {
    final bagian = nama.trim().split(RegExp(r'\s+'));
    if (bagian.isEmpty || bagian.first.isEmpty) return '?';
    if (bagian.length == 1) return bagian.first[0].toUpperCase();
    return (bagian[0][0] + bagian[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final t = XyTheme.of(context);
    final sayaId = context.watch<AppState>().user?.id ?? '';
    final namaLawan = _pesan.isNotEmpty
        ? (_pesan.firstWhere((m) => !m.dariSaya(sayaId),
                orElse: () => _pesan.first).dariNama ??
            widget.nama ??
            'Pengguna')
        : (widget.nama ?? 'Pengguna');
    final fotoLawan = widget.foto;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () => Navigator.push(context,
              xyRoute(ProfilPublikScreen(userId: widget.userId))),
          borderRadius: BorderRadius.circular(XyRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _avatar(fotoLawan, namaLawan, 38),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(namaLawan,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w700)),
                      Text('Pesan langsung',
                          style: TextStyle(fontSize: 11, color: t.muted)),
                    ]),
              ),
            ]),
          ),
        ),
      ),
      body: Column(children: [
        Expanded(
          child: _memuat
              ? const Center(
                  child: CircularProgressIndicator(color: XyTheme.primary))
              : _galat != null
                  ? Kosong(
                      icon: Icons.wifi_off_rounded,
                      judul: 'Waduh',
                      sub: _galat,
                      aksi: GradientButton(label: 'Coba Lagi', onPressed: _muat),
                    )
                  : _pesan.isEmpty
                      ? Kosong(
                          icon: Icons.forum_outlined,
                          judul: 'Mulai percakapan',
                          sub:
                              'Kirim pesan, gambar, atau tahan tombol mic untuk pesan suara.',
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                          itemCount: _pesan.length,
                          itemBuilder: (context, i) {
                            final m = _pesan[i];
                            final saya = m.dariSaya(sayaId);
                            final tunjukkanNama = !saya &&
                                (i == 0 || _pesan[i - 1].dariSaya(sayaId));
                            return Padding(
                              padding: EdgeInsets.only(
                                  bottom: i == _pesan.length - 1 ? 4 : 9),
                              child: _Gelembung(
                                  msg: m,
                                  saya: saya,
                                  namaLawan: namaLawan,
                                  fotoLawan: fotoLawan,
                                  tunjukkanNama: tunjukkanNama,
                                  avatar: _avatar(fotoLawan, namaLawan, 30)),
                            );
                          },
                        ),
        ),
        // ---------- bar rekam ----------
        if (_rekam)
          Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: XyTheme.primarySoft,
              borderRadius: BorderRadius.circular(XyRadius.md),
              border: Border.all(color: XyTheme.lavender),
            ),
            child: Row(children: [
              const Icon(Icons.graphic_eq_rounded, color: XyTheme.primary),
              const SizedBox(width: 10),
              Text('${_detik}s',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: XyTheme.primary)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _angkat >= 70 ? 'Lepas untuk membatalkan' : 'Geser ke atas untuk batal',
                  style: TextStyle(
                      fontSize: 12,
                      color: _angkat >= 70 ? XyTheme.danger : t.muted,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
        // ---------- bar input ----------
        Container(
          padding: EdgeInsets.fromLTRB(
              12, 8, 12, 10 + MediaQuery.of(context).viewInsets.bottom),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border(top: BorderSide(color: t.line)),
          ),
          child: SafeArea(
            top: false,
            child: Row(children: [
              IconButton(
                onPressed: _kirim || _rekam ? null : _kirimGambar,
                icon: const Icon(Icons.image_outlined, color: XyTheme.primary),
                tooltip: 'Kirim gambar',
              ),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  enabled: !_rekam,
                  decoration: InputDecoration(
                    hintText: 'Tulis pesan…',
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(XyRadius.pill),
                      borderSide: BorderSide(color: t.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(XyRadius.pill),
                      borderSide: BorderSide(color: t.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(XyRadius.pill),
                      borderSide: const BorderSide(color: XyTheme.primary, width: 1.6),
                    ),
                  ),
                  onSubmitted: (_) => _kirimTeks(),
                ),
              ),
              const SizedBox(width: 8),
              if (_ctrl.text.trim().isEmpty)
                GestureDetector(
                  onLongPressStart: (_) => _mulaiRekam(),
                  onLongPressMoveUpdate: (d) {
                    if (!_rekam) return;
                    setState(() => _angkat = math.max(0, -d.offsetFromStart.dy));
                  },
                  onLongPressEnd: (_) {
                    if (!_rekam) return;
                    _hentiRekam(batal: _angkat >= 70);
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _rekam ? null : XyTheme.gradPrimary,
                      color: _rekam ? XyTheme.danger : null,
                    ),
                    child: Icon(_rekam ? Icons.stop_rounded : Icons.mic_rounded,
                        color: Colors.white, size: 21),
                  ),
                )
              else
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, gradient: XyTheme.gradPrimary),
                  child: IconButton(
                    onPressed: _kirim ? null : _kirimTeks,
                    icon: _kirim
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 19),
                  ),
                ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _avatar(String? foto, String nama, double ukuran) {
    return Container(
      width: ukuran,
      height: ukuran,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: (foto ?? '').isNotEmpty
          ? AppImage(foto!)
          : Container(
              color: XyTheme.primarySoft,
              alignment: Alignment.center,
              child: Text(_inisial(nama),
                  style: TextStyle(
                      fontSize: ukuran * .38,
                      fontWeight: FontWeight.w800,
                      color: XyTheme.primary)),
            ),
    );
  }
}

/// Gelembung pesan: teks / gambar / suara, dengan penanda dibaca.
class _Gelembung extends StatelessWidget {
  const _Gelembung({
    required this.msg,
    required this.saya,
    required this.namaLawan,
    this.fotoLawan,
    required this.tunjukkanNama,
    required this.avatar,
  });

  final DmPesan msg;
  final bool saya;
  final String namaLawan;
  final String? fotoLawan;
  final bool tunjukkanNama;
  final Widget avatar;

  String get _jam {
    final d = msg.tanggal.toLocal();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final t = XyTheme.of(context);
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(saya ? 18 : 5),
      bottomRight: Radius.circular(saya ? 5 : 18),
    );

    Widget isi;
    if (msg.tipe == 'audio' && (msg.audio ?? '').isNotEmpty) {
      isi = _SuaraDm(msg: msg, saya: saya);
    } else if (msg.tipe == 'gambar' && (msg.gambar ?? '').isNotEmpty) {
      isi = ClipRRect(
        borderRadius: radius,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AppImage(msg.gambar!, tinggi: 190, lebar: 230),
          Container(
            color: saya ? XyTheme.primary : t.surface,
            padding: const EdgeInsets.fromLTRB(10, 4, 8, 5),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_jam,
                  style: TextStyle(
                      fontSize: 10,
                      color: saya ? Colors.white70 : t.muted,
                      fontWeight: FontWeight.w600)),
              if (saya) ...[
                const SizedBox(width: 4),
                Icon(
                    msg.dibaca
                        ? Icons.done_all_rounded
                        : Icons.done_rounded,
                    size: 13,
                    color: msg.dibaca ? const Color(0xFF7DD3FC) : Colors.white70),
              ],
            ]),
          ),
        ]),
      );
    } else {
      isi = Container(
        constraints: const BoxConstraints(maxWidth: 290),
        padding: const EdgeInsets.fromLTRB(13, 9, 10, 7),
        decoration: BoxDecoration(
          gradient: saya ? XyTheme.gradPrimary : null,
          color: saya ? null : t.surface,
          borderRadius: radius,
          border: saya ? null : Border.all(color: t.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (tunjukkanNama)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(namaLawan,
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: XyTheme.primary)),
            ),
          Text(msg.teks ?? '',
              style: TextStyle(
                  fontSize: 13.5,
                  height: 1.35,
                  color: saya ? Colors.white : t.ink)),
          const SizedBox(height: 3),
          Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.end, children: [
            Text(_jam,
                style: TextStyle(
                    fontSize: 10,
                    color: saya ? Colors.white70 : t.muted,
                    fontWeight: FontWeight.w600)),
            if (saya) ...[
              const SizedBox(width: 4),
              Icon(
                  msg.dibaca ? Icons.done_all_rounded : Icons.done_rounded,
                  size: 13,
                  color: msg.dibaca ? const Color(0xFF7DD3FC) : Colors.white70),
            ],
          ]),
        ]),
      );
    }

    return Row(
      mainAxisAlignment: saya ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!saya) ...[avatar, const SizedBox(width: 7)],
        isi,
      ],
    );
  }
}

/// Pemutar pesan suara di dalam gelembung (versi ringan dari cs_screen._Suara).
class _SuaraDm extends StatefulWidget {
  const _SuaraDm({required this.msg, required this.saya});
  final DmPesan msg;
  final bool saya;

  @override
  State<_SuaraDm> createState() => _SuaraDmState();
}

class _SuaraDmState extends State<_SuaraDm> {
  AudioPlayer? _player;
  bool _main = false;
  Duration _pos = Duration.zero;
  Duration? _dur;
  bool _dispose = false;

  List<int> get _bar {
    final seed = widget.msg.id.codeUnits.fold<int>(0, (a, b) => a + b);
    final r = math.Random(seed);
    final n = (widget.msg.durasi ?? 8) < 5 ? 18 : 26;
    return List.generate(n, (_) => 4 + r.nextInt(7));
  }

  @override
  void dispose() {
    _dispose = true;
    _player?.dispose();
    super.dispose();
  }

  Future<void> _putar() async {
    final url = widget.msg.audio;
    if (url == null || !url.startsWith('http')) return;
    if (_player == null) {
      final p = AudioPlayer();
      p.onPlayerStateChanged.listen((s) {
        if (_dispose || !mounted) return;
        setState(() => _main = s == PlayerState.playing);
      });
      p.onPositionChanged.listen((d) {
        if (_dispose || !mounted) return;
        setState(() => _pos = d);
      });
      p.onDurationChanged.listen((d) {
        if (_dispose || !mounted) return;
        setState(() => _dur = d);
      });
      p.onPlayerComplete.listen((_) {
        if (_dispose || !mounted) return;
        setState(() {
          _main = false;
          _pos = Duration.zero;
        });
      });
      _player = p;
    }
    final p = _player!;
    if (_main) {
      await p.pause();
    } else {
      try {
        final habis = _dur != null && _pos >= _dur!;
        if (_pos == Duration.zero || habis) {
          await p.stop();
          await p.setSourceUrl(url);
          await p.resume();
        } else {
          await p.resume();
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = XyTheme.of(context);
    final tampilDur =
        _dur ?? Duration(seconds: (widget.msg.durasi ?? 0).round());
    final posisi =
        _pos.inMilliseconds >= tampilDur.inMilliseconds ? Duration.zero : _pos;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 6),
      decoration: BoxDecoration(
        gradient: widget.saya ? XyTheme.gradPrimary : null,
        color: widget.saya ? null : t.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(widget.saya ? 18 : 5),
          bottomRight: Radius.circular(widget.saya ? 5 : 18),
        ),
        border: widget.saya ? null : Border.all(color: t.line),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Material(
          color: widget.saya
              ? Colors.white.withOpacity(.22)
              : t.primarySoft,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _putar,
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Icon(
                  _main ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 20,
                  color: widget.saya ? Colors.white : XyTheme.primary),
            ),
          ),
        ),
        const SizedBox(width: 9),
        SizedBox(
          height: 26,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < _bar.length; i++)
                Container(
                  width: 2.6,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: (i / _bar.length) <=
                            (tampilDur.inMilliseconds == 0
                                ? 0
                                : posisi.inMilliseconds /
                                    tampilDur.inMilliseconds)
                        ? (widget.saya ? Colors.white : XyTheme.primary)
                        : (widget.saya
                            ? Colors.white38
                            : XyTheme.lavender),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  height: _bar[i].toDouble(),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
              (posisi == Duration.zero ? tampilDur : tampilDur - posisi)
                  .toString()
                  .split('.')[0]
                  .substring(2),
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: widget.saya ? Colors.white : t.muted)),
          Text('Pesan suara',
              style: TextStyle(
                  fontSize: 9,
                  color: widget.saya ? Colors.white70 : t.muted)),
        ]),
        if (widget.saya) ...[
          const SizedBox(width: 6),
          Icon(widget.msg.dibaca ? Icons.done_all_rounded : Icons.done_rounded,
              size: 13,
              color: widget.msg.dibaca ? const Color(0xFF7DD3FC) : Colors.white70),
        ],
      ]),
    );
  }
}
