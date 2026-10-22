import 'package:flutter/material.dart';
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
  static const Color bg = Color(0xFF0F1A1E);
  static const Color surface = Color(0xFF162329);
  static const Color surfaceRaised = Color(0xFF1D2D34);
  static const Color outline = Color(0xFF2A3B43);

  // ── Aksen ──────────────────────────────────────────────────
  /// Teal terang: untuk ikon, tautan, indikator di atas latar gelap (kontras ≥ 7:1).
  static const Color accent = Color(0xFF4CC9AE);

  /// Teal dalam: untuk tombol terisi. Teks putih di atasnya = kontras 4.9:1 (lulus AA).
  static const Color primaryDeep = Color(0xFF0B7F6C);

  // ── Teks ───────────────────────────────────────────────────
  static const Color text = Color(0xFFEAF1F0); // 14:1
  static const Color textMuted = Color(0xFFA9B8BC); // 7.9:1
  static const Color textFaint = Color(0xFF8FA2AB); // 6:1 (dulu 3.2:1 — gagal AA)

  // ── Status ─────────────────────────────────────────────────
  static const Color success = Color(0xFF5FCB8A);
  static const Color warning = Color(0xFFF2B35E);
  static const Color error = Color(0xFFFF8A80);
  static const Color info = Color(0xFF7AA7FF);

  // ── Alias nama lama (JANGAN dihapus sampai semua layar dimigrasi) ──
  static const Color primaryDark = bg;
  static const Color secondaryDark = Color(0xFF131F24);
  static const Color cardDark = surface;
  static const Color surfaceDark = surfaceRaised;
  static const Color accentTeal = accent;
  static const Color accentBlue = info;
  static const Color accentPurple = Color(0xFFA99CFF);
  static const Color textPrimary = text;
  static const Color textSecondary = textMuted;
  static const Color textHint = textFaint;
  static const Color divider = outline;

  /// Gradasi tombol lama: dibuat nyaris datar & cukup gelap agar teks putih terbaca.
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0B8470), Color(0xFF0A7566)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [bg, Color(0xFF0C161A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [surface, Color(0xFF132026)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxDecoration glassDecoration({double opacity = 0.08}) {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: outline, width: 1),
    );
  }

  /// Warna tint transparan dari sebuah warna (untuk chip/ikon).
  static Color tint(Color c, [double alpha = 0.14]) => c.withValues(alpha: alpha);

  static ThemeData get darkTheme {
    final baseText = ThemeData(brightness: Brightness.dark).textTheme;
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
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        onPrimary: Color(0xFF06241E),
        secondary: info,
        onSecondary: Colors.white,
        surface: surface,
        onSurface: text,
        error: error,
        onError: Color(0xFF3A0B07),
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
        titleTextStyle: textTheme.titleLarge,
        iconTheme: const IconThemeData(color: text),
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
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
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
        backgroundColor: surfaceRaised,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: text),
        actionTextColor: accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}
