import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// ============================================================
///  XyCloud Design System — Premium Edition
///  Token spasi, radius, elevasi, gradien, dan tema Material 3.
/// ============================================================
class XySpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double page = 22;
}

class XyRadius {
  static const double sm = 14;
  static const double md = 18;
  static const double lg = 22;
  static const double xl = 28;
  static const double pill = 100;

  /// Radius khusus tombol supaya bentuknya membulat, bukan kotak.
  static const double tombol = 30;
}

class XyTheme {
  static XyPalette of(BuildContext context) =>
      XyPalette(Theme.of(context).brightness == Brightness.dark);

  // ---------- palet ungu XyCloudStore ----------
  // Diambil langsung dari logo resmi: ungu pekat glosi, tanpa warna neon.
  static const Color primary = Color(0xFF6C2BE2); // ungu utama
  static const Color primaryDeep = Color(0xFF4A12B8); // ungu pekat
  static const Color primaryDark = Color(0xFF33087F); // ungu paling gelap
  static const Color primarySoft = Color(0xFFF2ECFF); // latar lembut
  static const Color violet = Color(0xFF8B5CF6); // ungu terang
  static const Color lavender = Color(0xFFC4B5FD); // aksen lembut
  static const Color plum = Color(0xFF9333EA); // aksen tua

