import 'dart:convert';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/cache.dart';
import '../../core/prefs.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import '../widgets/lembar.dart';
import 'pembaruan_screen.dart';
import 'tentang_screen.dart';
import 'opsi_screen.dart';
import 'hapus_akun_screen.dart';
import 'stiker_library_screen.dart';

/// ============================================================
///  Pengaturan: daftar utama dan halaman turunannya
/// ============================================================
///  Setiap pengaturan punya halamannya sendiri supaya nyaman dibaca
///  dan tidak menumpuk lembar bawah.
class PengaturanScreen extends StatelessWidget {
  const PengaturanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        children: [
          const _Judul('Akun'),
          _Baris(
            ikon: Icons.badge_outlined,
            judul: 'Ubah Profil',
            sub: 'Nama, nomor WhatsApp, dan foto',
            tujuan: const UbahProfilScreen(),
          ),
          _Baris(
            ikon: Icons.lock_outline_rounded,
            judul: 'Keamanan',
            sub: 'Ganti password dan info sesi',
            tujuan: const KeamananScreen(),
          ),
          const _Judul('Tampilan'),
          _Baris(
            ikon: Icons.dark_mode_outlined,
            judul: 'Tema Aplikasi',
            sub: 'Terang, gelap, atau ikut sistem',
            tujuan: const TemaScreen(),
          ),
          _Baris(ikon:Icons.text_fields_rounded,judul:'Teks & Gerakan',sub:'Ukuran teks dan animasi halaman',tujuan:const OpsiTampilanScreen()),
          _Baris(ikon:Icons.sports_esports_rounded,judul:'Streaming & Kontrol',sub:'Resolusi, FPS, bitrate, gamepad, dan keyboard',tujuan:const OpsiStreamingScreen()),
          const _Judul('Aplikasi'),
          _Baris(ikon:Icons.emoji_emotions_outlined,judul:'Stiker & Penyimpanan',sub:'Koleksi otomatis, folder internal, dan cache',tujuan:const StikerLibraryScreen()),
          _Baris(
            ikon: Icons.notifications_none_rounded,
            judul: 'Notifikasi',
            sub: 'Atur pemberitahuan komunitas',
            tujuan: const OpsiNotifikasiScreen(),
          ),
          _Baris(
            ikon: Icons.data_saver_on_rounded,
            judul: 'Data dan Penyimpanan',
            sub: 'Mode hemat data dan data tersimpan',
            tujuan: const DataScreen(),
          ),
          _Baris(
            ikon: Icons.shield_moon_outlined,
            judul: 'Privasi dan Konten',
            sub: 'Saringan konten dewasa dan laporan',
            tujuan: const PrivasiScreen(),
          ),
          _Baris(
            ikon: Icons.system_update_alt_rounded,
            judul: 'Cek Pembaruan',
            sub: 'Pastikan aplikasimu versi terbaru',
            tujuan: const PembaruanScreen(),
          ),
          const _Judul('Sesi dan akun'),
          _Baris(ikon: Icons.delete_forever_outlined, judul: 'Hapus Akun', sub: 'Konfirmasi identitas sebelum menghapus', tujuan: const HapusAkunScreen()),
          ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 8), leading: const Icon(Icons.logout_rounded, color: XyTheme.danger), title: const Text('Keluar dari Akun'),
            onTap: () async { if (await konfirmasi(context, judul:'Keluar dari akun?', pesan:'Data sesi di HP akan dibersihkan. Akunmu tidak dihapus.', tombolYa:'Keluar', bahaya:true) && context.mounted) { await context.read<AppState>().logout(); } }),
          const _Judul('Lainnya'),
          _Baris(
            ikon: Icons.help_outline_rounded,
            judul: 'Pusat Bantuan',
            sub: 'Pertanyaan yang sering ditanyakan',
            tujuan: const BantuanScreen(),
          ),
          _Baris(
            ikon: Icons.info_outline_rounded,
            judul: 'Tentang Aplikasi',
            sub: 'Versi, legal, dan lisensi',
            tujuan: const TentangScreen(),
          ),
        ],
      ),
    );
  }
}

class _Judul extends StatelessWidget {
  const _Judul(this.teks);
  final String teks;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
        child: Text(teks.toUpperCase(),
            style:  TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: XyTheme.of(context).muted)),
      );
}

