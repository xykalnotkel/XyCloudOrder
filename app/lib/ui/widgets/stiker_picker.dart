import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../data/stiker_store.dart';
import '../../models/stiker.dart';
import '../../providers/app_state.dart';
import 'lembar.dart';

Future<PilihanStiker?> pilihStiker(BuildContext context) =>
    showModalBottomSheet<PilihanStiker>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: XyTheme.of(context).surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const StikerPicker(),
    );

class GambarStiker extends StatefulWidget {
  const GambarStiker(this.stiker,{super.key,this.bytes,this.ukuran=160});
  final Stiker stiker;final Uint8List? bytes;final double ukuran;
  @override State<GambarStiker> createState()=>_GambarStikerState();
}
class _GambarStikerState extends State<GambarStiker>{
  Future<Uint8List>? future;
  @override void initState(){super.initState();load();}
  @override void didUpdateWidget(covariant GambarStiker old){super.didUpdateWidget(old);if(old.stiker.url!=widget.stiker.url||old.bytes!=widget.bytes)load();}
  void load(){
    if(widget.bytes!=null){future=Future.value(widget.bytes!);return;}
    String? user;try{user=context.read<AppState>().user?.id;}catch(_){}
    future=user==null?StikerStore.unduh(widget.stiker.url):StikerStore.untuk(user).bytesUntuk(widget.stiker);
  }
  @override Widget build(BuildContext context)=>Semantics(label:widget.stiker.nama,image:true,child:SizedBox(width:widget.ukuran,height:widget.ukuran,
    child:FutureBuilder<Uint8List>(future:future,builder:(context,snapshot){
      if(snapshot.hasData)return Image.memory(snapshot.data!,fit:BoxFit.contain,gaplessPlayback:true,cacheWidth:(widget.ukuran*MediaQuery.devicePixelRatioOf(context)).ceil().clamp(128,512),errorBuilder:(_,__,___)=>const Icon(Icons.broken_image_outlined));
      if(snapshot.hasError)return IconButton(tooltip:'Coba muat stiker lagi',onPressed:()=>setState(load),icon:const Icon(Icons.refresh_rounded));
      return const Center(child:SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)));
    })));
}

Future<void> menuStiker(BuildContext context, Stiker stiker) async {
  final id = context.read<AppState>().user?.id;
  if (id == null) return;
  await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: XyTheme.of(context).surface,
      builder: (ctx) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            GambarStiker(stiker, ukuran: 190),
            if (stiker.dariGiphy)
              TextButton(
                  onPressed: () => launchUrl(Uri.parse('https://giphy.com'),
                      mode: LaunchMode.externalApplication),
                  child: const Text('Powered by GIPHY')),
            const SizedBox(height: 16),
            FilledButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tambahkan ke koleksi'),
                onPressed: () async {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Menyimpan stiker terenkripsi…')));
                  try {
                    await StikerStore.untuk(id).simpan(stiker);
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content:
                              Text('Stiker tersimpan di koleksi HP ini.')));
                  } catch (e) {
                    if (context.mounted)
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('$e')));
                  }
                }),
          ])));
}

class StikerPicker extends StatefulWidget {
  const StikerPicker({super.key});
  @override
  State<StikerPicker> createState() => _StikerPickerState();
}

class _StikerPickerState extends State<StikerPicker> {
  late final StikerStore _store =
      StikerStore.untuk(context.read<AppState>().user!.id);
  final _cari = TextEditingController();
  final Map<String, Future<Uint8List>> _gambar = {};
  List<StikerLokal> _koleksi = [];
  List<Stiker> _hasil = [];
  Timer? _debounce;
  int _tab = 0, _request = 0, _offset = 0;
  String _jenis = 'stiker';
  bool _sibuk = false, _memuat = true, _siap = true, _lagi = false;
  String? _galat;
  @override
  void initState() {
    super.initState();
    _muatKoleksi();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cari.dispose();
    super.dispose();
  }

