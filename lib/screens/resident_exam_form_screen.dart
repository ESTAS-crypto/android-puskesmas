import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/resident_exam.dart';
import '../services/speech_service.dart';
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

  final List<TextEditingController> _keluhanCtrls = [TextEditingController()];
  final List<TextEditingController> _tindakLanjutCtrls = [
    TextEditingController()
  ];
  final List<Map<String, TextEditingController>> _customFieldCtrls = [];

  String? _fotoPath;
  bool _isListening = false;
  String? _activeField;
  bool _speechAvailable = true;
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

  @override
  void initState() {
    super.initState();
    final e = widget.existingExam;
    _namaCtrl = TextEditingController(text: e?.nama ?? '');
    _nikCtrl = TextEditingController(text: e?.nik ?? '');
    _tanggal = e?.tanggal ?? DateFormat('dd.MM.yy').format(DateTime.now());
    _tanggalLahirCtrl = TextEditingController(text: e?.tanggalLahir ?? '');
    _usiaCtrl = TextEditingController(text: e?.usia ?? '');
    _alamatCtrl = TextEditingController(text: e?.alamat ?? '');
    _kategoriKeluargaCtrl =
        TextEditingController(text: e?.kategoriKeluarga ?? '');
    _bbCtrl = TextEditingController(text: e?.bb ?? '');
    _tbCtrl = TextEditingController(text: e?.tb ?? '');
    _lpCtrl = TextEditingController(text: e?.lingkarPinggang ?? '');
    _tensiCtrl = TextEditingController(text: e?.tensi ?? '');
    _lilaCtrl = TextEditingController(text: e?.lila ?? '');
    _likaCtrl = TextEditingController(text: e?.lika ?? '');
    _gulaDarahCtrl = TextEditingController(text: e?.gulaDarah ?? '');
    _fotoPath = e?.fotoPath;

    if (e != null) {
      _keluhanCtrls.clear();
      for (final k in e.keluhan) {
        _keluhanCtrls.add(TextEditingController(text: k));
      }
      if (_keluhanCtrls.isEmpty) _keluhanCtrls.add(TextEditingController());

      _tindakLanjutCtrls.clear();
      for (final t in e.tindakLanjut) {
        _tindakLanjutCtrls.add(TextEditingController(text: t));
      }
      if (_tindakLanjutCtrls.isEmpty) {
        _tindakLanjutCtrls.add(TextEditingController());
      }

      for (final entry in e.customFields.entries) {
        _customFieldCtrls.add({
          'label': TextEditingController(text: entry.key),
          'value': TextEditingController(text: entry.value),
        });
      }
    }

    _initSpeech();

    // Load autocomplete cache
    StorageService.getAllResidents().then((list) {
      if (mounted) setState(() => _cachedResidents = list);
    });

    // Add listeners for dynamic progress calculation
    _namaCtrl.addListener(_onFieldChanged);
    _alamatCtrl.addListener(_onFieldChanged);
    _bbCtrl.addListener(_onFieldChanged);
    _tbCtrl.addListener(_onFieldChanged);
    _tensiCtrl.addListener(_onFieldChanged);
    _gulaDarahCtrl.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initSpeech() async {
    final available = await _speechService.initialize();
    if (mounted) setState(() => _speechAvailable = available);
  }

  @override
  void dispose() {
    _namaCtrl.removeListener(_onFieldChanged);
    _alamatCtrl.removeListener(_onFieldChanged);
    _bbCtrl.removeListener(_onFieldChanged);
    _tbCtrl.removeListener(_onFieldChanged);
    _tensiCtrl.removeListener(_onFieldChanged);
    _gulaDarahCtrl.removeListener(_onFieldChanged);

    _namaCtrl.dispose();
    _nikCtrl.dispose();
    _tanggalLahirCtrl.dispose();
    _usiaCtrl.dispose();
    _alamatCtrl.dispose();
    _kategoriKeluargaCtrl.dispose();
    _bbCtrl.dispose();
    _tbCtrl.dispose();
    _lpCtrl.dispose();
    _tensiCtrl.dispose();
    _lilaCtrl.dispose();
    _likaCtrl.dispose();
    _gulaDarahCtrl.dispose();
    for (final c in _keluhanCtrls) {
      c.dispose();
    }
    for (final c in _tindakLanjutCtrls) {
      c.dispose();
    }
    for (final m in _customFieldCtrls) {
      m['label']?.dispose();
      m['value']?.dispose();
    }
    _speechService.dispose();
    super.dispose();
  }

  // ── Perhitungan Progres Pengisian ─────────────────────────
  int get _filledSectionsCount {
    int count = 0;
    // 1. Identitas
    if (_namaCtrl.text.trim().isNotEmpty &&
        (_alamatCtrl.text.trim().isNotEmpty ||
            _usiaCtrl.text.trim().isNotEmpty ||
            _tanggalLahirCtrl.text.trim().isNotEmpty)) {
      count++;
    }
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
    if (_keluhanCtrls.any((c) => c.text.trim().isNotEmpty)) {
      count++;
    }
    // 4. Tindak Lanjut
    if (_tindakLanjutCtrls.any((c) => c.text.trim().isNotEmpty)) {
      count++;
    }
    // 5. Foto
    if (_fotoPath != null && _fotoPath!.isNotEmpty) {
      count++;
    }
    return count;
  }

  // ── Voice Input Handling ──────────────────────────────────
  Future<void> _toggleVoice(
      String fieldName, TextEditingController ctrl) async {
    if (!_speechAvailable) {
      _showVoiceUnavailableDialog();
      return;
    }

    if (_isListening && _activeField == fieldName) {
      await _speechService.stopListening();
      setState(() {
        _isListening = false;
        _activeField = null;
      });
      return;
    }

    if (_isListening) await _speechService.stopListening();
    setState(() {
      _isListening = true;
      _activeField = fieldName;
    });

    _showListeningBottomSheet(fieldName, ctrl);

    await _speechService.startListening(
      onResult: (text) {
        if (!mounted) return;
        setState(() {
          ctrl.text = ctrl.text.isEmpty ? text : '${ctrl.text} $text';
          ctrl.selection =
              TextSelection.fromPosition(TextPosition(offset: ctrl.text.length));
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _activeField = null;
        });
      },
    );
  }

  void _showListeningBottomSheet(
      String fieldName, TextEditingController ctrl) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // Mic pulsing avatar
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A64A8).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0A64A8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic_rounded,
                        color: Colors.white, size: 28),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Mendengarkan…',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Ucapkan keluhan pasien, misalnya "pusing dan sulit tidur".',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 14),
              const RepaintBoundary(
                child: SizedBox(
                  height: 46,
                  child: _VoiceSoundwaveBars(),
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Selesai',
                kind: AppButtonKind.tonal,
                onPressed: () {
                  _speechService.stopListening();
                  setState(() {
                    _isListening = false;
                    _activeField = null;
                  });
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      if (_isListening) {
        _speechService.stopListening();
        setState(() {
          _isListening = false;
          _activeField = null;
        });
      }
    });
  }

  void _showVoiceUnavailableDialog() {
    AppToast.show(
      context,
      'Input suara tidak tersedia di perangkat ini. Silakan ketik manual.',
      kind: AppToastKind.warning,
    );
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
    final progressPercent = (filledCount / 5).clamp(0.0, 1.0);
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
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
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
                        child: LinearProgressIndicator(
                          value: progressPercent,
                          minHeight: 10,
                          backgroundColor: const Color(0xFFEAF3FA),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF0A64A8)),
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
      bottomNavigationBar: Container(
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
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          16 + MediaQuery.of(context).padding.bottom,
        ),
        child: AppButton(
          label: 'Simpan pasien',
          icon: AppGlyph.check,
          kind: AppButtonKind.primary,
          onPressed: _save,
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
          focusNode: FocusNode(),
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

              for (var c in _customFieldCtrls) {
                c['label']?.dispose();
                c['value']?.dispose();
              }
              _customFieldCtrls.clear();
              for (final entry in selection.customFields.entries) {
                _customFieldCtrls.add({
                  'label': TextEditingController(text: entry.key),
                  'value': TextEditingController(text: entry.value),
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
                onPressed: () => _toggleVoice('nama', controller),
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
                  onPressed: () => _toggleVoice('alamat', _alamatCtrl),
                  icon: const Icon(Icons.mic_none_rounded,
                      color: Color(0xFF0A64A8), size: 20),
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
                      _customFieldCtrls[idx]['label']?.dispose();
                      _customFieldCtrls[idx]['value']?.dispose();
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
                'label': TextEditingController(),
                'value': TextEditingController(),
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
                    _keluhanCtrls.add(TextEditingController(text: k));
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

        // Input List
        ..._keluhanCtrls.asMap().entries.map((entry) {
          final idx = entry.key;
          final ctrl = entry.value;
          final fieldId = 'keluhan_$idx';
          final isActive = _isListening && _activeField == fieldId;

          return Padding(
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
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Hapus keluhan',
                    onPressed: () => setState(() {
                      ctrl.dispose();
                      _keluhanCtrls.removeAt(idx);
                    }),
                    icon: const Icon(Icons.close_rounded,
                        color: AppTheme.error, size: 20),
                  ),
                ],
              ],
            ),
          );
        }),

        const SizedBox(height: 6),
        AppButton(
          label: 'Tambah keluhan',
          icon: AppGlyph.plus,
          kind: AppButtonKind.tonal,
          onPressed: () => setState(() => _keluhanCtrls.add(TextEditingController())),
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
                        .add(TextEditingController(text: t));
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

        // Input List
        ..._tindakLanjutCtrls.asMap().entries.map((entry) {
          final idx = entry.key;
          final ctrl = entry.value;
          final fieldId = 'tindak_$idx';
          final isActive = _isListening && _activeField == fieldId;

          return Padding(
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
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Hapus tindak lanjut',
                    onPressed: () => setState(() {
                      ctrl.dispose();
                      _tindakLanjutCtrls.removeAt(idx);
                    }),
                    icon: const Icon(Icons.close_rounded,
                        color: AppTheme.error, size: 20),
                  ),
                ],
              ],
            ),
          );
        }),

        const SizedBox(height: 6),
        AppButton(
          label: 'Tambah tindak lanjut',
          icon: AppGlyph.plus,
          kind: AppButtonKind.tonal,
          onPressed: () => setState(
              () => _tindakLanjutCtrls.add(TextEditingController())),
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

/// Soundwave visualizer animasi 10 batang sesuai Galat.dc.html.
/// Diisolasi dalam RepaintBoundary untuk performa 60fps tanpa repaint parent sheet.
class _VoiceSoundwaveBars extends StatefulWidget {
  const _VoiceSoundwaveBars();

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
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(_baseHeights.length, (idx) {
            final base = _baseHeights[idx];
            // Modulasi ketinggian bergantian secara harmonis
            final factor = 0.4 + 0.6 * (idx.isEven ? t : (1.0 - t));
            final h = (base * factor).clamp(6.0, 42.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 5,
              height: h,
              decoration: BoxDecoration(
                color: const Color(0xFF0A64A8),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        );
      },
    );
  }
}
