import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../theme/app_theme.dart';
import '../models/user_session.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import 'dashboard_screen.dart';

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
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;



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
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
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
      role = await SupabaseService.fetchUserRole(uid);
      // Untuk login (bukan register), ambil profil lengkap
      if (!_isRegisterMode) {
        try {
          final profile = await SupabaseService.adminGetAllUsers()
              .then((users) => users.firstWhere((u) => u['id'] == uid, orElse: () => {}));
          if (profile.isNotEmpty) {
            nama = (profile['nama'] as String?) ?? nama;
            puskesmas = (profile['puskesmas'] as String?) ?? '';
            email = (profile['email'] as String?) ?? '';
          }
        } catch (_) {}
      }
    }

    final session = UserSession(
      userId: uid,
      email: email,
      nama: nama,
      puskesmas: puskesmas,
      bulan: '',
      tahun: '',
      role: role,
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
  }

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
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
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
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
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
            Icon(Icons.lock_reset_rounded, color: AppTheme.accentTeal, size: 24),
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
                prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.accentTeal),
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
              const Icon(Icons.dialpad_rounded, color: AppTheme.accentTeal, size: 24),
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
                Icon(Icons.password_rounded, color: AppTheme.accentTeal, size: 24),
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
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.accentTeal),
                    suffixIcon: IconButton(
                      onPressed: () => setDialogState(() => obscure = !obscure),
                      icon: Icon(
                        obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App Icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accentTeal.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.home_work_rounded, color: Colors.white, size: 40),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Laporan Kunjungan',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isRegisterMode ? 'Buat akun baru' : 'Masuk ke akun Anda',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 32),

                      // Error Message
                      if (_errorMessage != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: AppTheme.error, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: AppTheme.error, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Form Card
                      Container(
                        decoration: AppTheme.glassDecoration(opacity: 0.06),
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // === USERNAME (selalu tampil) ===
                              _buildLabel(_isRegisterMode ? 'Username' : 'Username atau Email'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _usernameController,
                                keyboardType: TextInputType.text,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  hintText: _isRegisterMode ? 'Buat username unik' : 'Masukkan username atau email',
                                  prefixIcon: const Icon(Icons.person_outline_rounded, color: AppTheme.accentTeal),
                                ),
                                style: const TextStyle(color: AppTheme.textPrimary),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return _isRegisterMode ? 'Username wajib diisi' : 'Username/Email wajib diisi';
                                  }
                                  if (_isRegisterMode) {
                                    if (v.trim().length < 3) return 'Username minimal 3 karakter';
                                    if (v.contains(' ')) return 'Username tidak boleh mengandung spasi';
                                    if (v.contains('@')) return 'Username tidak boleh mengandung @';
                                  }
                                  return null;
                                },
                              ),

                              // === EMAIL (hanya saat Register) ===
                              if (_isRegisterMode) ...[
                                const SizedBox(height: 16),
                                _buildLabel('Email'),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    hintText: 'contoh@email.com',
                                    prefixIcon: Icon(Icons.email_outlined, color: AppTheme.accentTeal),
                                  ),
                                  style: const TextStyle(color: AppTheme.textPrimary),
                                  validator: _isRegisterMode
                                      ? (v) {
                                          if (v == null || v.trim().isEmpty) return 'Email wajib diisi';
                                          if (!v.contains('@')) return 'Email tidak valid';
                                          return null;
                                        }
                                      : null,
                                ),
                              ],
                              const SizedBox(height: 16),

                              // === PASSWORD ===
                              _buildLabel('Password'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  hintText: 'Minimal 6 karakter',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.accentTeal),
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                      color: AppTheme.textHint,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                style: const TextStyle(color: AppTheme.textPrimary),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Password wajib diisi';
                                  if (v.length < 6) return 'Password minimal 6 karakter';
                                  return null;
                                },
                              ),

                              // === LUPA PASSWORD → Reset via Email ===
                              if (!_isRegisterMode)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: _showResetPasswordDialog,
                                    icon: const Icon(Icons.lock_reset_rounded, color: AppTheme.accentTeal, size: 18),
                                    label: const Text(
                                      'Lupa Password?',
                                      style: TextStyle(
                                        color: AppTheme.accentTeal,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),

                              // === PROFILE FIELDS (hanya Register) ===
                              if (_isRegisterMode) ...[
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(children: [
                                    Expanded(child: Divider(color: AppTheme.divider)),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 12),
                                      child: Text('Data Profil', style: TextStyle(color: AppTheme.textHint, fontSize: 12)),
                                    ),
                                    Expanded(child: Divider(color: AppTheme.divider)),
                                  ]),
                                ),
                                const SizedBox(height: 8),

                                _buildLabel('Nama Kader / Petugas'),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _namaController,
                                  decoration: const InputDecoration(
                                    hintText: 'Masukkan nama Anda',
                                    prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.accentTeal),
                                  ),
                                  style: const TextStyle(color: AppTheme.textPrimary),
                                  validator: _isRegisterMode
                                      ? (v) => v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null
                                      : null,
                                ),
                                const SizedBox(height: 16),

                                _buildLabel('Nama Puskesmas'),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _puskesmasController,
                                  decoration: const InputDecoration(
                                    hintText: 'Contoh: Balas Klumprik',
                                    prefixIcon: Icon(Icons.local_hospital_outlined, color: AppTheme.accentTeal),
                                  ),
                                  style: const TextStyle(color: AppTheme.textPrimary),
                                  validator: _isRegisterMode
                                      ? (v) => v == null || v.trim().isEmpty ? 'Puskesmas wajib diisi' : null
                                      : null,
                                ),
                              ],
                              const SizedBox(height: 28),

                              // Login/Register button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Ink(
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.primaryGradient,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Container(
                                      alignment: Alignment.center,
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  _isRegisterMode ? Icons.person_add_rounded : Icons.login_rounded,
                                                  color: Colors.white,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  _isRegisterMode ? 'Daftar' : 'Masuk',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Toggle Register/Login
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isRegisterMode ? 'Sudah punya akun?' : 'Belum punya akun?',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              _isRegisterMode = !_isRegisterMode;
                              _errorMessage = null;
                            }),
                            child: Text(
                              _isRegisterMode ? 'Masuk' : 'Daftar',
                              style: const TextStyle(
                                color: AppTheme.accentTeal,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_done_rounded, size: 16, color: AppTheme.textHint),
                          const SizedBox(width: 6),
                          Text(
                            'Data tersimpan di cloud & lokal',
                            style: TextStyle(color: AppTheme.textHint, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