class _Baris extends StatelessWidget {
  const _Baris({required this.ikon, required this.judul, required this.sub, required this.tujuan});
  final IconData ikon;
  final String judul, sub;
  final Widget tujuan;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: XyCard(
          padding: const EdgeInsets.all(15),
          onTap: () => Navigator.push(context, xyRoute(tujuan)),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: XyTheme.of(context).primarySoft, borderRadius: BorderRadius.circular(13)),
              child: Icon(ikon, size: 20, color: XyTheme.primary),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(judul, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 3),
                Text(sub, style:  TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5)),
              ]),
            ),
             Icon(Icons.chevron_right_rounded, color: XyTheme.of(context).muted),
          ]),
        ),
      );
}

// ============================================================
//  Ubah profil
// ============================================================
class UbahProfilScreen extends StatefulWidget {
  const UbahProfilScreen({super.key});

  @override
  State<UbahProfilScreen> createState() => _UbahProfilScreenState();
}

class _UbahProfilScreenState extends State<UbahProfilScreen> {
  late final _nama = TextEditingController(text: context.read<AppState>().user?.nama ?? '');
  late final _phone = TextEditingController(text: context.read<AppState>().user?.phone ?? '');
  bool proses = false;
  String? pesan;

  @override
  void dispose() {
    _nama.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (_nama.text.trim().length < 3) {
      setState(() => pesan = 'Nama minimal 3 karakter');
      return;
    }
    setState(() {
      proses = true;
      pesan = null;
    });
    final galat = await context.read<AppState>().perbaruiProfil(
          nama: _nama.text.trim(),
          phone: _phone.text.trim(),
        );
    if (!mounted) return;
    setState(() {
      proses = false;
      pesan = galat;
    });
    if (galat == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil diperbarui.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = context.watch<AppState>().user;
    return Scaffold(
      appBar: AppBar(title: const Text('Ubah Profil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          Center(child: XyIlustrasi('profil', tinggi: 150)),
          const SizedBox(height: 18),
          const _Label('Nama Lengkap'),
          TextField(
            controller: _nama,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Nama yang tampil di komunitas',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 18),
          const _Label('Nomor WhatsApp'),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              hintText: '08xxxxxxxxxx',
              prefixIcon: Icon(Icons.phone_iphone_rounded),
            ),
          ),
          const SizedBox(height: 10),
           Text('Nomor ini dipakai admin untuk menghubungimu soal pesanan.',
              style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12, height: 1.5)),
          if (u?.email != null) ...[
            const SizedBox(height: 18),
            const _Label('Email'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                color: XyTheme.of(context).lineSoft,
                borderRadius: BorderRadius.circular(XyRadius.md),
              ),
              child: Row(children: [
                 Icon(Icons.mail_outline_rounded, size: 19, color: XyTheme.of(context).muted),
                const SizedBox(width: 12),
                Expanded(child: Text(u!.email, style: const TextStyle(fontWeight: FontWeight.w600))),
                const Icon(Icons.verified_rounded, size: 17, color: XyTheme.success),
              ]),
            ),
            const SizedBox(height: 6),
             Text('Email tidak bisa diubah sendiri. Hubungi admin kalau perlu diganti.',
                style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5)),
          ],
          if (pesan != null) ...[
            const SizedBox(height: 16),
            _KotakGalat(pesan!),
          ],
          const SizedBox(height: 24),
          GradientButton(label: 'Simpan Perubahan', icon: Icons.check_rounded, loading: proses, onPressed: _simpan),
        ],
      ),
    );
  }
}

// ============================================================
//  Keamanan
// ============================================================
class KeamananScreen extends StatefulWidget {
  const KeamananScreen({super.key});

  @override
  State<KeamananScreen> createState() => _KeamananScreenState();
}

class _KeamananScreenState extends State<KeamananScreen> {
  final _lama = TextEditingController();
  final _baru = TextEditingController();
  final _ulang = TextEditingController();
  bool lihat = false;
  bool proses = false;
  String? pesan;

