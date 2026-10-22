import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/user_session.dart';
import '../models/custom_role.dart';
import '../services/supabase_service.dart';
import '../services/storage_service.dart';
import '../widgets/ui/ui.dart';
import 'dashboard_screen.dart';

/// Layar untuk melengkapi profil setelah Google Sign-In pertama kali.
/// Sesuai spesifikasi mockup Google.dc.html (Fase 7).
class GoogleProfileSetupScreen extends StatefulWidget {
  final String email;
  final String googleName;

  const GoogleProfileSetupScreen({
    super.key,
    required this.email,
    required this.googleName,
  });

  @override
  State<GoogleProfileSetupScreen> createState() =>
      _GoogleProfileSetupScreenState();
}

class _GoogleProfileSetupScreenState extends State<GoogleProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _namaController;
  final _puskesmasController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.googleName);
  }

  @override
  void dispose() {
    _namaController.dispose();
    _puskesmasController.dispose();
    super.dispose();
  }

  String _getInitial() {
    final text = _namaController.text.trim().isNotEmpty
        ? _namaController.text.trim()
        : (widget.googleName.trim().isNotEmpty
            ? widget.googleName.trim()
            : widget.email.trim());
    return text.isNotEmpty ? text[0].toUpperCase() : 'U';
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
    final role = profile['role'] as String? ?? 'user';
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
              ).animate(CurvedAnimation(
                  parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = _getInitial();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFD6ECFA), Color(0xFFF1F8FD)],
            stops: [0.0, 0.45],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Avatar circle
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryDeep,
                            boxShadow: [
                              BoxShadow(
                                color: Color.fromRGBO(10, 100, 168, 0.20),
                                blurRadius: 18,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Title
                      const Text(
                        'Lengkapi profil',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.text,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Subtitle
                      const Text(
                        'Satu langkah lagi sebelum mulai.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Email Pill
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(63, 90, 112, 0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const _GoogleLetterG(),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  widget.email,
                                  style: const TextStyle(
                                    color: Color(0xFF3F5A70),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Error Banner
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0F0),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: const Color(0xFFFFD2D2)),
                          ),
                          child: Row(
                            children: [
                              const AppIcon(AppGlyph.warning,
                                  color: AppTheme.error, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: AppTheme.error,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Field 1: Nama Lengkap
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF3FA),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0xFFD3E4F1)),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Nama lengkap',
                              style: TextStyle(
                                color: Color(0xFF4A667E),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            TextFormField(
                              controller: _namaController,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(
                                color: AppTheme.text,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                hintText: 'Masukkan nama lengkap',
                                hintStyle: TextStyle(
                                  color: Color(0xFF8BA5BA),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Nama wajib diisi';
                                }
                                if (v.trim().length < 2) {
                                  return 'Nama terlalu pendek';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Field 2: Puskesmas
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF3FA),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0xFFD3E4F1)),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Puskesmas',
                              style: TextStyle(
                                color: Color(0xFF4A667E),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            TextFormField(
                              controller: _puskesmasController,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              style: const TextStyle(
                                color: AppTheme.text,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                hintText: 'Contoh: Balas Klumprik',
                                hintStyle: TextStyle(
                                  color: Color(0xFF8BA5BA),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Puskesmas wajib diisi';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Caption
                      const Text(
                        'Nama dan puskesmas akan tampil di setiap laporan yang Anda buat.',
                        style: TextStyle(
                          color: Color(0xFF4A667E),
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Submit button
                      AppButton(
                        label: 'Simpan & lanjut',
                        kind: AppButtonKind.primary,
                        loading: _isLoading,
                        onPressed: _isLoading ? null : _submit,
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
}

class _GoogleLetterG extends StatelessWidget {
  const _GoogleLetterG();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFF4285F4),
        shape: BoxShape.circle,
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          height: 1.1,
        ),
      ),
    );
  }
}

