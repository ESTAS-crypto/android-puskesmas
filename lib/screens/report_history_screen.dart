import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../models/report.dart';
import '../models/resident_exam.dart';
import '../models/user_session.dart';
import '../models/custom_role.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../services/pdf_service.dart';
import '../services/docx_service.dart';
import '../widgets/ui/ui.dart';
import 'custom_roles_screen.dart';
import 'report_form_screen.dart';

const List<String> _bulanIndo = [
  '',
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

String _formatMonthYear(DateTime dt) {
  final monthName = (dt.month >= 1 && dt.month <= 12) ? _bulanIndo[dt.month] : '';
  return '$monthName ${dt.year}';
}

class ReportHistoryScreen extends StatefulWidget {
  final UserSession session;
  final bool showExportOnLoad;

  const ReportHistoryScreen({
    super.key,
    required this.session,
    this.showExportOnLoad = false,
  });

  @override
  State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
}

class _ReportHistoryScreenState extends State<ReportHistoryScreen> {
  List<Report> _reports = [];
  Set<String> _pendingSyncIds = {};
  bool _isLoading = true;
  bool _isExporting = false;
  String _searchQuery = '';
  late final TextEditingController _searchController;
  bool _isGlobalMode = false;
  bool _isGlobalSearching = false;
  List<Map<String, dynamic>> _globalResults = [];
  List<Map<String, dynamic>> _globalReports = [];
  bool _globalViewPerReport = true;
  Timer? _debounceTimer;

  Map<String, Map<String, dynamic>> _userProfilesMap = {};
  Map<String, CustomRole> _customRolesMap = {};

  List<Report> get _filteredReports {
    if (_searchQuery.isEmpty) return _reports;
    final query = _searchQuery.toLowerCase();
    return _reports.where((report) {
      if (report.summaryNames.toLowerCase().contains(query)) return true;
      for (final exam in report.exams) {
        if (exam.nama.toLowerCase().contains(query) ||
            exam.nik.toLowerCase().contains(query) ||
            exam.alamat.toLowerCase().contains(query) ||
            exam.tanggal.toLowerCase().contains(query)) {
          return true;
        }
      }
      return false;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadReports();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    final reports = await StorageService.getReports();
    final pendingIds = await StorageService.getPendingSyncIds();

    if (mounted) {
      setState(() {
        _reports = reports;
        _pendingSyncIds = pendingIds;
        _isLoading = false;
      });

      // Auto-sync semua laporan lokal ke cloud (fire-and-forget)
      if (SupabaseService.isLoggedIn && reports.isNotEmpty) {
        SupabaseService.syncAllToCloud(reports).then((_) async {
          final freshPending = await StorageService.getPendingSyncIds();
          if (mounted) {
            setState(() => _pendingSyncIds = freshPending);
          }
        }).catchError((_) {});
      }

      // Auto-cleanup laporan lokal lama (berdasarkan remote config admin)
      StorageService.cleanupOldLocalData().then((deletedCount) {
        if (deletedCount > 0 && mounted) {
          StorageService.getReports().then((freshReports) {
            if (mounted) setState(() => _reports = freshReports);
          });
        }
      });

      if (widget.showExportOnLoad && reports.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showExportDialog());
      }
    }
  }

  Future<void> _deleteReport(Report report) async {
    final isPending = _pendingSyncIds.contains(report.id);
    final confirm = await AppConfirmSheet.show(
      context,
      title: 'Hapus Laporan?',
      message: 'Laporan #${report.no} (${report.totalPasien} pasien) akan dihapus permanen dari perangkat.',
      confirmLabel: 'Hapus Laporan',
      isDangerous: true,
      pendingCount: isPending ? 1 : 0,
    );

    if (confirm == true) {
      await StorageService.deleteReport(report.id);
      await _loadReports();
      if (mounted) {
        AppToast.show(
          context,
          'Laporan #${report.no} berhasil dihapus',
          kind: AppToastKind.info,
        );
      }
    }
  }

  void _editReport(Report report) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportFormScreen(
          session: widget.session,
          existingReport: report,
        ),
      ),
    ).then((_) => _loadReports());
  }

  Future<void> _showExportDialog({String? preselectType}) async {
    final selectedIds = Set<String>.from(_reports.map((r) => r.id));

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final allSelected = selectedIds.length == _reports.length;
            final noneSelected = selectedIds.isEmpty;

            return DraggableScrollableSheet(
              initialChildSize: 0.72,
              minChildSize: 0.45,
              maxChildSize: 0.94,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle bar
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.outline,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Title & Subtitle
                      const Text(
                        'Ekspor Laporan',
                        style: TextStyle(
                          color: AppTheme.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${selectedIds.length} dari ${_filteredReports.length} laporan dipilih',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 14),

                      // Select All / Deselect All button
                      Row(
                        children: [
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  setSheetState(() {
                                    if (allSelected) {
                                      selectedIds.clear();
                                    } else {
                                      selectedIds.addAll(_filteredReports.map((r) => r.id));
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryDeep.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      AppIcon(
                                        allSelected ? AppGlyph.check : AppGlyph.spark,
                                        size: 16,
                                        color: AppTheme.primaryDeep,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        allSelected ? 'Hapus Semua Pilihan' : 'Pilih Semua',
                                        style: const TextStyle(
                                          color: AppTheme.primaryDeep,
                                          fontSize: 13,
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
                      const SizedBox(height: 12),

                      // Report list with checkboxes
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: _filteredReports.length,
                          itemBuilder: (context, index) {
                            final report = _filteredReports[index];
                            final isSelected = selectedIds.contains(report.id);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primaryDeep.withValues(alpha: 0.06)
                                    : AppTheme.surfaceRaised,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primaryDeep.withValues(alpha: 0.35)
                                      : AppTheme.outline,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () {
                                    setSheetState(() {
                                      if (isSelected) {
                                        selectedIds.remove(report.id);
                                      } else {
                                        selectedIds.add(report.id);
                                      }
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    child: Row(
                                      children: [
                                        // Checkbox container
                                        Container(
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            color: isSelected ? AppTheme.primaryDeep : Colors.transparent,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isSelected ? AppTheme.primaryDeep : AppTheme.outline,
                                              width: 1.8,
                                            ),
                                          ),
                                          child: isSelected
                                              ? const Icon(
                                                  Icons.check_rounded,
                                                  color: Colors.white,
                                                  size: 15,
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 12),

                                        // Number badge
                                        Container(
                                          width: 34,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryDeep.withValues(alpha: 0.10),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '#${report.no}',
                                            style: const TextStyle(
                                              color: AppTheme.primaryDeep,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Report info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                report.summaryNames,
                                                style: const TextStyle(
                                                  color: AppTheme.text,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${report.tanggalDisplay} \u00B7 ${report.totalPasien} Pasien',
                                                style: const TextStyle(
                                                  color: AppTheme.textSecondary,
                                                  fontSize: 12,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
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
                          },
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Export buttons
                      Row(
                        children: [
                          Expanded(
                            child: _buildExportSheetButton(
                              label: 'Ekspor PDF',
                              color: const Color(0xFFC0392B),
                              enabled: !noneSelected,
                              onTap: () {
                                final selectedReports = _filteredReports
                                    .where((r) => selectedIds.contains(r.id))
                                    .toList();
                                Navigator.pop(ctx);
                                _exportPdf(selectedReports);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildExportSheetButton(
                              label: 'Ekspor DOCX',
                              color: AppTheme.primaryDeep,
                              enabled: !noneSelected,
                              onTap: () {
                                final selectedReports = _filteredReports
                                    .where((r) => selectedIds.contains(r.id))
                                    .toList();
                                Navigator.pop(ctx);
                                _exportDocx(selectedReports);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildExportSheetButton({
    required String label,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: enabled ? color.withValues(alpha: 0.12) : AppTheme.surfaceRaised,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: enabled ? color.withValues(alpha: 0.3) : AppTheme.outline,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(
                AppGlyph.export,
                size: 18,
                color: enabled ? color : AppTheme.textMuted,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: enabled ? color : AppTheme.textMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportPdf(List<Report> selectedReports) async {
    setState(() => _isExporting = true);
    try {
      final path = await PdfService.generatePdf(
        reports: selectedReports,
        session: widget.session,
      );
      if (!mounted) return;
      setState(() => _isExporting = false);
      _showExportSuccess(path, 'PDF');
    } catch (e) {
      setState(() => _isExporting = false);
      if (!mounted) return;
      AppToast.show(
        context,
        'Gagal ekspor PDF: $e',
        kind: AppToastKind.error,
      );
    }
  }

  Future<void> _exportDocx(List<Report> selectedReports) async {
    setState(() => _isExporting = true);
    try {
      final path = await DocxService.generateDocx(
        reports: selectedReports,
        session: widget.session,
      );
      if (!mounted) return;
      setState(() => _isExporting = false);
      _showExportSuccess(path, 'DOCX');
    } catch (e) {
      setState(() => _isExporting = false);
      if (!mounted) return;
      AppToast.show(
        context,
        'Gagal ekspor DOCX: $e',
        kind: AppToastKind.error,
      );
    }
  }

  void _showExportSuccess(String path, String type) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const AppIcon(AppGlyph.check, color: AppTheme.success, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              'File $type Berhasil Dibuat!',
              style: const TextStyle(
                color: AppTheme.text,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              path.split(RegExp(r'[\\/]')).last,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            AppButton(
              label: 'Bagikan File',
              kind: AppButtonKind.primary,
              icon: AppGlyph.export,
              onPressed: () {
                Navigator.pop(ctx);
                Share.shareXFiles([XFile(path)]);
              },
            ),
            const SizedBox(height: 10),
            AppButton(
              label: 'Buka File',
              kind: AppButtonKind.tonal,
              icon: AppGlyph.spark,
              onPressed: () {
                Navigator.pop(ctx);
                OpenFile.open(path);
              },
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup', style: TextStyle(color: AppTheme.textMuted)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header (Riwayat.dc.html) ──
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const AppIcon(AppGlyph.back, color: AppTheme.text, size: 22),
                      tooltip: 'Kembali',
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        'Riwayat laporan',
                        style: TextStyle(
                          color: AppTheme.text,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (_filteredReports.isNotEmpty && !_isGlobalMode)
                      IconButton(
                        onPressed: _isExporting ? null : () => _showExportDialog(),
                        icon: const AppIcon(AppGlyph.export, color: AppTheme.primaryDeep, size: 22),
                        tooltip: 'Ekspor Semua',
                      ),
                  ],
                ),
              ),

              // ── Kolom Pencarian (Riwayat.dc.html) ──
              _buildSearchBar(),

              // ── Segmented Tabs: Di perangkat / Semua puskesmas ──
              _buildSegmentedTabs(),

              // ── Baris Tombol Cepat Ekspor (Riwayat.dc.html) ──
              if (!_isGlobalMode) _buildExportRow(),

              // ── Kartu Peringatan Pending Sync (Riwayat.dc.html) ──
              if (!_isGlobalMode) _buildPendingWarningCard(),

              // ── Progress indicator saat ekspor ──
              if (_isExporting)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                  child: LinearProgressIndicator(
                    backgroundColor: AppTheme.surfaceRaised,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryDeep),
                  ),
                ),

              // ── Konten Riwayat ──
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppTheme.primaryDeep),
                      )
                    : _isGlobalMode
                        ? _buildGlobalResults()
                        : _filteredReports.isEmpty
                            ? _buildEmptyState()
                            : _buildLocalReportList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceRaised,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppTheme.outline),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) {
            _debounceTimer?.cancel();
            _debounceTimer = Timer(const Duration(milliseconds: 300), () {
              if (!mounted) return;
              setState(() => _searchQuery = val.trim());
            });
          },
          style: const TextStyle(
            color: AppTheme.text,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: _isGlobalMode
                ? 'Cari nama kader, pasien, atau NIK...'
                : 'Cari nama pasien atau tanggal',
            hintStyle: const TextStyle(
              color: AppTheme.textFaint,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 14, right: 10),
              child: AppIcon(AppGlyph.search, size: 20, color: AppTheme.textFaint),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textMuted),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedTabs() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_isGlobalMode) {
                  setState(() => _isGlobalMode = false);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: AppMotion.decelerate,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_isGlobalMode ? AppTheme.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: !_isGlobalMode
                      ? [
                          BoxShadow(
                            color: const Color(0xFF0B2A40).withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    'Di perangkat',
                    style: TextStyle(
                      color: !_isGlobalMode ? AppTheme.primaryDeep : AppTheme.textMuted,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!widget.session.canGlobalMode) {
                  AppToast.show(
                    context,
                    'Akses ke data semua puskesmas terbatas untuk admin atau peran khusus',
                    kind: AppToastKind.warning,
                  );
                  return;
                }
                if (!_isGlobalMode) {
                  setState(() => _isGlobalMode = true);
                  if (_globalReports.isEmpty && _globalResults.isEmpty) {
                    _loadAllGlobal();
                  }
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: AppMotion.decelerate,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _isGlobalMode ? AppTheme.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: _isGlobalMode
                      ? [
                          BoxShadow(
                            color: const Color(0xFF0B2A40).withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Semua puskesmas',
                        style: TextStyle(
                          color: _isGlobalMode ? AppTheme.primaryDeep : AppTheme.textMuted,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (!widget.session.canGlobalMode) ...[
                        const SizedBox(width: 6),
                        const AppIcon(AppGlyph.lock, size: 14, color: AppTheme.textMuted),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportRow() {
    final hasReports = _filteredReports.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: !hasReports || _isExporting
                    ? null
                    : () => _showExportDialog(preselectType: 'pdf'),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryDeep.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppIcon(AppGlyph.export, size: 20, color: AppTheme.primaryDeep),
                      SizedBox(width: 8),
                      Text(
                        'Ekspor PDF',
                        style: TextStyle(
                          color: AppTheme.primaryDeep,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: !hasReports || _isExporting
                    ? null
                    : () => _showExportDialog(preselectType: 'docx'),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryDeep.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppIcon(AppGlyph.export, size: 20, color: AppTheme.primaryDeep),
                      SizedBox(width: 8),
                      Text(
                        'Ekspor DOCX',
                        style: TextStyle(
                          color: AppTheme.primaryDeep,
                          fontSize: 15,
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
    );
  }

  Widget _buildPendingWarningCard() {
    final count = _pendingSyncIds.length;
    if (count == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.warning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.warning.withValues(alpha: 0.30)),
        ),
        child: Row(
          children: [
            const AppIcon(AppGlyph.cloud, size: 22, color: AppTheme.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$count laporan belum terkirim. Akan dikirim otomatis saat online.',
                style: const TextStyle(
                  color: Color(0xFF6B4000),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isSearching = _searchQuery.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(
              isSearching ? AppGlyph.search : AppGlyph.report,
              size: 56,
              color: AppTheme.textFaint,
            ),
            const SizedBox(height: 16),
            Text(
              isSearching ? 'Laporan tidak ditemukan' : 'Belum ada riwayat laporan',
              style: const TextStyle(
                color: AppTheme.text,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              isSearching
                  ? 'Coba gunakan kata kunci nama pasien atau tanggal lain.'
                  : 'Laporan yang telah Anda simpan akan muncul di sini.',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroupedReportWidgets() {
    final List<Widget> widgets = [];
    String? currentMonthYear;

    for (final report in _filteredReports) {
      final monthYear = _formatMonthYear(report.createdAt);
      if (monthYear != currentMonthYear) {
        currentMonthYear = monthYear;
        widgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
            child: Text(
              monthYear,
              style: const TextStyle(
                color: AppTheme.textFaint,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
      widgets.add(_buildReportCard(report));
    }
    return widgets;
  }

  Widget _buildLocalReportList() {
    final items = _buildGroupedReportWidgets();
    return AnimatedList(
      key: ValueKey('list_${_searchQuery}_${items.length}'),
      initialItemCount: items.length,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index, animation) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: AppMotion.decelerate,
        );
        return FadeTransition(
          opacity: curvedAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: items[index],
          ),
        );
      },
    );
  }

  Widget _buildReportCard(Report report) {
    final isPending = _pendingSyncIds.contains(report.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onTap: () => _showReportPreviewSheet(report),
        child: Row(
          children: [
            // Chip nomor urut
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryDeep.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                '#${report.no}',
                style: const TextStyle(
                  color: AppTheme.primaryDeep,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Nama & Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.summaryNames,
                    style: const TextStyle(
                      color: AppTheme.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${report.totalPasien} pasien \u00B7 ${report.tanggalDisplay}',
                    style: const TextStyle(
                      color: AppTheme.textFaint,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Trailing Status Pill: Terkirim vs Belum terkirim
            isPending
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIcon(AppGlyph.cloud, size: 13, color: AppTheme.warning),
                        SizedBox(width: 4),
                        Text(
                          'Belum terkirim',
                          style: TextStyle(
                            color: AppTheme.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIcon(AppGlyph.check, size: 13, color: AppTheme.success),
                        SizedBox(width: 4),
                        Text(
                          'Terkirim',
                          style: TextStyle(
                            color: AppTheme.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

            // Elipsis Aksi Popup Menu
            PopupMenuButton<String>(
              color: AppTheme.surface,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textMuted, size: 20),
              onSelected: (value) {
                if (value == 'preview') _showReportPreviewSheet(report);
                if (value == 'edit') _editReport(report);
                if (value == 'copy') _copyReportData(report);
                if (value == 'delete') _deleteReport(report);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'preview',
                  child: Row(
                    children: [
                      AppIcon(AppGlyph.eye, color: AppTheme.primaryDeep, size: 18),
                      SizedBox(width: 10),
                      Text('Lihat Detail', style: TextStyle(color: AppTheme.text, fontSize: 14)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      AppIcon(AppGlyph.edit, color: AppTheme.warning, size: 18),
                      SizedBox(width: 10),
                      Text('Edit Laporan', style: TextStyle(color: AppTheme.text, fontSize: 14)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'copy',
                  child: Row(
                    children: [
                      AppIcon(AppGlyph.report, color: AppTheme.textMuted, size: 18),
                      SizedBox(width: 10),
                      Text('Salin Data', style: TextStyle(color: AppTheme.text, fontSize: 14)),
                    ],
                  ),
                ),
                if (widget.session.canDeleteReport)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        AppIcon(AppGlyph.trash, color: AppTheme.error, size: 18),
                        SizedBox(width: 10),
                        Text('Hapus Laporan', style: TextStyle(color: AppTheme.error, fontSize: 14)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // GLOBAL MODE LOGIC & RENDERING
  // ─────────────────────────────────────────────

  Future<void> _loadAllGlobal() async {
    setState(() => _isGlobalSearching = true);
    final results = await Future.wait([
      SupabaseService.globalGetAllExams(),
      SupabaseService.globalGetAllReports(),
      SupabaseService.getCustomRoles(),
      SupabaseService.fetchProfilesWithRoles(),
    ]);

    if (mounted) {
      final rolesData = results[2] as List<Map<String, dynamic>>;
      final rolesMap = <String, CustomRole>{};
      for (final m in rolesData) {
        final role = CustomRole.fromMap(m);
        rolesMap[role.id] = role;
      }

      setState(() {
        _globalResults = results[0] as List<Map<String, dynamic>>;
        _globalReports = results[1] as List<Map<String, dynamic>>;
        _customRolesMap = rolesMap;
        _userProfilesMap = results[3] as Map<String, Map<String, dynamic>>;
        _isGlobalSearching = false;
      });
    }
  }

  Future<void> _performGlobalSearch(String query) async {
    // Local filter on global results
  }

  Widget _buildGlobalResults() {
    if (_isGlobalSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryDeep),
            SizedBox(height: 16),
            Text('Memuat data semua puskesmas...', style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    // Toggle tampilan per laporan / per pasien
    final toggleHeader = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          const AppIcon(AppGlyph.hospital, size: 16, color: AppTheme.primaryDeep),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _globalViewPerReport
                  ? '${_globalReports.length} laporan di server'
                  : '${_globalResults.length} pasien di server',
              style: const TextStyle(
                color: AppTheme.primaryDeep,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _globalViewPerReport = !_globalViewPerReport),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.surfaceRaised,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.outline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(
                    _globalViewPerReport ? AppGlyph.report : AppGlyph.patient,
                    size: 14,
                    color: AppTheme.primaryDeep,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _globalViewPerReport ? 'Per Laporan' : 'Per Pasien',
                    style: const TextStyle(
                      color: AppTheme.primaryDeep,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    // ── Tampilan Per Laporan ──
    if (_globalViewPerReport) {
      final filteredReports = _searchQuery.isEmpty
          ? _globalReports
          : _globalReports.where((r) {
              final q = _searchQuery.toLowerCase();
              final kader = (r['user_nama'] as String? ?? '').toLowerCase();
              final puskesmas = (r['user_puskesmas'] as String? ?? '').toLowerCase();
              final exams = r['resident_exams'] as List? ?? [];
              final pasienNames = exams.map((e) => (e['nama'] as String? ?? '').toLowerCase()).join(' ');
              return kader.contains(q) || puskesmas.contains(q) || pasienNames.contains(q);
            }).toList();

      if (filteredReports.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppIcon(AppGlyph.report, size: 56, color: AppTheme.textFaint),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isEmpty ? 'Belum ada data di server' : 'Laporan tidak ditemukan',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
              ),
            ],
          ),
        );
      }

      return Column(
        children: [
          toggleHeader,
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filteredReports.length,
              itemBuilder: (context, index) => _buildGlobalReportCard(filteredReports[index]),
            ),
          ),
        ],
      );
    }

    // ── Tampilan Per Pasien ──
    final filtered = _searchQuery.isEmpty
        ? _globalResults
        : _globalResults.where((row) {
            final q = _searchQuery.toLowerCase();
            final n = (row['nama'] as String? ?? '').toLowerCase();
            final nik = (row['nik'] as String? ?? '').toLowerCase();
            final a = (row['alamat'] as String? ?? '').toLowerCase();
            final reportsData = row['reports'] as Map<String, dynamic>?;
            final kaderName = (reportsData?['user_nama'] as String? ?? '').toLowerCase();
            return n.contains(q) || nik.contains(q) || a.contains(q) || kaderName.contains(q);
          }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppIcon(AppGlyph.patient, size: 56, color: AppTheme.textFaint),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? 'Belum ada data pasien di server' : 'Tidak ada hasil untuk "$_searchQuery"',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        toggleHeader,
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filtered.length,
            itemBuilder: (context, index) => _buildGlobalResultCard(filtered[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildGlobalReportCard(Map<String, dynamic> report) {
    final no = report['no'] as int? ?? 0;
    final userId = report['user_id'] as String? ?? '';
    final kader = report['user_nama'] as String? ?? 'Petugas';
    final puskesmas = report['user_puskesmas'] as String? ?? '';
    final createdAt = report['created_at'] as String? ?? '';
    final exams = report['resident_exams'] as List? ?? [];
    final pasienCount = exams.length;

    final profileInfo = _userProfilesMap[userId];
    final builtInRole = profileInfo?['role'] as String? ?? 'user';
    final customRoleId = profileInfo?['custom_role_id'] as String?;
    final customRole = customRoleId != null ? _customRolesMap[customRoleId] : null;

    String tanggalStr = '';
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        tanggalStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      } catch (_) {}
    }

    final namaList = exams.take(3).map((e) => e['nama'] as String? ?? '-').join(', ');
    final extraCount = pasienCount > 3 ? ' +${pasienCount - 3} lainnya' : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        onTap: () => _showGlobalReportDetailSheet(report),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryDeep.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '#$no',
                    style: const TextStyle(
                      color: AppTheme.primaryDeep,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kader,
                        style: const TextStyle(
                          color: AppTheme.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (puskesmas.isNotEmpty)
                        Text(
                          'Puskesmas $puskesmas',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      const SizedBox(height: 4),
                      _buildRoleBadge(builtInRole, customRole),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryDeep.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon(AppGlyph.eye, color: AppTheme.primaryDeep, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Lihat',
                        style: TextStyle(
                          color: AppTheme.primaryDeep,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceRaised,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const AppIcon(AppGlyph.patient, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pasienCount == 0 ? 'Belum ada pasien' : '$namaList$extraCount',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryDeep.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$pasienCount pasien',
                      style: const TextStyle(
                        color: AppTheme.primaryDeep,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (tanggalStr.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 12, color: AppTheme.textFaint),
                  const SizedBox(width: 4),
                  Text(
                    tanggalStr,
                    style: const TextStyle(color: AppTheme.textFaint, fontSize: 11),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String builtInRole, CustomRole? customRole) {
    if (customRole != null) {
      final color = Color(customRole.colorValue);
      final icon = getCustomRoleIconData(customRole.iconName);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 4),
            Text(
              customRole.name,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    if (builtInRole == 'user') return const SizedBox.shrink();

    final Map<String, ({Color color, IconData icon, String label})> roleStyles = {
      'owner': (color: const Color(0xFFB06A00), icon: Icons.workspace_premium_rounded, label: 'Owner'),
      'developer': (color: AppTheme.primaryDeep, icon: Icons.code_rounded, label: 'Developer'),
      'admin': (color: AppTheme.success, icon: Icons.admin_panel_settings_rounded, label: 'Admin'),
    };

    final style = roleStyles[builtInRole];
    if (style == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: style.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, color: style.color, size: 12),
          const SizedBox(width: 4),
          Text(
            style.label,
            style: TextStyle(color: style.color, fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalResultCard(Map<String, dynamic> row) {
    final nama = row['nama'] as String? ?? '-';
    final nik = row['nik'] as String? ?? '';
    final alamat = row['alamat'] as String? ?? '-';
    final tanggal = row['tanggal'] as String? ?? '-';
    final usia = row['usia'] as String? ?? '-';
    final tensi = row['tensi'] as String? ?? '';
    final bb = row['bb'] as String? ?? '';
    final tb = row['tb'] as String? ?? '';

    final reportData = row['reports'] as Map<String, dynamic>?;
    final ownerNama = reportData?['user_nama'] as String? ?? 'Petugas';
    final ownerPuskesmas = reportData?['user_puskesmas'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        onTap: () => _showPatientDetailSheet(row),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryDeep.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    nama.isNotEmpty ? nama[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: AppTheme.primaryDeep,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nama,
                        style: const TextStyle(
                          color: AppTheme.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (nik.isNotEmpty)
                        Text(
                          'NIK: $nik',
                          style: const TextStyle(
                            color: AppTheme.primaryDeep,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _importToLocal(row),
                  icon: const AppIcon(AppGlyph.plus, size: 18, color: AppTheme.primaryDeep),
                  tooltip: 'Simpan ke Lokal',
                  visualDensity: VisualDensity.compact,
                ),
                if (widget.session.canDeleteReport)
                  IconButton(
                    onPressed: () => _deleteGlobalExam(row),
                    icon: const AppIcon(AppGlyph.trash, size: 18, color: AppTheme.error),
                    tooltip: 'Hapus dari Server',
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _infoChip(Icons.calendar_today_rounded, tanggal),
                _infoChip(Icons.cake_rounded, '$usia thn'),
                _infoChip(Icons.location_on_outlined, alamat),
              ],
            ),
            if (tensi.isNotEmpty || bb.isNotEmpty || tb.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (tensi.isNotEmpty) _healthChip('Tensi', tensi),
                  if (bb.isNotEmpty) _healthChip('BB', '$bb kg'),
                  if (tb.isNotEmpty) _healthChip('TB', '$tb cm'),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceRaised,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppIcon(AppGlyph.patient, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '$ownerNama${ownerPuskesmas.isNotEmpty ? ' \u2022 PKM $ownerPuskesmas' : ''}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteGlobalExam(Map<String, dynamic> row) async {
    final nama = row['nama'] as String? ?? 'Pasien';
    final reportData = row['reports'] as Map<String, dynamic>?;
    final reportId = reportData?['id'] as String? ?? row['report_id'] as String? ?? '';

    final confirm = await AppConfirmSheet.show(
      context,
      title: 'Hapus dari Server?',
      message: 'Hapus laporan yang berisi data "$nama" dari server? Tindakan ini tidak bisa dibatalkan.',
      confirmLabel: 'Hapus dari Server',
      isDangerous: true,
    );

    if (confirm != true || reportId.isEmpty) return;

    final error = await SupabaseService.adminDeleteReport(reportId);
    if (!mounted) return;
    if (error != null) {
      AppToast.show(
        context,
        error,
        kind: AppToastKind.error,
      );
    } else {
      AppToast.show(
        context,
        'Laporan berhasil dihapus dari server',
        kind: AppToastKind.success,
      );
      if (_searchQuery.length >= 2) {
        _performGlobalSearch(_searchQuery);
      } else {
        _loadAllGlobal();
      }
    }
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.textMuted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _healthChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.primaryDeep.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: AppTheme.primaryDeep,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // DETAIL & PREVIEW SHEETS
  // ─────────────────────────────────────────────

  void _showGlobalReportDetailSheet(Map<String, dynamic> report) {
    final no = report['no'] as int? ?? 0;
    final kader = report['user_nama'] as String? ?? 'Petugas';
    final puskesmas = report['user_puskesmas'] as String? ?? '';
    final exams = report['resident_exams'] as List? ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryDeep.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Laporan #$no',
                      style: const TextStyle(
                        color: AppTheme.primaryDeep,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kader,
                          style: const TextStyle(
                            color: AppTheme.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (puskesmas.isNotEmpty)
                          Text(
                            'Puskesmas $puskesmas',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryDeep.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${exams.length} Pasien',
                      style: const TextStyle(
                        color: AppTheme.primaryDeep,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(color: AppTheme.outline),
              const SizedBox(height: 4),
              Expanded(
                child: exams.isEmpty
                    ? const Center(
                        child: Text('Tidak ada data pasien', style: TextStyle(color: AppTheme.textSecondary)),
                      )
                    : ListView.separated(
                        controller: scrollCtrl,
                        itemCount: exams.length,
                        separatorBuilder: (_, __) => const Divider(color: AppTheme.outline, height: 1),
                        itemBuilder: (_, i) {
                          final exam = exams[i] as Map<String, dynamic>;
                          final nama = exam['nama'] as String? ?? '-';
                          final nik = exam['nik'] as String? ?? '';
                          final tanggal = exam['tanggal'] as String? ?? '';
                          final usia = exam['usia'] as String? ?? '';
                          final tensi = exam['tensi'] as String? ?? '';
                          final bb = exam['bb'] as String? ?? '';
                          final tb = exam['tb'] as String? ?? '';
                          final keluhan = (exam['keluhan'] as List?)?.join(', ') ?? '';

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceRaised,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              nama,
                                              style: const TextStyle(
                                                color: AppTheme.text,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () {
                                              final text =
                                                  'Nama: $nama${nik.isNotEmpty ? '\nNIK: $nik' : ''}${tanggal.isNotEmpty ? '\nTanggal: $tanggal' : ''}${usia.isNotEmpty ? '\nUsia: $usia thn' : ''}${tensi.isNotEmpty ? '\nTensi: $tensi' : ''}${bb.isNotEmpty ? '\nBB: $bb kg' : ''}${tb.isNotEmpty ? '\nTB: $tb cm' : ''}${keluhan.isNotEmpty ? '\nKeluhan: $keluhan' : ''}';
                                              Clipboard.setData(ClipboardData(text: text));
                                              AppToast.show(
                                                context,
                                                'Data pasien disalin ke clipboard',
                                                kind: AppToastKind.success,
                                              );
                                            },
                                            child: const Icon(
                                              Icons.copy_rounded,
                                              size: 16,
                                              color: AppTheme.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (nik.isNotEmpty)
                                        Text(
                                          'NIK: $nik',
                                          style: const TextStyle(color: AppTheme.primaryDeep, fontSize: 11),
                                        ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          if (tanggal.isNotEmpty) _infoChip(Icons.calendar_today_rounded, tanggal),
                                          if (usia.isNotEmpty) _infoChip(Icons.cake_rounded, '$usia thn'),
                                          if (tensi.isNotEmpty) _healthChip('Tensi', tensi),
                                          if (bb.isNotEmpty) _healthChip('BB', '$bb kg'),
                                          if (tb.isNotEmpty) _healthChip('TB', '$tb cm'),
                                        ],
                                      ),
                                      if (keluhan.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            'Keluhan: $keluhan',
                                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPatientDetailSheet(Map<String, dynamic> row) {
    final nama = row['nama'] as String? ?? '-';
    final nik = row['nik'] as String? ?? '';
    final alamat = row['alamat'] as String? ?? '-';
    final tanggal = row['tanggal'] as String? ?? '-';
    final usia = row['usia'] as String? ?? '-';
    final kategori = row['kategori_keluarga'] as String? ?? '';
    final tensi = row['tensi'] as String? ?? '';
    final bb = row['bb'] as String? ?? '';
    final tb = row['tb'] as String? ?? '';
    final lp = row['lingkar_pinggang'] as String? ?? '';
    final lila = row['lila'] as String? ?? '';
    final lika = row['lika'] as String? ?? '';
    final gd = row['gula_darah'] as String? ?? '';
    final keluhan = List<String>.from(row['keluhan'] as List? ?? []);
    final tindakLanjut = List<String>.from(row['tindak_lanjut'] as List? ?? []);
    final reportData = row['reports'] as Map<String, dynamic>?;
    final ownerNama = reportData?['user_nama'] as String? ?? 'Petugas';
    final ownerPuskesmas = reportData?['user_puskesmas'] as String? ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.94,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppTheme.outline, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryDeep.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      nama.isNotEmpty ? nama[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppTheme.primaryDeep,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nama,
                          style: const TextStyle(
                            color: AppTheme.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (nik.isNotEmpty)
                          Text(
                            'NIK: $nik',
                            style: const TextStyle(
                              color: AppTheme.primaryDeep,
                              fontSize: 13,
                              fontFamily: 'monospace',
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _copyPatientData(row),
                    icon: const AppIcon(AppGlyph.report, color: AppTheme.textMuted, size: 20),
                    tooltip: 'Salin Teks',
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _importToLocal(row);
                    },
                    icon: const AppIcon(AppGlyph.plus, color: AppTheme.primaryDeep, size: 20),
                    tooltip: 'Simpan ke Lokal',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _detailSection('Identitas Pasien', [
                      _detailRow('Tanggal', tanggal),
                      _detailRow('Usia', '$usia tahun'),
                      _detailRow('Alamat', alamat),
                      if (kategori.isNotEmpty) _detailRow('Kategori', kategori),
                    ]),
                    const SizedBox(height: 12),
                    _detailSection('Hasil Pemeriksaan', [
                      if (tensi.isNotEmpty) _detailRow('Tensi', tensi),
                      if (bb.isNotEmpty) _detailRow('Berat Badan', '$bb kg'),
                      if (tb.isNotEmpty) _detailRow('Tinggi Badan', '$tb cm'),
                      if (lp.isNotEmpty) _detailRow('Lingkar Pinggang', '$lp cm'),
                      if (lila.isNotEmpty) _detailRow('LILA', '$lila cm'),
                      if (lika.isNotEmpty) _detailRow('LIKA', '$lika cm'),
                      if (gd.isNotEmpty) _detailRow('Gula Darah', '$gd mg/dL'),
                    ]),
                    if (keluhan.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _detailSection('Keluhan', keluhan.map((k) => _detailRow('\u2022', k)).toList()),
                    ],
                    if (tindakLanjut.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _detailSection('Tindak Lanjut', tindakLanjut.map((t) => _detailRow('\u2022', t)).toList()),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceRaised,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const AppIcon(AppGlyph.patient, size: 18, color: AppTheme.textMuted),
                          const SizedBox(width: 8),
                          Text(
                            'Petugas: $ownerNama${ownerPuskesmas.isNotEmpty ? ' \u2022 PKM $ownerPuskesmas' : ''}',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReportPreviewSheet(Report report) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppTheme.outline, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryDeep.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '#${report.no}',
                      style: const TextStyle(
                        color: AppTheme.primaryDeep,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Laporan #${report.no}',
                          style: const TextStyle(
                            color: AppTheme.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${report.tanggalDisplay} \u2022 ${report.totalPasien} Pasien',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _copyReportData(report),
                    icon: const AppIcon(AppGlyph.report, color: AppTheme.textMuted, size: 20),
                    tooltip: 'Salin Teks',
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _editReport(report);
                    },
                    icon: const AppIcon(AppGlyph.edit, color: AppTheme.warning, size: 20),
                    tooltip: 'Edit',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: report.exams.length,
                  itemBuilder: (context, index) {
                    final exam = report.exams[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryDeep.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: AppTheme.primaryDeep,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      exam.nama.isNotEmpty ? exam.nama : '(Tanpa nama)',
                                      style: const TextStyle(
                                        color: AppTheme.text,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (exam.nik.isNotEmpty)
                                      Text(
                                        'NIK: ${exam.nik}',
                                        style: const TextStyle(
                                          color: AppTheme.primaryDeep,
                                          fontSize: 12,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _detailSection('Identitas Pasien', [
                            _detailRow('Tanggal', exam.tanggal),
                            if (exam.usia.isNotEmpty) _detailRow('Usia', '${exam.usia} tahun'),
                            if (exam.alamat.isNotEmpty) _detailRow('Alamat', exam.alamat),
                            if (exam.kategoriKeluarga.isNotEmpty) _detailRow('Kategori', exam.kategoriKeluarga),
                          ]),
                          const SizedBox(height: 8),
                          _detailSection('Hasil Pemeriksaan', [
                            if (exam.tensi.isNotEmpty) _detailRow('Tensi', exam.tensi),
                            if (exam.bb.isNotEmpty) _detailRow('Berat Badan', '${exam.bb} kg'),
                            if (exam.tb.isNotEmpty) _detailRow('Tinggi Badan', '${exam.tb} cm'),
                            if (exam.lingkarPinggang.isNotEmpty) _detailRow('Lingkar Pinggang', '${exam.lingkarPinggang} cm'),
                            if (exam.lila.isNotEmpty) _detailRow('LILA', '${exam.lila} cm'),
                            if (exam.lika.isNotEmpty) _detailRow('LIKA', '${exam.lika} cm'),
                            if (exam.gulaDarah.isNotEmpty) _detailRow('Gula Darah', '${exam.gulaDarah} mg/dL'),
                          ]),
                          if (exam.keluhan.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _detailSection('Keluhan', exam.keluhan.map((k) => _detailRow('\u2022', k)).toList()),
                          ],
                          if (exam.tindakLanjut.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _detailSection('Tindak Lanjut', exam.tindakLanjut.map((t) => _detailRow('\u2022', t)).toList()),
                          ],
                          if (index < report.exams.length - 1)
                            const Divider(color: AppTheme.outline, height: 24),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildExportSheetButton(
                      label: 'Ekspor PDF',
                      color: const Color(0xFFC0392B),
                      enabled: true,
                      onTap: () {
                        Navigator.pop(ctx);
                        _exportPdf([report]);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildExportSheetButton(
                      label: 'Ekspor DOCX',
                      color: AppTheme.primaryDeep,
                      enabled: true,
                      onTap: () {
                        Navigator.pop(ctx);
                        _exportDocx([report]);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // COPY & IMPORT HELPERS
  // ─────────────────────────────────────────────

  Future<void> _importToLocal(Map<String, dynamic> row) async {
    final exam = ResidentExam(
      tanggal: row['tanggal'] as String? ?? '',
      nama: row['nama'] as String? ?? '',
      nik: row['nik'] as String? ?? '',
      usia: row['usia'] as String? ?? '',
      alamat: row['alamat'] as String? ?? '',
      kategoriKeluarga: row['kategori_keluarga'] as String? ?? '',
      bb: row['bb'] as String? ?? '',
      tb: row['tb'] as String? ?? '',
      lingkarPinggang: row['lingkar_pinggang'] as String? ?? '',
      tensi: row['tensi'] as String? ?? '',
      lila: row['lila'] as String? ?? '',
      lika: row['lika'] as String? ?? '',
      gulaDarah: row['gula_darah'] as String? ?? '',
      keluhan: List<String>.from(row['keluhan'] as List? ?? []),
      tindakLanjut: List<String>.from(row['tindak_lanjut'] as List? ?? []),
    );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportFormScreen(
          session: widget.session,
          initialExams: [exam],
        ),
      ),
    ).then((_) => _loadReports());

    AppToast.show(
      context,
      'Data "${exam.nama}" masuk ke laporan baru',
      kind: AppToastKind.success,
    );
  }

  void _copyPatientData(Map<String, dynamic> row) {
    final lines = <String>[];
    void add(String label, dynamic value) {
      if (value != null && value.toString().isNotEmpty) lines.add('$label: $value');
    }

    add('Nama', row['nama']);
    add('NIK', row['nik']);
    add('Tanggal', row['tanggal']);
    add('Usia', '${row['usia']} tahun');
    add('Alamat', row['alamat']);
    add('Kategori', row['kategori_keluarga']);
    add('Tensi', row['tensi']);
    add('BB', '${row['bb']} kg');
    add('TB', '${row['tb']} cm');
    add('Lingkar Pinggang', '${row['lingkar_pinggang']} cm');
    add('LILA', '${row['lila']} cm');
    add('LIKA', '${row['lika']} cm');
    add('Gula Darah', '${row['gula_darah']} mg/dL');
    final keluhan = List<String>.from(row['keluhan'] as List? ?? []);
    if (keluhan.isNotEmpty) lines.add('Keluhan: ${keluhan.join(", ")}');
    final tl = List<String>.from(row['tindak_lanjut'] as List? ?? []);
    if (tl.isNotEmpty) lines.add('Tindak Lanjut: ${tl.join(", ")}');

    final reportData = row['reports'] as Map<String, dynamic>?;
    final owner = reportData?['user_nama'] as String? ?? '';
    final pkm = reportData?['user_puskesmas'] as String? ?? '';
    if (owner.isNotEmpty) lines.add('Petugas: $owner${pkm.isNotEmpty ? ' (PKM $pkm)' : ''}');

    Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (mounted) {
      AppToast.show(
        context,
        'Data pasien disalin ke clipboard',
        kind: AppToastKind.success,
      );
    }
  }

  void _copyReportData(Report report) {
    final buf = StringBuffer();
    buf.writeln('Laporan #${report.no} — ${report.tanggalDisplay}');
    buf.writeln('Total Pasien: ${report.totalPasien}');
    buf.writeln('\u2500' * 30);
    for (var i = 0; i < report.exams.length; i++) {
      final e = report.exams[i];
      buf.writeln('\nPasien ${i + 1}: ${e.nama}');
      if (e.nik.isNotEmpty) buf.writeln('  NIK: ${e.nik}');
      buf.writeln('  Tanggal: ${e.tanggal}');
      if (e.usia.isNotEmpty) buf.writeln('  Usia: ${e.usia} tahun');
      if (e.alamat.isNotEmpty) buf.writeln('  Alamat: ${e.alamat}');
      if (e.tensi.isNotEmpty) buf.writeln('  Tensi: ${e.tensi}');
      if (e.bb.isNotEmpty) buf.writeln('  BB: ${e.bb} kg');
      if (e.tb.isNotEmpty) buf.writeln('  TB: ${e.tb} cm');
      if (e.lingkarPinggang.isNotEmpty) buf.writeln('  LP: ${e.lingkarPinggang} cm');
      if (e.lila.isNotEmpty) buf.writeln('  LILA: ${e.lila} cm');
      if (e.lika.isNotEmpty) buf.writeln('  LIKA: ${e.lika} cm');
      if (e.gulaDarah.isNotEmpty) buf.writeln('  Gula Darah: ${e.gulaDarah} mg/dL');
      if (e.keluhan.isNotEmpty) buf.writeln('  Keluhan: ${e.keluhan.join(", ")}');
      if (e.tindakLanjut.isNotEmpty) buf.writeln('  Tindak Lanjut: ${e.tindakLanjut.join(", ")}');
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    if (mounted) {
      AppToast.show(
        context,
        'Data laporan disalin ke clipboard',
        kind: AppToastKind.success,
      );
    }
  }

  // ─────────────────────────────────────────────
  // DETAIL WIDGETS
  // ─────────────────────────────────────────────

  Widget _detailSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.primaryDeep,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    if (value.isEmpty || value == ' tahun' || value == ' cm' || value == ' kg' || value == ' mg/dL') {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: label == '\u2022' ? 16 : 100,
            child: Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: AppTheme.text, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
