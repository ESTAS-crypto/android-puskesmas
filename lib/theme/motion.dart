import 'package:flutter/material.dart';

/// Satu sumber kebenaran untuk durasi & kurva animasi.
/// Semua animasi di app memakai nilai ini supaya terasa konsisten.
class AppMotion {
  AppMotion._();

  // Durasi
  static const Duration instant = Duration(milliseconds: 100); // feedback sentuh
  static const Duration fast = Duration(milliseconds: 180); // hover, toggle, switch kecil
  static const Duration medium = Duration(milliseconds: 300); // expand, kartu, sheet
  static const Duration slow = Duration(milliseconds: 520); // masuk layar, angka naik

  // Kurva (Material 3)
  static const Curve standard = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve decelerate = Cubic(0.05, 0.7, 0.1, 1.0); // elemen MASUK
  static const Curve accelerate = Cubic(0.3, 0.0, 0.8, 0.15); // elemen KELUAR

  /// True jika pengguna mematikan animasi di pengaturan aksesibilitas HP.
  static bool reduced(BuildContext context) =>
      MediaQuery.of(context).disableAnimations;

  /// Durasi yang menghormati pengaturan "kurangi animasi".
  static Duration of(BuildContext context, Duration base) =>
      reduced(context) ? Duration.zero : base;
}

/// Transisi antar-layar: halaman baru memudar + bergeser sedikit dari kanan,
/// halaman lama bergeser pelan ke kiri (parallax). Dipasang lewat
/// ThemeData.pageTransitionsTheme sehingga SEMUA MaterialPageRoute ikut halus.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.of(context).disableAnimations) return child;

    final incoming = CurvedAnimation(
      parent: animation,
      curve: AppMotion.decelerate,
      reverseCurve: AppMotion.accelerate,
    );
    final outgoing = CurvedAnimation(
      parent: secondaryAnimation,
      curve: AppMotion.standard,
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.05, 0),
      ).animate(outgoing),
      child: FadeTransition(
        opacity: incoming,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.07, 0),
            end: Offset.zero,
          ).animate(incoming),
          child: child,
        ),
      ),
    );
  }
}
