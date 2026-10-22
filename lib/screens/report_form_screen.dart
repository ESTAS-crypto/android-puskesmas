import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../widgets/ui/ui.dart';
import '../models/report.dart';
import '../models/resident_exam.dart';
import '../models/user_session.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
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
  final Set<String> _removingIds = {};

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

  /// Hapus dengan animasi kartu menciut, lalu beri kesempatan "Urungkan".
  Future<void> _removeExam(int index) async {
    final exam = _exams[index];
    HapticFeedback.mediumImpact();
    setState(() => _removingIds.add(exam.id));
    await Future.delayed(AppMotion.of(context, AppMotion.medium));
    if (!mounted) return;
    final at = _exams.indexWhere((e) => e.id == exam.id);
    if (at == -1) return;
    setState(() {
      _exams.removeAt(at);
      _removingIds.remove(exam.id);
    });
    _saveDraft();

    final label = exam.nama.isNotEmpty ? exam.nama : 'Pasien';
    AppToast.show(
      context,
      '$label dihapus dari laporan',
      kind: AppToastKind.info,
      actionLabel: 'Urungkan',
      onAction: () {
        if (!mounted) return;
        setState(() => _exams.insert(math.min(at, _exams.length), exam));
        _saveDraft();
      },
    );
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
      AppToast.show(
        context,
        'Tambahkan minimal 1 pasien sebelum menyimpan.',
        kind: AppToastKind.warning,
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

      // Auto-sync ke cloud (fire-and-forget, tidak blocking)
      if (SupabaseService.isLoggedIn) {
        SupabaseService.syncReportToCloud(report).catchError((_) {});
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => SuccessScreen(session: widget.session, report: report),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: AppMotion.decelerate),
            child: child,
          ),
          transitionDuration: AppMotion.medium,
        ),
      );
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          'Laporan belum berhasil disimpan. Coba lagi.',
          kind: AppToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final editing = widget.existingReport != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Ubah laporan' : 'Laporan baru'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text('Daftar pasien', style: t.titleMedium),
                      ),
                    ),
                    // Penghitung: bergeser halus tiap jumlah berubah
                    AnimatedSwitcher(
                      duration: AppMotion.fast,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: ScaleTransition(scale: anim, child: child),
                      ),
                      child: StatusPill(
                        key: ValueKey(_exams.length),
                        label: '${_exams.length} orang',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AnimatedSize(
                  duration: AppMotion.medium,
                  curve: AppMotion.standard,
                  alignment: Alignment.topCenter,
                  child: _exams.isEmpty
                      ? EmptyState(
                          icon: AppGlyph.users,
                          title: 'Belum ada pasien',
                          message:
                              'Tambahkan pasien yang Anda kunjungi. Data tersimpan otomatis sebagai draf.',
                          action: AppButton(
                            label: 'Tambah pasien pertama',
                            icon: AppGlyph.userAdd,
                            expand: false,
                            onPressed: () => _addOrEditExam(),
                          ),
                        )
                      : ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _exams.length,
                          proxyDecorator: (child, index, animation) {
                            // Kartu "terangkat" halus saat diseret
                            return AnimatedBuilder(
                              animation: animation,
                              builder: (_, c) {
                                final v = Curves.easeOut.transform(animation.value);
                                return Transform.scale(
                                  scale: 1 + 0.02 * v,
                                  child: Material(
                                    color: Colors.transparent,
                                    elevation: 10 * v,
                                    shadowColor: Colors.black,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.lg),
                                    child: c,
                                  ),
                                );
                              },
                              child: child,
                            );
                          },
                          onReorder: (oldIndex, newIndex) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              if (newIndex > oldIndex) newIndex--;
                              final item = _exams.removeAt(oldIndex);
                              _exams.insert(newIndex, item);
                            });
                            _saveDraft();
                          },
                          itemBuilder: (context, index) {
                            final exam = _exams[index];
                            return _examCard(exam, index,
                                key: ValueKey(exam.id));
                          },
                        ),
                ),
                if (_exams.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  AppButton(
                    label: 'Tambah pasien',
                    icon: AppGlyph.userAdd,
                    kind: AppButtonKind.tonal,
                    onPressed: () => _addOrEditExam(),
                  ),
                ],
              ],
            ),
          ),

          // ── Bar simpan: menempel di bawah, mudah dijangkau ibu jari ──
          Container(
            decoration: const BoxDecoration(
              color: AppTheme.bg,
              border: Border(top: BorderSide(color: AppTheme.outline)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: AppButton(
                  label: editing ? 'Perbarui laporan' : 'Simpan laporan',
                  icon: AppGlyph.tick,
                  loading: _isSaving,
                  onPressed: _saveReport,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _examCard(ResidentExam exam, int index, {required Key key}) {
    final t = Theme.of(context).textTheme;
    final removing = _removingIds.contains(exam.id);
    final meta = [
      if (exam.usia.isNotEmpty) exam.usia,
      if (exam.alamat.isNotEmpty) exam.alamat,
      if (exam.tensi.isNotEmpty) 'Tensi ${exam.tensi}',
    ].join(' · ');

    final card = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => _addOrEditExam(existing: exam, index: index),
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        semanticLabel:
            'Pasien ${index + 1}, ${exam.nama.isNotEmpty ? exam.nama : 'tanpa nama'}. Ketuk untuk mengubah.',
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.tint(AppTheme.accent),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                '${index + 1}',
                style: t.titleSmall?.copyWith(color: AppTheme.accent),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exam.nama.isNotEmpty ? exam.nama : '(Tanpa nama)',
                    style: t.titleMedium?.copyWith(fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(meta,
                        style: t.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            ReorderableDragStartListener(
              index: index,
              child: const SizedBox(
                width: 40,
                height: 44,
                child: AppIcon(AppGlyph.drag,
                    color: AppTheme.textFaint, size: 22),
              ),
            ),
            IconButton(
              tooltip: 'Hapus pasien',
              onPressed: removing ? null : () => _removeExam(index),
              icon: const AppIcon(AppGlyph.trash,
                  color: AppTheme.error, size: 22),
            ),
          ],
        ),
      ),
    );

    return KeyedSubtree(
      key: key,
      child: AnimatedSize(
        duration: AppMotion.medium,
        curve: AppMotion.standard,
        alignment: Alignment.topCenter,
        child: removing
            ? const SizedBox(width: double.infinity)
            : TweenAnimationBuilder<double>(
                // Masuk halus saat kartu pertama kali muncul
                tween: Tween<double>(begin: 0, end: 1),
                duration: AppMotion.of(context, AppMotion.medium),
                curve: AppMotion.decelerate,
                builder: (_, v, child) => Opacity(
                  opacity: v,
                  child: Transform.translate(
                    offset: Offset(0, 12 * (1 - v)),
                    child: child,
                  ),
                ),
                child: card,
              ),
      ),
    );
  }
}
