import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import 'common.dart';

/// Gambar produk dari server; kalau kosong dipakai gradien bawaan.
class GambarProduk extends StatelessWidget {
  const GambarProduk({
    super.key,
    required this.produk,
    this.tinggi = 190,
    this.radius = XyRadius.lg,
  });

  final AkunProduk produk;
  final double tinggi;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final hemat = context.select<AppState, bool>((s) => s.hematData);
    if (produk.gambar.isEmpty || hemat) {
      return GradientThumb(
        seed: produk.id,
        icon: Icons.vpn_key_rounded,
        size: tinggi,
        radius: radius,
      );
    }
    return AppImage(
      produk.gambar,
      tinggi: tinggi,
      lebar: double.infinity,
      fit: BoxFit.cover,
      radius: radius,
      placeholderKet: true,
    );
  }
}

/// Bintang rating, bisa dipakai untuk menampilkan atau memilih nilai.
class Bintang extends StatelessWidget {
  const Bintang({super.key, required this.nilai, this.ukuran = 15, this.onPilih});
  final double nilai;
  final double ukuran;
  final ValueChanged<int>? onPilih;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final penuh = i < nilai.round();
        final ikon = Icon(
          penuh ? Icons.star_rounded : Icons.star_outline_rounded,
          size: ukuran,
          color: penuh ? XyTheme.gold : XyTheme.of(context).line,
        );
        if (onPilih == null) return ikon;
        return Pressable(
          onTap: () => onPilih!(i + 1),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: ikon),
        );
      }),
    );
  }
}

/// Satu kartu ulasan pembeli.
class KartuUlasan extends StatelessWidget {
  const KartuUlasan(this.u, {super.key});
  final Ulasan u;

  @override
  Widget build(BuildContext context) {
    final inisial = u.nama.trim().isEmpty ? 'X' : u.nama.trim()[0].toUpperCase();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: XyCard(
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(gradient: XyTheme.gradPrimary, shape: BoxShape.circle),
              child: Center(
                child: Text(inisial,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u.nama, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 3),
                Row(children: [
                  Bintang(nilai: u.rating.toDouble(), ukuran: 13),
                  const SizedBox(width: 7),
                  Text(tanggal(u.waktu), style:  TextStyle(color: XyTheme.of(context).muted, fontSize: 11)),
                ]),
              ]),
            ),
          ]),
          if (u.komentar.isNotEmpty) ...[
            const SizedBox(height: 11),
            Text(u.komentar, style:  TextStyle(fontSize: 13.2, height: 1.55, color: XyTheme.of(context).inkSoft)),
          ],
          if (u.gambar != null) ...[
            const SizedBox(height: 11),
            ClipRRect(
              borderRadius: BorderRadius.circular(XyRadius.sm),
              child: Image.network(u.gambar!,
                  height: 140, width: double.infinity, fit: BoxFit.cover, cacheWidth: 900),
            ),
          ],
          if (u.balasan != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: XyTheme.of(context).primarySoft,
                borderRadius: BorderRadius.circular(XyRadius.sm),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: const [
                  Icon(Icons.storefront_rounded, size: 14, color: XyTheme.primary),
                  SizedBox(width: 6),
                  Text('Balasan XyCloudStore',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: XyTheme.primary)),
                ]),
                const SizedBox(height: 6),
                Text(u.balasan!, style: const TextStyle(fontSize: 12.5, height: 1.5)),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Formulir menulis ulasan (bintang, komentar, foto opsional).
Future<void> bukaFormUlasan(BuildContext context, AkunProduk produk) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(_).viewInsets.bottom),
      child: _FormUlasan(produk: produk),
    ),
  );
}

class _FormUlasan extends StatefulWidget {
  const _FormUlasan({required this.produk});
  final AkunProduk produk;

  @override
  State<_FormUlasan> createState() => _FormUlasanState();
}

class _FormUlasanState extends State<_FormUlasan> {
  int rating = 5;
  final _komentar = TextEditingController();
  String? _fotoDataUri;
  bool proses = false;

  @override
  void dispose() {
    _komentar.dispose();
    super.dispose();
  }

  Future<void> _pilihFoto() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 75);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    final tipe = f.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
    setState(() => _fotoDataUri = 'data:image/$tipe;base64,${base64Encode(bytes)}');
  }

  Future<void> _kirim() async {
    setState(() => proses = true);
    final galat = await context.read<AppState>().kirimUlasan(
          produkId: widget.produk.id,
          rating: rating,
          komentar: _komentar.text.trim(),
          gambar: _fotoDataUri,
        );
    if (!mounted) return;
    setState(() => proses = false);
    if (galat != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(galat)));
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Terima kasih, ulasanmu sudah tayang.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
      decoration:  BoxDecoration(
        color: XyTheme.of(context).bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(
          child: Container(
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(color: XyTheme.of(context).line, borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 18),
        const Text('Tulis Ulasan',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -.6)),
        const SizedBox(height: 4),
        Text(widget.produk.nama, style:  TextStyle(color: XyTheme.of(context).muted, fontSize: 12.5)),
        const SizedBox(height: 18),
        Center(child: Bintang(nilai: rating.toDouble(), ukuran: 36, onPilih: (v) => setState(() => rating = v))),
        const SizedBox(height: 18),
        TextField(
          controller: _komentar,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Bagaimana pengalamanmu memakai produk ini?',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _pilihFoto,
              icon: Icon(_fotoDataUri == null ? Icons.image_outlined : Icons.check_rounded, size: 18),
              label: Text(_fotoDataUri == null ? 'Tambah Foto' : 'Foto siap dikirim'),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        GradientButton(
          label: 'Kirim Ulasan',
          icon: Icons.send_rounded,
          loading: proses,
          onPressed: proses ? null : _kirim,
        ),
      ]),
    );
  }
}
