import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/user_session.dart';
import '../models/custom_role.dart';
import '../services/supabase_service.dart';
import '../services/storage_service.dart';
import 'dashboard_screen.dart';

/// Layar untuk melengkapi profil setelah Google Sign-In pertama kali.
/// Meminta nama kader dan nama puskesmas — tidak dibuat secara acak.
class GoogleProfileSetupScreen extends StatefulWidget {
  final String email;
  final String googleName; // Nama dari akun Google sebagai placeholder

  const GoogleProfileSetupScreen({
    super.key,
    required this.email,
    required this.googleName,
  });

  @override
  State<GoogleProfileSetupScreen> createState() => _GoogleProfileSetupScreenState();
}

class _GoogleProfileSetupScreenState extends State<GoogleProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _namaController;
  final _puskesmasController = TextEditingController();

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Pra-isi dengan nama Google sebagai saran, bukan paksa
    _namaController = TextEditingController(text: widget.googleName);

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _puskesmasController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final nama = _namaController.text.trim();
    final puskesmas = _puskesmasController.text.trim();

    final error = await SupabaseService.saveGoogleProfile(
      nama: nama,
      puskesmas: puskesmas,
    );

    if (error != null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = error;
        });
      }
      return;
    }

    // Fetch role + custom role dari server
    final uid = SupabaseService.currentUserId ?? '';
    final profile = uid.isNotEmpty
        ? await SupabaseService.fetchUserProfile(uid)
        : {'role': 'user', 'customRoleMap': null};
    final role = profile['role'] as String;
    final crMap = profile['customRoleMap'] as Map<String, dynamic>?;
    final customRole = crMap != null ? CustomRole.fromMap(crMap) : null;

    final session = UserSession(
      userId: uid,
      email: widget.email,
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
        transitionDuration: const Duration(milliseconds: 400),
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon header
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accentTeal.withValues(alpha: 0.35),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.badge_rounded,
                          color: Colors.white,
                          size: 42,
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'Lengkapi Profil',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Halo ${widget.googleName.isNotEmpty ? widget.googleName.split(' ').first : ''}! Sebelum mulai,\nlengkapi data kader Anda.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Badge Google Account
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4285F4).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFF4285F4).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _GoogleLogo(),
                            const SizedBox(width: 8),
                            Text(
                              widget.email,
                              style: const TextStyle(
                                color: Color(0xFF4285F4),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Error message
                      if (_errorMessage != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.12),
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
                              // Nama kader
                              _buildLabel('Nama Kader / Petugas *'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _namaController,
                                textInputAction: TextInputAction.next,
                                style: const TextStyle(color: AppTheme.textPrimary),
                                decoration: const InputDecoration(
                                  hintText: 'Masukkan nama lengkap Anda',
                                  prefixIcon: Icon(Icons.person_rounded, color: AppTheme.accentTeal),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Nama wajib diisi';
                                  if (v.trim().length < 2) return 'Nama terlalu pendek';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '* Silakan ubah jika nama di atas kurang tepat',
                                style: TextStyle(color: AppTheme.textHint, fontSize: 11),
                              ),

                              const SizedBox(height: 20),

                              // Nama puskesmas
                              _buildLabel('Nama Puskesmas *'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _puskesmasController,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                style: const TextStyle(color: AppTheme.textPrimary),
                                decoration: const InputDecoration(
                                  hintText: 'Contoh: Balas Klumprik',
                                  prefixIcon: Icon(Icons.local_hospital_outlined, color: AppTheme.accentTeal),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Puskesmas wajib diisi';
                                  return null;
                                },
                              ),

                              const SizedBox(height: 28),

                              // Submit button
                              SizedBox(
                                width: double.infinity,
                                height: 54,
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
                                          : const Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                                                SizedBox(width: 10),
                                                Text(
                                                  'Simpan & Masuk',
                                                  style: TextStyle(
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

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

/// Widget ikon Google sederhana menggunakan huruf "G" berwarna
class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final textSpan = TextSpan(
      text: 'G',
      style: TextStyle(
        color: const Color(0xFF4285F4),
        fontSize: size.width * 0.85,
        fontWeight: FontWeight.w700,
      ),
    );
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