  @override
  void dispose() {
    _lama.dispose();
    _baru.dispose();
    _ulang.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (_baru.text.length < 6) {
      setState(() => pesan = 'Password baru minimal 6 karakter');
      return;
    }
    if (_baru.text != _ulang.text) {
      setState(() => pesan = 'Ulangi password belum sama');
      return;
    }
    setState(() {
      proses = true;
      pesan = null;
    });
    final galat = await context.read<AppState>().gantiPassword(_lama.text, _baru.text);
    if (!mounted) return;
    setState(() {
      proses = false;
      pesan = galat;
    });
    if (galat == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password berhasil diganti.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Keamanan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          XyCard(
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: XyTheme.success.withOpacity(.10), shape: BoxShape.circle),
                child: const Icon(Icons.shield_rounded, color: XyTheme.success, size: 21),
              ),
              const SizedBox(width: 13),
               Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Akunmu terlindungi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  SizedBox(height: 3),
                  Text('Password disimpan terenkripsi dan sesi otomatis kedaluwarsa 30 hari.',
                      style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.8, height: 1.45)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 22),
          const Text('Ganti Password',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -.3)),
          const SizedBox(height: 4),
           Text('Kosongkan password lama kalau kamu mendaftar lewat Google.',
              style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12.5, height: 1.5)),
          const SizedBox(height: 18),
          Text('Setelah password disimpan, semua sesi dicabut dan kamu perlu masuk lagi.',style:TextStyle(color:XyTheme.of(context).muted,height:1.5)),
          TextButton(onPressed:()async{final e=await context.read<AppState>().kodePasswordSosial();if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e??'Kode dikirim. Masukkan pada kolom password lama.')));},child:const Text('Akun Google tanpa password? Kirim kode email')),
          const _Label('Password Lama'),
          TextField(
            controller: _lama,
            obscureText: !lihat,
            decoration: InputDecoration(
              hintText: 'Password sekarang',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(lihat ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                onPressed: () => setState(() => lihat = !lihat),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const _Label('Password Baru'),
          TextField(
            controller: _baru,
            obscureText: !lihat,
            decoration: const InputDecoration(
              hintText: 'Minimal 6 karakter',
              prefixIcon: Icon(Icons.lock_reset_rounded),
            ),
          ),
          const SizedBox(height: 18),
          const _Label('Ulangi Password Baru'),
          TextField(
            controller: _ulang,
            obscureText: !lihat,
            decoration: const InputDecoration(
              hintText: 'Ketik ulang password baru',
              prefixIcon: Icon(Icons.lock_reset_rounded),
            ),
          ),
          if (pesan != null) ...[
            const SizedBox(height: 16),
            _KotakGalat(pesan!),
          ],
          const SizedBox(height: 24),
          GradientButton(label: 'Simpan Password', icon: Icons.check_rounded, loading: proses, onPressed: _simpan),

          const SizedBox(height: 34),
          const Text('Zona Berbahaya',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: XyTheme.danger)),
          const SizedBox(height: 10),
          XyCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
               Text(
                'Menghapus akun akan menghilangkan profil, riwayat chat, diskusi, ulasan, dan pemberitahuanmu '
                'secara permanen. Riwayat pembayaran disamarkan untuk keperluan pembukuan. '
                'Pastikan saldomu sudah habis sebelum menghapus.',
                style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12.5, height: 1.6),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => _hapusAkun(context),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: XyTheme.danger)),
                  icon: const Icon(Icons.delete_forever_rounded, size: 18, color: XyTheme.danger),
                  label: const Text('Hapus Akun Saya',
                      style: TextStyle(color: XyTheme.danger, fontWeight: FontWeight.w800)),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _hapusAkun(BuildContext context) async {
    await Navigator.push(context, xyRoute(const HapusAkunScreen()));
  }

}

// ============================================================
//  Notifikasi
// ============================================================
class PengaturanNotifikasiScreen extends StatelessWidget {
  const PengaturanNotifikasiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final u = s.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          Center(child: XyIlustrasi('notifikasi', tinggi: 150)),
          const SizedBox(height: 16),
          XyCard(
            padding: const EdgeInsets.fromLTRB(15, 6, 8, 6),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: XyTheme.of(context).primarySoft, borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.groups_2_outlined, size: 20, color: XyTheme.primary),
              ),
              const SizedBox(width: 13),
               Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Komunitas', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  SizedBox(height: 3),
                  Text('Balasan diskusi, suka, dan pengumuman admin',
                      style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5, height: 1.4)),
                ]),
              ),
              Switch(
                value: u?.notifForum ?? true,
                activeColor: XyTheme.primary,
                onChanged: (v) async {
                  final galat = await s.perbaruiProfil(notifForum: v);
                  if (galat != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(galat)));
                  }
                },
              ),
            ]),
          ),
          const SizedBox(height: 12),
          XyCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children:  [
                Icon(Icons.lock_clock_rounded, size: 18, color: XyTheme.of(context).muted),
                SizedBox(width: 9),
                Text('Selalu aktif', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
              ]),
              const SizedBox(height: 10),
               Text(
                'Pemberitahuan pesanan, balasan admin, dan perubahan saldo tetap dikirim karena '
                'bersifat penting. Kamu masih bisa mematikannya lewat pengaturan Android.',
                style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12.5, height: 1.6),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  Data dan penyimpanan
