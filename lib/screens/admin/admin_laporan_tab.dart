import 'package:flutter/material.dart';
import '../../models/user_session.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../widgets/ui/ui.dart';

/// Tab 2 Panel Admin: Kelola Laporan & Auto-Delete
/// Desain sesuai mockups/main-canvas/AdminLaporan.dc.html
class AdminLaporanTab extends StatefulWidget {
  final UserSession session;
  final List<Map<String, dynamic>> reports;
  final bool loading;
  final int totalExamCount;
  final int reportDeleteValue;
  final String reportDeleteUnit;
  final int localDeleteValue;
  final String localDeleteUnit;
  final Future<void> Function() onRefresh;
  final Future<void> Function(int value, String unit) onSaveReportDelete;
  final Future<void> Function(int value, String unit) onSaveLocalDelete;
  final Future<void> Function(String reportId, int no) onShowDetail;
  final Future<void> Function(
    String reportId,
    int no,
    String ownerNama,
    String ownerPkm,
    String format,
  ) onExport;
  final Future<void> Function(String reportId, int no) onDeleteReport;
  final Future<void> Function(List<Map<String, dynamic>> oldReports)
      onDeleteOldReports;
  final void Function(Map<String, dynamic> report)? onEditReport;

  const AdminLaporanTab({
    super.key,
    required this.session,
    required this.reports,
    required this.loading,
    required this.totalExamCount,
    required this.reportDeleteValue,
    required this.reportDeleteUnit,
    required this.localDeleteValue,
    required this.localDeleteUnit,
    required this.onRefresh,
    required this.onSaveReportDelete,
    required this.onSaveLocalDelete,
    required this.onShowDetail,
    required this.onExport,
    required this.onDeleteReport,
    required this.onDeleteOldReports,
    this.onEditReport,
  });

  @override
  State<AdminLaporanTab> createState() => _AdminLaporanTabState();
}

