import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/resident_exam.dart';
import '../services/speech_service.dart';
import '../services/voice_text_cleaner.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/ui.dart';

/// Form untuk mengisi data satu warga dalam sebuah laporan kunjungan rumah.
/// Mengembalikan [ResidentExam] melalui Navigator.pop().
class ResidentExamFormScreen extends StatefulWidget {
  final ResidentExam? existingExam;
  final int examIndex;

  const ResidentExamFormScreen({
    super.key,
    this.existingExam,
    required this.examIndex,
  });

  @override
  State<ResidentExamFormScreen> createState() => _ResidentExamFormScreenState();
}

class _ResidentExamFormScreenState extends State<ResidentExamFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _speechService = SpeechService();
  final _imagePicker = ImagePicker();

  List<ResidentExam> _cachedResidents = [];

  late final FocusNode _namaFocusNode;
  final List<TextEditingController> _trackedControllers = [];

  late TextEditingController _namaCtrl;
  late TextEditingController _nikCtrl;
  late String _tanggal;
  late TextEditingController _tanggalLahirCtrl;
  late TextEditingController _usiaCtrl;
  late TextEditingController _alamatCtrl;
  late TextEditingController _kategoriKeluargaCtrl;
  late TextEditingController _bbCtrl;
  late TextEditingController _tbCtrl;
  late TextEditingController _lpCtrl;
  late TextEditingController _tensiCtrl;
  late TextEditingController _lilaCtrl;
  late TextEditingController _likaCtrl;
  late TextEditingController _gulaDarahCtrl;

  final List<TextEditingController> _keluhanCtrls = [];
  final List<TextEditingController> _tindakLanjutCtrls = [];
  final List<Map<String, TextEditingController>> _customFieldCtrls = [];

  String? _fotoPath;
  bool _isListening = false;
  String? _activeField;
  bool _locationPermissionDenied = false;

  // Quick suggestion chips
  static const List<String> _quickKeluhan = [
    'Pusing',
    'Sulit tidur',
    'Batuk',
    'Demam',
    'Nyeri sendi',
    'Lemas',
    'Mual',
    'Sesak nafas',
  ];

  static const List<String> _quickTindakLanjut = [
    'Rujuk ke puskesmas',
    'Kontrol ulang 1 minggu',
    'Edukasi diet & olahraga',
    'Minum obat teratur',
    'Istirahat cukup',
  ];

  TextEditingController _createTrackedController([String text = '']) {
    final ctrl = TextEditingController(text: text);
    ctrl.addListener(_onFieldChanged);
    _trackedControllers.add(ctrl);
    return ctrl;
  }

  void _removeTrackedController(TextEditingController ctrl) {
    ctrl.removeListener(_onFieldChanged);
    _trackedControllers.remove(ctrl);
    ctrl.dispose();
  }

  @override
  void initState() {
    super.initState();
    _namaFocusNode = FocusNode();
    final e = widget.existingExam;

    _namaCtrl = _createTrackedController(e?.nama ?? '');
    _nikCtrl = _createTrackedController(e?.nik ?? '');
    _tanggal = e?.tanggal ?? DateFormat('dd.MM.yy').format(DateTime.now());
    _tanggalLahirCtrl = _createTrackedController(e?.tanggalLahir ?? '');
    _usiaCtrl = _createTrackedController(e?.usia ?? '');
    _alamatCtrl = _createTrackedController(e?.alamat ?? '');
    _kategoriKeluargaCtrl =
        _createTrackedController(e?.kategoriKeluarga ?? '');
    _bbCtrl = _createTrackedController(e?.bb ?? '');
    _tbCtrl = _createTrackedController(e?.tb ?? '');
    _lpCtrl = _createTrackedController(e?.lingkarPinggang ?? '');
    _tensiCtrl = _createTrackedController(e?.tensi ?? '');
    _lilaCtrl = _createTrackedController(e?.lila ?? '');
    _likaCtrl = _createTrackedController(e?.lika ?? '');
    _gulaDarahCtrl = _createTrackedController(e?.gulaDarah ?? '');
    _fotoPath = e?.fotoPath;

    _keluhanCtrls.clear();
    if (e != null && e.keluhan.isNotEmpty) {
      for (final k in e.keluhan) {
        _keluhanCtrls.add(_createTrackedController(k));
      }
    } else {
      _keluhanCtrls.add(_createTrackedController());
    }

    _tindakLanjutCtrls.clear();
    if (e != null && e.tindakLanjut.isNotEmpty) {
      for (final t in e.tindakLanjut) {
        _tindakLanjutCtrls.add(_createTrackedController(t));
      }
    } else {
      _tindakLanjutCtrls.add(_createTrackedController());
    }

    _customFieldCtrls.clear();
    if (e != null) {
      for (final entry in e.customFields.entries) {
        _customFieldCtrls.add({
          'label': _createTrackedController(entry.key),
          'value': _createTrackedController(entry.value),
        });
      }
    }

    _initSpeech();

    // Load autocomplete cache
    StorageService.getAllResidents().then((list) {
      if (mounted) setState(() => _cachedResidents = list);
    });
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initSpeech() async {
    await _speechService.initialize();
  }

  @override
  void dispose() {
    _namaFocusNode.dispose();
    for (final c in _trackedControllers) {
      c.removeListener(_onFieldChanged);
      c.dispose();
    }
    _speechService.dispose();
    super.dispose();
  }

  // ── Perhitungan Progres Pengisian Realtime ─────────────────
  // Setiap pengisian field sekecil apapun langsung menambah persentase secara realtime
  double get _fillProgress {
    double score = 0;
    const double maxScore = 100;

    // 1. Identitas Pasien (Maks 40%)
    if (_namaCtrl.text.trim().isNotEmpty) score += 15; // Nama pasien (wajib)
    if (_alamatCtrl.text.trim().isNotEmpty) score += 7;
    if (_usiaCtrl.text.trim().isNotEmpty) score += 5;
    if (_tanggalLahirCtrl.text.trim().isNotEmpty) score += 4;
    if (_nikCtrl.text.trim().isNotEmpty) score += 5;
    if (_kategoriKeluargaCtrl.text.trim().isNotEmpty) score += 4;

    // 2. Pemeriksaan Fisik (Maks 30%)
    if (_tensiCtrl.text.trim().isNotEmpty) score += 8;
    if (_bbCtrl.text.trim().isNotEmpty) score += 6;
    if (_tbCtrl.text.trim().isNotEmpty) score += 6;
    if (_gulaDarahCtrl.text.trim().isNotEmpty) score += 4;
    if (_lpCtrl.text.trim().isNotEmpty) score += 3;
    if (_lilaCtrl.text.trim().isNotEmpty || _likaCtrl.text.trim().isNotEmpty) score += 3;
    for (final m in _customFieldCtrls) {
      if ((m['value']?.text.trim().isNotEmpty ?? false)) score += 2;
    }

    // 3. Keluhan (Maks 10%)
    if (_keluhanCtrls.any((c) => c.text.trim().isNotEmpty)) score += 10;

    // 4. Tindak Lanjut (Maks 10%)
    if (_tindakLanjutCtrls.any((c) => c.text.trim().isNotEmpty)) score += 10;

    // 5. Foto Dokumentasi (Maks 10%)
    if (_fotoPath != null && _fotoPath!.isNotEmpty) score += 10;

    return (score / maxScore).clamp(0.0, 1.0);
  }

  int get _filledSectionsCount {
    int count = 0;
    // 1. Identitas
    if (_namaCtrl.text.trim().isNotEmpty) count++;
    // 2. Pemeriksaan Fisik
    if (_bbCtrl.text.trim().isNotEmpty ||
        _tbCtrl.text.trim().isNotEmpty ||
        _lpCtrl.text.trim().isNotEmpty ||
        _tensiCtrl.text.trim().isNotEmpty ||
        _lilaCtrl.text.trim().isNotEmpty ||
        _likaCtrl.text.trim().isNotEmpty ||
        _gulaDarahCtrl.text.trim().isNotEmpty ||
        _customFieldCtrls.any((m) =>
            (m['label']?.text.trim().isNotEmpty ?? false) &&
            (m['value']?.text.trim().isNotEmpty ?? false))) {
      count++;
    }
    // 3. Keluhan
    if (_keluhanCtrls.any((c) => c.text.trim().isNotEmpty)) count++;
    // 4. Tindak Lanjut
    if (_tindakLanjutCtrls.any((c) => c.text.trim().isNotEmpty)) count++;
    // 5. Foto
    if (_fotoPath != null && _fotoPath!.isNotEmpty) count++;
    return count;
  }

  // ── Voice Input Handling (Mockup Galat.dc.html cap 5) ───
  Future<void> _toggleVoice(String fieldName, TextEditingController ctrl,
      {VoiceKind kind = VoiceKind.text}) async {
    // Tutup sesi sebelumnya bila sedang aktif
    if (_isListening) {
      await _speechService.stopListening();
      if (mounted) setState(() { _isListening = false; _activeField = null; });
    }

    final base = ctrl.text.trim();
    String recognizedSpoken = '';
    final sheetKey = GlobalKey<_VoiceListeningSheetState>();

    void put(String spoken) {
      final cleaned = VoiceTextCleaner.clean(spoken, kind);
      if (cleaned.isEmpty) return;
      final merged = base.isEmpty
          ? cleaned
          : (kind == VoiceKind.digits ? '$base$cleaned' : '$base $cleaned');
      ctrl.text = merged;
      ctrl.selection = TextSelection.collapsed(offset: merged.length);
    }

    String hintText;
    if (fieldName == 'nama') {
      hintText = 'Ucapkan nama lengkap warga/pasien, misalnya "Evan Atharasya".';
    } else if (fieldName == 'alamat') {
      hintText = 'Ucapkan alamat lengkap, misalnya "RT 03 RW 02 Balas Klumprik".';
    } else if (fieldName == 'nik') {
      hintText = 'Ucapkan 16 digit NIK secara jelas.';
    } else if (fieldName.contains('keluhan')) {
      hintText = 'Ucapkan keluhan pasien, misalnya "pusing dan sulit tidur".';
    } else if (fieldName.contains('tindak')) {
      hintText = 'Ucapkan tindak lanjut, misalnya "edukasi pola makan dan istirahat".';
    } else {
      hintText = 'Ucapkan data dengan jelas ke mikrofon HP.';
    }

    setState(() {
      _isListening = true;
      _activeField = fieldName;
    });

    if (!mounted) return;

    Future<void> restartListening() async {
      await _speechService.stopListening();
      recognizedSpoken = '';
      ctrl.text = base;
      ctrl.selection = TextSelection.collapsed(offset: base.length);
      sheetKey.currentState?.updateText('');
      sheetKey.currentState?.setListening(true);
      await _speechService.startListening(
        onPartial: (p) {
          recognizedSpoken = p;
          sheetKey.currentState?.updateText(VoiceTextCleaner.clean(p, kind));
          put(p);
        },
        onResult: (t) {
          recognizedSpoken = t;
          sheetKey.currentState?.updateText(VoiceTextCleaner.clean(t, kind));
          put(t);
        },
        onError: (msg) {
          if (!mounted) return;
          AppToast.show(context, msg, kind: AppToastKind.warning);
          sheetKey.currentState?.setListening(false);
        },
        onDone: () {
          sheetKey.currentState?.setListening(false);
        },
      );
    }

    final sheetFuture = showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _VoiceListeningSheet(
        key: sheetKey,
        title: 'Mendengarkan…',
        hint: hintText,
        speechService: _speechService,
        onRetry: restartListening,
        onFinish: (finalSpoken) {
          if (finalSpoken.trim().isNotEmpty) {
            put(finalSpoken);
          }
          _speechService.stopListening();
          Navigator.pop(ctx);
        },
        onCancel: () {
          _speechService.stopListening();
          Navigator.pop(ctx);
        },
      ),
    );

    await restartListening();

    await sheetFuture;

    // Bersihkan listener ketika modal ditutup
    await _speechService.stopListening();
    if (recognizedSpoken.trim().isNotEmpty) {
      put(recognizedSpoken);
    }
    if (mounted) {
      setState(() {
        _isListening = false;
        _activeField = null;
      });
    }
  }

  // ── Photo & Geotag Handling ──────────────────────────────
  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(11, 42, 64, 0.14),
              blurRadius: 30,
              offset: Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Pilih Sumber Foto Pasien',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              tileColor: const Color(0xFFEAF3FA),
              leading: const Icon(Icons.camera_alt_rounded,
                  color: Color(0xFF0A64A8)),
              title: const Text('Kamera',
                  style: TextStyle(
                      color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
              subtitle: const Text('Ambil foto langsung di lokasi kunjungan',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 8),
            ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              tileColor: const Color(0xFFEAF3FA),
              leading: const Icon(Icons.photo_library_rounded,
                  color: Color(0xFF2E9C6A)),
              title: const Text('Galeri',
                  style: TextStyle(
                      color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
              subtitle: const Text('Pilih dari foto yang sudah tersimpan',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    // Check location permission if taking photo
    if (source == ImageSource.camera) {
      final status = await Permission.location.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        setState(() => _locationPermissionDenied = true);
      } else {
        setState(() => _locationPermissionDenied = false);
      }
    }

    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _fotoPath = picked.path);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      AppToast.show(
        context,
        'Harap lengkapi nama pasien dan data wajib lainnya',
        kind: AppToastKind.warning,
      );
      return;
    }

    final keluhan = _keluhanCtrls
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final tindakLanjut = _tindakLanjutCtrls
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final customFields = <String, String>{};
    for (final m in _customFieldCtrls) {
      final label = m['label']!.text.trim();
      final value = m['value']!.text.trim();
      if (label.isNotEmpty && value.isNotEmpty) customFields[label] = value;
    }

    final exam = ResidentExam(
      id: widget.existingExam?.id,
      tanggal: _tanggal,
      tanggalLahir: _tanggalLahirCtrl.text.trim(),
      nama: _namaCtrl.text.trim(),
      nik: _nikCtrl.text.trim(),
      usia: _usiaCtrl.text.trim(),
      alamat: _alamatCtrl.text.trim(),
      kategoriKeluarga: _kategoriKeluargaCtrl.text.trim(),
      bb: _bbCtrl.text.trim(),
      tb: _tbCtrl.text.trim(),
      lingkarPinggang: _lpCtrl.text.trim(),
      tensi: _tensiCtrl.text.trim(),
      lila: _lilaCtrl.text.trim(),
      lika: _likaCtrl.text.trim(),
      gulaDarah: _gulaDarahCtrl.text.trim(),
      keluhan: keluhan,
      tindakLanjut: tindakLanjut,
      fotoPath: _fotoPath,
      customFields: customFields,
    );
    Navigator.pop(context, exam);
  }

  @override
  Widget build(BuildContext context) {
    final filledCount = _filledSectionsCount;
    final progressPercent = _fillProgress;
    final percentInt = (progressPercent * 100).round();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFD6ECFA), Color(0xFFF1F8FD)],
            stops: [0.0, 0.35],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: const AppIcon(
                          AppGlyph.back,
                          size: 20,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.existingExam != null
                            ? 'Edit Data Pasien #${widget.examIndex}'
                            : 'Data Pasien #${widget.examIndex}',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Scrollable Form Body ──
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    children: [
                      // ── Progress Bar Section ──
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$filledCount dari 5 bagian terisi',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            '$percentInt%',
                            style: const TextStyle(
                              color: Color(0xFF0A64A8),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          tween: Tween<double>(begin: 0, end: progressPercent),
                          builder: (context, value, child) {
                            return LinearProgressIndicator(
                              value: value,
                              minHeight: 10,
                              backgroundColor: const Color(0xFFEAF3FA),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF0A64A8)),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── CARD 1: Identitas Pasien ──
                      _buildIdentitasCard(),
                      const SizedBox(height: 14),

                      // ── CARD 2: Hasil Pemeriksaan ──
                      _buildPemeriksaanCard(),
                      const SizedBox(height: 14),

                      // ── CARD 3: Keluhan ──
                      _buildKeluhanCard(),
                      const SizedBox(height: 14),

                      // ── CARD 4: Tindak Lanjut ──
                      _buildTindakLanjutCard(),
                      const SizedBox(height: 14),

                      // ── CARD 5: Foto Geotag ──
                      _buildFotoGeotagCard(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // ── Sticky Footer Simpan ──
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF1F8FD),
            border: const Border(
              top: BorderSide(color: AppTheme.divider, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0B2A40).withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          child: AppButton(
            label: 'Simpan pasien',
            icon: AppGlyph.check,
            kind: AppButtonKind.primary,
            onPressed: _save,
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // CARD 1: IDENTITAS PASIEN
  // ══════════════════════════════════════════════════════════════
  Widget _buildIdentitasCard() {
    final isLengkap = _namaCtrl.text.trim().isNotEmpty &&
        _alamatCtrl.text.trim().isNotEmpty &&
        _usiaCtrl.text.trim().isNotEmpty;

    return _cardContainer(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Identitas pasien',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            StatusPill(
              label: isLengkap ? 'Lengkap' : 'Belum lengkap',
              color: isLengkap ? AppTheme.success : AppTheme.warning,
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Tanggal Kunjungan
        _dateField(
          label: 'Tanggal kunjungan',
          value: _tanggal,
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF0A64A8),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: AppTheme.textPrimary,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked != null) {
              setState(() =>
                  _tanggal = DateFormat('dd.MM.yy').format(picked));
            }
          },
        ),
        const SizedBox(height: 10),

        // Nama Lengkap (Auto-complete)
        RawAutocomplete<ResidentExam>(
          textEditingController: _namaCtrl,
          focusNode: _namaFocusNode,
          displayStringForOption: (option) => option.nama,
          optionsBuilder: (textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<ResidentExam>.empty();
            }
            return _cachedResidents.where((r) => r.nama
                .toLowerCase()
                .contains(textEditingValue.text.toLowerCase()));
          },
          onSelected: (selection) {
            setState(() {
              _nikCtrl.text = selection.nik;
              _tanggalLahirCtrl.text = selection.tanggalLahir;
              _usiaCtrl.text = selection.usia;
              _alamatCtrl.text = selection.alamat;
              _kategoriKeluargaCtrl.text = selection.kategoriKeluarga;

              if (selection.tb.isNotEmpty) _tbCtrl.text = selection.tb;
              if (selection.bb.isNotEmpty) _bbCtrl.text = selection.bb;
              if (selection.lingkarPinggang.isNotEmpty) {
                _lpCtrl.text = selection.lingkarPinggang;
              }
              if (selection.tensi.isNotEmpty) {
                _tensiCtrl.text = selection.tensi;
              }
              if (selection.lila.isNotEmpty) {
                _lilaCtrl.text = selection.lila;
              }
              if (selection.lika.isNotEmpty) {
                _likaCtrl.text = selection.lika;
              }
              if (selection.gulaDarah.isNotEmpty) {
                _gulaDarahCtrl.text = selection.gulaDarah;
              }

              for (final c in _customFieldCtrls) {
                if (c['label'] != null) _removeTrackedController(c['label']!);
                if (c['value'] != null) _removeTrackedController(c['value']!);
              }
              _customFieldCtrls.clear();
              for (final entry in selection.customFields.entries) {
                _customFieldCtrls.add({
                  'label': _createTrackedController(entry.key),
                  'value': _createTrackedController(entry.value),
                });
              }
            });
            AppToast.show(
              context,
              'Data "${selection.nama}" berhasil dimuat otomatis',
              kind: AppToastKind.info,
            );
          },
          fieldViewBuilder:
              (context, controller, focusNode, onFieldSubmitted) {
            final isActive = _isListening && _activeField == 'nama';
            return _styledField(
              label: 'Nama lengkap (auto-complete)',
              controller: controller,
              focusNode: focusNode,
              hint: 'Ketik nama warga…',
              required: true,
              suffixWidget: IconButton(
                onPressed: () =>
                    _toggleVoice('nama', controller, kind: VoiceKind.name),
                icon: Icon(
                  isActive ? Icons.mic_rounded : Icons.mic_none_rounded,
                  color: isActive ? AppTheme.error : const Color(0xFF0A64A8),
                  size: 22,
                ),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 8,
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 320,
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        leading: const CircleAvatar(
                          radius: 14,
                          backgroundColor: Color(0xFFEAF3FA),
                          child: Icon(Icons.person,
                              size: 16, color: Color(0xFF0A64A8)),
                        ),
                        title: Text(
                          option.nama,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          option.alamat.isEmpty ? 'Alamat -' : option.alamat,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                        ),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),

        // Usia & Alamat Row
        Row(
          children: [
            Expanded(
              child: _styledField(
                label: 'Usia',
                controller: _usiaCtrl,
                hint: 'mis. 62 tahun',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _styledField(
                label: 'Alamat',
                controller: _alamatCtrl,
                hint: 'mis. RT 03/RW 02',
                suffixWidget: IconButton(
                  onPressed: () => _toggleVoice('alamat', _alamatCtrl,
                      kind: VoiceKind.address),
                  icon: Icon(
                    _isListening && _activeField == 'alamat'
                        ? Icons.mic_rounded
                        : Icons.mic_none_rounded,
                    color: _isListening && _activeField == 'alamat'
                        ? AppTheme.error
                        : const Color(0xFF0A64A8),
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Tanggal Lahir (auto calculate age)
        _dateField(
          label: 'Tanggal lahir',
          value: _tanggalLahirCtrl.text.isEmpty
              ? 'Pilih tanggal lahir'
              : _tanggalLahirCtrl.text,
          onTap: () async {
            DateTime initDate = DateTime(1985);
            if (_tanggalLahirCtrl.text.isNotEmpty) {
              try {
                initDate =
                    DateFormat('dd.MM.yy').parse(_tanggalLahirCtrl.text);
              } catch (_) {}
            }
            final picked = await showDatePicker(
              context: context,
              initialDate: initDate,
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF0A64A8),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: AppTheme.textPrimary,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked != null) {
              setState(() {
                _tanggalLahirCtrl.text =
                    DateFormat('dd.MM.yy').format(picked);
                final now = DateTime.now();
                int age = now.year - picked.year;
                if (now.month < picked.month ||
                    (now.month == picked.month && now.day < picked.day)) {
                  age--;
                }
                _usiaCtrl.text = '$age';
              });
            }
          },
        ),
        const SizedBox(height: 10),

        // NIK & Kategori Keluarga
        Row(
          children: [
            Expanded(
              child: _styledField(
                label: 'NIK',
                controller: _nikCtrl,
                hint: '16 digit NIK',
                keyboardType: TextInputType.number,
                suffixWidget: IconButton(
                  onPressed: () =>
                      _toggleVoice('nik', _nikCtrl, kind: VoiceKind.digits),
                  icon: Icon(
                    _isListening && _activeField == 'nik'
                        ? Icons.mic_rounded
                        : Icons.mic_none_rounded,
                    color: _isListening && _activeField == 'nik'
                        ? AppTheme.error
                        : const Color(0xFF0A64A8),
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _styledField(
                label: 'Kategori keluarga',
                controller: _kategoriKeluargaCtrl,
                hint: 'mis. Lansia / Ibu',
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // CARD 2: HASIL PEMERIKSAAN
  // ══════════════════════════════════════════════════════════════
  Widget _buildPemeriksaanCard() {
    final hasMetrics = _bbCtrl.text.trim().isNotEmpty ||
        _tbCtrl.text.trim().isNotEmpty ||
        _lpCtrl.text.trim().isNotEmpty ||
        _tensiCtrl.text.trim().isNotEmpty ||
        _gulaDarahCtrl.text.trim().isNotEmpty;

    return _cardContainer(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Hasil pemeriksaan',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            StatusPill(
              label: hasMetrics ? 'Terisi' : 'Kosong',
              color: hasMetrics ? AppTheme.success : AppTheme.textMuted,
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Row 1: BB & TB
        Row(
          children: [
            Expanded(
              child: _styledField(
                label: 'BB (kg)',
                controller: _bbCtrl,
                hint: 'mis. 58',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _styledField(
                label: 'TB (cm)',
                controller: _tbCtrl,
                hint: 'mis. 152',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Row 2: LP & Tensi
        Row(
          children: [
            Expanded(
              child: _styledField(
                label: 'LP (cm)',
                controller: _lpCtrl,
                hint: 'mis. 88',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _styledField(
                label: 'Tensi',
                controller: _tensiCtrl,
                hint: 'mis. 120/80',
                keyboardType: TextInputType.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Row 3: LILA & LiKa
        Row(
          children: [
            Expanded(
              child: _styledField(
                label: 'LILA (cm)',
                controller: _lilaCtrl,
                hint: 'mis. 26',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _styledField(
                label: 'LiKa (cm)',
                controller: _likaCtrl,
                hint: 'mis. 31',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Row 4: Gula Darah
        _styledField(
          label: 'Gula darah (mg/dL)',
          controller: _gulaDarahCtrl,
          hint: 'mis. 145',
          keyboardType: TextInputType.number,
        ),

        // Dynamic custom fields
        if (_customFieldCtrls.isNotEmpty) ...[
          const SizedBox(height: 10),
          ..._customFieldCtrls.asMap().entries.map((entry) {
            final idx = entry.key;
            final ctrls = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _styledField(
                      label: 'Parameter',
                      controller: ctrls['label']!,
                      hint: 'mis. Kolesterol',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _styledField(
                      label: 'Nilai',
                      controller: ctrls['value']!,
                      hint: 'mis. 190 mg/dL',
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Hapus parameter',
                    onPressed: () => setState(() {
                      final label = _customFieldCtrls[idx]['label'];
                      final value = _customFieldCtrls[idx]['value'];
                      if (label != null) _removeTrackedController(label);
                      if (value != null) _removeTrackedController(value);
                      _customFieldCtrls.removeAt(idx);
                    }),
                    icon: const Icon(Icons.close_rounded,
                        color: AppTheme.error, size: 20),
                  ),
                ],
              ),
            );
          }),
        ],

        const SizedBox(height: 10),
        AppButton(
          label: 'Tambah hasil pemeriksaan',
          icon: AppGlyph.plus,
          kind: AppButtonKind.tonal,
          onPressed: () => setState(() => _customFieldCtrls.add({
                'label': _createTrackedController(),
                'value': _createTrackedController(),
              })),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // CARD 3: KELUHAN
  // ══════════════════════════════════════════════════════════════
  Widget _buildKeluhanCard() {
    final validCount =
        _keluhanCtrls.where((c) => c.text.trim().isNotEmpty).length;

    return _cardContainer(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Keluhan',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            StatusPill(
              label: validCount > 0 ? '$validCount keluhan' : 'Belum ada',
              color: validCount > 0 ? const Color(0xFF0A64A8) : AppTheme.textMuted,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Quick Suggestion Pills
        const Text(
          'Keluhan umum (ketuk untuk menambahkan):',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _quickKeluhan.map((k) {
            return InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                // Find first empty controller or add new one
                final emptyIndex = _keluhanCtrls
                    .indexWhere((c) => c.text.trim().isEmpty);
                setState(() {
                  if (emptyIndex != -1) {
                    _keluhanCtrls[emptyIndex].text = k;
                  } else {
                    _keluhanCtrls.add(_createTrackedController(k));
                  }
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A64A8).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFF0A64A8).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add,
                        size: 14, color: Color(0xFF0A64A8)),
                    const SizedBox(width: 4),
                    Text(
                      k,
                      style: const TextStyle(
                        color: Color(0xFF0A64A8),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),

        // Input List (Bisa digeser/reorder posisi keluhan seperti daftar pasien)
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: _keluhanCtrls.length,
          onReorder: (oldIndex, newIndex) {
            HapticFeedback.selectionClick();
            setState(() {
              if (newIndex > oldIndex) newIndex--;
              final item = _keluhanCtrls.removeAt(oldIndex);
              _keluhanCtrls.insert(newIndex, item);
            });
          },
          itemBuilder: (context, idx) {
            final ctrl = _keluhanCtrls[idx];
            final fieldId = 'keluhan_$idx';
            final isActive = _isListening && _activeField == fieldId;

            return Padding(
              key: ObjectKey(ctrl),
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _styledField(
                      label: 'Keluhan ${idx + 1}',
                      controller: ctrl,
                      hint: 'Tuliskan keluhan pasien…',
                      suffixWidget: IconButton(
                        onPressed: () => _toggleVoice(fieldId, ctrl),
                        icon: Icon(
                          isActive
                              ? Icons.mic_rounded
                              : Icons.mic_none_rounded,
                          color: isActive
                              ? AppTheme.error
                              : const Color(0xFF0A64A8),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  if (_keluhanCtrls.length > 1) ...[
                    const SizedBox(width: 4),
                    ReorderableDragStartListener(
                      index: idx,
                      child: const SizedBox(
                        width: 38,
                        height: 48,
                        child: Center(
                          child: AppIcon(
                            AppGlyph.drag,
                            color: AppTheme.textFaint,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Hapus keluhan',
                      onPressed: () => setState(() {
                        _removeTrackedController(ctrl);
                        _keluhanCtrls.removeAt(idx);
                      }),
                      icon: const Icon(Icons.close_rounded,
                          color: AppTheme.error, size: 20),
                    ),
                  ],
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 6),
        AppButton(
          label: 'Tambah keluhan',
          icon: AppGlyph.plus,
          kind: AppButtonKind.tonal,
          onPressed: () => setState(() => _keluhanCtrls.add(_createTrackedController())),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // CARD 4: TINDAK LANJUT
  // ══════════════════════════════════════════════════════════════
  Widget _buildTindakLanjutCard() {
    final validCount =
        _tindakLanjutCtrls.where((c) => c.text.trim().isNotEmpty).length;

    return _cardContainer(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Tindak lanjut',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            StatusPill(
              label:
                  validCount > 0 ? '$validCount tindak lanjut' : 'Belum ada',
              color: validCount > 0 ? const Color(0xFF0A64A8) : AppTheme.textMuted,
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Contoh: rujuk ke puskesmas, kontrol ulang 1 minggu.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 10),

        // Quick Suggestion Pills
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _quickTindakLanjut.map((t) {
            return InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                final emptyIndex = _tindakLanjutCtrls
                    .indexWhere((c) => c.text.trim().isEmpty);
                setState(() {
                  if (emptyIndex != -1) {
                    _tindakLanjutCtrls[emptyIndex].text = t;
                  } else {
                    _tindakLanjutCtrls
                        .add(_createTrackedController(t));
                  }
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E9C6A).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFF2E9C6A).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add,
                        size: 14, color: Color(0xFF2E9C6A)),
                    const SizedBox(width: 4),
                    Text(
                      t,
                      style: const TextStyle(
                        color: Color(0xFF2E9C6A),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),

        // Input List (Bisa digeser/reorder posisi tindak lanjut seperti daftar pasien)
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: _tindakLanjutCtrls.length,
          onReorder: (oldIndex, newIndex) {
            HapticFeedback.selectionClick();
            setState(() {
              if (newIndex > oldIndex) newIndex--;
              final item = _tindakLanjutCtrls.removeAt(oldIndex);
              _tindakLanjutCtrls.insert(newIndex, item);
            });
          },
          itemBuilder: (context, idx) {
            final ctrl = _tindakLanjutCtrls[idx];
            final fieldId = 'tindak_$idx';
            final isActive = _isListening && _activeField == fieldId;

            return Padding(
              key: ObjectKey(ctrl),
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _styledField(
                      label: 'Tindak lanjut ${idx + 1}',
                      controller: ctrl,
                      hint: 'Tuliskan rekomendasi tindakan…',
                      suffixWidget: IconButton(
                        onPressed: () => _toggleVoice(fieldId, ctrl),
                        icon: Icon(
                          isActive
                              ? Icons.mic_rounded
                              : Icons.mic_none_rounded,
                          color: isActive
                              ? AppTheme.error
                              : const Color(0xFF0A64A8),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  if (_tindakLanjutCtrls.length > 1) ...[
                    const SizedBox(width: 4),
                    ReorderableDragStartListener(
                      index: idx,
                      child: const SizedBox(
                        width: 38,
                        height: 48,
                        child: Center(
                          child: AppIcon(
                            AppGlyph.drag,
                            color: AppTheme.textFaint,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Hapus tindak lanjut',
                      onPressed: () => setState(() {
                        _removeTrackedController(ctrl);
                        _tindakLanjutCtrls.removeAt(idx);
                      }),
                      icon: const Icon(Icons.close_rounded,
                          color: AppTheme.error, size: 20),
                    ),
                  ],
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 6),
        AppButton(
          label: 'Tambah tindak lanjut',
          icon: AppGlyph.plus,
          kind: AppButtonKind.tonal,
          onPressed: () => setState(
              () => _tindakLanjutCtrls.add(_createTrackedController())),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // CARD 5: FOTO GEOTAG
  // ══════════════════════════════════════════════════════════════
  Widget _buildFotoGeotagCard() {
    final hasPhoto = _fotoPath != null && _fotoPath!.isNotEmpty;

    return _cardContainer(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Foto geotag',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            StatusPill(
              label: hasPhoto ? 'Tersedia' : 'Opsional',
              color: hasPhoto ? AppTheme.success : AppTheme.textMuted,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Location permission warning card from Galat.dc.html Cap 4
        if (_locationPermissionDenied) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFB06A00).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFB06A00).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.location_off_rounded,
                        color: Color(0xFF8A5200), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Lokasi belum diizinkan',
                      style: TextStyle(
                        color: Color(0xFF8A5200),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Foto tetap bisa disimpan tanpa lokasi. Aktifkan izin kalau ingin lokasi ikut tercatat.',
                  style: TextStyle(
                    color: Color(0xFF4A667E),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Pengaturan',
                        kind: AppButtonKind.tonal,
                        onPressed: () => openAppSettings(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppButton(
                        label: 'Lewati lokasi',
                        kind: AppButtonKind.ghost,
                        onPressed: () => setState(
                            () => _locationPermissionDenied = false),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Photo display or pick box
        if (hasPhoto && File(_fotoPath!).existsSync()) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Image.file(
                  File(_fotoPath!),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: Color(0xFF7FE0A8), size: 14),
                        SizedBox(width: 5),
                        Text(
                          'Foto tersimpan',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Row(
                    children: [
                      _photoActionButton(
                        icon: Icons.refresh_rounded,
                        tooltip: 'Ganti foto',
                        onTap: _pickPhoto,
                      ),
                      const SizedBox(width: 8),
                      _photoActionButton(
                        icon: Icons.delete_outline_rounded,
                        tooltip: 'Hapus foto',
                        isDanger: true,
                        onTap: () => setState(() => _fotoPath = null),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _pickPhoto,
            child: Container(
              height: 130,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF3FA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF9FC4E0),
                  width: 2,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_rounded,
                      color: Color(0xFF0A64A8), size: 32),
                  SizedBox(height: 8),
                  Text(
                    'Ambil foto',
                    style: TextStyle(
                      color: Color(0xFF0A64A8),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Lokasi dicatat otomatis saat foto diambil',
                    style: TextStyle(
                      color: Color(0xFF4A667E),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // HELPER WIDGETS
  // ══════════════════════════════════════════════════════════════
  Widget _cardContainer({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(11, 42, 64, 0.06),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Color.fromRGBO(10, 100, 168, 0.08),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _styledField({
    required String label,
    required TextEditingController controller,
    String? hint,
    FocusNode? focusNode,
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixWidget,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF4A667E),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: keyboardType,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    hintText: hint,
                    hintStyle: const TextStyle(
                      color: AppTheme.textHint,
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                    border: InputBorder.none,
                  ),
                  validator: required
                      ? (v) => v == null || v.trim().isEmpty
                          ? '$label wajib diisi'
                          : null
                      : null,
                ),
              ),
              if (suffixWidget != null) suffixWidget,
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF3FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF4A667E),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_calendar_rounded,
                color: Color(0xFF0A64A8), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _photoActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDanger
                ? AppTheme.error.withValues(alpha: 0.85)
                : Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

/// Bottom Sheet untuk input suara sesuai mockup Galat.dc.html (cap 5).
/// Menampilkan mic berdenyut, visualizer 10 gelombang suara, dan teks realtime.
class _VoiceListeningSheet extends StatefulWidget {
  final String title;
  final String hint;
  final SpeechService speechService;
  final Future<void> Function() onRetry;
  final ValueChanged<String> onFinish;
  final VoidCallback onCancel;

  const _VoiceListeningSheet({
    super.key,
    required this.title,
    required this.hint,
    required this.speechService,
    required this.onRetry,
    required this.onFinish,
    required this.onCancel,
  });

  @override
  State<_VoiceListeningSheet> createState() => _VoiceListeningSheetState();
}

class _VoiceListeningSheetState extends State<_VoiceListeningSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  String _liveText = '';
  bool _isListening = true;

  @override
  void initState() {
    super.initState();
    _liveText = '';
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.94, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  void updateText(String text) {
    if (mounted) {
      setState(() {
        _liveText = text;
      });
    }
  }

  void setListening(bool listening) {
    if (mounted) {
      setState(() {
        _isListening = listening;
        if (!listening) {
          _pulseCtrl.stop();
        } else if (!_pulseCtrl.isAnimating) {
          _pulseCtrl.repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(11, 42, 64, 0.14),
            blurRadius: 34,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        22,
        14,
        22,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD3E4F1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Double ring pulsing mic avatar (Galat.dc.html cap 5)
          // Ketuk mikrofon untuk jeda atau rekam ulang suara secara cepat
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              if (_isListening) {
                widget.speechService.stopListening();
                setListening(false);
              } else {
                updateText('');
                widget.onRetry();
              }
            },
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (context, _) {
                final scale = _isListening ? _pulseAnim.value : 1.0;
                return Container(
                  width: 84 * scale,
                  height: 84 * scale,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A64A8).withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _isListening
                            ? const Color(0xFF0A64A8)
                            : const Color(0xFF0A64A8).withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x330A64A8),
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isListening
                            ? Icons.mic_rounded
                            : Icons.replay_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // Status Mendengarkan
          Text(
            _isListening ? 'Mendengarkan…' : 'Selesai mendengarkan',
            style: const TextStyle(
              color: Color(0xFF0B2A40),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),

          // Hint / guidance field
          Text(
            widget.hint,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF3F5A70),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),

          // 10 Soundwave bars (Galat.dc.html cap 5)
          RepaintBoundary(
            child: SizedBox(
              height: 46,
              child: _VoiceSoundwaveBars(
                level: widget.speechService.level,
                isListening: _isListening,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Live transcript preview box
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F8FD),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD3E4F1)),
            ),
            child: Center(
              child: Text(
                _liveText.isNotEmpty
                    ? _liveText
                    : 'Bicara sekarang, kata-kata Anda akan muncul di sini…',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _liveText.isNotEmpty
                      ? const Color(0xFF0B2A40)
                      : const Color(0xFF4A667E),
                  fontSize: 16,
                  fontWeight: _liveText.isNotEmpty
                      ? FontWeight.w600
                      : FontWeight.w400,
                  fontStyle: _liveText.isNotEmpty
                      ? FontStyle.normal
                      : FontStyle.italic,
                  height: 1.35,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Tombol Aksi: Ulangi (rekam ulang jika tidak cocok) & Selesai
          Row(
            children: [
              Expanded(
                flex: 1,
                child: AppButton(
                  label: 'Ulangi',
                  kind: AppButtonKind.tonal,
                  icon: AppGlyph.update,
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    updateText('');
                    widget.onRetry();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: AppButton(
                  label: 'Selesai',
                  kind: AppButtonKind.primary,
                  icon: AppGlyph.check,
                  onPressed: () => widget.onFinish(_liveText),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Soundwave visualizer animasi 10 batang sesuai Galat.dc.html.
/// Diisolasi dalam RepaintBoundary untuk performa 60fps tanpa repaint parent sheet.
class _VoiceSoundwaveBars extends StatefulWidget {
  final ValueListenable<double>? level;
  final bool isListening;
  const _VoiceSoundwaveBars({this.level, this.isListening = true});

  @override
  State<_VoiceSoundwaveBars> createState() => _VoiceSoundwaveBarsState();
}

class _VoiceSoundwaveBarsState extends State<_VoiceSoundwaveBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  static const _baseHeights = [
    10.0, 22.0, 34.0, 18.0, 40.0, 26.0, 14.0, 30.0, 20.0, 12.0
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isListening) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _VoiceSoundwaveBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening != oldWidget.isListening) {
      if (widget.isListening) {
        _ctrl.repeat(reverse: true);
      } else {
        _ctrl.stop();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listenables = <Listenable>[_ctrl];
    if (widget.level != null) listenables.add(widget.level!);

    return AnimatedBuilder(
      animation: Listenable.merge(listenables),
      builder: (context, _) {
        final t = widget.isListening ? _ctrl.value : 0.0;
        final lvl = widget.isListening ? (widget.level?.value ?? 0.0) : 0.0;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(_baseHeights.length, (idx) {
            final base = _baseHeights[idx];
            // Modulasi ketinggian bergantian secara harmonis ditambah reaksi terhadap level suara
            final wave = 0.35 + 0.65 * (idx.isEven ? t : (1.0 - t));
            final boost = 1.0 + (lvl * 1.4);
            final h = widget.isListening
                ? (base * wave * boost).clamp(6.0, 44.0)
                : 6.0;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: 5,
              height: h,
              decoration: BoxDecoration(
                color: widget.isListening
                    ? const Color(0xFF0A64A8)
                    : const Color(0xFF0A64A8).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        );
      },
    );
  }
}

