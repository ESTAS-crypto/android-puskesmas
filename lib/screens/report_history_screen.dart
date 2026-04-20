import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../models/report.dart';
import '../models/resident_exam.dart';
import '../models/user_session.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
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
  String _searchQuery = '';
  bool _isGlobalMode = false;
  bool _isGlobalSearching = false;
  List<Map<String, dynamic>> _globalResults = [];
  Timer? _debounceTimer;

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
    _loadReports();
  }

  Future<void> _loadReports() async {
    final reports = await StorageService.getReports();
    if (mounted) {
      setState(() {
        _reports = reports;
        _isLoading = false;
      });

      // Auto-sync semua laporan lokal ke cloud (fire-and-forget)
      if (SupabaseService.isLoggedIn && reports.isNotEmpty) {
        SupabaseService.syncAllToCloud(reports).catchError((_) {});
      }

      // Auto-cleanup laporan lokal lama (berdasarkan remote config admin)
      StorageService.cleanupOldLocalData().then((deletedCount) {
        if (deletedCount > 0 && mounted) {
          // Reload reports setelah cleanup
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Laporan?', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Laporan ${report.no} — ${report.totalPasien} pasien — akan dihapus permanen.',
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
                        '${selectedIds.length} dari ${_filteredReports.length} laporan dipilih',
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
                                    selectedIds.addAll(_filteredReports.map((r) => r.id));
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
                          itemCount: _filteredReports.length,
                          itemBuilder: (context, index) {
                            final report = _filteredReports[index];
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
                                                report.summaryNames,
                                                style: const TextStyle(
                                                  color: AppTheme.textPrimary,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                '${report.tanggalDisplay} • ${report.totalPasien} Pasien',
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
                            child: _buildExportButton(
                              icon: Icons.description_rounded,
                              title: 'DOCX',
                              color: const Color(0xFF448AFF),
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
              path.split(RegExp(r'[\\/]')).last,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Share.shareXFiles([XFile(path)]);
                },
                icon: const Icon(Icons.share_rounded),
                label: const Text('Bagikan File'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentTeal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  OpenFile.open(path);
                },
                icon: const Icon(Icons.open_in_new_rounded, color: AppTheme.accentTeal),
                label: const Text('Buka File', style: TextStyle(color: AppTheme.accentTeal)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.accentTeal),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 4),
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
                    if (_filteredReports.isNotEmpty)
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

              // Search Bar + Global Toggle
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (val) {
                          _debounceTimer?.cancel();
                          _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                            if (!mounted) return;
                            setState(() => _searchQuery = val);
                          });
                        },
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: _isGlobalMode
                              ? 'Cari nama kader, nama pasien, atau NIK...'
                              : 'Cari nama, NIK, alamat, atau tanggal...',
                          hintStyle: const TextStyle(color: AppTheme.textHint),
                          prefixIcon: Icon(
                            _isGlobalMode ? Icons.public_rounded : Icons.search_rounded,
                            color: _isGlobalMode ? const Color(0xFF4CAF50) : AppTheme.textHint,
                          ),
                          filled: true,
                          fillColor: AppTheme.cardDark,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: _isGlobalMode
                                ? const BorderSide(color: Color(0xFF4CAF50), width: 1.5)
                                : BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: _isGlobalMode
                                ? BorderSide(color: const Color(0xFF4CAF50).withValues(alpha: 0.5), width: 1.5)
                                : BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: _isGlobalMode ? const Color(0xFF4CAF50) : AppTheme.accentTeal,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Global toggle button
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isGlobalMode = !_isGlobalMode;
                          _globalResults = [];
                        });
                        if (_isGlobalMode) {
                          _loadAllGlobal();
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _isGlobalMode
                              ? const Color(0xFF4CAF50).withValues(alpha: 0.15)
                              : AppTheme.cardDark,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _isGlobalMode
                                ? const Color(0xFF4CAF50).withValues(alpha: 0.5)
                                : AppTheme.divider,
                          ),
                        ),
                        child: Icon(
                          _isGlobalMode ? Icons.public_rounded : Icons.public_off_rounded,
                          color: _isGlobalMode ? const Color(0xFF4CAF50) : AppTheme.textHint,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Global mode indicator
              if (_isGlobalMode)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.public_rounded, color: Color(0xFF4CAF50), size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mode Global — Menampilkan data semua petugas. Bisa cari nama petugas',
                          style: TextStyle(color: Color(0xFF4CAF50), fontSize: 11),
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
                    : _isGlobalMode
                        ? _buildGlobalResults()
                        : _filteredReports.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.search_off_rounded, size: 64, color: AppTheme.textHint),
                                    const SizedBox(height: 16),
                                    Text(
                                      _reports.isEmpty ? 'Belum ada laporan' : 'Laporan tidak ditemukan',
                                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _filteredReports.length,
                                itemBuilder: (context, index) {
                                  final report = _filteredReports[index];
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

  Future<void> _loadAllGlobal() async {
    setState(() => _isGlobalSearching = true);
    final results = await SupabaseService.globalGetAllExams();
    if (mounted) setState(() { _globalResults = results; _isGlobalSearching = false; });
  }

  Future<void> _performGlobalSearch(String query) async { }

  Widget _buildGlobalResults() {
    if (_isGlobalSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF4CAF50)),
            SizedBox(height: 16),
            Text('Memuat semua data...', style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    final filtered = _searchQuery.isEmpty ? _globalResults : _globalResults.where((row) {
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
            Icon(Icons.search_off_rounded, size: 64, color: AppTheme.textHint),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? 'Belum ada data di server' : 'Tidak ada hasil untuk "$_searchQuery"',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.people_alt_rounded, size: 14, color: Color(0xFF4CAF50)),
              const SizedBox(width: 6),
              Text(
                '${filtered.length} pasien',
                style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final row = filtered[index];
              return _buildGlobalResultCard(row);
            },
          ),
        ),
      ],
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

    // Extract owner info from joined reports table
    final reportData = row['reports'] as Map<String, dynamic>?;
    final ownerNama = reportData?['user_nama'] as String? ?? 'Petugas';
    final ownerPuskesmas = reportData?['user_puskesmas'] as String? ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showPatientDetailSheet(row),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nama pasien + badge + copy button
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4CAF50), Color(0xFF00BCD4)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        nama.isNotEmpty ? nama[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
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
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (nik.isNotEmpty)
                            Text(
                              'NIK: $nik',
                              style: TextStyle(
                                color: AppTheme.accentTeal.withValues(alpha: 0.8),
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Import button
                    IconButton(
                      onPressed: () => _importToLocal(row),
                      icon: const Icon(Icons.download_rounded, size: 18, color: AppTheme.textHint),
                      tooltip: 'Simpan ke Lokal',
                      visualDensity: VisualDensity.compact,
                    ),
                    // Admin: Hapus dari cloud
                    if (widget.session.isAdmin)
                      IconButton(
                        onPressed: () => _deleteGlobalExam(row),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.error),
                        tooltip: 'Hapus dari Server',
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Detail info
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _infoChip(Icons.calendar_today_rounded, tanggal),
                    _infoChip(Icons.cake_rounded, '$usia thn'),
                    _infoChip(Icons.location_on_outlined, alamat),
                  ],
                ),

                // Health data preview
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
                // Owner / Puskesmas info
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 14, color: AppTheme.textHint),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '$ownerNama${ownerPuskesmas.isNotEmpty ? ' \u2022 PKM $ownerPuskesmas' : ''}',
                          style: const TextStyle(color: AppTheme.textHint, fontSize: 11),
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
        ),
      ),
    );
  }

  Future<void> _deleteGlobalExam(Map<String, dynamic> row) async {
    final nama = row['nama'] as String? ?? 'Pasien';
    final reportData = row['reports'] as Map<String, dynamic>?;
    final reportId = reportData?['id'] as String? ?? row['report_id'] as String? ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus dari Server?', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Hapus laporan yang berisi data "$nama" dari server?\n\nTindakan ini tidak bisa dibatalkan.',
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

    if (confirm != true || reportId.isEmpty) return;

    final error = await SupabaseService.adminDeleteReport(reportId);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppTheme.error),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Laporan berhasil dihapus dari server'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
      // Refresh global search
      if (_searchQuery.length >= 2) {
        _performGlobalSearch(_searchQuery);
      }
    }
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.textHint),
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
        color: AppTheme.accentTeal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(color: AppTheme.accentTeal.withValues(alpha: 0.9), fontSize: 11, fontWeight: FontWeight.w500),
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
          onTap: () => _showReportPreviewSheet(report),
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
                        report.summaryNames,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${report.tanggalDisplay} \u2022 ${report.totalPasien} Pasien',
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
                          Icon(Icons.visibility_rounded, color: AppTheme.accentBlue, size: 18),
                          SizedBox(width: 8),
                          Text('Preview', style: TextStyle(color: AppTheme.textPrimary)),
                        ],
                      ),
                    ),
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
                      value: 'copy',
                      child: Row(
                        children: [
                          Icon(Icons.copy_rounded, color: AppTheme.warning, size: 18),
                          SizedBox(width: 8),
                          Text('Salin Data', style: TextStyle(color: AppTheme.textPrimary)),
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

  // ─────────────────────────────────────────────
  // DETAIL / PREVIEW SHEETS
  // ─────────────────────────────────────────────

  /// Detail bottom sheet untuk hasil global search
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
      backgroundColor: AppTheme.cardDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Handle
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              // Header
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF00BCD4)]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(nama.isNotEmpty ? nama[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nama, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                        if (nik.isNotEmpty) Text('NIK: $nik', style: TextStyle(color: AppTheme.accentTeal.withValues(alpha: 0.8), fontSize: 13, fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      _copyPatientData(row);
                    },
                    icon: const Icon(Icons.copy_rounded, color: AppTheme.textHint, size: 20),
                    tooltip: 'Salin Teks',
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _importToLocal(row);
                    },
                    icon: const Icon(Icons.download_rounded, color: AppTheme.accentTeal),
                    tooltip: 'Simpan ke Lokal',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Content
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
                      _detailSection('Keluhan', keluhan.map((k) => _detailRow('•', k)).toList()),
                    ],
                    if (tindakLanjut.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _detailSection('Tindak Lanjut', tindakLanjut.map((t) => _detailRow('•', t)).toList()),
                    ],
                    const SizedBox(height: 12),
                    // Owner info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppTheme.surfaceDark, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 18, color: AppTheme.textHint),
                          const SizedBox(width: 8),
                          Text('Petugas: $ownerNama${ownerPuskesmas.isNotEmpty ? ' \u2022 PKM $ownerPuskesmas' : ''}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
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

  /// Preview bottom sheet untuk laporan lokal — layout sama dengan global
  void _showReportPreviewSheet(Report report) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Handle
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              // Header
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(14)),
                    alignment: Alignment.center,
                    child: Text('${report.no}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Laporan #${report.no}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                        Text('${report.tanggalDisplay} \u2022 ${report.totalPasien} Pasien', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () { _copyReportData(report); },
                    icon: const Icon(Icons.copy_rounded, color: AppTheme.textHint, size: 20),
                    tooltip: 'Salin Teks',
                  ),
                  IconButton(
                    onPressed: () { Navigator.pop(ctx); _editReport(report); },
                    icon: const Icon(Icons.edit_rounded, color: AppTheme.warning),
                    tooltip: 'Edit',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Patient list — same style as global
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
                          // Pasien header
                          Row(
                            children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(10)),
                                alignment: Alignment.center,
                                child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(exam.nama.isNotEmpty ? exam.nama : '(Tanpa nama)', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                                    if (exam.nik.isNotEmpty)
                                      Text('NIK: ${exam.nik}', style: TextStyle(color: AppTheme.accentTeal.withValues(alpha: 0.8), fontSize: 12, fontFamily: 'monospace')),
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
                            Divider(color: AppTheme.divider, height: 24),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Export buttons
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () { Navigator.pop(ctx); _exportPdf([report]); },
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                      label: const Text('Export PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5252).withValues(alpha: 0.15),
                        foregroundColor: const Color(0xFFFF5252),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () { Navigator.pop(ctx); _exportDocx([report]); },
                      icon: const Icon(Icons.description_rounded, size: 18),
                      label: const Text('Export DOCX'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF448AFF).withValues(alpha: 0.15),
                        foregroundColor: const Color(0xFF448AFF),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
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

  /// Import data pasien dari global search ke laporan lokal baru
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('\u2705 Data "${exam.nama}" masuk ke laporan baru — silakan edit & simpan'),
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 3),
      ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('\u2705 Data pasien disalin ke clipboard'), backgroundColor: Color(0xFF4CAF50), duration: Duration(seconds: 2)),
      );
    }
  }

  void _copyReportData(Report report) {
    final buf = StringBuffer();
    buf.writeln('Laporan #${report.no} — ${report.tanggalDisplay}');
    buf.writeln('Total Pasien: ${report.totalPasien}');
    buf.writeln('─' * 30);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('\u2705 Data laporan disalin ke clipboard'), backgroundColor: AppTheme.accentTeal, duration: Duration(seconds: 2)),
      );
    }
  }

  // ─────────────────────────────────────────────
  // DETAIL SHEET WIDGETS
  // ─────────────────────────────────────────────

  Widget _detailSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppTheme.accentTeal, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    if (value.isEmpty || value == ' tahun' || value == ' cm' || value == ' kg' || value == ' mg/dL') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: label == '•' ? 16 : 100,
            child: Text(label, style: const TextStyle(color: AppTheme.textHint, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
