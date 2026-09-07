import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'core/pengaturan.dart';
import 'package:flutter/foundation.dart';
import 'data/lapor_galat.dart';
import 'data/push_service.dart';
import 'providers/app_state.dart';
import 'ui/screens/flow_gate.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/screens/shell.dart';
import 'ui/widgets/perawatan_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  LicenseRegistry.addLicense(() async* {yield LicenseEntryWithLineBreaks(['Moonlight Android / XyCloudStore Streaming'],await rootBundle.loadString('assets/licenses/moonlight-gpl3.txt'));});
  await PushService.mulai();
  await LaporGalat.siapkan();

  // semua galat yang lolos ditangkap dan dilaporkan ke server sendiri
  LaporGalat.pasang(() => runApp(const XyCloudStoreApp()));
}

class XyCloudStoreApp extends StatelessWidget {
  const XyCloudStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: Builder(builder: (context) => MaterialApp(
        key: ValueKey(context.watch<AppState>().user?.id ?? 'tamu'),
        title: 'XyCloudStore',
        debugShowCheckedModeBanner: false,
        theme: XyTheme.light(),
        darkTheme: XyTheme.gelap(),
        themeMode: context.watch<AppState>().modeTema,
        builder: (context, child) {
          final gelap = Theme.of(context).brightness == Brightness.dark;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: gelap ? Brightness.light : Brightness.dark,
              systemNavigationBarColor: XyTheme.of(context).surface,
              systemNavigationBarIconBrightness: gelap ? Brightness.light : Brightness.dark,
            ),
            child: MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:TextScaler.linear((MediaQuery.textScalerOf(context).scale(1)*PengaturanLokal.skala).clamp(.85,1.6))),child:child!),
          );
        },
        home: const _Root(),
      )),
    );
  }
}

/// Begitu user berhasil login, seluruh stack flow (splash/onboarding/welcome/login)
/// diganti oleh shell aplikasi.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    // selama token tersimpan sedang diperiksa, tetap tampilkan splash
    if (s.memeriksaSesi) {
      return const SplashScreen(pesan: 'Memulihkan sesi kamu');
    }

    // server sedang mode pemeliharaan: tampilkan halaman perawatan yang jelas
    // (baik sebelum maupun sesudah login), bukan deretan galat yang membingungkan
    if (s.perawatan) {
      return PerawatanScreen(
        pesan: s.pesanPerawatan,
        onCoba: s.cobaLagiPerawatan,
        onKeluar: s.masuk ? s.logout : null,
      );
    }

    final masuk = s.masuk;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 480),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: .98, end: 1.0).animate(a), child: child),
      ),
      child: masuk ? const XyShell(key: ValueKey('shell')) : const FlowGate(key: ValueKey('flow')),
    );
  }
}
