import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../models/custom_role.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../services/update_service.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

/// Splash v2 — 2,8 detik. Lihat storyboard & spesifikasi gerak di prototipe.
///
/// Garis waktu (detik):
///  0.00  Sama dengan splash sistem Android (langit polos + logo di lingkaran putih)
///  0.25–1.00 Logo mengecil, naik, sudut membulat
///  0.45–1.35 Tiga lapis gelombang naik, lalu bergeser pelan terus
///  0.55–1.45 Satu ring denyut
///  0.95–1.76 Judul muncul kata demi kata
///  1.35–2.15 Garis detak jantung digambar
///  2.40–2.80 Memudar ke warna layar berikutnya
///
/// Pemeriksaan login berjalan PARALEL sejak detik 0 (bukan menunggu animasi).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const double _total = 2.8; // detik
  static const _sky = Color(0xFFD6ECFA);
  static const _exitColor = Color(0xFFDCEFFB);

  late final AnimationController _intro = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2800));
  late final AnimationController _drift =
      AnimationController(vsync: this, duration: const Duration(seconds: 20))
        ..repeat();
  late final Future<Widget> _destination = _resolveDestination();
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _run();
  }

  Future<void> _run() async {
    final reduced = AppMotion.reduced(context);
    if (reduced) {
      _intro.value = 2.2 / _total; // tampilkan frame lengkap saja
      await Future.wait([
        Future.delayed(const Duration(milliseconds: 600)),
        _destination,
      ]);
    } else {
      // Animasi merek (min. tampil) + pemeriksaan login berjalan bersamaan.
      await Future.wait([_intro.forward().orCancel, _destination]);
    }
    if (!mounted) return;
    final destination = await _destination;
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: AppMotion.standard),
          child: child,
        ),
        transitionDuration: AppMotion.of(context, AppMotion.medium),
      ),
    );
  }

  Future<Widget> _resolveDestination() async {
    // Cek 1: Apakah Supabase auth session masih aktif?
    // Cek 2: Apakah ada session lokal di SharedPreferences? (offline fallback)
    final localSessionRaw = await StorageService.getSession();
    final isSupabaseLoggedIn = SupabaseService.isLoggedIn;

    if (localSessionRaw != null &&
        (isSupabaseLoggedIn || localSessionRaw.userId.isNotEmpty)) {
      var session = localSessionRaw;
      // Segarkan role dari server (maks. 3 detik) agar perubahan role langsung berlaku.
      if (isSupabaseLoggedIn && session.userId.isNotEmpty) {
        try {
          final freshProfile = await SupabaseService
              .fetchUserProfile(session.userId)
              .timeout(const Duration(seconds: 3));
          final freshRole = freshProfile['role'] as String;
          final crMap = freshProfile['customRoleMap'] as Map<String, dynamic>?;
          final freshCustomRole =
              crMap != null ? CustomRole.fromMap(crMap) : null;

          final roleChanged = freshRole != session.role;
          final crChanged = freshCustomRole?.id != session.customRole?.id;

          if (roleChanged || crChanged) {
            session = session.copyWith(
              role: freshRole,
              customRole: freshCustomRole,
              clearCustomRole: freshCustomRole == null,
            );
            await StorageService.saveSession(session);
            debugPrint('[Splash] Session di-refresh: role=$freshRole');
          }
        } catch (e) {
          debugPrint('[Splash] Gagal refresh session: $e');
        }
      }
      return DashboardScreen(session: session);
    }
    return const LoginScreen();
  }

  @override
  void dispose() {
    _intro.dispose();
    _drift.dispose();
    super.dispose();
  }

  // ── helper animasi ──
  double _seg(double t, double a, double b, [Curve c = AppMotion.decelerate]) =>
      c.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFF0A64A8),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _sky,
        body: LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth, h = box.maxHeight;
          return AnimatedBuilder(
            animation: Listenable.merge([_intro, _drift]),
            builder: (context, _) {
              final t = _intro.value * _total;
              return _scene(w, h, t);
            },
          );
        }),
      ),
    );
  }

  Widget _scene(double w, double h, double t) {
    const std = AppMotion.standard;
    final k = w / 390; // skala dari desain 390 lebar

    // Latar: warna polos → gradasi langit-laut (tanpa saveLayer)
    final g = _seg(t, .2, 1.2, std);
    Color c(Color to) => Color.lerp(_sky, to, g)!;

    // Logo
    final m = _seg(t, .25, 1.0);
    final sz = (160 + (112 - 160) * m) * k;
    final cy = h * (0.5 + (0.338 - 0.5) * m);
    final radius = (80 + (32 - 80) * m) * k;

    // Ring
    final rp = _seg(t, .55, 1.45, std);
    final rs = 112 * k * (1 + .9 * rp);
    final ringAlpha = t > .55 ? .4 * (1 - rp) : 0.0;

    // Matahari & awan
    final sun = _seg(t, .5, 1.4, std);
    final cloud = _seg(t, .7, 1.4, std);

    // Gelombang
    final rise = (260 * (1 - _seg(t, .45, 1.35))) * k;
    final dr = _drift.value * math.pi * 2;

    final tag = _seg(t, 1.45, 1.95, std);
    final ecg = _seg(t, 1.35, 2.15, std);
    final ver = _seg(t, 1.9, 2.3, std);
    final exit = _seg(t, 2.4, 2.8, std);

    Widget word(String s, int i) {
      final p = _seg(t, .95 + i * .09, 1.5);
      return Opacity(
        opacity: p,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - p)),
          child: Text(s,
              style: TextStyle(
                  fontSize: 28 * k.clamp(.85, 1.2),
                  fontWeight: FontWeight.w700,
                  height: 1.22,
                  color: const Color(0xFF0B2A40))),
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  c(const Color(0xFFCBE8FA)),
                  c(const Color(0xFF9ED2F1)),
                  c(const Color(0xFF6FB8E3)),
                ],
                stops: const [0, .52, 1],
              ),
            ),
          ),
        ),
        // Matahari
        Positioned(
          right: 46 * k,
          top: h * .083,
          child: Opacity(
            opacity: sun * .95,
            child: Transform.scale(
              scale: .8 + .2 * sun,
              child: Container(
                width: 74 * k,
                height: 74 * k,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    Color(0xFFFFF3C9),
                    Color(0xFFFFE08A),
                    Color(0x00FFE08A),
                  ], stops: [0, .6, .72]),
                ),
              ),
            ),
          ),
        ),
        // Awan
        Positioned(
          left: 36 * k + t * 9,
          top: h * .133,
          child: Opacity(
            opacity: cloud * .85,
            child: Container(
              width: 110 * k,
              height: 32 * k,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ),
        Positioned(
          left: 236 * k - t * 6,
          top: h * .2,
          child: Opacity(
            opacity: cloud * .7,
            child: Container(
              width: 84 * k,
              height: 26 * k,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ),
        // Gelombang
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _WavePainter(
                t: math.min(t, _total),
                drift: dr,
                rise: rise,
                k: k,
                h: h,
              ),
            ),
          ),
        ),
        // Ring denyut
        Positioned(
          left: w / 2 - rs / 2,
          top: h * .338 - rs / 2,
          child: Container(
            width: rs,
            height: rs,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.primaryDeep.withValues(alpha: ringAlpha),
                width: 3,
              ),
            ),
          ),
        ),
        // Logo
        Positioned(
          left: w / 2 - sz / 2,
          top: cy - sz / 2,
          child: Container(
            width: sz,
            height: sz,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryDeep.withValues(alpha: .22),
                  blurRadius: 34,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: OverflowBox(
              maxWidth: sz * 1.2,
              maxHeight: sz * 1.2,
              // icon.png punya margin putih: perbesar agar logo ±60% kotak
              child: Image.asset('assets/icon.png',
                  width: sz * 1.13, height: sz * 1.13, fit: BoxFit.contain),
            ),
          ),
        ),
        // Judul
        Positioned(
          left: 0,
          right: 0,
          top: h * .44,
          child: Column(
            children: [
              word('Puskesmas', 0),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  word('Kunjungan', 1),
                  const SizedBox(width: 8),
                  word('Rumah', 2),
                ],
              ),
            ],
          ),
        ),
        // Slogan
        Positioned(
          left: 0,
          right: 0,
          top: h * .547,
          child: Opacity(
            opacity: tag,
            child: Transform.translate(
              offset: Offset(0, 8 * (1 - tag)),
              child: const Text(
                'Catat kunjungan, rapi dan mudah',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Color(0xFF0B2A40)),
              ),
            ),
          ),
        ),
        // Garis detak jantung
        Positioned(
          left: w / 2 - 70 * k,
          top: h * .65,
          child: Opacity(
            opacity: math.min(1, ecg * 4),
            child: CustomPaint(
              size: Size(140 * k, 40 * k),
              painter: _EcgPainter(progress: ecg, k: k),
            ),
          ),
        ),
        // Versi
        Positioned(
          left: 0,
          right: 0,
          bottom: 28 + MediaQuery.of(context).padding.bottom,
          child: Opacity(
            opacity: ver,
            child: Text(
              'v${UpdateService.currentVersion}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
          ),
        ),
        // Keluar: pudar ke warna layar berikutnya
        Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(
              color: _exitColor.withValues(alpha: exit),
            ),
          ),
        ),
      ],
    );
  }
}