  void _pesan(Object e) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('FormatException: ', ''))));
  }

  Future<void> _muatKoleksi() async {
    try {
      final d = await _store.daftar();
      if (mounted) setState(() => _koleksi = d);
    } catch (e) {
      if (mounted)
        setState(() => _galat = 'Koleksi lokal belum bisa dibaca. $e');
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  Future<void> _giphy({bool tambah = false}) async {
    final n = ++_request;
    setState(() {
      _memuat = true;
      _galat = null;
    });
    try {
      final d = await context
          .read<AppState>()
          .cariStiker(_cari.text, jenis: _jenis, offset: tambah ? _offset : 0);
      if (!mounted || n != _request) return;
      final list = (d['items'] as List? ?? [])
          .map((x) => Stiker.fromJson(Map<String, dynamic>.from(x)))
          .toList();
      setState(() {
        _siap = d['siap'] == true;
        _hasil = tambah ? [..._hasil, ...list] : list;
        _offset = (d['berikutnya'] as num?)?.toInt() ?? 0;
        _lagi = d['ada_lagi'] == true;
      });
    } catch (e) {
      if (mounted && n == _request)
        setState(() => _galat =
            'GIPHY belum bisa dimuat. Coba lagi atau pilih dari koleksi.');
    } finally {
      if (mounted && n == _request) setState(() => _memuat = false);
    }
  }

  Future<void> _galeri() async {
    if (_sibuk) return;
    setState(() => _sibuk = true);
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (x == null) return;
      if (await x.length() > 8 * 1024 * 1024)
        throw const FormatException('Gambar asal maksimal 8 MB.');
      final p = await StikerStore.dariGaleri(await x.readAsBytes());
      await _store.simpan(p.stiker, bytes: p.bytes);
      if (mounted) Navigator.pop(context, p);
    } catch (e) {
      _pesan(e);
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _tautan() async {
    final v = await tanyaTeks(context,
        judul: 'Impor stiker',
        keterangan: 'Tautan resmi GIPHY atau URL gambar GIF/WebP GIPHY.',
        petunjuk: 'https://giphy.com/…');
    if (v == null || v.trim().isEmpty || !mounted) return;
    setState(() => _sibuk = true);
    try {
      final stiker = await context.read<AppState>().imporStiker(v.trim());
      final data = await StikerStore.unduh(stiker.url);
      await _store.simpan(stiker, bytes: data);
      if (mounted) Navigator.pop(context, PilihanStiker(stiker, bytes: data));
    } catch (e) {
      _pesan(e);
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _hapus(StikerLokal p) async {
    if (await konfirmasi(context,
        judul: 'Hapus dari koleksi?',
        pesan: 'Stiker yang sudah terkirim di komentar tidak ikut dihapus.',
        tombolYa: 'Hapus',
        bahaya: true)) {
      try {
        await _store.hapus(p);
        _gambar.remove(p.id);
        await _muatKoleksi();
      } catch (e) {
        _pesan(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = XyTheme.of(context);
    return SizedBox(
        height: MediaQuery.sizeOf(context).height * .76,
        child: Column(children: [
          const SizedBox(height: 9),
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: pal.line, borderRadius: BorderRadius.circular(8))),
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 8, 4),
              child: Row(children: [
                const Expanded(
                    child: Text('Stiker',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700))),
                IconButton(
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded)),
              ])),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(children: [
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: _sibuk ? null : _galeri,
                        icon:
                            const Icon(Icons.photo_library_outlined, size: 19),
                        label: const Text('Dari galeri'))),
                const SizedBox(width: 10),
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: _sibuk ? null : _tautan,
                        icon: const Icon(Icons.link_rounded, size: 19),
                        label: const Text('Impor link'))),
              ])),
          if (_sibuk) const LinearProgressIndicator(),
          Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: Row(children: [
                ChoiceChip(
                    label: Text('Koleksi (${_koleksi.length})'),
                    selected: _tab == 0,
                    onSelected: (_) {
                      _request++;
                      setState(() {
                        _tab = 0;
                        _memuat = false;
                        _galat = null;
                      });
                    }),
                const SizedBox(width: 8),
                ChoiceChip(
                    label: const Text('GIPHY'),
                    selected: _tab == 1,
                    onSelected: (_) {
                      setState(() => _tab = 1);
                      _giphy();
                    }),
              ])),
          if (_tab == 1)
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(children: [
                  TextField(
                      controller: _cari,
                      decoration: const InputDecoration(
                          hintText: 'Cari reaksi, ekspresi, atau karakter…',
                          prefixIcon: Icon(Icons.search_rounded)),
                      onChanged: (_) {
                        _debounce?.cancel();
                        _debounce = Timer(
                            const Duration(milliseconds: 450), () => _giphy());
                      },
                      onSubmitted: (_) => _giphy()),
                  Row(children: [
                    for (final jenis in ['stiker', 'gif'])
                      Padding(
                          padding: const EdgeInsets.only(right: 8, top: 6),
                          child: ChoiceChip(
                              label: Text(
                                  jenis == 'gif' ? 'GIF' : 'Stiker transparan'),
                              selected: _jenis == jenis,
                              onSelected: (_) {
                                setState(() => _jenis = jenis);
                                _giphy();
                              }))
                  ]),
                ])),
          Expanded(
              child: _galat != null
                  ? Center(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(_galat!, textAlign: TextAlign.center),
                            TextButton(
                                onPressed: () =>
                                    _tab == 1 ? _giphy() : _muatKoleksi(),
                                child: const Text('Coba lagi'))
                          ])))
                  : _memuat && (_tab == 0 ? _koleksi.isEmpty : _hasil.isEmpty)
                      ? const Center(child: CircularProgressIndicator())
                      : _tab == 1 && !_siap
                          ? const Center(
                              child: Padding(
                                  padding: EdgeInsets.all(28),
                                  child: Text(
                                      'Pencarian GIPHY belum diaktifkan admin.\nGaleri dan koleksi lokal tetap bisa digunakan.',
                                      textAlign: TextAlign.center)))
                          : (_tab == 0 ? _koleksi.isEmpty : _hasil.isEmpty)
                              ? Center(
                                  child: Text(
                                      _tab == 0
                                          ? 'Koleksi masih kosong.\nTambah dari galeri atau tekan lama stiker orang lain.'
                                          : 'Tidak ada hasil. Coba kata lain.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: pal.muted, height: 1.6)))
                              : GridView.builder(
                                  padding: const EdgeInsets.all(18),
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                          maxCrossAxisExtent: 132,
                                          mainAxisSpacing: 10,
                                          crossAxisSpacing: 10),
                                  itemCount: _tab == 0
                                      ? _koleksi.length
                                      : _hasil.length,
                                  itemBuilder: (ctx, i) {
                                    if (_tab == 1) {
                                      final st = _hasil[i];
                                      return Material(
                                          color: pal.lineSoft,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              onTap: () => Navigator.pop(
                                                  context, PilihanStiker(st)),
                                              onLongPress: () =>
                                                  menuStiker(context, st),
                                              child: Padding(
                                                  padding:
                                                      const EdgeInsets.all(8),
                                                  child: GambarStiker(st,
                                                      ukuran: 100))));
                                    }
                                    final p = _koleksi[i];
                                    return FutureBuilder<Uint8List>(
                                        future: _gambar.putIfAbsent(
                                            p.id, () => _store.baca(p)),
                                        builder: (ctx, snap) => Material(
                                            color: pal.lineSoft,
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                onLongPress: () => _hapus(p),
                                                onTap: snap.hasData
                                                    ? () => Navigator.pop(
                                                        context,
                                                        PilihanStiker(p.stiker,
                                                            bytes: snap.data))
                                                    : null,
                                                child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    child: snap.hasData
                                                        ? GambarStiker(p.stiker,
                                                            bytes: snap.data,
                                                            ukuran: 100)
                                                        : Icon(snap.hasError ? Icons.lock_outline : Icons.hourglass_empty,
                                                            color: pal.muted)))));
                                  })),
          if (_tab == 1 && _lagi)
            TextButton(
                onPressed: _memuat ? null : () => _giphy(tambah: true),
                child: Text(_memuat ? 'Memuat…' : 'Muat lainnya')),
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
              child: Text(
                  _tab == 1
                      ? 'Powered by GIPHY · Tekan lama untuk menyimpan'
                      : 'Terenkripsi di HP ini · WebP, GIF & gambar statis',
                  style: TextStyle(fontSize: 11, color: pal.muted))),
        ]));
  }
}