// ============================================================
class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  int kb = 0;

  @override
  void initState() {
    super.initState();
    _hitung();
  }

  Future<void> _hitung() async {
    final n = await Cache.ukuranKb();
    if (mounted) setState(() => kb = n);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Data dan Penyimpanan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          XyCard(
            padding: const EdgeInsets.fromLTRB(15, 6, 8, 6),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: XyTheme.of(context).primarySoft, borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.data_saver_on_rounded, size: 20, color: XyTheme.primary),
              ),
              const SizedBox(width: 13),
               Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Mode Hemat Data', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  SizedBox(height: 3),
                  Text('Gambar produk dan komunitas tidak diunduh otomatis',
                      style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5, height: 1.4)),
                ]),
              ),
              Switch(value: s.hematData, activeColor: XyTheme.primary, onChanged: s.setHematData),
            ]),
          ),
          const SizedBox(height: 12),
          XyCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.sd_storage_outlined, size: 19, color: XyTheme.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Data tersimpan di perangkat',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                ),
                Text('$kb KB', style: const TextStyle(fontWeight: FontWeight.w800, color: XyTheme.primary)),
              ]),
              const SizedBox(height: 10),
               Text(
                'Katalog, pesanan, dan diskusi disimpan supaya aplikasi langsung terisi saat dibuka '
                'dan tetap bisa dilihat ketika sedang tanpa internet.',
                style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12.5, height: 1.6),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final yakin = await konfirmasi(
                      context,
                      judul: 'Bersihkan data tersimpan?',
                      pesan: 'Aplikasi akan mengunduh ulang katalog saat dibuka lagi. Akunmu tidak terpengaruh.',
                      tombolYa: 'Bersihkan',
                      ikon: Icons.cleaning_services_outlined,
                    );
                    if (!yakin) return;
                    await Cache.bersihkan();
                    await _hitung();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Data tersimpan dibersihkan.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                  label: const Text('Bersihkan Sekarang'),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  Privasi dan konten
// ============================================================
class PrivasiScreen extends StatefulWidget {
  const PrivasiScreen({super.key});

  @override
  State<PrivasiScreen> createState() => _PrivasiScreenState();
}

class _PrivasiScreenState extends State<PrivasiScreen> {
  bool saringan = true;

