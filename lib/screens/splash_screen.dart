import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Lottie animation controller - plays ONCE first
  late AnimationController _lottieCtrl;
  // Text entry animations - starts AFTER Lottie finishes
  late AnimationController _textCtrl;
  // Exit animation
  late AnimationController _exitCtrl;

  late Animation<double> _titleFade;
  late Animation<double> _titleScale;
  late Animation<double> _titleRise;
  late Animation<double> _subFade;
  late Animation<double> _subScale;
  late Animation<double> _subRise;
  late Animation<double> _lineFade;
  late Animation<double> _lineW;
  late Animation<double> _loaderFade;
  late Animation<double> _bottomFade;
  late Animation<double> _exitFade;
  late Animation<double> _exitSlide;

  bool _navigated = false;
  bool _lottieFinished = false;

  @override
  void initState() {
    super.initState();

    // ── Lottie controller: plays once at a comfortable pace ──
    _lottieCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    // Listen for Lottie animation completion → then start text animations
    _lottieCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_lottieFinished) {
        _lottieFinished = true;
        // Small pause after Lottie finishes, then show text
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _textCtrl.forward();
        });
      }
    });

    // ── Text stagger (starts AFTER Lottie finishes) ──
    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));

    _titleFade = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _textCtrl,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOut)));
    _titleScale = Tween(begin: 0.6, end: 1.0).animate(CurvedAnimation(
        parent: _textCtrl,
        curve: const Interval(0.0, 0.30, curve: Curves.easeOutBack)));
    _titleRise = Tween(begin: 20.0, end: 0.0).animate(CurvedAnimation(
        parent: _textCtrl,
        curve: const Interval(0.0, 0.30, curve: Curves.easeOutCubic)));

    _subFade = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _textCtrl,
        curve: const Interval(0.15, 0.40, curve: Curves.easeOut)));
    _subScale = Tween(begin: 0.7, end: 1.0).animate(CurvedAnimation(
        parent: _textCtrl,
        curve: const Interval(0.15, 0.45, curve: Curves.easeOutBack)));
    _subRise = Tween(begin: 15.0, end: 0.0).animate(CurvedAnimation(
        parent: _textCtrl,
        curve: const Interval(0.15, 0.45, curve: Curves.easeOutCubic)));

    _lineFade = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _textCtrl,
        curve: const Interval(0.30, 0.50, curve: Curves.easeOut)));
    _lineW = Tween(begin: 0.0, end: 80.0).animate(CurvedAnimation(
        parent: _textCtrl,
        curve: const Interval(0.30, 0.55, curve: Curves.elasticOut)));

    _loaderFade = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _textCtrl,
        curve: const Interval(0.50, 0.70, curve: Curves.easeOut)));
    _bottomFade = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _textCtrl,
        curve: const Interval(0.60, 0.80, curve: Curves.easeOut)));

    // ── Exit ──
    _exitCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _exitFade = Tween(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn));
    _exitSlide = Tween(begin: 0.0, end: -40.0).animate(
        CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInCubic));

    // Start Lottie playing ONCE (forward only, no repeat)
    _lottieCtrl.forward();

    _checkSession();
  }

  Future<void> _checkSession() async {
    // Wait for Lottie + text animations to play fully
    await Future.delayed(const Duration(milliseconds: 6500));
    if (!mounted || _navigated) return;
    _navigated = true;

    final session = await StorageService.getSession();
    if (!mounted) return;

    final destination = session != null
        ? DashboardScreen(session: session)
        : const LoginScreen();

    await _exitCtrl.forward();
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _lottieCtrl.dispose();
    _textCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_textCtrl, _exitCtrl, _lottieCtrl]),
        builder: (context, _) {
          return Opacity(
            opacity: _exitFade.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, _exitSlide.value),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.2),
                    radius: 1.3,
                    colors: [
                      Color(0xFF132742),
                      Color(0xFF0D1B2A),
                      Color(0xFF070F1A),
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
                child: Stack(
                  children: [
                    // ═══ Main content - CENTERED ═══
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // ── LOTTIE ANIMATION (centered, plays once) ──
                            SizedBox(
                              width: 220,
                              height: 220,
                              child: Lottie.asset(
                                'assets/hospital.json',
                                controller: _lottieCtrl,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildFallbackIcon();
                                },
                              ),
                            ),

                            const SizedBox(height: 32),

                            // ── TITLE (appears after Lottie finishes) ──
                            Transform.translate(
                              offset: Offset(0, _titleRise.value),
                              child: Transform.scale(
                                scale: _titleScale.value,
                                child: Opacity(
                                  opacity: _titleFade.value.clamp(0.0, 1.0),
                                  child: const Text(
                                    'Laporan Kunjungan',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // ── SUBTITLE ──
                            Transform.translate(
                              offset: Offset(0, _subRise.value),
                              child: Transform.scale(
                                scale: _subScale.value,
                                child: Opacity(
                                  opacity: _subFade.value.clamp(0.0, 1.0),
                                  child: const Text(
                                    'K U N J U N G A N   R U M A H',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w300,
                                      letterSpacing: 4,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // ── EXPANDING LINE ──
                            Opacity(
                              opacity: _lineFade.value.clamp(0.0, 1.0),
                              child: Container(
                                width: _lineW.value,
                                height: 3,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      AppTheme.accentTeal,
                                      AppTheme.accentBlue,
                                      Colors.transparent,
                                    ],
                                    stops: [0.0, 0.3, 0.7, 1.0],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 50),

                            // ── LOADER ──
                            Opacity(
                              opacity: _loaderFade.value.clamp(0.0, 1.0),
                              child: const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  color: AppTheme.accentTeal,
                                  strokeWidth: 2.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ═══ Bottom text ═══
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 36,
                      child: Opacity(
                        opacity: _bottomFade.value.clamp(0.0, 1.0),
                        child: const Column(
                          children: [
                            Text('Puskesmas Kunjungan Rumah',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: AppTheme.textHint,
                                    fontSize: 11,
                                    letterSpacing: 1)),
                            SizedBox(height: 4),
                            Text('v2.3',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: AppTheme.textHint, fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFallbackIcon() {
    return Container(
      width: 116,
      height: 116,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [Color(0xFF00E5CC), Color(0xFF00BFA6), Color(0xFF448AFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(Icons.home_work_rounded, color: Colors.white, size: 52),
    );
  }
}
