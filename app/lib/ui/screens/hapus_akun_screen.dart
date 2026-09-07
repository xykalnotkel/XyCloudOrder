import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';

class HapusAkunScreen extends StatefulWidget {
  const HapusAkunScreen({super.key});
  @override
  State<HapusAkunScreen> createState() => _HapusAkunScreenState();
}

class _HapusAkunScreenState extends State<HapusAkunScreen> {
  final _konfirmasi = TextEditingController(),
      _rahasia = TextEditingController();
  Map<String, dynamic>? _info;
  String? _galat;
  bool _sibuk = false, _kirim = false;
  int _tunggu = 0;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _konfirmasi.dispose();
    _rahasia.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _muat() async {
    setState(() => _galat = null);
    try {
      final d = await context.read<AppState>().infoHapusAkun();
      if (mounted) setState(() => _info = d);
    } catch (e) {
      if (mounted)
        setState(() => _galat = 'Informasi akun belum bisa dimuat. Coba lagi.');
    }
  }

  Future<void> _kode() async {
    setState(() => _kirim = true);
    try {
      await context.read<AppState>().mintaKodeHapus();
      if (!mounted) return;
      setState(() => _tunggu = 60);
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted || _tunggu <= 1) {
          t.cancel();
          if (mounted) setState(() => _tunggu = 0);
        } else {
          setState(() => _tunggu--);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Kode konfirmasi dikirim ke email akunmu.')));
    } catch (e) {
      if (mounted) setState(() => _galat = '$e');
    } finally {
      if (mounted) setState(() => _kirim = false);
    }
  }

  Future<void> _hapus() async {
    if (_sibuk || _konfirmasi.text.trim() != 'HAPUS' || _rahasia.text.isEmpty)
      return;
    FocusScope.of(context).unfocus();
    setState(() {
      _sibuk = true;
      _galat = null;
    });
    final otp = _info?['perlu_otp'] == true;
    final s = context.read<AppState>();
    final error = await s.hapusAkun(
        password: otp ? null : _rahasia.text,
        kode: otp ? _rahasia.text.trim() : null);
    if (mounted)
      setState(() {
        _sibuk = false;
        _galat = error;
      });
  }

  @override
  Widget build(BuildContext context) {
    final pal = XyTheme.of(context), otp = _info?['perlu_otp'] == true;
    final boleh = _info?['boleh_hapus'] == true;
    return Scaffold(
        appBar: AppBar(title: const Text('Hapus Akun')),
        body: ListView(padding: const EdgeInsets.all(22), children: [
          Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: XyTheme.danger.withOpacity(.09),
                  borderRadius: BorderRadius.circular(20)),
              child: const Row(children: [
                Icon(Icons.delete_forever_outlined,
                    color: XyTheme.danger, size: 28),
                SizedBox(width: 14),
                Expanded(
                    child: Text('Keputusan ini tidak bisa dibatalkan.',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 17)))
              ])),
          const SizedBox(height: 18),
          Text(
              'Profil, chat, diskusi, komentar, ulasan, dan koleksi stiker lokal akun ini akan dihapus. Data transaksi disimpan tanpa identitas akun untuk pembukuan. Saldo tidak akan dihanguskan secara otomatis.',
              style: TextStyle(color: pal.inkSoft, height: 1.65)),
          const SizedBox(height: 20),
          if (_info == null && _galat == null)
            const Center(child: CircularProgressIndicator()),
          if (_info != null && !boleh)
            XyCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Selesaikan dulu sebelum menghapus',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  ...(_info!['penghalang'] as List).map((x) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child:
                          Text('• $x', style: TextStyle(color: pal.inkSoft)))),
                  const Text(
                      'Kamu tetap dapat keluar dari akun tanpa menghapusnya.'),
                ])),
          if (boleh) ...[
            Text(otp ? 'Verifikasi lewat email' : 'Konfirmasi password',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            if (otp) ...[
              Text(
                  'Akun Google memerlukan kode sekali pakai. Email hanya dikirim saat kamu menekan tombol di bawah.',
                  style: TextStyle(color: pal.muted, height: 1.5)),
              const SizedBox(height: 12),
              OutlinedButton(
                  onPressed: _kirim || _tunggu > 0 ? null : _kode,
                  child: Text(_kirim
                      ? 'Mengirim…'
                      : _tunggu > 0
                          ? 'Kirim ulang dalam $_tunggu detik'
                          : 'Kirim kode konfirmasi')),
              const SizedBox(height: 12)
            ],
            TextField(
                controller: _rahasia,
                enabled: !_sibuk,
                obscureText: !otp,
                keyboardType:
                    otp ? TextInputType.number : TextInputType.visiblePassword,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                    labelText: otp ? 'Kode 6 digit' : 'Password saat ini',
                    prefixIcon:
                        Icon(otp ? Icons.pin_outlined : Icons.lock_outline)),
                onChanged: (_) => setState(() {})),
            const SizedBox(height: 20),
            const Text('Ketik HAPUS untuk menyetujui',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            TextField(
                controller: _konfirmasi,
                enabled: !_sibuk,
                autocorrect: false,
                decoration: const InputDecoration(hintText: 'HAPUS'),
                onChanged: (_) => setState(() {})),
            const SizedBox(height: 24),
            FilledButton.icon(
                onPressed: _sibuk ||
                        _konfirmasi.text.trim() != 'HAPUS' ||
                        _rahasia.text.isEmpty
                    ? null
                    : _hapus,
                style: FilledButton.styleFrom(backgroundColor: XyTheme.danger),
                icon: _sibuk
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.delete_forever_outlined),
                label: Text(_sibuk ? 'Menghapus…' : 'Hapus akun permanen')),
          ],
          if (_galat != null) ...[
            const SizedBox(height: 18),
            Text(_galat!, style: const TextStyle(color: XyTheme.danger)),
            if (_info == null)
              TextButton(onPressed: _muat, child: const Text('Coba lagi'))
          ],
          const SizedBox(height: 12),
          TextButton(
              onPressed: _sibuk ? null : () => Navigator.pop(context),
              child: const Text('Batal, pertahankan akun')),
        ]));
  }
}
