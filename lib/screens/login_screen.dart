import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../widgets/ui/ui.dart';
import '../models/user_session.dart';
import '../models/custom_role.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import 'dashboard_screen.dart';
import 'google_profile_setup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _namaController = TextEditingController();
  final _puskesmasController = TextEditingController();

  late AnimationController _animController;



  bool _isLoading = false;
  bool _isRegisterMode = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  int _loginAttempts = 0;
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _animController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _namaController.dispose();
    _puskesmasController.dispose();
    super.dispose();
  }

  /// Proses login menggunakan akun Google.
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await SupabaseService.signInWithGoogle();

    if (!mounted) return;

    final error = result['error'] as String?;
    if (error != null) {
      // Login dibatalkan adalah bukan error yang perlu ditampilkan
      if (!error.contains('dibatalkan')) {
        setState(() {
          _isLoading = false;
          _errorMessage = error;
        });
      } else {
        setState(() => _isLoading = false);
      }
      return;
    }

    final isNewUser = result['isNewUser'] as bool? ?? true;
    final email = result['email'] as String? ?? '';
    final googleName = result['googleName'] as String? ?? '';

    if (isNewUser) {
      // Pengguna baru → minta nama kader & puskesmas dulu
      setState(() => _isLoading = false);
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => GoogleProfileSetupScreen(
            email: email,
            googleName: googleName,
          ),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } else {
      // Pengguna lama → langsung ke dashboard
      final uid = SupabaseService.currentUserId ?? '';
      final profile = uid.isNotEmpty
          ? await SupabaseService.fetchUserProfile(uid)
          : {'role': 'user', 'customRoleMap': null};
      final role = profile['role'] as String;
      final crMap = profile['customRoleMap'] as Map<String, dynamic>?;
      final customRole = crMap != null ? CustomRole.fromMap(crMap) : null;
      final nama = result['existingNama'] as String? ?? googleName;
      final puskesmas = result['existingPuskesmas'] as String? ?? '';

      final session = UserSession(
        userId: uid,
        email: email,
        nama: nama,
        puskesmas: puskesmas,
        bulan: '',
        tahun: '',
        role: role,
        customRole: customRole,
      );

      await StorageService.saveSession(session);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => DashboardScreen(session: session),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cooldownSeconds > 0) {
      setState(() => _errorMessage = 'Tunggu $_cooldownSeconds detik sebelum mencoba lagi.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    String? error;

    if (_isRegisterMode) {
      // Step 1: Register (buat akun di Supabase)
      error = await SupabaseService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        username: _usernameController.text.trim(),
      );

      if (error != null) {
        setState(() { _isLoading = false; _errorMessage = error; });
        return;
      }

      setState(() => _isLoading = false);
      _showSuccessSnackBar('Kode OTP telah dikirim ke email Anda!');

      // Step 2: Minta OTP konfirmasi email
      final otp = await _requestOtpDialog(_emailController.text.trim(), otpLength: 8);
      if (otp == null || otp.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      setState(() => _isLoading = true);

      // Step 3: Verifikasi OTP + simpan profil
      error = await SupabaseService.verifySignupOtp(
        email: _emailController.text.trim(),
        otp: otp,
        username: _usernameController.text.trim(),
        nama: _namaController.text.trim(),
        puskesmas: _puskesmasController.text.trim(),
      );
    } else {
      // Login dengan username ATAU email
      error = await SupabaseService.signIn(
        _usernameController.text.trim(),
        _passwordController.text.trim(),
      );
    }

    if (error != null) {
      _loginAttempts++;
      if (_loginAttempts >= 3) {
        _startCooldown();
      }
      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
      return;
    }

    // Login berhasil — reset counter
    _loginAttempts = 0;

    // Login berhasil — ambil profil + role dari cloud
    final uid = SupabaseService.currentUserId ?? '';
    String role = 'user';
    String nama = _isRegisterMode ? _namaController.text.trim() : _usernameController.text.trim();
    String puskesmas = _isRegisterMode ? _puskesmasController.text.trim() : '';
    String email = _isRegisterMode ? _emailController.text.trim() : '';

    if (uid.isNotEmpty) {
      final profile = await SupabaseService.fetchUserProfile(uid);
      role = profile['role'] as String;
      final crMap = profile['customRoleMap'] as Map<String, dynamic>?;
      // Untuk login (bukan register), ambil profil lengkap
      if (!_isRegisterMode) {
        try {
          final users = await SupabaseService.adminGetAllUsers();
          final userProfile = users.firstWhere((u) => u['id'] == uid, orElse: () => {});
          if (userProfile.isNotEmpty) {
            nama = (userProfile['nama'] as String?) ?? nama;
            puskesmas = (userProfile['puskesmas'] as String?) ?? '';
            email = (userProfile['email'] as String?) ?? '';
          }
        } catch (_) {}
      }
      final crMapFinal = crMap;
      final customRoleObj = crMapFinal != null ? CustomRole.fromMap(crMapFinal) : null;

      final session = UserSession(
        userId: uid,
        email: email,
        nama: nama,
        puskesmas: puskesmas,
        bulan: '',
        tahun: '',
        role: role,
        customRole: customRoleObj,
      );

      await StorageService.saveSession(session);

      // Download data dari cloud (jika login di device baru)
      final cloudReports = await SupabaseService.downloadFromCloud();
      if (cloudReports.isNotEmpty) {
        final localReports = await StorageService.getReports();
        final localIds = localReports.map((r) => r.id).toSet();
        for (final report in cloudReports) {
          if (!localIds.contains(report.id)) {
            await StorageService.saveReportLocalOnly(report);
          }
        }
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => DashboardScreen(session: session),
          transitionsBuilder: (_, anim, __, child) {
            return FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
      return;
    }
  } // end _submit

  void _startCooldown() {
    _cooldownSeconds = 30;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() => _cooldownSeconds--);
      if (_cooldownSeconds <= 0) {
        timer.cancel();
        _loginAttempts = 0;
      }
    });
  }

  Future<void> _showResetPasswordDialog() async {
    // Step 1: Minta Email
    final email = await _requestEmailDialog();
    if (email == null || email.isEmpty) return;

    setState(() => _isLoading = true);
    final error1 = await SupabaseService.resetPassword(email);
    setState(() => _isLoading = false);

    if (!mounted) return;
    if (error1 != null) {
      _showErrorSnackBar(error1);
      return;
    }

    _showSuccessSnackBar('Kode OTP telah dikirim ke email Anda!');

    // Step 2: Minta OTP
    final otp = await _requestOtpDialog(email, otpLength: 8);
    if (otp == null || otp.isEmpty) return;

    setState(() => _isLoading = true);
    final error2 = await SupabaseService.verifyResetOtp(email, otp);
    setState(() => _isLoading = false);

    if (!mounted) return;
    if (error2 != null) {
      _showErrorSnackBar(error2);
      return;
    }

    // Step 3: Minta Password Baru
    final newPassword = await _requestNewPasswordDialog();
    if (newPassword == null || newPassword.isEmpty) return;

    setState(() => _isLoading = true);
    final error3 = await SupabaseService.updatePassword(newPassword);
    setState(() => _isLoading = false);

    if (!mounted) return;
    if (error3 != null) {
      _showErrorSnackBar(error3);
      return;
    }

    _showSuccessSnackBar('Password berhasil diubah! Silakan login dengan password baru.');
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const AppIcon(AppGlyph.check, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF1B5E20),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const AppIcon(AppGlyph.warning, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<String?> _requestEmailDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            AppIcon(AppGlyph.lock, color: AppTheme.accentTeal, size: 24),
            SizedBox(width: 10),
            Text('Reset Password', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan email Anda. Kami akan mengirimkan kode OTP 6-angka.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'contoh@email.com',
                prefixIcon: const AppIcon(AppGlyph.mail, color: AppTheme.accentTeal),
                filled: true,
                fillColor: AppTheme.surfaceDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppTheme.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppTheme.divider),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentTeal,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Kirim Kode', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<String?> _requestOtpDialog(String email, {int otpLength = 8}) async {
    String otpValue = '';
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        // Hitung lebar layar untuk menyesuaikan lebar kotak pin code
        final screenWidth = MediaQuery.of(ctx).size.width;
        // AlertDialog padding kiri-kanan default biasanya 40 + konten padding 24
        final availableWidth = screenWidth - 128; 
        final maxFieldWidth = availableWidth / otpLength;
        // Jarak antar pin default ~5px. clamp membatasi ukuran layar sangat kecil atau sangat besar.
        final calculatedFieldWidth = (maxFieldWidth - 6).clamp(24.0, 45.0);
        final calculatedFieldHeight = (calculatedFieldWidth * 1.3).clamp(36.0, 56.0);

        return AlertDialog(
          backgroundColor: AppTheme.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const AppIcon(AppGlyph.lock, color: AppTheme.accentTeal, size: 24),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Verifikasi OTP', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Masukkan kode OTP $otpLength angka yang dikirim ke:\n$email',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),
                PinCodeTextField(
                  appContext: ctx,
                  length: otpLength,
                  onChanged: (value) => otpValue = value,
                  onCompleted: (value) {
                    Navigator.pop(ctx, value);
                  },
                  autoFocus: true,
                  keyboardType: TextInputType.number,
                  animationType: AnimationType.scale,
                  animationDuration: const Duration(milliseconds: 200),
                  enableActiveFill: true,
                  textStyle: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(10),
                    fieldHeight: calculatedFieldHeight,
                    fieldWidth: calculatedFieldWidth,
                    activeFillColor: AppTheme.surfaceDark,
                    inactiveFillColor: AppTheme.surfaceDark,
                    selectedFillColor: AppTheme.surfaceDark,
                    activeColor: AppTheme.accentTeal,
                    inactiveColor: AppTheme.divider,
                    selectedColor: AppTheme.accentTeal,
                  ),
                ),
              ],
            ),
          ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, otpValue),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentTeal,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Verifikasi', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    });
  }

  Future<String?> _requestNewPasswordDialog() async {
    final controller = TextEditingController();
    bool obscure = true;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder( // Butuh StatefulBuilder untuk toggle mata password di dialog
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.cardDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                AppIcon(AppGlyph.lock, color: AppTheme.accentTeal, size: 24),
                SizedBox(width: 10),
                Text('Password Baru', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Masukkan password baru Anda (minimal 6 karakter).',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  obscureText: obscure,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Password minimal 6 karakter',
                    prefixIcon: const AppIcon(AppGlyph.lock, color: AppTheme.accentTeal),
                    suffixIcon: IconButton(
                      onPressed: () => setDialogState(() => obscure = !obscure),
                      icon: AppIcon(
                        obscure ? AppGlyph.eyeOff : AppGlyph.eye,
                        color: AppTheme.textHint,
                        size: 20,
                      ),
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppTheme.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppTheme.divider),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentTeal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Simpan', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }

  /// Bagian form yang muncul/hilang dengan tinggi & pudar yang halus.
  Widget _reveal({required bool show, required Widget child}) {
    return AnimatedSize(
      duration: AppMotion.medium,
      curve: AppMotion.standard,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: AppMotion.medium,
        switchInCurve: AppMotion.decelerate,
        switchOutCurve: AppMotion.accelerate,
        transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, if (current != null) current],
        ),
        child: show
            ? KeyedSubtree(key: const ValueKey('shown'), child: child)
            : const SizedBox(key: ValueKey('hidden'), width: double.infinity),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    var i = 0;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Brand ──
                  StaggerIn(
                    animation: _animController,
                    index: i++,
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryDeep,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                          child: const AppIcon(AppGlyph.home,
                              color: Colors.white, size: 32),
                        ),
                        const SizedBox(height: 20),
                        Text('Laporan Kunjungan', style: t.headlineSmall),
                        const SizedBox(height: 6),
                        AnimatedSwitcher(
                          duration: AppMotion.fast,
                          child: Text(
                            _isRegisterMode
                                ? 'Buat akun untuk mulai mencatat'
                                : 'Masuk untuk melanjutkan',
                            key: ValueKey(_isRegisterMode),
                            style: t.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Pesan galat (live region: dibacakan TalkBack) ──
                  AnimatedSize(
                    duration: AppMotion.medium,
                    curve: AppMotion.standard,
                    alignment: Alignment.topCenter,
                    child: AnimatedSwitcher(
                      duration: AppMotion.fast,
                      child: _errorMessage == null
                          ? const SizedBox(
                              key: ValueKey('no-error'), width: double.infinity)
                          : Semantics(
                              liveRegion: true,
                              key: ValueKey(_errorMessage),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppTheme.tint(AppTheme.error, 0.12),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                  border: Border.all(
                                      color:
                                          AppTheme.tint(AppTheme.error, 0.4)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const AppIcon(AppGlyph.warning,
                                        color: AppTheme.error, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: t.bodyMedium
                                            ?.copyWith(color: AppTheme.error),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ),

                  // ── Form ──
                  StaggerIn(
                    animation: _animController,
                    index: i++,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _usernameController,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: _isRegisterMode
                                  ? 'Username'
                                  : 'Username atau email',
                              hintText: _isRegisterMode
                                  ? 'Buat username unik'
                                  : null,
                              prefixIcon:
                                  const AppIcon(AppGlyph.patient),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return _isRegisterMode
                                    ? 'Username wajib diisi'
                                    : 'Username/Email wajib diisi';
                              }
                              if (_isRegisterMode) {
                                if (v.trim().length < 3) return 'Username minimal 3 karakter';
                                if (v.contains(' ')) return 'Username tidak boleh mengandung spasi';
                                if (v.contains('@')) return 'Username tidak boleh mengandung @';
                              }
                              return null;
                            },
                          ),

                          _reveal(
                            show: _isRegisterMode,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  hintText: 'contoh@email.com',
                                  prefixIcon: AppIcon(AppGlyph.mail),
                                ),
                                validator: _isRegisterMode
                                    ? (v) {
                                        if (v == null || v.trim().isEmpty) return 'Email wajib diisi';
                                        if (!v.contains('@')) return 'Email tidak valid';
                                        return null;
                                      }
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: _isRegisterMode
                                ? TextInputAction.next
                                : TextInputAction.done,
                            onFieldSubmitted: (_) {
                              if (!_isRegisterMode && !_isLoading) _submit();
                            },
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'Minimal 6 karakter',
                              prefixIcon: const AppIcon(AppGlyph.lock),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Tampilkan password'
                                    : 'Sembunyikan password',
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                                icon: AnimatedSwitcher(
                                  duration: AppMotion.fast,
                                  child: AppIcon(_obscurePassword ? AppGlyph.eyeOff : AppGlyph.eye,
                                    key: ValueKey(_obscurePassword),
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Password wajib diisi';
                              if (v.length < 6) return 'Password minimal 6 karakter';
                              return null;
                            },
                          ),

                          // Lupa password (hanya mode masuk)
                          _reveal(
                            show: !_isRegisterMode,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _showResetPasswordDialog,
                                child: const Text('Lupa password?'),
                              ),
                            ),
                          ),

                          // Data profil (hanya mode daftar)
                          _reveal(
                            show: _isRegisterMode,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 20),
                                Text('Data profil', style: t.titleSmall),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _namaController,
                                  textInputAction: TextInputAction.next,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    labelText: 'Nama kader / petugas',
                                    prefixIcon: AppIcon(AppGlyph.idcard),
                                  ),
                                  validator: _isRegisterMode
                                      ? (v) => v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _puskesmasController,
                                  textInputAction: TextInputAction.done,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    labelText: 'Nama Puskesmas',
                                    hintText: 'Contoh: Balas Klumprik',
                                    prefixIcon: AppIcon(AppGlyph.hospital),
                                  ),
                                  validator: _isRegisterMode
                                      ? (v) => v == null || v.trim().isEmpty ? 'Puskesmas wajib diisi' : null
                                      : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          AppButton(
                            label: _isRegisterMode ? 'Daftar' : 'Masuk',
                            icon: _isRegisterMode
                                ? AppGlyph.userAdd
                                : AppGlyph.login,
                            loading: _isLoading,
                            onPressed: _submit,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Google + ganti mode ──
                  StaggerIn(
                    animation: _animController,
                    index: i++,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _reveal(
                          show: !_isRegisterMode,
                          child: Column(
                            children: [
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  const Expanded(child: Divider()),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Text('atau', style: t.bodySmall),
                                  ),
                                  const Expanded(child: Divider()),
                                ],
                              ),
                              const SizedBox(height: 20),
                              AppButton(
                                label: 'Masuk dengan Google',
                                icon: Icons.g_mobiledata_rounded,
                                kind: AppButtonKind.ghost,
                                onPressed: _isLoading ? null : _signInWithGoogle,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isRegisterMode
                                  ? 'Sudah punya akun?'
                                  : 'Belum punya akun?',
                              style: t.bodyMedium,
                            ),
                            TextButton(
                              onPressed: () => setState(() {
                                _isRegisterMode = !_isRegisterMode;
                                _errorMessage = null;
                              }),
                              child: Text(_isRegisterMode ? 'Masuk' : 'Daftar'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const AppIcon(AppGlyph.cloud,
                                size: 16, color: AppTheme.textFaint),
                            const SizedBox(width: 6),
                            Text('Data tersimpan di cloud & di perangkat',
                                style: t.bodySmall),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
