import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'data/push_service.dart';
import 'providers/app_state.dart';
import 'ui/screens/flow_gate.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/screens/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  await PushService.mulai();
  runApp(const XyCloudStoreApp());
}

class XyCloudStoreApp extends StatelessWidget {
  const XyCloudStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'XyCloudStore',
        debugShowCheckedModeBanner: false,
        theme: XyTheme.light(),
        builder: (context, child) => MediaQuery.withNoTextScaling(child: child!),
        home: const _Root(),
      ),
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
