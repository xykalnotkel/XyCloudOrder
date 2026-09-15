import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/biometrik.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import '../widgets/lembar.dart';

/// ============================================================
///  Layar kunci passkey / sidik jari (Batch I)
/// ============================================================
///  Muncul setiap kali aplikasi dibuka bila pengguna mengaktifkan
///  "Login dengan sidik jari" di Keamanan. Sesi tetap tersimpan;
///  layar ini hanya gerbang biometrik di depan shell aplikasi.
class KunciBiometrikScreen extends StatefulWidget {
  const KunciBiometrikScreen({super.key});

  @override
  State<KunciBiometrikScreen> createState() => _KunciBiometrikScreenState();
}

class _KunciBiometrikScreenState extends State<KunciBiometrikScreen> {
  bool _sibuk = false;
  String? _galat;

  @override
  void initState() {
    super.initState();
    // Langsung minta biometrik begitu layar tampil.
    WidgetsBinding.instance.addPostFrameCallback((_) => _coba());
  }

  Future<void> _coba() async {
    if (_sibuk) return;
    setState(() {
      _sibuk = true;
      _galat = null;
    });
    final ok = await Biometrik.autentikasi(
        alasan: 'Buka XyCloudStore dengan sidik jari atau wajahmu');
    if (!mounted) return;
    setState(() => _sibuk = false);
    if (ok) {
      HapticFeedback.mediumImpact();
      context.read<AppState>().bukaKunciBiometrik();
    } else {
      setState(() => _galat = 'Verifikasi dibatalkan atau gagal. Coba lagi.');
    }
  }

  Future<void> _pakaiPassword() async {
    final yakin = await konfirmasi(
      context,
      judul: 'Keluar dan pakai password?',
      pesan:
          'Sesi tersimpan akan dihapus. Kamu perlu masuk lagi dengan email dan password.',
      tombolYa: 'Keluar',
      ikon: Icons.logout_rounded,
      bahaya: true,
    );
    if (yakin && mounted) {
      await context.read<AppState>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final nama = context.watch<AppState>().user?.nama ?? '';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const XyLogo(size: 74),
                const SizedBox(height: 22),
                Text(
                  nama.isEmpty ? 'Aplikasi terkunci' : 'Halo, $nama',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      letterSpacing: -.5),
                ),
                const SizedBox(height: 8),
                Text(
                  'Verifikasi sidik jari atau wajahmu untuk membuka XyCloudStore.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: XyTheme.of(context).muted,
                      fontSize: 13,
                      height: 1.55),
                ),
                const SizedBox(height: 34),
                Pressable(
                  onTap: _sibuk ? null : _coba,
                  scale: .92,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          XyTheme.violet.withOpacity(.22),
                          XyTheme.primary.withOpacity(.10),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                          color: XyTheme.violet.withOpacity(.5), width: 1.6),
                      boxShadow: XyTheme.glow(XyTheme.primary, .22),
                    ),
                    child: _sibuk
                        ? const Padding(
                            padding: EdgeInsets.all(30),
                            child: CircularProgressIndicator(strokeWidth: 2.6),
                          )
                        : const Icon(Icons.fingerprint_rounded,
                            size: 52, color: XyTheme.violet),
                  ),
                ),
                const SizedBox(height: 16),
                if (_galat != null)
                  Text(
                    _galat!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: XyTheme.dangerBright,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                const SizedBox(height: 26),
                GradientButton(
                  label: 'Verifikasi Sidik Jari',
                  icon: Icons.fingerprint_rounded,
                  loading: _sibuk,
                  onPressed: _coba,
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _pakaiPassword,
                  icon: const Icon(Icons.password_rounded, size: 16),
                  label: const Text('Gunakan password saja'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
