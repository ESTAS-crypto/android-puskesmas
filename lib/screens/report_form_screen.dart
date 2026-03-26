import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/report.dart';
import '../models/resident_exam.dart';
import '../models/user_session.dart';
import '../services/storage_service.dart';
import 'resident_exam_form_screen.dart';
import 'success_screen.dart';

/// Screen utama untuk membuat/mengedit sebuah Laporan.
/// Satu Laporan = satu dokumen yang bisa berisi banyak data warga (ResidentExam).
class ReportFormScreen extends StatefulWidget {
  final UserSession session;
  final Report? existingReport;
  final List<ResidentExam>? initialExams;

  const ReportFormScreen({
    super.key,
    required this.session,
    this.existingReport,
    this.initialExams,
  });

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  List<ResidentExam> _exams = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingReport != null) {
      _exams = List.from(widget.existingReport!.exams);
    } else if (widget.initialExams != null) {
      _exams = List.from(widget.initialExams!);
    }
  }

  Future<void> _addOrEditExam({ResidentExam? existing, int? index}) async {
    final result = await Navigator.push<ResidentExam>(
      context,
      MaterialPageRoute(
        builder: (_) => ResidentExamFormScreen(
          existingExam: existing,
          examIndex: index != null ? index + 1 : _exams.length + 1,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        if (index != null) {
          _exams[index] = result;
        } else {
          _exams.add(result);
        }
      });
      _saveDraft();
    }
  }

  void _removeExam(int index) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Data Pasien?', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Data "${_exams[index].nama}" akan dihapus dari laporan ini.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus', style: TextStyle(color: AppTheme.error))),
        ],
      ),
    ).then((confirm) {
      if (confirm == true) {
        setState(() => _exams.removeAt(index));
        _saveDraft();
      }
    });
  }

  Future<void> _saveDraft() async {
    // Only save draft for new reports, not when editing an existing one
    if (widget.existingReport != null) return;
    final report = Report(
      id: widget.existingReport?.id, // this would be null usually for draft
      no: widget.existingReport?.no ?? 0, // temporary 0
      exams: _exams,
    );
    await StorageService.saveDraft(report);
  }

  Future<void> _saveReport() async {
    if (_exams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.warning),
            SizedBox(width: 8),
            Text('Tambahkan minimal 1 data pasien dulu!'),
          ]),
          backgroundColor: AppTheme.cardDark,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final no = widget.existingReport?.no ?? await StorageService.getNextReportNo();
      final report = Report(
        id: widget.existingReport?.id,
        no: no,
        exams: _exams,
      );

      if (widget.existingReport != null) {
        await StorageService.updateReport(report);
      } else {
        await StorageService.saveReport(report);
        await StorageService.clearDraft(); // Clear draft on successful save
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => SuccessScreen(session: widget.session, report: report),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ===== AppBar =====
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        'Buat Laporan',
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppTheme.divider, height: 1),

              // ===== Body =====
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // -- Header Daftar Warga --
                    Row(
                      children: [
                        const Text('Daftar Pasien', style: TextStyle(color: AppTheme.accentTeal, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accentTeal.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('${_exams.length} Orang', style: const TextStyle(color: AppTheme.accentTeal, fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // -- List Warga --
                    if (_exams.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.people_outline_rounded, color: AppTheme.textHint, size: 48),
                            SizedBox(height: 12),
                            Text('Belum ada data pasien', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                            SizedBox(height: 4),
                            Text('Tekan "+ Tambah Pasien" untuk mulai', style: TextStyle(color: AppTheme.textHint, fontSize: 13)),
                          ],
                        ),
                      )
                    else
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _exams.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex--;
                            final item = _exams.removeAt(oldIndex);
                            _exams.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, index) {
                          final exam = _exams[index];
                          return _examCard(exam, index, key: ValueKey(exam.id));
                        },
                      ),
                    const SizedBox(height: 16),

                    // -- Tombol Tambah Warga --
                    GestureDetector(
                      onTap: () => _addOrEditExam(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(16),
                          color: AppTheme.accentTeal.withValues(alpha: 0.05),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_add_alt_1_rounded, color: AppTheme.accentTeal, size: 24),
                            SizedBox(width: 10),
                            Text('Tambah Pasien', style: TextStyle(color: AppTheme.accentTeal, fontWeight: FontWeight.w700, fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // -- Tombol Simpan --
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Ink(
                          decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(16)),
                          child: Container(
                            alignment: Alignment.center,
                            child: _isSaving
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    const Icon(Icons.save_rounded, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text(
                                      widget.existingReport != null ? 'Update Laporan' : 'Simpan Laporan',
                                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                                    ),
                                  ]),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _examCard(ResidentExam exam, int index, {required Key key}) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _addOrEditExam(existing: exam, index: index),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Number badge
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(10)),
                  child: Center(child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exam.nama.isNotEmpty ? exam.nama : '(Tidak ada nama)',
                          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (exam.usia.isNotEmpty) exam.usia,
                          if (exam.alamat.isNotEmpty) exam.alamat,
                          if (exam.tensi.isNotEmpty) 'Tensi: ${exam.tensi}',
                        ].join(' · '),
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Drag handle & actions
                Column(
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle_rounded, color: AppTheme.textHint, size: 20),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _removeExam(index),
                      child: const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 20),
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
