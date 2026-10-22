import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import '../models/report.dart';
import '../models/user_session.dart';
import '../services/docx_service.dart';
import '../services/pdf_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/ui.dart';
import 'dashboard_screen.dart';
import 'report_form_screen.dart';

class SuccessScreen extends StatefulWidget {
  final UserSession session;
  final Report report;

  const SuccessScreen({
    super.key,
    required this.session,
    required this.report,
  });

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  bool _isExporting = false;
  bool _isPending = false;
  String? _lastGeneratedPath;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    );
    _animController.forward();

    _checkSyncStatus();
  }

  Future<void> _checkSyncStatus() async {
    final pendingIds = await StorageService.getPendingSyncIds();
    if (mounted) {
      setState(() {
        _isPending = pendingIds.contains(widget.report.id);
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _goToDashboard() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
          builder: (_) => DashboardScreen(session: widget.session)),
      (route) => false,
    );
  }

  void _createNew() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (_) => ReportFormScreen(session: widget.session)),
    );
  }

  Future<String?> _ensureFileGenerated() async {
    if (_lastGeneratedPath != null) return _lastGeneratedPath;
    try {
      final path = await PdfService.generatePdf(
        reports: [widget.report],
        session: widget.session,
      );
      _lastGeneratedPath = path;
      return path;
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Gagal membuat file PDF: $e',
            kind: AppToastKind.error);
      }
      return null;
    }
  }

  Future<void> _shareFile() async {
    setState(() => _isExporting = true);
    final path = await _ensureFileGenerated();
    setState(() => _isExporting = false);
    if (path == null) return;
    await Share.shareXFiles([XFile(path)]);
  }

  Future<void> _openFile() async {
    setState(() => _isExporting = true);
    final path = await _ensureFileGenerated();
    setState(() => _isExporting = false);
    if (path == null) return;
    await OpenFile.open(path);
  }

  Future<void> _exportDocx() async {
    setState(() => _isExporting = true);
    try {
      final path = await DocxService.generateDocx(
        reports: [widget.report],
        session: widget.session,
      );
      setState(() => _isExporting = false);
      if (!mounted) return;
      AppToast.show(context, 'File Word (.docx) berhasil dibuat',
          kind: AppToastKind.success);
      await OpenFile.open(path);
    } catch (e) {
      setState(() => _isExporting = false);
      if (!mounted) return;
      AppToast.show(context, 'Gagal: $e', kind: AppToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPasien = widget.report.totalPasien;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Container(
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Triple Concentric Circles Hero ──
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: Container(
                      width: 176,
                      height: 176,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0A64A8).withValues(alpha: 0.07),
                      ),
                      child: Center(
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF0A64A8).withValues(alpha: 0.12),
                          ),
                          child: Center(
                            child: Container(
                              width: 86,
                              height: 86,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF0A64A8),
                              ),
                              child: const Center(
                                child: AppIcon(
                                  AppGlyph.check,
                                  color: Colors.white,
                                  size: 44,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Title & Message ──
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      children: [
                        const Text(
                          'Laporan tersimpan',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isPending
                              ? '$totalPasien data pasien aman di HP Anda.'
                              : '$totalPasien data pasien berhasil disimpan dalam laporan ini.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 16,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Status Pills
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            const StatusPill(
                              label: 'Tersimpan di perangkat',
                              color: AppTheme.success,
                            ),
                            if (_isPending)
                              const StatusPill(
                                label: 'Menunggu sinyal',
                                color: AppTheme.warning,
                                icon: AppGlyph.cloud,
                              )
                            else
                              const StatusPill(
                                label: 'Terkirim ke server',
                                color: AppTheme.success,
                                icon: AppGlyph.check,
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Offline Info Banner (From SuksesOffline.dc.html)
                        if (_isPending) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppTheme.divider),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color.fromRGBO(11, 42, 64, 0.05),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Color(0xFFEAF3FA),
                                    borderRadius: BorderRadius.all(Radius.circular(12)),
                                  ),
                                  child: AppIcon(
                                    AppGlyph.cloud,
                                    color: Color(0xFF0A64A8),
                                    size: 20,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Tidak perlu melakukan apa-apa. Laporan dikirim otomatis saat HP kembali online.',
                                    style: TextStyle(
                                      color: Color(0xFF4A667E),
                                      fontSize: 14,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // ── Summary Card ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppTheme.divider),
                            boxShadow: const [
                              BoxShadow(
                                color: Color.fromRGBO(11, 42, 64, 0.04),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _summaryRow('Laporan', '#${widget.report.no}'),
                              _summaryRow('Tanggal', widget.report.tanggalDisplay),
                              _summaryRow('Pasien', '$totalPasien orang'),
                              _summaryRow('Daftar Nama', widget.report.summaryNames),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Primary Actions (Matching Sukses.dc.html) ──
                        AppButton(
                          label: 'Bagikan file (PDF)',
                          icon: AppGlyph.export,
                          loading: _isExporting,
                          kind: AppButtonKind.primary,
                          onPressed: _shareFile,
                        ),
                        const SizedBox(height: 10),
                        AppButton(
                          label: 'Buka file (PDF)',
                          kind: AppButtonKind.tonal,
                          onPressed: _openFile,
                        ),
                        const SizedBox(height: 10),
                        AppButton(
                          label: 'Ekspor ke Word (.docx)',
                          kind: AppButtonKind.tonal,
                          onPressed: _exportDocx,
                        ),
                        const SizedBox(height: 16),

                        // Secondary Actions
                        Row(
                          children: [
                            Expanded(
                              child: AppButton(
                                label: 'Buat Baru',
                                icon: AppGlyph.plus,
                                kind: AppButtonKind.ghost,
                                onPressed: _createNew,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: AppButton(
                                label: 'Beranda',
                                kind: AppButtonKind.ghost,
                                onPressed: _goToDashboard,
                              ),
                            ),
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

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF4A667E),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