  @override
  void initState() {
    super.initState();
    Prefs.saringKonten().then((v) => mounted ? setState(() => saringan = v) : null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privasi dan Konten')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          XyCard(
            padding: const EdgeInsets.fromLTRB(15, 6, 8, 6),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: XyTheme.of(context).primarySoft, borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.shield_moon_outlined, size: 20, color: XyTheme.primary),
              ),
              const SizedBox(width: 13),
               Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Saringan Konten Dewasa', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  SizedBox(height: 3),
                  Text('Gambar yang ditandai sensitif ditutup dulu, ketuk untuk melihat',
                      style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5, height: 1.4)),
                ]),
              ),
              Switch(
                value: saringan,
                activeColor: XyTheme.primary,
                onChanged: (v) async {
                  setState(() => saringan = v);
                  await Prefs.simpanSaringKonten(v);
                },
              ),
            ]),
          ),
          const SizedBox(height: 12),
          XyCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:  [
              Row(children: [
                Icon(Icons.flag_outlined, size: 18, color: XyTheme.primary),
                SizedBox(width: 9),
                Text('Melaporkan konten', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
              ]),
              SizedBox(height: 10),
              Text(
                'Setiap diskusi dan komentar punya tombol Laporkan. Pilih alasannya, admin akan meninjau '
                'lalu menandai konten sebagai sensitif atau menghapusnya. Kami tidak memblokir gambar secara '
                'membabi buta supaya diskusi tetap hidup.',
                style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12.5, height: 1.6),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          XyCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: const [
                Icon(Icons.download_for_offline_outlined, size: 18, color: XyTheme.primary),
                SizedBox(width: 9),
                Text('Unduh dataku', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
              ]),
              const SizedBox(height: 10),
               Text(
                'Ambil seluruh data yang kami simpan tentangmu: profil, pesanan, transaksi, '
                'percakapan, diskusi, dan ulasan. Hasilnya disalin ke papan klip dalam bentuk JSON.',
                style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12.5, height: 1.6),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Mengumpulkan datamu...'), duration: Duration(seconds: 1)),
                    );
                    final data = await context.read<AppState>().dataSaya();
                    if (!context.mounted) return;
                    if (data == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Gagal mengambil data, coba lagi.')),
                      );
                      return;
                    }
                    final teks = const JsonEncoder.withIndent('  ').convert(data);
                    await Clipboard.setData(ClipboardData(text: teks));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Data disalin, ${(teks.length / 1024).ceil()} KB. '
                          'Tempel ke aplikasi catatan untuk menyimpannya.')),
                    );
                  },
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Ambil Data Saya'),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          XyCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:  [
              Row(children: [
                Icon(Icons.privacy_tip_outlined, size: 18, color: XyTheme.primary),
                SizedBox(width: 9),
                Text('Data yang kami simpan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
              ]),
              SizedBox(height: 10),
              Text(
                'Nama, email, nomor WhatsApp, riwayat pesanan, dan percakapan dengan admin. '
                'Kami tidak pernah menjual data dan tidak memasang pelacak pihak ketiga.',
                style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12.5, height: 1.6),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  Pusat bantuan
// ============================================================
class BantuanScreen extends StatelessWidget {
  const BantuanScreen({super.key});

  static const _tanya = [
    ('Bagaimana cara mengisi saldo?',
      'Buka Dompet lalu Isi Saldo, pilih nominal, transfer sesuai instruksi, dan unggah bukti. '
      'Kalau pembayaran otomatis aktif, saldo masuk sendiri dalam hitungan detik.'),
    ('Berapa lama pesanan sewa PC diproses?',
      'Unit disiapkan otomatis begitu pembayaran masuk, biasanya kurang dari satu menit. '
      'Kamu akan menerima pemberitahuan saat PC siap.'),
    ('Akun digital saya bermasalah, bagaimana?',
      'Buka Chat Kirana dan sebutkan kode pesanannya. Selama masih dalam masa garansi, akun diganti gratis.'),
    ('Kenapa kode verifikasi tidak masuk?',
      'Cek folder spam atau promosi. Kalau masih belum ada, tekan Kirim ulang kode setelah 60 detik.'),
    ('Bisakah saya menghapus akun?',
      'Bisa. Hubungi admin lewat Chat Kirana, akun dan datanya kami hapus paling lambat tujuh hari kerja.'),
    ('Apakah aman menyimpan saldo di sini?',
      'Saldo tersimpan di server kami dan setiap perubahan tercatat di riwayat transaksi. '
      'Password disimpan terenkripsi dan sesi kedaluwarsa otomatis.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pusat Bantuan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          const Center(child: XyIlustrasi('cs', tinggi: 150)),
          const SizedBox(height: 8),
          const Text('Pertanyaan yang sering ditanyakan',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -.3)),
          const SizedBox(height: 14),
          ..._tanya.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: XyCard(
                  padding: EdgeInsets.zero,
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      iconColor: XyTheme.primary,
                      collapsedIconColor: XyTheme.of(context).muted,
                      title: Text(t.$1,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.8, height: 1.4)),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(t.$2,
                              style:  TextStyle(color: XyTheme.of(context).muted, fontSize: 12.8, height: 1.65)),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

// ============================================================
//  Tema tampilan
// ============================================================
class TemaScreen extends StatefulWidget {
  const TemaScreen({super.key});

  @override
  State<TemaScreen> createState() => _TemaScreenState();
}

class _TemaScreenState extends State<TemaScreen> {
  String pilihan = 'sistem';

  @override
  void initState() {
    super.initState();
    Prefs.tema().then((v) => mounted ? setState(() => pilihan = v) : null);
  }

  @override
  Widget build(BuildContext context) {
    const opsi = [
      ('sistem', 'Ikut Sistem', 'Mengikuti pengaturan gelap atau terang di HP', Icons.brightness_auto_rounded),
      ('terang', 'Terang', 'Latar putih keunguan, nyaman di siang hari', Icons.light_mode_rounded),
      ('gelap', 'Gelap', 'Latar ungu tua, enak dipakai malam hari', Icons.dark_mode_rounded),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Tema Aplikasi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: opsi.map((o) {
          final aktif = o.$1 == pilihan;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: XyCard(
              padding: const EdgeInsets.all(16),
              onTap: () async {
                setState(() => pilihan = o.$1);
                await context.read<AppState>().setTema(o.$1);
              },
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: aktif ? XyTheme.primary : XyTheme.of(context).primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(o.$4, size: 21, color: aktif ? Colors.white : XyTheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(o.$2, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                    const SizedBox(height: 3),
                    Text(o.$3, style:  TextStyle(color: XyTheme.of(context).muted, fontSize: 11.8, height: 1.4)),
                  ]),
                ),
                Icon(aktif ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    color: aktif ? XyTheme.primary : XyTheme.of(context).line),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ============================================================
//  Cek pembaruan aplikasi
// ============================================================
class PembaruanScreen extends StatefulWidget {
  const PembaruanScreen({super.key});

  @override
  State<PembaruanScreen> createState() => _PembaruanScreenState();
}

class _PembaruanScreenState extends State<PembaruanScreen> {
  bool memeriksa = true;

  @override
  void initState() {
    super.initState();
    _periksa();
  }

  Future<void> _periksa() async {
    setState(() => memeriksa = true);
    await context.read<AppState>().periksaPembaruan();
    if (mounted) setState(() => memeriksa = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final ada = s.adaPembaruan;
    final rilis = s.rilisTerbaru;

    return Scaffold(
      appBar: AppBar(title: const Text('Cek Pembaruan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        children: [
          Center(
            child: Column(children: [
              const XyLogo(size: 84, radius: 26),
              const SizedBox(height: 16),
              Text('Versi terpasang ${s.versiSekarang.isEmpty ? '-' : s.versiSekarang}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 6),
              if (memeriksa)
                 Text('Memeriksa versi terbaru...',
                    style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12.5))
              else
                Text(
                  ada
                      ? 'Versi baru ${rilis?['versi'] ?? ''} sudah tersedia'
                      : 'Aplikasimu sudah versi terbaru',
                  style: TextStyle(
                    color: ada ? XyTheme.primary : XyTheme.success,
                    fontSize: 12.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 24),
          if (ada && rilis != null) ...[
            XyCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.new_releases_rounded, size: 19, color: XyTheme.primary),
                  const SizedBox(width: 9),
                  Text('Pembaruan ${rilis['versi']}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                ]),
                const SizedBox(height: 10),
                 Text(
                  'Unduh berkas terbaru lalu pasang menimpa aplikasi yang sekarang. '
                  'Datamu tetap aman karena ditandatangani kunci yang sama.',
                  style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12.8, height: 1.6),
                ),
                const SizedBox(height: 16),
                GradientButton(
                  label: 'Lihat & Perbarui Sekarang',
                  icon: Icons.system_update_alt_rounded,
                  onPressed: () => Navigator.push(
                      context, xyRoute(const PembaruanScreen())),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: memeriksa ? null : _periksa,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Periksa Lagi'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  Potongan kecil
// ============================================================
class _Label extends StatelessWidget {
  const _Label(this.teks);
  final String teks;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9, left: 2),
        child: Text(teks,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, letterSpacing: -.1)),
      );
}

class _KotakGalat extends StatelessWidget {
  const _KotakGalat(this.pesan);
  final String pesan;

  @override
  Widget build(BuildContext context) => Container(
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
            child: Text(pesan,
                style: const TextStyle(color: XyTheme.danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}

/// Dipakai halaman lain untuk menyalin teks singkat.
Future<void> salinTeks(BuildContext context, String teks, String label) async {
  await Clipboard.setData(ClipboardData(text: teks));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label disalin'), duration: const Duration(seconds: 1)),
    );
  }
}
