import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import '../theme/app_theme.dart';
import '../models/report.dart';
import '../models/user_session.dart';
import '../services/pdf_service.dart';
import '../services/docx_service.dart';
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

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0, 0.6, curve: Curves.elasticOut),
      ),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.3, 1, curve: Curves.easeOut),
      ),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _goToDashboard() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => DashboardScreen(session: widget.session)),
      (route) => false,
    );
  }

  void _createNew() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ReportFormScreen(session: widget.session)),
    );
  }

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);
    try {
      final path = await PdfService.generatePdf(
        reports: [widget.report],
        session: widget.session,
      );
      setState(() => _isExporting = false);
      if (!mounted) return;
      _showSuccess(path, 'PDF');
    } catch (e) {
      setState(() => _isExporting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e'), backgroundColor: AppTheme.error),
      );
    }
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
      _showSuccess(path, 'DOCX');
    } catch (e) {
      setState(() => _isExporting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  void _showSuccess(String path, String type) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.success),
            const SizedBox(width: 8),
            Expanded(child: Text('File $type berhasil dibuat!')),
          ],
        ),
        backgroundColor: AppTheme.cardDark,
        action: SnackBarAction(
          label: 'Buka',
          textColor: AppTheme.accentTeal,
          onPressed: () => OpenFile.open(path),
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
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Success Animation
                ScaleTransition(
                  scale: _scaleAnim,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF00BFA6)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.success.withValues(alpha: 0.3),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 50),
                  ),
                ),
                const SizedBox(height: 24),

                FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    children: [
                      const Text(
                        'Laporan Tersimpan!',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Data kunjungan ${widget.report.nama} berhasil disimpan',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // Report summary card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: AppTheme.glassDecoration(opacity: 0.06),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSummaryRow('Nama', widget.report.nama),
                            _buildSummaryRow('Tanggal', widget.report.tanggal),
                            _buildSummaryRow('Alamat', widget.report.alamat),
                            _buildSummaryRow('Keluhan', '${widget.report.keluhan.length} item'),
                            _buildSummaryRow('Tindak Lanjut', '${widget.report.tindakLanjut.length} item'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Export buttons
                      const Text(
                        'Ekspor Laporan Ini',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildExportButton(
                              icon: Icons.picture_as_pdf_rounded,
                              label: 'PDF',
                              color: const Color(0xFFFF5252),
                              onTap: _isExporting ? null : _exportPdf,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildExportButton(
                              icon: Icons.description_rounded,
                              label: 'Word',
                              color: const Color(0xFF448AFF),
                              onTap: _isExporting ? null : _exportDocx,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Action buttons
                FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _createNew,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_rounded, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    'Buat Laporan Baru',
                                    style: TextStyle(
                                      color: Colors.white,
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
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _goToDashboard,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.divider),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.dashboard_rounded, color: AppTheme.textSecondary),
                              SizedBox(width: 8),
                              Text(
                                'Kembali ke Dashboard',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                              ),
                            ],
                          ),
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

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: AppTheme.textHint, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
