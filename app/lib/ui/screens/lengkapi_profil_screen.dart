import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/kompres.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import '../widgets/galeri_picker.dart';

/// ============================================================
///  Lengkapi Profil — onboarding setelah pertama kali masuk
/// ============================================================
///  Tampil sekali setelah daftar/masuk (termasuk lewat Google) selama
///  username masih kosong: foto profil, nama tampilan, username publik,
///  dan nomor WhatsApp. Tidak bisa kembali (root gate) — setelah disimpan,
///  AppState.user terisi username dan aplikasi otomatis lanjut ke shell.
class LengkapiProfilScreen extends StatefulWidget {
  const LengkapiProfilScreen({super.key});

  @override
  State<LengkapiProfilScreen> createState() => _LengkapiProfilScreenState();
}

class _LengkapiProfilScreenState extends State<LengkapiProfilScreen> {
  late final _nama =
      TextEditingController(text: context.read<AppState>().user?.nama ?? '');
  late final _username = TextEditingController(
      text: context.read<AppState>().user?.username ?? '');
  late final _phone =
      TextEditingController(text: context.read<AppState>().user?.phone ?? '');
  String? _foto; // data URI foto baru (null = pakai foto lama/Google)
  bool _proses = false;
  String? _pesan;

  @override
  void dispose() {
    _nama.dispose();
    _username.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pilihFoto() async {
    // Batch I: galeri kustom + kompres WebP client-side (hemat kuota & server).
    final f = await GaleriPicker.pilihGambar(context, judul: 'Pilih Foto Profil');
    if (f == null || !mounted) return;
    final bytes = await f.readAsBytes();
    final nama = f.uri.pathSegments.isNotEmpty ? f.uri.pathSegments.last : 'foto.jpg';
    final uri = await Kompres.dataUri(bytes, nama, maxSisi: 700, kualitas: 78);
    if (!mounted) return;
    setState(() => _foto = uri);
  }

  Future<void> _simpan() async {
    final nama = _nama.text.trim();
    final un =
        _username.text.trim().toLowerCase().replaceFirst(RegExp(r'^@'), '');
    if (nama.length < 3) {
      setState(() => _pesan = 'Nama minimal 3 karakter.');
      return;
    }
    if (un.length < 3 ||
        un.length > 20 ||
        !RegExp(r'^[a-z0-9_.]+$').hasMatch(un)) {
      setState(() => _pesan =
          'Username 3–20 karakter: huruf kecil, angka, titik, atau underscore.');
      return;
    }
    // Aturan ketat Batch I (sama dengan server): awalan/akhiran & titik ganda.
    if (!RegExp(r'^[a-z0-9]').hasMatch(un) ||
        RegExp(r'[._]$').hasMatch(un) ||
        un.contains('..')) {
      setState(() => _pesan =
          'Username harus diawali huruf/angka, tidak berakhir titik/underscore, tanpa titik berurutan.');
      return;
    }
    setState(() {
      _proses = true;
      _pesan = null;
    });
    final galat = await context.read<AppState>().perbaruiProfil(
          nama: nama,
          username: un,
          phone: _phone.text.trim(),
          foto: _foto,
        );
    if (!mounted) return;
    setState(() {
      _proses = false;
      _pesan = galat;
    });
    // Sukses: user diperbarui → gate root otomatis pindah ke aplikasi.
  }

  @override
  Widget build(BuildContext context) {
    final u = context.watch<AppState>().user;
    final fotoLama = (u?.foto ?? '').isNotEmpty;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: ListView(
          padding: EdgeInsets.fromLTRB(
              22, MediaQuery.of(context).padding.top + 10, 22, 34),
          children: [
            const SizedBox(height: 14),
            Center(child: XyIlustrasi('profil', tinggi: 140)),
            const SizedBox(height: 16),
            const Text('Satu langkah lagi!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -.5)),
            const SizedBox(height: 6),
            Text(
                'Lengkapi profilmu supaya bisa di-mention di komunitas dan mudah dihubungi soal pesanan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: XyTheme.of(context).muted, fontSize: 13, height: 1.55)),
            const SizedBox(height: 24),
            Center(
              child: Stack(children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: XyTheme.primary.withOpacity(.10),
                    border: Border.all(color: XyTheme.primary.withOpacity(.35), width: 2),
                    image: _foto == null && fotoLama
                        ? DecorationImage(image: NetworkImage(u!.foto!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _foto == null && !fotoLama
                      ? Center(
                          child: Text(
                            (u?.nama ?? '').isNotEmpty ? u!.nama[0].toUpperCase() : 'X',
                            style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                color: XyTheme.primary),
                          ),
                        )
                      : (_foto != null
                          ? ClipOval(
                              child: Image.memory(
                                base64Decode(_foto!.split(',').last),
                                width: 96,
                                height: 96,
                                fit: BoxFit.cover,
                              ),
                            )
                          : null),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Pressable(
                    onTap: _pilihFoto,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: XyTheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: XyTheme.shadowSm,
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 26),
            const XyLabel('Nama Tampilan'),
            TextField(
              controller: _nama,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Nama yang tampil di komunitas',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 16),
            const XyLabel('Username Publik'),
            TextField(
              controller: _username,
              autocorrect: false,
              decoration: const InputDecoration(
                hintText: 'contoh: haekal_saputra',
                prefixText: '@',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
            const SizedBox(height: 6),
            Text('Username unik tanpa spasi. Bisa diganti lagi lewat Profil → ikon pensil.',
                style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5)),
            const SizedBox(height: 16),
            const XyLabel('Nomor WhatsApp (opsional)'),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: '08xxxxxxxxxx',
                prefixIcon: Icon(Icons.phone_iphone_rounded),
              ),
            ),
            if (_pesan != null) ...[
              const SizedBox(height: 14),
              Text(_pesan!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: XyTheme.danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 26),
            GradientButton(
              label: _proses ? 'Menyimpan…' : 'Simpan & Mulai',
              loading: _proses,
              onPressed: _proses ? null : _simpan,
            ),
          ],
        ),
      ),
    );
  }
}