  static const Color ink = Color(0xFF1A1033); // teks utama (ungu kehitaman)
  static const Color inkSoft = Color(0xFF453B5E);
  static const Color muted = Color(0xFF7C7391);
  static const Color line = Color(0xFFEAE3F7);
  static const Color lineSoft = Color(0xFFF4F0FD);
  static const Color bg = Color(0xFFFAF8FF);
  static const Color surface = Color(0xFFFFFFFF);

  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD9880F);
  static const Color danger = Color(0xFFDC2626);
  static const Color gold = Color(0xFFD9A441);

  // ---------- gradien ----------
  static const LinearGradient gradPrimary = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF5B16CC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient gradDeep = LinearGradient(
    colors: [Color(0xFF33087F), Color(0xFF5B16CC), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient gradMidnight = LinearGradient(
    colors: [Color(0xFF1A1033), Color(0xFF2E1065), Color(0xFF4A12B8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient gradAurora = LinearGradient(
    colors: [Color(0xFFC4B5FD), Color(0xFF8B5CF6), Color(0xFF6C2BE2)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  static const LinearGradient gradSoft = LinearGradient(
    colors: [Color(0xFFF6F1FF), Color(0xFFEDE4FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient gradGold = LinearGradient(
    colors: [Color(0xFFE8C07A), Color(0xFFC08A2E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ---------- elevasi ----------
  /// Alias lama supaya kode lain tetap jalan (tidak ada warna neon lagi).
  static const Color cyan = violet;

  static List<BoxShadow> get shadowXs => [
        BoxShadow(
            color: ink.withOpacity(.035),
            blurRadius: 8,
            offset: const Offset(0, 2)),
      ];
  static List<BoxShadow> get shadowSm => [
        BoxShadow(
            color: ink.withOpacity(.05),
            blurRadius: 16,
            offset: const Offset(0, 6)),
      ];
  static List<BoxShadow> get shadowMd => [
        BoxShadow(
            color: ink.withOpacity(.07),
            blurRadius: 28,
            offset: const Offset(0, 12)),
        BoxShadow(
            color: ink.withOpacity(.03),
            blurRadius: 4,
            offset: const Offset(0, 1)),
      ];
  static List<BoxShadow> glow(Color c, [double o = .32]) => [
        BoxShadow(
            color: c.withOpacity(o),
            blurRadius: 26,
            offset: const Offset(0, 12)),
      ];

  // ---------- palet gelap ----------
  static const Color bgGelap = Color(0xFF120C22);
  static const Color surfaceGelap = Color(0xFF1B1233);
  static const Color lineGelap = Color(0xFF2C1F4D);
  static const Color inkGelap = Color(0xFFECE6FA);
  static const Color mutedGelap = Color(0xFF9C92B8);

  // ---------- tema ----------
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        surface: surface,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: bg,
      splashFactory: InkSparkle.splashFactory,
    );

    final text = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
      bodyColor: ink,
      displayColor: ink,
    );

    return base.copyWith(
      textTheme: text.copyWith(
        displayLarge: text.displayLarge
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1.6),
        headlineMedium: text.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1),
        titleLarge: text.titleLarge
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.5),
        titleMedium: text.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.2),
        bodyMedium: text.bodyMedium?.copyWith(height: 1.55),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -.4,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFD9CFF0),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(XyRadius.tombol)),
          textStyle: const TextStyle(
              fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -.1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          backgroundColor: surface,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: line),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(XyRadius.tombol)),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        prefixIconColor: muted,
        suffixIconColor: muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(XyRadius.md),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(XyRadius.md),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(XyRadius.md),
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(XyRadius.md),
          borderSide: const BorderSide(color: danger),
        ),
        hintStyle: const TextStyle(color: muted, fontWeight: FontWeight.w500),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surface,
        side: const BorderSide(color: line),
        labelStyle:
            const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(XyRadius.pill)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
      dividerTheme: const DividerThemeData(color: line, space: 1, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(XyRadius.sm)),
        insetPadding: const EdgeInsets.all(16),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(XyRadius.xl)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }

  /// Tema gelap: ungu tetap jadi warna utama, latar dibuat teduh
  /// supaya nyaman dipakai malam hari tanpa kehilangan identitas merek.
  static ThemeData gelap() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: violet,
        surface: surfaceGelap,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: bgGelap,
      splashFactory: InkSparkle.splashFactory,
    );

    final text = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
      bodyColor: inkGelap,
      displayColor: inkGelap,
    );

    return base.copyWith(
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1),
        titleLarge: text.titleLarge
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.5),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        bodyMedium: text.bodyMedium?.copyWith(height: 1.55),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgGelap,
        foregroundColor: inkGelap,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: inkGelap,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -.4,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: violet,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(XyRadius.tombol)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: inkGelap,
          backgroundColor: surfaceGelap,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: lineGelap),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(XyRadius.tombol)),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: lavender,
          textStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceGelap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        prefixIconColor: mutedGelap,
        suffixIconColor: mutedGelap,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(XyRadius.md),
          borderSide: const BorderSide(color: lineGelap),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(XyRadius.md),
          borderSide: const BorderSide(color: lineGelap),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(XyRadius.md),
          borderSide: const BorderSide(color: violet, width: 1.6),
        ),
        hintStyle:
            const TextStyle(color: mutedGelap, fontWeight: FontWeight.w500),
      ),
      dividerTheme:
          const DividerThemeData(color: lineGelap, space: 1, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceGelap,
        contentTextStyle: const TextStyle(
            color: inkGelap, fontWeight: FontWeight.w600, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(XyRadius.sm)),
        insetPadding: const EdgeInsets.all(16),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: surfaceGelap,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(XyRadius.xl)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}

/// Warna permukaan/teks harus mengikuti tema pada BuildContext, bukan konstanta terang.
@immutable
class XyPalette {
  const XyPalette(this.dark);
  final bool dark;
  Color get bg => dark ? XyTheme.bgGelap : XyTheme.bg;
  Color get surface => dark ? XyTheme.surfaceGelap : XyTheme.surface;
  Color get ink => dark ? XyTheme.inkGelap : XyTheme.ink;
  Color get inkSoft => dark ? const Color(0xFFCCC1DF) : XyTheme.inkSoft;
  Color get muted => dark ? const Color(0xFFB2A6C9) : XyTheme.muted;
  Color get line => dark ? XyTheme.lineGelap : XyTheme.line;
  Color get lineSoft => dark ? const Color(0xFF251A3B) : XyTheme.lineSoft;
  Color get primarySoft => dark ? const Color(0xFF30204A) : XyTheme.primarySoft;
  Color get accent => dark ? XyTheme.lavender : XyTheme.primary;
  LinearGradient get gradSoft => dark
      ? const LinearGradient(colors: [Color(0xFF291B40), Color(0xFF20152F)])
      : XyTheme.gradSoft;
}
