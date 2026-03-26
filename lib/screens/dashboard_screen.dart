import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/user_session.dart';
import '../models/resident_exam.dart';
import '../services/storage_service.dart';
import '../widgets/changelog_dialog.dart';
import 'login_screen.dart';
import 'report_form_screen.dart';
import 'report_history_screen.dart';

class DashboardScreen extends StatefulWidget {
  final UserSession session;

  const DashboardScreen({super.key, required this.session});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  int _reportCount = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animController.forward();
    _loadReportCount();
    _checkChangelog();
  }

  Future<void> _loadReportCount() async {
    final reports = await StorageService.getReports();
    if (mounted) {
      setState(() => _reportCount = reports.length);
    }
  }

  Future<void> _checkChangelog() async {
    final shouldShow = await ChangelogDialog.shouldShowChangelog();
    if (shouldShow && mounted) {
      // Small delay so dashboard renders first
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        ChangelogDialog.show(context, isAutoShow: true);
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Keluar?', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'Data laporan akan tetap tersimpan di perangkat.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await StorageService.clearSession();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  Future<void> _navigateToForm() async {
    final draft = await StorageService.getDraft();
    if (draft != null && draft.exams.isNotEmpty) {
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Lanjutkan Draf?', style: TextStyle(color: AppTheme.textPrimary)),
          content: Text(
            'Ada draf laporan sebelumnya dengan ${draft.totalPasien} pasien yang belum disimpan. Ingin melanjutkannya?',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await StorageService.clearDraft();
                if (ctx.mounted) Navigator.pop(ctx, false);
              },
              child: const Text('Hapus & Buat Baru', style: TextStyle(color: AppTheme.error)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Lanjutkan', style: TextStyle(color: AppTheme.accentTeal)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        _openForm(initialExams: draft.exams);
        return;
      } else if (confirm == null) {
        return; // Dialog dismissed
      }
    }
    _openForm();
  }

  void _openForm({List<ResidentExam>? initialExams}) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ReportFormScreen(
          session: widget.session,
          initialExams: initialExams,
        ),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    ).then((_) => _loadReportCount());
  }

  void _navigateToHistory() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ReportHistoryScreen(session: widget.session),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    ).then((_) => _loadReportCount());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildAnimatedChild(
                  delay: 0,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Halo,',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              widget.session.nama,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => ChangelogDialog.show(context),
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceDark,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.new_releases_outlined, color: AppTheme.accentTeal, size: 20),
                        ),
                      ),
                      IconButton(
                        onPressed: _logout,
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceDark,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.logout_rounded, color: AppTheme.textSecondary, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Info Card
                _buildAnimatedChild(
                  delay: 100,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentTeal.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Puskesmas ${widget.session.puskesmas}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Periode: ${widget.session.bulanTahun}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.description_outlined, color: Colors.white, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                '$_reportCount Laporan',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Menu Label
                _buildAnimatedChild(
                  delay: 200,
                  child: const Text(
                    'Menu',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Buttons
                _buildAnimatedChild(
                  delay: 300,
                  child: _buildMenuButton(
                    icon: Icons.add_circle_outline_rounded,
                    title: 'Buat Laporan Baru',
                    subtitle: 'Tambah data kunjungan rumah',
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00BFA6), Color(0xFF00ACC1)],
                    ),
                    onTap: _navigateToForm,
                  ),
                ),
                const SizedBox(height: 12),

                _buildAnimatedChild(
                  delay: 400,
                  child: _buildMenuButton(
                    icon: Icons.history_rounded,
                    title: 'Riwayat Laporan',
                    subtitle: 'Lihat & kelola laporan sebelumnya',
                    gradient: const LinearGradient(
                      colors: [Color(0xFF448AFF), Color(0xFF7C4DFF)],
                    ),
                    onTap: _navigateToHistory,
                  ),
                ),
                const SizedBox(height: 12),

                _buildAnimatedChild(
                  delay: 500,
                  child: _buildMenuButton(
                    icon: Icons.picture_as_pdf_rounded,
                    title: 'Generate Dokumen',
                    subtitle: 'Ekspor semua laporan ke PDF atau DOCX',
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                    ),
                    onTap: () => _showExportDialog(),
                  ),
                ),

                const Spacer(),

                // Footer
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off_rounded, size: 14, color: AppTheme.textHint),
                      const SizedBox(width: 6),
                      Text(
                        'Berjalan 100% Offline',
                        style: TextStyle(color: AppTheme.textHint, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedChild({required int delay, required Widget child}) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        final delayedProgress = ((_animController.value - (delay / 1000)).clamp(0.0, 1.0) * 2.5).clamp(0.0, 1.0);
        return Opacity(
          opacity: delayedProgress,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - delayedProgress)),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required LinearGradient gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.textHint),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showExportDialog() async {
    final reports = await StorageService.getReports();
    if (reports.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.warning),
              SizedBox(width: 8),
              Text('Belum ada laporan untuk diekspor'),
            ],
          ),
          backgroundColor: AppTheme.cardDark,
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportHistoryScreen(
          session: widget.session,
          showExportOnLoad: true,
        ),
      ),
    ).then((_) => _loadReportCount());
  }
}
