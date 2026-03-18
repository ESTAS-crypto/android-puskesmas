import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/user_session.dart';
import '../services/storage_service.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();

  final _puskesmasController = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  String _selectedBulan = 'Februari';
  String _selectedTahun = '2026';

  final List<String> _bulanList = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  final List<String> _tahunList = List.generate(
    10,
    (i) => (2024 + i).toString(),
  );

  bool _isLoading = false;

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
    _animController.dispose();
    _namaController.dispose();

    _puskesmasController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final session = UserSession(
      nama: _namaController.text.trim(),
      puskesmas: _puskesmasController.text.trim(),
      bulan: _selectedBulan,
      tahun: _selectedTahun,
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
        transitionDuration: const Duration(milliseconds: 500),
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
                        child: const Icon(
                          Icons.home_work_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
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
                        'Masuk untuk mulai membuat laporan',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 32),

                      // Form Card
                      Container(
                        decoration: AppTheme.glassDecoration(opacity: 0.06),
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Nama Kader / Petugas'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _namaController,
                                decoration: const InputDecoration(
                                  hintText: 'Masukkan nama Anda',
                                  prefixIcon: Icon(Icons.person_outline_rounded, color: AppTheme.accentTeal),
                                ),
                                style: const TextStyle(color: AppTheme.textPrimary),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Nama wajib diisi'
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
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Puskesmas wajib diisi'
                                    : null,
                              ),
                              const SizedBox(height: 16),

                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildLabel('Bulan'),
                                        const SizedBox(height: 8),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: AppTheme.surfaceDark,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: AppTheme.divider),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: _selectedBulan,
                                              isExpanded: true,
                                              dropdownColor: AppTheme.cardDark,
                                              style: const TextStyle(color: AppTheme.textPrimary),
                                              items: _bulanList.map((b) {
                                                return DropdownMenuItem(value: b, child: Text(b));
                                              }).toList(),
                                              onChanged: (v) => setState(() => _selectedBulan = v!),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildLabel('Tahun'),
                                        const SizedBox(height: 8),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: AppTheme.surfaceDark,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: AppTheme.divider),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: _selectedTahun,
                                              isExpanded: true,
                                              dropdownColor: AppTheme.cardDark,
                                              style: const TextStyle(color: AppTheme.textPrimary),
                                              items: _tahunList.map((t) {
                                                return DropdownMenuItem(value: t, child: Text(t));
                                              }).toList(),
                                              onChanged: (v) => setState(() => _selectedTahun = v!),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 28),

                              // Login button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
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
                                                Icon(Icons.login_rounded, color: Colors.white),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Masuk',
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

                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wifi_off_rounded, size: 16, color: AppTheme.textHint),
                          const SizedBox(width: 6),
                          Text(
                            'Aplikasi berjalan offline',
                            style: TextStyle(
                              color: AppTheme.textHint,
                              fontSize: 12,
                            ),
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
