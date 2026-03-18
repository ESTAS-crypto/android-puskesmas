import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import '../theme/app_theme.dart';
import '../models/report.dart';
import '../models/user_session.dart';
import '../services/storage_service.dart';
import '../services/pdf_service.dart';
import '../services/docx_service.dart';
import 'report_form_screen.dart';

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
  bool _isLoading = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    final reports = await StorageService.getReports();
    if (mounted) {
      setState(() {
        _reports = reports;
        _isLoading = false;
      });
      if (widget.showExportOnLoad && reports.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showExportDialog());
      }
    }
  }

  Future<void> _deleteReport(Report report) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Laporan?', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Laporan ${report.nama} akan dihapus permanen.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await StorageService.deleteReport(report.id);
      _loadReports();
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

  Future<void> _showExportDialog() async {
    // Use a Set to track selected report IDs — start with all selected
    final selectedIds = Set<String>.from(_reports.map((r) => r.id));

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final allSelected = selectedIds.length == _reports.length;
            final noneSelected = selectedIds.isEmpty;

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle bar
                      Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Title
                      const Text(
                        'Ekspor Laporan',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${selectedIds.length} dari ${_reports.length} laporan dipilih',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 12),

                      // Select All / Deselect All button
                      Row(
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              onPressed: () {
                                setSheetState(() {
                                  if (allSelected) {
                                    selectedIds.clear();
                                  } else {
                                    selectedIds.addAll(_reports.map((r) => r.id));
                                  }
                                });
                              },
                              icon: Icon(
                                allSelected
                                    ? Icons.deselect_rounded
                                    : Icons.select_all_rounded,
                                color: AppTheme.accentTeal,
                                size: 18,
                              ),
                              label: Text(
                                allSelected ? 'Hapus Semua Pilihan' : 'Pilih Semua',
                                style: const TextStyle(color: AppTheme.accentTeal, fontSize: 13),
                              ),
                              style: TextButton.styleFrom(
                                backgroundColor: AppTheme.accentTeal.withValues(alpha: 0.1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Report list with checkboxes
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: _reports.length,
                          itemBuilder: (context, index) {
                            final report = _reports[index];
                            final isSelected = selectedIds.contains(report.id);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.accentTeal.withValues(alpha: 0.08)
                                    : AppTheme.surfaceDark,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.accentTeal.withValues(alpha: 0.3)
                                      : AppTheme.divider,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
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
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    child: Row(
                                      children: [
                                        // Checkbox
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? AppTheme.accentTeal
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isSelected
                                                  ? AppTheme.accentTeal
                                                  : AppTheme.textHint,
                                              width: 2,
                                            ),
                                          ),
                                          child: isSelected
                                              ? const Icon(
                                                  Icons.check_rounded,
                                                  color: Colors.white,
                                                  size: 16,
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 12),

                                        // Number badge
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            gradient: AppTheme.primaryGradient,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '${report.no}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),

                                        // Report info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                report.nama,
                                                style: const TextStyle(
                                                  color: AppTheme.textPrimary,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              Text(
                                                '${report.tanggal} • ${report.alamat}',
                                                style: const TextStyle(
                                                  color: AppTheme.textSecondary,
                                                  fontSize: 11,
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

                      const SizedBox(height: 12),

                      // Export buttons
                      Row(
                        children: [
                          Expanded(
                            child: _buildExportButton(
                              icon: Icons.picture_as_pdf_rounded,
                              title: 'PDF',
                              color: const Color(0xFFFF5252),
                              enabled: !noneSelected,
                              onTap: () {
                                final selectedReports = _reports
                                    .where((r) => selectedIds.contains(r.id))
                                    .toList();
                                Navigator.pop(ctx);
                                _exportPdf(selectedReports);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildExportButton(
                              icon: Icons.description_rounded,
                              title: 'DOCX',
                              color: const Color(0xFF448AFF),
                              enabled: !noneSelected,
                              onTap: () {
                                final selectedReports = _reports
                                    .where((r) => selectedIds.contains(r.id))
                                    .toList();
                                Navigator.pop(ctx);
                                _exportDocx(selectedReports);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
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

  Widget _buildExportButton({
    required IconData icon,
    required String title,
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
            color: enabled
                ? color.withValues(alpha: 0.15)
                : AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: enabled
                  ? color.withValues(alpha: 0.3)
                  : AppTheme.divider,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: enabled ? color : AppTheme.textHint, size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: enabled ? AppTheme.textPrimary : AppTheme.textHint,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal export PDF: $e'), backgroundColor: AppTheme.error),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal export DOCX: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  void _showExportSuccess(String path, String type) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              'File $type Berhasil Dibuat!',
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              path.split('/').last,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  OpenFile.open(path);
                },
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Buka File'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentTeal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup', style: TextStyle(color: AppTheme.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary, size: 20),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Riwayat Laporan',
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (_reports.isNotEmpty)
                      IconButton(
                        onPressed: _isExporting ? null : _showExportDialog,
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.accentTeal.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.file_download_rounded, color: AppTheme.accentTeal, size: 20),
                        ),
                      ),
                  ],
                ),
              ),

              // Loading / exporting overlay
              if (_isExporting)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: LinearProgressIndicator(
                    backgroundColor: AppTheme.surfaceDark,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentTeal),
                  ),
                ),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.accentTeal))
                    : _reports.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox_rounded, size: 64, color: AppTheme.textHint),
                                const SizedBox(height: 16),
                                const Text(
                                  'Belum ada laporan',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _reports.length,
                            itemBuilder: (context, index) {
                              final report = _reports[index];
                              return _buildReportCard(report);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard(Report report) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _editReport(report),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${report.no}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.nama,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${report.tanggal} • ${report.alamat}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  color: AppTheme.cardDark,
                  icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textHint),
                  onSelected: (value) {
                    if (value == 'edit') _editReport(report);
                    if (value == 'delete') _deleteReport(report);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, color: AppTheme.accentTeal, size: 18),
                          SizedBox(width: 8),
                          Text('Edit', style: TextStyle(color: AppTheme.textPrimary)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 18),
                          SizedBox(width: 8),
                          Text('Hapus', style: TextStyle(color: AppTheme.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
