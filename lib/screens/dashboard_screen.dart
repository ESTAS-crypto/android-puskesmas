import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../models/report.dart';
import '../theme/motion.dart';
import '../widgets/ui/ui.dart';
import '../models/user_session.dart';
import '../models/resident_exam.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../services/update_service.dart';
import '../widgets/changelog_dialog.dart';
import '../widgets/connectivity_banner.dart';
import '../widgets/role_badge.dart';
import 'login_screen.dart';
import 'report_form_screen.dart';
import 'report_history_screen.dart';
import 'admin_panel_screen.dart';

class DashboardScreen extends StatefulWidget {
  final UserSession session;

  const DashboardScreen({super.key, required this.session});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

enum _DraftChoice { resume, discard }

class _DashboardScreenState extends State<DashboardScreen> {
  int _reportCount = 0;
  int _patientCount = 0;
  int _monthCount = 0;
  List<Report> _recent = [];
  Report? _draft;

  @override
  void initState() {
    super.initState();
    _loadSummary();
    _checkChangelog();
    _checkAppUpdate();
    // Background tasks — tidak memblokir UI
    _runBackgroundTasks();
  }

  /// Jalankan auto-cleanup lokal dan (jika admin) server cleanup.
  Future<void> _runBackgroundTasks() async {
    // 1. Cleanup lokal selalu dijalankan
    StorageService.cleanupOldLocalData().then((count) {
      if (count > 0) {
        debugPrint('[Dashboard] Local cleanup: $count laporan dihapus');
        _loadSummary();
      }
    });

    // 2. Jika admin dan online → cleanup server juga
    if (widget.session.isAdmin && SupabaseService.isLoggedIn) {
      final prefs = await SharedPreferences.getInstance();
      final photoVal = prefs.getInt('ad_photo_val') ?? 0;
      final photoUnit = prefs.getString('ad_photo_unit') ?? 'bulan';
      final reportVal = prefs.getInt('ad_report_val') ?? 0;
      final reportUnit = prefs.getString('ad_report_unit') ?? 'bulan';

      int toDays(int v, String u) {
        if (v <= 0) return 0;
        switch (u) {
          case 'hari':
            return v;
          case 'minggu':
            return v * 7;
          default:
            return v * 30;
        }
      }

      SupabaseService.adminAutoCleanServerData(
        photoDeleteDays: toDays(photoVal, photoUnit),
        reportDeleteDays: toDays(reportVal, reportUnit),
      );
    }
  }

  Future<void> _loadSummary() async {
    final reports = await StorageService.getReports();
    final draft = await StorageService.getDraft();
    if (!mounted) return;
    final now = DateTime.now();
    final sorted = [...reports]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    setState(() {
      _reportCount = reports.length;
      _patientCount = reports.fold<int>(0, (sum, r) => sum + r.totalPasien);
      _monthCount = reports
          .where((r) =>
              r.createdAt.year == now.year && r.createdAt.month == now.month)
          .length;
      _recent = sorted.take(3).toList();
      _draft = (draft != null && draft.exams.isNotEmpty) ? draft : null;
    });
  }

