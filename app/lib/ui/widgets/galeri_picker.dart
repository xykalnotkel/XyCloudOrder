import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/motion.dart';
import '../../core/theme.dart';
import 'common.dart';

/// ============================================================
///  GaleriPicker — pemilih galeri kustom (Batch I)
/// ============================================================
///  Permintaan pemilik: "custom gallery picker" — grid galeri milik
///  sendiri (bukan picker bawaan sistem) dengan pilihan album,
///  thumbnail cepat, dan dukungan video (untuk banner profil MP4).
///
///  Izin ditangani sendiri; bila ditolak permanen, pengguna tetap
///  bisa jatuh ke picker sistem lewat tombol di layar izin.
/// Jenis saringan galeri (Batch J).
enum _FilterGaleri { foto, video, semua }

class GaleriPicker {
  GaleriPicker._();

  /// Sentinel: pengguna memilih jatuh ke picker sistem.
  static const String pakaiSistem = '__sistem__';

  /// Buka galeri kustom. `bolehVideo` menampilkan video (untuk banner).
  /// Mengembalikan File yang dipilih, [pakaiSistem] bila pengguna
  /// memilih picker sistem, atau null bila batal.
  static Future<Object?> buka(
    BuildContext context, {
    bool bolehVideo = false,
    String judul = 'Pilih dari Galeri',
  }) {
    return Navigator.push<Object?>(
      context,
      xyRoute(_GaleriScreen(bolehVideo: bolehVideo, judul: judul)),
    );
  }

  /// Nyaman dipakai: galeri kustom dulu; kalau izin ditolak dan pengguna
  /// memilih picker sistem, otomatis jatuh ke image_picker.
  static Future<File?> pilihGambar(
    BuildContext context, {
    bool bolehVideo = false,
    String judul = 'Pilih dari Galeri',
  }) async {
    final hasil = await buka(context, bolehVideo: bolehVideo, judul: judul);
    if (hasil is File) return hasil;
    if (hasil == pakaiSistem) {
      final x = bolehVideo
          ? await ImagePicker().pickMedia()
          : await ImagePicker().pickImage(source: ImageSource.gallery);
      return x == null ? null : File(x.path);
    }
    return null;
  }
}

class _GaleriScreen extends StatefulWidget {
  const _GaleriScreen({required this.bolehVideo, required this.judul});
  final bool bolehVideo;
  final String judul;

  @override
  State<_GaleriScreen> createState() => _GaleriScreenState();
}

class _GaleriScreenState extends State<_GaleriScreen> {
  static const _perHalaman = 60;

  final _scroll = ScrollController();
  List<AssetPathEntity> _album = [];
  AssetPathEntity? _aktif;
  List<AssetEntity> _aset = [];
  int _halaman = 0;
  bool _habis = false;
  bool _memuat = true;
  bool _izinDitolak = false;
  bool _mengambil = false;