class _WavePainter extends CustomPainter {
  final double t, drift, rise, k, h;
  _WavePainter(
      {required this.t,
      required this.drift,
      required this.rise,
      required this.k,
      required this.h});

  Path _wave(Size s, double base, double amp, double ph, double r) {
    final p = Path()
      ..moveTo(-10, base + r + amp * math.sin(-10 / s.width * math.pi * 2 + ph));
    for (double x = 0; x <= s.width + 10; x += 8) {
      p.lineTo(x, base + r + amp * math.sin(x / s.width * math.pi * 2 + ph));
    }
    return p
      ..lineTo(s.width + 10, s.height + 10)
      ..lineTo(-10, s.height + 10)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
        _wave(size, h * .758, 16 * k, t * 1.1 + drift * 2, rise),
        Paint()..color = const Color(0xFF7CC3E6));
    canvas.drawPath(
        _wave(size, h * .80, 20 * k, 1 - t * .9 - drift * 3, rise * 1.15),
        Paint()..color = const Color(0xFF3F9FD0));
    canvas.drawPath(
        _wave(size, h * .858, 14 * k, 2 + t * .7 + drift, rise * 1.3),
        Paint()..color = const Color(0xFF0A64A8));
  }

  @override
  bool shouldRepaint(covariant _WavePainter o) =>
      o.t != t || o.drift != drift || o.rise != rise;
}

class _EcgPainter extends CustomPainter {
  final double progress, k;
  _EcgPainter({required this.progress, required this.k});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 20 * k)
      ..lineTo(34 * k, 20 * k)
      ..lineTo(44 * k, 20 * k)
      ..lineTo(52 * k, 4 * k)
      ..lineTo(62 * k, 38 * k)
      ..lineTo(70 * k, 12 * k)
      ..lineTo(76 * k, 20 * k)
      ..lineTo(140 * k, 20 * k);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = const Color(0xFF0A64A8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _EcgPainter o) => o.progress != progress;
}