  Future<void> _checkChangelog() async {
    final shouldShow = await ChangelogDialog.shouldShowChangelog();
    if (shouldShow && mounted) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        ChangelogDialog.show(context, isAutoShow: true);
      }
    }
  }

  /// Periksa pembaruan aplikasi OTA (silent = tidak menampilkan apa-apa jika sudah terbaru)
  Future<void> _checkAppUpdate() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    UpdateService.checkAndShowUpdate(context, silent: true);
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Selamat pagi';
    if (h < 15) return 'Selamat siang';
    if (h < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  Future<void> _logout() async {
    final pending = await StorageService.getPendingSyncCount();
    if (!mounted) return;

    final confirm = await AppConfirmSheet.show(
      context,
      title: 'Keluar dari akun?',
      message: pending > 0
          ? 'Ada $pending laporan yang belum terkirim. Laporan tetap aman di HP, tetapi baru terkirim setelah Anda masuk lagi dan online.'
          : 'Laporan yang sudah dibuat tetap tersimpan di perangkat ini.',
      confirmLabel: pending > 0 ? 'Keluar juga' : 'Keluar',
      cancelLabel: pending > 0 ? 'Tetap di sini' : 'Batal',
      isDangerous: true,
      pendingCount: pending,
    );

    if (confirm) {
      await SupabaseService.signOut();
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
      final choice = await showModalBottomSheet<_DraftChoice>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lanjutkan draf?',
                    style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Ada draf dengan ${draft.totalPasien} pasien yang belum disimpan.',
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                AppButton(
                  label: 'Lanjutkan draf',
                  icon: AppGlyph.edit,
                  onPressed: () => Navigator.pop(ctx, _DraftChoice.resume),
                ),
                const SizedBox(height: 10),
                AppButton(
                  label: 'Hapus draf & mulai baru',
                  kind: AppButtonKind.danger,
                  onPressed: () => Navigator.pop(ctx, _DraftChoice.discard),
                ),
              ],
            ),
          ),
        ),
      );

      if (choice == null) return; // sheet ditutup
      if (choice == _DraftChoice.resume) {
        _openForm(initialExams: draft.exams);
        return;
      }
      await StorageService.clearDraft();
    }
    _openForm();
  }

  void _openForm({List<ResidentExam>? initialExams}) {
    _push(ReportFormScreen(
      session: widget.session,
      initialExams: initialExams,
    ));
  }

  void _navigateToHistory() =>
      _push(ReportHistoryScreen(session: widget.session));

  void _navigateToAdmin() => _push(AdminPanelScreen(session: widget.session));

  /// Transisi layar diatur terpusat oleh PageTransitionsTheme (lihat motion.dart).
  void _push(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page))
        .then((_) => _loadSummary());
  }

  Future<void> _showExportDialog() async {
    final reports = await StorageService.getReports();
    if (reports.isEmpty) {
      if (!mounted) return;
      AppToast.show(
        context,
        'Belum ada laporan untuk diekspor. Buat laporan dulu.',
        kind: AppToastKind.warning,
      );
      return;
    }

    if (!mounted) return;
    _push(ReportHistoryScreen(
      session: widget.session,
      showExportOnLoad: true,
    ));
  }

  // ───────────────────────────── UI ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    final nama = widget.session.nama.trim();
    final firstName = nama.isEmpty ? 'Kader' : nama.split(' ').first;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: ConnectivityBanner(
          child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadSummary,
            color: AppTheme.accent,
            backgroundColor: AppTheme.surfaceRaised,
            child: StaggerScope(
              builder: (context, anim) {
                var i = 0;
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    StaggerIn(
                      animation: anim,
                      index: i++,
                      child: _buildHeader(firstName),
                    ),
                    const SizedBox(height: 24),
                    StaggerIn(
                      animation: anim,
                      index: i++,
                      child: _buildHero(),
                    ),
                    const SizedBox(height: 16),
                    StaggerIn(
                      animation: anim,
                      index: i++,
                      child: _buildStats(),
                    ),
                    const SizedBox(height: 28),
                    StaggerIn(
                      animation: anim,
                      index: i++,
                      child: _buildQuickActions(),
                    ),
                    const SizedBox(height: 28),
                    StaggerIn(
                      animation: anim,
                      index: i++,
                      child: _buildRecent(),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildHeader(String firstName) {
    final t = Theme.of(context).textTheme;
    final initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.tint(AppTheme.accent),
                shape: BoxShape.circle,
              ),
              child: Text(
                initial,
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_greeting(), style: t.bodyMedium),
                  Text(
                    firstName,
                    style: t.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            AppIconButton(
              icon: AppGlyph.spark,
              tooltip: 'Apa yang baru',
              color: AppTheme.accent,
              onTap: () => ChangelogDialog.show(context),
            ),
            const SizedBox(width: 8),
            AppIconButton(
              icon: AppGlyph.update,
              tooltip: 'Cek pembaruan aplikasi',
              onTap: () => UpdateService.checkAndShowUpdate(context, silent: false),
            ),
            const SizedBox(width: 8),
            AppIconButton(
              icon: AppGlyph.logout,
              tooltip: 'Keluar',
              onTap: _logout,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StatusPill(
              label: 'Puskesmas ${widget.session.puskesmas}',
              icon: AppGlyph.hospital,
              color: AppTheme.textMuted,
            ),
            RoleBadge(session: widget.session),
          ],
        ),
      ],
    );
  }

  Widget _buildHero() {
    final hasDraft = _draft != null;
    return AppCard(
      onTap: _navigateToForm,
      color: AppTheme.primaryDeep,
      borderColor: Colors.transparent,
      padding: const EdgeInsets.all(22),
      semanticLabel: hasDraft
          ? 'Buat laporan baru. Ada draf ${_draft!.totalPasien} pasien yang belum disimpan.'
          : 'Buat laporan baru',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: AppMotion.medium,
                  switchInCurve: AppMotion.decelerate,
                  child: hasDraft
                      ? Container(
                          key: const ValueKey('draft'),
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Draf tersimpan · ${_draft!.totalPasien} pasien',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('nodraft')),
                ),
                Text(
                  hasDraft ? 'Lanjutkan laporan' : 'Buat laporan baru',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  hasDraft
                      ? 'Teruskan dari data yang sudah Anda isi.'
                      : 'Catat pasien yang Anda kunjungi hari ini.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: AppIcon(hasDraft ? AppGlyph.arrow : AppGlyph.plus,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    Widget tile(String label, int value) {
      return Expanded(
        child: AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          semanticLabel: '$label: $value',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CountUp(
                value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontSize: 26),
              ),
              const SizedBox(height: 2),
              Text(label,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        tile('Laporan', _reportCount),
        const SizedBox(width: 10),
        tile('Pasien', _patientCount),
        const SizedBox(width: 10),
        tile('Bulan ini', _monthCount),
      ],
    );
  }

  Widget _quickAction({
    required Object icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      semanticLabel: '$title. $subtitle',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.tint(AppTheme.accent),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: AppIcon(icon, color: AppTheme.accent, size: 24),
          ),
          const SizedBox(height: 14),
          Text(title, style: t.titleMedium),
          const SizedBox(height: 2),
          Text(subtitle,
              style: t.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Akses cepat'),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _quickAction(
                  icon: AppGlyph.history,
                  title: 'Riwayat',
                  subtitle: 'Cari & kelola laporan',
                  onTap: _navigateToHistory,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _quickAction(
                  icon: AppGlyph.export,
                  title: 'Dokumen',
                  subtitle: 'Ekspor ke PDF atau DOCX',
                  onTap: _showExportDialog,
                ),
              ),
            ],
          ),
        ),
        if (widget.session.isAdmin) ...[
          const SizedBox(height: 12),
          AppCard(
            onTap: _navigateToAdmin,
            semanticLabel: 'Panel admin. Kelola pengguna, laporan, dan foto.',
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.tint(AppTheme.accent),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const AppIcon(AppGlyph.shield,
                      color: AppTheme.accent, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Panel admin',
                          style: Theme.of(context).textTheme.titleMedium),
                      Text('Kelola pengguna, laporan & foto',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const AppIcon(AppGlyph.chevron,
                    color: AppTheme.textFaint),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRecent() {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Laporan terbaru',
          actionLabel: _recent.isEmpty ? null : 'Lihat semua',
          onAction: _navigateToHistory,
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: AppMotion.medium,
          switchInCurve: AppMotion.decelerate,
          child: _recent.isEmpty
              ? const EmptyState(
                  key: ValueKey('empty'),
                  icon: AppGlyph.report,
                  title: 'Belum ada laporan',
                  message:
                      'Laporan pertama Anda akan muncul di sini setelah disimpan.',
                )
              : Column(
                  key: const ValueKey('list'),
                  children: [
                    for (final r in _recent)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          onTap: _navigateToHistory,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          semanticLabel:
                              'Laporan nomor ${r.no}, ${r.totalPasien} pasien. ${r.summaryNames}',
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceRaised,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Text('#${r.no}',
                                    style: t.titleSmall
                                        ?.copyWith(color: AppTheme.accent)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.summaryNames,
                                        style: t.titleMedium?.copyWith(
                                            fontSize: 15),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${r.totalPasien} pasien · ${r.tanggalDisplay}',
                                      style: t.bodySmall,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const AppIcon(AppGlyph.chevron,
                                  color: AppTheme.textFaint),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