  @override
  void initState() {
    super.initState();
    _siapkan();
    _scroll.addListener(() {
      if (_scroll.position.pixels >
          _scroll.position.maxScrollExtent - MediaQuery.of(context).size.width) {
        _muatLagi();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // Batch J: saringan Foto / Video / Semua sesuai permintaan pemilik.
  _FilterGaleri _filter = _FilterGaleri.foto;

  RequestType get _tipe => switch (_filter) {
        _FilterGaleri.foto => RequestType.image,
        _FilterGaleri.video => RequestType.video,
        _FilterGaleri.semua => RequestType.common,
      };

  Future<void> _gantiFilter(_FilterGaleri f) async {
    if (f == _filter) return;
    setState(() {
      _filter = f;
      _memuat = true;
    });
    final album = await PhotoManager.getAssetPathList(
      type: _tipe,
      hasAll: true,
      onlyAll: false,
    );
    if (!mounted) return;
    setState(() {
      _album = album;
      _aktif = album.isNotEmpty ? album.first : null;
    });
    await _muatLagi(reset: true);
  }

  Widget _barFilter(XyPalette t) => Padding(
        padding: const EdgeInsets.fromLTRB(9, 8, 9, 4),
        child: Row(children: [
          for (final f in const [
            (_FilterGaleri.foto, 'Foto', Icons.image_rounded),
            (_FilterGaleri.video, 'Video', Icons.videocam_rounded),
            (_FilterGaleri.semua, 'Semua', Icons.layers_rounded),
          ])
            Expanded(
              child: GestureDetector(
                onTap: () => _gantiFilter(f.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: _filter == f.$1 ? XyTheme.violet : t.lineSoft,
                    borderRadius: BorderRadius.circular(XyRadius.pill),
                    border: Border.all(
                        color: _filter == f.$1 ? XyTheme.violet : t.line),
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(f.$3,
                            size: 14,
                            color: _filter == f.$1 ? Colors.white : t.muted),
                        const SizedBox(width: 5),
                        Text(f.$2,
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: _filter == f.$1 ? Colors.white : t.muted)),
                      ]),
                ),
              ),
            ),
        ]),
      );

  Future<void> _siapkan() async {
    final izin = await PhotoManager.requestPermissionExtend();
    if (!mounted) return;
    if (!izin.isAuth && !izin.hasAccess) {
      setState(() {
        _memuat = false;
        _izinDitolak = true;
      });
      return;
    }
    final album = await PhotoManager.getAssetPathList(
      type: _tipe,
      hasAll: true,
      onlyAll: false,
    );
    if (!mounted) return;
    setState(() {
      _album = album;
      _aktif = album.isNotEmpty ? album.first : null;
      _memuat = false;
    });
    await _muatLagi(reset: true);
  }

  Future<void> _gantiAlbum(AssetPathEntity a) async {
    setState(() {
      _aktif = a;
      _memuat = true;
    });
    await _muatLagi(reset: true);
  }

  Future<void> _muatLagi({bool reset = false}) async {
    final a = _aktif;
    if (a == null) return;
    if (reset) {
      _halaman = 0;
      _habis = false;
    }
    if (_habis) {
      if (mounted) setState(() => _memuat = false);
      return;
    }
    final batch =
        await a.getAssetListPaged(page: _halaman, size: _perHalaman);
    if (!mounted) return;
    setState(() {
      _aset = reset ? batch : [..._aset, ...batch];
      _halaman++;
      _habis = batch.length < _perHalaman;
      _memuat = false;
    });
  }

  Future<void> _pilih(AssetEntity e) async {
    if (_mengambil) return;
    // Menu khusus foto tetap menolak video (video hanya untuk banner Pro/VIP).
    if (e.type == AssetType.video && !widget.bolehVideo) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Menu ini khusus foto. Video/GIF bisa dipakai untuk banner profil (Pro/VIP).')));
      return;
    }
    setState(() => _mengambil = true);
    HapticFeedback.selectionClick();
    try {
      // Video dibatasi 15MB (batas banner di server).
      final f = await e.file;
      if (!mounted) return;
      if (f == null) {
        setState(() => _mengambil = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Berkas tidak bisa dibaca.')));
        return;
      }
      Navigator.pop(context, f);
    } catch (_) {
      if (!mounted) return;
      setState(() => _mengambil = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuka berkas.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = XyTheme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _album.length < 2
              ? null
              : () async {
                  final pilihan = await showModalBottomSheet<AssetPathEntity>(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => Container(
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: t.surfaceHigh,
                        borderRadius: BorderRadius.circular(XyRadius.xxl),
                      ),
                      child: SafeArea(
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (final a in _album)
                              ListTile(
                                leading: Icon(
                                    a.isAll
                                        ? Icons.photo_library_rounded
                                        : Icons.folder_rounded,
                                    color: t.accent),
                                title: Text(a.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14)),
                                trailing: _aktif?.id == a.id
                                    ? Icon(Icons.check_rounded,
                                        color: t.accent)
                                    : null,
                                onTap: () => Navigator.pop(ctx, a),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                  if (pilihan != null) _gantiAlbum(pilihan);
                },
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
              child: Text(
                _aktif?.name ?? widget.judul,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (_album.length > 1)
              const Icon(Icons.arrow_drop_down_rounded, size: 22),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(children: [
        _barFilter(XyTheme.of(context)),
        Expanded(child: Stack(children: [
        if (_izinDitolak)
          Kosong(
            icon: Icons.no_photography_outlined,
            judul: 'Akses galeri ditolak',
            sub:
                'Beri izin akses foto & video untuk memakai galeri kustom, atau gunakan picker sistem.',
            ilustrasi: '',
            aksi: Column(children: [
              GradientButton(
                label: 'Buka Pengaturan',
                icon: Icons.settings_rounded,
                onPressed: PhotoManager.openSetting,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pop(context, GaleriPicker.pakaiSistem),
                icon: const Icon(Icons.folder_open_rounded, size: 18),
                label: const Text('Pakai picker sistem'),
              ),
            ]),
          )
        else if (_memuat && _aset.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (_aset.isEmpty)
          Kosong(
            icon: Icons.photo_library_outlined,
            judul: 'Galeri kosong',
            sub: widget.bolehVideo
                ? 'Belum ada foto atau video di album ini.'
                : 'Belum ada foto di album ini.',
            ilustrasi: '',
            aksi: OutlinedButton.icon(
              onPressed: () =>
                  Navigator.pop(context, GaleriPicker.pakaiSistem),
              icon: const Icon(Icons.folder_open_rounded, size: 18),
              label: const Text('Pakai picker sistem'),
            ),
          )
        else
          GridView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(3, 3, 3, 90),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 3,
              mainAxisSpacing: 3,
            ),
            itemCount: _aset.length + (_habis ? 0 : 1),
            itemBuilder: (context, i) {
              if (i >= _aset.length) {
                return const Center(
                    child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ));
              }
              final e = _aset[i];
              return _KotakAset(
                entity: e,
                onTap: () => _pilih(e),
              );
            },
          ),
        if (_mengambil)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withOpacity(.45),
              child: const Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 12),
                  Text('Membuka berkas…',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
      ])),
        ]),
    );
  }
}

class _KotakAset extends StatefulWidget {
  const _KotakAset({required this.entity, required this.onTap});
  final AssetEntity entity;
  final VoidCallback onTap;

  @override
  State<_KotakAset> createState() => _KotakAsetState();
}

class _KotakAsetState extends State<_KotakAset> {
  Uint8List? _data;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final d = await widget.entity
          .thumbnailDataWithSize(const ThumbnailSize(240, 240), quality: 72);
      if (mounted && d != null) setState(() => _data = d);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entity;
    final video = e.type == AssetType.video;
    final d = _data;
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(fit: StackFit.expand, children: [
        if (d != null)
          Image.memory(d, fit: BoxFit.cover, gaplessPlayback: true)
        else
          ColoredBox(color: XyTheme.of(context).lineSoft),
        if (video) ...[
          Positioned(
            left: 5,
            bottom: 4,
            child: Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.62),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Row(children: [
                  const Icon(Icons.play_arrow_rounded,
                      size: 12, color: Colors.white),
                  const SizedBox(width: 2),
                  Text(
                    _durasi(e.duration),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700),
                  ),
                ]),
              ),
            ]),
          ),
        ],
        if ((e.title ?? '').toLowerCase().endsWith('.gif'))
          Positioned(
            right: 5,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.62),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Text('GIF',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800)),
            ),
          ),
      ]),
    );
  }

  static String _durasi(int detik) {
    final m = detik ~/ 60;
    final s = detik % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