class _AdminLaporanTabState extends State<AdminLaporanTab> {
  late int _val;
  late String _unit;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _val = widget.reportDeleteValue;
    _unit = widget.reportDeleteUnit;
  }

  @override
  void didUpdateWidget(AdminLaporanTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reportDeleteValue != widget.reportDeleteValue ||
        oldWidget.reportDeleteUnit != widget.reportDeleteUnit) {
      _val = widget.reportDeleteValue;
      _unit = widget.reportDeleteUnit;
    }
  }

  int _unitToDays(int value, String unit) {
    if (value <= 0) return 0;
    switch (unit) {
      case 'hari':
        return value;
      case 'minggu':
        return value * 7;
      case 'bulan':
        return value * 30;
      default:
        return value * 30;
    }
  }

  Future<void> _updateSettings(int newVal, String newUnit) async {
    setState(() {
      _val = newVal;
      _unit = newUnit;
      _saving = true;
    });
    try {
      await widget.onSaveReportDelete(newVal, newUnit);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatDate(String isoString) {
    if (isoString.isEmpty) return '-';
    try {
      final dt = DateTime.parse(isoString);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des'
      ];
      return '${dt.day} ${months[dt.month - 1]}';
    } catch (_) {
      return isoString;
    }
  }

  void _showExportSheet(Map<String, dynamic> report) {
    final reportId = report['id'] as String? ?? '';
    final no = report['no'] as int? ?? 0;
    final owner = report['user_nama'] as String? ?? 'Petugas';
    final pkm = report['user_puskesmas'] as String? ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.outline,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Cetak Laporan #$no',
              style: const TextStyle(
                color: AppTheme.text,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pilih format dokumen untuk diekspor atau dibagikan',
              style: const TextStyle(
                color: AppTheme.textFaint,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Format PDF',
                    icon: AppGlyph.export,
                    kind: AppButtonKind.tonal,
                    onPressed: () {
                      Navigator.pop(ctx);
                      widget.onExport(reportId, no, owner, pkm, 'pdf');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Format DOCX',
                    icon: AppGlyph.report,
                    kind: AppButtonKind.primary,
                    onPressed: () {
                      Navigator.pop(ctx);
                      widget.onExport(reportId, no, owner, pkm, 'docx');
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading && widget.reports.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      );
    }

    final deleteDays = _unitToDays(_val, _unit);
    final oldReports = widget.reports.where((r) {
      if (deleteDays <= 0) return false;
      final ca = r['created_at'] as String? ?? '';
      if (ca.isEmpty) return false;
      try {
        return DateTime.now().difference(DateTime.parse(ca)).inDays > deleteDays;
      } catch (_) {
        return false;
      }
    }).toList();

    return RefreshIndicator(
      color: AppTheme.accent,
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── Auto-Delete Card (AdminLaporan.dc.html line 33-36) ──
          _buildAutoDeleteCard(oldReports),

          const SizedBox(height: 14),

          // ── Section Title ──
          Row(
            children: [
              Text(
                'Daftar Laporan (${widget.reports.length})',
                style: const TextStyle(
                  color: AppTheme.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (widget.totalExamCount > 0)
                Text(
                  '${widget.totalExamCount} Pasien total',
                  style: const TextStyle(
                    color: AppTheme.textFaint,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Report List ──
          if (widget.reports.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'Belum ada laporan',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                ),
              ),
            )
          else
            ...widget.reports.map((r) => _buildReportCard(r, deleteDays)),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAutoDeleteCard(List<Map<String, dynamic>> oldReports) {
    final isEnabled = _val > 0;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: Header + Switch
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hapus otomatis laporan lama',
                      style: TextStyle(
                        color: AppTheme.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Dihitung dari tanggal laporan dibuat',
                      style: TextStyle(
                        color: AppTheme.textFaint,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: isEnabled,
                activeThumbColor: AppTheme.accent,
                activeTrackColor: AppTheme.accent.withValues(alpha: 0.3),
                onChanged: _saving
                    ? null
                    : (on) {
                        if (on) {
                          _updateSettings(3, _unit);
                        } else {
                          _updateSettings(0, _unit);
                        }
                      },
              ),
            ],
          ),

          if (isEnabled) ...[
            const SizedBox(height: 14),

            // Segmented Unit Tabs (Hari | Minggu | Bulan)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceRaised,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  _unitTab('Hari', 'hari'),
                  _unitTab('Minggu', 'minggu'),
                  _unitTab('Bulan', 'bulan'),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Stepper: [-] Number [+]
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _iconCircleButton(
                  icon: Icons.remove_rounded,
                  onTap: _saving || _val <= 1
                      ? null
                      : () => _updateSettings(_val - 1, _unit),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    '$_val',
                    style: const TextStyle(
                      color: AppTheme.text,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _iconCircleButton(
                  icon: Icons.add_rounded,
                  onTap: _saving || _val >= 365
                      ? null
                      : () => _updateSettings(_val + 1, _unit),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              'Laporan lebih tua dari $_val $_unit akan dihapus',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textFaint,
                fontSize: 13,
              ),
            ),

            if (oldReports.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppTheme.error.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const AppIcon(AppGlyph.warning, color: AppTheme.error, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${oldReports.length} laporan sudah melewati batas waktu.',
                        style: const TextStyle(
                          color: AppTheme.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => widget.onDeleteOldReports(oldReports),
                      child: const Text(
                        'Hapus Sekarang',
                        style: TextStyle(
                          color: AppTheme.error,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _unitTab(String label, String value) {
    final active = _unit == value;
    return Expanded(
      child: GestureDetector(
        onTap: _saving ? null : () => _updateSettings(_val, value),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.decelerate,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppTheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active ? AppTheme.cardShadow : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: active ? AppTheme.primaryDeep : AppTheme.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconCircleButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Material(
      color: AppTheme.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppTheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: enabled ? AppTheme.textMuted : AppTheme.textMuted.withValues(alpha: 0.3),
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report, int deleteDays) {
    final reportId = report['id'] as String? ?? '';
    final no = report['no'] as int? ?? 0;
    final owner = report['user_nama'] as String? ?? 'Petugas';
    final pkm = report['user_puskesmas'] as String? ?? '';
    final createdAt = report['created_at'] as String? ?? '';
    final patientCount = report['patient_count'] as int? ?? 0;

    String dateDisplay = _formatDate(createdAt);
    bool isOld = false;
    int daysLeft = 999;

    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt);
        if (deleteDays > 0) {
          final ageInDays = DateTime.now().difference(dt).inDays;
          daysLeft = deleteDays - ageInDays;
          isOld = daysLeft <= 0;
        }
      } catch (_) {}
    }

    // Subtitle text: "Balas Klumprik · 3 pasien · 20 Okt"
    final subtitleParts = <String>[];
    if (pkm.isNotEmpty) subtitleParts.add(pkm);
    if (patientCount > 0) {
      subtitleParts.add('$patientCount pasien');
    } else if (owner.isNotEmpty) {
      subtitleParts.add(owner);
    }
    subtitleParts.add(dateDisplay);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Row: Chip #24, Title & Subtitle, Status Pill
            Row(
              children: [
                // Chip #24 (AdminLaporan.dc.html line 23)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.tint(AppTheme.accent),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '#$no',
                    style: const TextStyle(
                      color: AppTheme.accent,
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
                        'Laporan #$no',
                        style: const TextStyle(
                          color: AppTheme.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitleParts.join(' · '),
                        style: const TextStyle(
                          color: AppTheme.textFaint,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isOld)
                  const StatusPill(
                    label: 'Kedaluwarsa',
                    color: AppTheme.error,
                  )
                else if (deleteDays > 0 && daysLeft <= 14)
                  StatusPill(
                    label: 'Hapus $daysLeft hari lagi',
                    color: AppTheme.warning,
                  )
                else
                  const StatusPill(
                    label: 'Terkirim',
                    color: AppTheme.success,
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Bottom Buttons Row (Lihat | Cetak | Edit | Trash)
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Lihat',
                    height: 40,
                    kind: AppButtonKind.tonal,
                    onPressed: () => widget.onShowDetail(reportId, no),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    label: 'Cetak',
                    height: 40,
                    kind: AppButtonKind.tonal,
                    onPressed: () => _showExportSheet(report),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    label: 'Edit',
                    height: 40,
                    kind: AppButtonKind.tonal,
                    onPressed: () {
                      if (widget.onEditReport != null) {
                        widget.onEditReport!(report);
                      } else {
                        widget.onShowDetail(reportId, no);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: AppTheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                    side: const BorderSide(color: AppTheme.outline),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => widget.onDeleteReport(reportId, no),
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: AppIcon(
                          AppGlyph.trash,
                          color: AppTheme.error,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
