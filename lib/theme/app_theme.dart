import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'motion.dart';

/// Skala jarak & radius. Pakai ini, bukan angka bebas.
class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double huge = 32;
}

class AppRadius {
  AppRadius._();
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
}

/// Design tokens v3 — "tenang & klinis".
///
/// Prinsip: SATU warna aksen (teal), warna lain hanya untuk status (sukses,
/// peringatan, galat). Latar gelap kehijauan yang lembut, bukan biru pekat.
/// Nama konstanta lama dipertahankan sebagai alias supaya layar yang belum
/// didesain ulang (riwayat, admin, dll.) otomatis ikut palet baru.
class AppTheme {
  AppTheme._();

  // ── Permukaan ──────────────────────────────────────────────
  static const Color bg = Color(0xFFF1F8FD);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceRaised = Color(0xFFEAF3FA);
  static const Color outline = Color(0xFFD3E4F1);
  static const Color border = outline;

  // ── Aksen ──────────────────────────────────────────────────
  /// Biru laut primer untuk tombol terisi, ikon aksen, tautan, dan indikator.
  /// Teks putih di atasnya = kontras 6.2:1 (lulus WCAG AA).
  static const Color accent = Color(0xFF0A64A8);
  static const Color primaryDeep = Color(0xFF0A64A8);

  // ── Teks ───────────────────────────────────────────────────
  static const Color text = Color(0xFF0B2A40); // 14.8:1
  static const Color textMuted = Color(0xFF3F5A70); // 7.2:1
  static const Color textFaint = Color(0xFF4A667E); // ≥ 4.6:1

  // ── Status ─────────────────────────────────────────────────
  static const Color success = Color(0xFF176B40);
  static const Color warning = Color(0xFF8A5200);
  static const Color error = Color(0xFFB02323);
  static const Color info = Color(0xFF0A64A8);

  // ── Bayangan Kartu ──────────────────────────────────────────
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color.fromRGBO(11, 42, 64, 0.06),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color.fromRGBO(10, 100, 168, 0.08),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  // ── Alias nama lama (JANGAN dihapus sampai semua layar dimigrasi) ──
  static const Color primaryDark = bg;
  static const Color secondaryDark = Color(0xFFE3EFF8);
  static const Color cardDark = surface;
  static const Color surfaceDark = surfaceRaised;
  static const Color accentTeal = accent;
  static const Color accentBlue = info;
  static const Color accentPurple = Color(0xFF5B4EB3);
  static const Color textPrimary = text;
  static const Color textSecondary = textMuted;
  static const Color textHint = textFaint;
  static const Color divider = outline;

  /// Gradasi tombol & header: biru laut pekat agar teks putih terbaca jelas.
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0A64A8), Color(0xFF08548E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Gradasi atas layar: dari biru langit #D6ECFA ke latar #F1F8FD (±340 px)
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFFD6ECFA), bg],
    stops: [0.0, 0.38],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [surface, Color(0xFFF6FAFD)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxDecoration glassDecoration({double opacity = 0.08}) {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: outline, width: 1),
      boxShadow: cardShadow,
    );
  }

  /// Warna tint transparan dari sebuah warna (untuk chip/ikon).
  static Color tint(Color c, [double alpha = 0.10]) => c.withValues(alpha: alpha);

  /// Tema utama aplikasi (Tema Terang "Laut & Langit")
  static ThemeData get lightTheme {
    final baseText = ThemeData(brightness: Brightness.light).textTheme;
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(baseText)
        .apply(bodyColor: text, displayColor: text)
        .copyWith(
          headlineSmall: GoogleFonts.plusJakartaSans(
              fontSize: 24, fontWeight: FontWeight.w700, color: text, height: 1.25),
          titleLarge: GoogleFonts.plusJakartaSans(
              fontSize: 20, fontWeight: FontWeight.w700, color: text, height: 1.3),
          titleMedium: GoogleFonts.plusJakartaSans(
              fontSize: 16, fontWeight: FontWeight.w600, color: text, height: 1.35),
          titleSmall: GoogleFonts.plusJakartaSans(
              fontSize: 14, fontWeight: FontWeight.w600, color: textMuted),
          bodyLarge: GoogleFonts.plusJakartaSans(
              fontSize: 16, fontWeight: FontWeight.w400, color: text, height: 1.5),
          bodyMedium: GoogleFonts.plusJakartaSans(
              fontSize: 14, fontWeight: FontWeight.w400, color: textMuted, height: 1.5),
          bodySmall: GoogleFonts.plusJakartaSans(
              fontSize: 12, fontWeight: FontWeight.w400, color: textFaint, height: 1.4),
          labelLarge: GoogleFonts.plusJakartaSans(
              fontSize: 15, fontWeight: FontWeight.w600, color: text),
        );

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c, width: w),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      colorScheme: const ColorScheme.light(
        primary: accent,
        onPrimary: Colors.white,
        secondary: Color(0xFF3F9FD0),
        onSecondary: Colors.white,
        surface: surface,
        onSurface: text,
        error: error,
        onError: Colors.white,
        outline: outline,
      ),
      textTheme: textTheme,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: AppPageTransitionsBuilder(),
          TargetPlatform.iOS: AppPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: text),
        iconTheme: const IconThemeData(color: text),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: bg,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      ),
      dividerTheme: const DividerThemeData(color: outline, thickness: 1, space: 1),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryDeep,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          elevation: 0,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          minimumSize: const Size(48, 44),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceRaised,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: border(outline),
        enabledBorder: border(outline),
        focusedBorder: border(accent, 1.8),
        errorBorder: border(error),
        focusedErrorBorder: border(error, 1.8),
        hintStyle: textTheme.bodyMedium?.copyWith(color: textFaint),
        labelStyle: textTheme.bodyMedium,
        floatingLabelStyle:
            textTheme.bodyMedium?.copyWith(color: accent, fontWeight: FontWeight.w600),
        errorStyle: textTheme.bodySmall?.copyWith(color: error),
        prefixIconColor: textFaint,
        suffixIconColor: textFaint,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: outline),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(color: text),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: textMuted),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: outline,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryDeep,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: accent),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: accent,
        selectionHandleColor: accent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF0B2A40),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor: const Color(0xFF8FD0FF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }

  /// Alias darkTheme mengarah ke lightTheme agar layar yang masih memanggil darkTheme
  /// otomatis ikut berganti ke tema terang yang konsisten.
  static ThemeData get darkTheme => lightTheme;
}
