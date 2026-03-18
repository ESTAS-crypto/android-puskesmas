import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../theme/app_theme.dart';
import '../models/report.dart';
import '../models/user_session.dart';
import '../services/storage_service.dart';
import '../services/speech_service.dart';
import 'success_screen.dart';

class ReportFormScreen extends StatefulWidget {
  final UserSession session;
  final Report? existingReport;

  const ReportFormScreen({
    super.key,
    required this.session,
    this.existingReport,
  });

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _speechService = SpeechService();
  final _imagePicker = ImagePicker();

  late TextEditingController _namaCtrl;
  late TextEditingController _usiaCtrl;
  late TextEditingController _alamatCtrl;
  late TextEditingController _bbCtrl;
  late TextEditingController _tbCtrl;
  late TextEditingController _lingkarPinggangCtrl;
  late TextEditingController _tensiCtrl;
  late TextEditingController _lilaCtrl;
  late TextEditingController _likaCtrl;
  late TextEditingController _gulaDarahCtrl;
  late TextEditingController _kategoriKeluargaCtrl;

  final List<TextEditingController> _keluhanControllers = [TextEditingController()];
  final List<TextEditingController> _tindakLanjutControllers = [TextEditingController()];

  // Custom measurement fields: each entry is {label: controller, value: controller}
  final List<Map<String, TextEditingController>> _customFieldControllers = [];

  String? _fotoPath;
  String? _activeListeningField;
  bool _isListening = false;
  bool _isSaving = false;

  String _tanggal = DateFormat('dd.MM.yy').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    final r = widget.existingReport;
    _namaCtrl = TextEditingController(text: r?.nama ?? '');
    _usiaCtrl = TextEditingController(text: r?.usia ?? '');
    _alamatCtrl = TextEditingController(text: r?.alamat ?? '');
    _bbCtrl = TextEditingController(text: r?.bb ?? '');
    _tbCtrl = TextEditingController(text: r?.tb ?? '');
    _lingkarPinggangCtrl = TextEditingController(text: r?.lingkarPinggang ?? '');
    _tensiCtrl = TextEditingController(text: r?.tensi ?? '');
    _lilaCtrl = TextEditingController(text: r?.lila ?? '');
    _likaCtrl = TextEditingController(text: r?.lika ?? '');
    _gulaDarahCtrl = TextEditingController(text: r?.gulaDarah ?? '');
    _kategoriKeluargaCtrl = TextEditingController(text: r?.kategoriKeluarga ?? '');
    _fotoPath = r?.fotoPath;
    if (r != null) {
      _tanggal = r.tanggal;
      _keluhanControllers.clear();
      for (final k in r.keluhan) {
        _keluhanControllers.add(TextEditingController(text: k));
      }
      if (_keluhanControllers.isEmpty) _keluhanControllers.add(TextEditingController());
      _tindakLanjutControllers.clear();
      for (final t in r.tindakLanjut) {
        _tindakLanjutControllers.add(TextEditingController(text: t));
      }
      if (_tindakLanjutControllers.isEmpty) _tindakLanjutControllers.add(TextEditingController());

      // Restore custom fields
      for (final entry in r.customFields.entries) {
        _customFieldControllers.add({
          'label': TextEditingController(text: entry.key),
          'value': TextEditingController(text: entry.value),
        });
      }
    }
    _speechService.initialize();
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _usiaCtrl.dispose();
    _alamatCtrl.dispose();
    _bbCtrl.dispose();
    _tbCtrl.dispose();
    _lingkarPinggangCtrl.dispose();
    _tensiCtrl.dispose();
    _lilaCtrl.dispose();
    _likaCtrl.dispose();
    _gulaDarahCtrl.dispose();
    _kategoriKeluargaCtrl.dispose();
    for (final c in _keluhanControllers) {
      c.dispose();
    }
    for (final c in _tindakLanjutControllers) {
      c.dispose();
    }
    for (final m in _customFieldControllers) {
      m['label']?.dispose();
      m['value']?.dispose();
    }
    _speechService.dispose();
    super.dispose();
  }

  Future<void> _toggleVoice(String fieldName, TextEditingController controller) async {
    if (_isListening && _activeListeningField == fieldName) {
      await _speechService.stopListening();
      setState(() {
        _isListening = false;
        _activeListeningField = null;
      });
      return;
    }

    if (_isListening) {
      await _speechService.stopListening();
    }

    setState(() {
      _isListening = true;
      _activeListeningField = fieldName;
    });

    await _speechService.startListening(
      onResult: (text) {
        setState(() {
          if (controller.text.isNotEmpty) {
            controller.text = '${controller.text} $text';
          } else {
            controller.text = text;
          }
          controller.selection = TextSelection.fromPosition(
            TextPosition(offset: controller.text.length),
          );
          _isListening = false;
          _activeListeningField = null;
        });
      },
      onError: (error) {
        setState(() {
          _isListening = false;
          _activeListeningField = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: AppTheme.error),
                const SizedBox(width: 8),
                Expanded(child: Text(error)),
              ],
            ),
            backgroundColor: AppTheme.cardDark,
          ),
        );
      },
    );
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Pilih Sumber Foto',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: AppTheme.accentTeal),
              ),
              title: const Text('Kamera', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.photo_library_rounded, color: AppTheme.accentBlue),
              ),
              title: const Text('Galeri', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );

    if (picked != null) {
      setState(() => _fotoPath = picked.path);
    }
  }

  Future<void> _saveReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final keluhan = _keluhanControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      final tindakLanjut = _tindakLanjutControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final no = widget.existingReport?.no ?? await StorageService.getNextReportNo();

      // Build custom fields map
      final customFields = <String, String>{};
      for (final m in _customFieldControllers) {
        final label = m['label']!.text.trim();
        final value = m['value']!.text.trim();
        if (label.isNotEmpty && value.isNotEmpty) {
          customFields[label] = value;
        }
      }

      final report = Report(
        id: widget.existingReport?.id,
        no: no,
        tanggal: _tanggal,
        nama: _namaCtrl.text.trim(),
        usia: _usiaCtrl.text.trim(),
        alamat: _alamatCtrl.text.trim(),
        bb: _bbCtrl.text.trim(),
        tb: _tbCtrl.text.trim(),
        lingkarPinggang: _lingkarPinggangCtrl.text.trim(),
        tensi: _tensiCtrl.text.trim(),
        lila: _lilaCtrl.text.trim(),
        lika: _likaCtrl.text.trim(),
        gulaDarah: _gulaDarahCtrl.text.trim(),
        kategoriKeluarga: _kategoriKeluargaCtrl.text.trim(),
        keluhan: keluhan,
        tindakLanjut: tindakLanjut,
        fotoPath: _fotoPath,
        customFields: customFields,
      );

      if (widget.existingReport != null) {
        await StorageService.updateReport(report);
      } else {
        await StorageService.saveReport(report);
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => SuccessScreen(
            session: widget.session,
            report: report,
          ),
          transitionsBuilder: (_, anim, __, child) {
            return FadeTransition(opacity: anim, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
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
                    Expanded(
                      child: Text(
                        widget.existingReport != null ? 'Edit Laporan' : 'Laporan Baru',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_isListening)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppTheme.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Merekam...',
                              style: TextStyle(color: AppTheme.error, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Form Content
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Tanggal
                      _buildSectionTitle('Tanggal Kunjungan'),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                            builder: (context, child) {
                              return Theme(
                                data: AppTheme.darkTheme.copyWith(
                                  colorScheme: const ColorScheme.dark(
                                    primary: AppTheme.accentTeal,
                                    surface: AppTheme.cardDark,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (date != null) {
                            setState(() => _tanggal = DateFormat('dd.MM.yy').format(date));
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceDark,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.divider),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, color: AppTheme.accentTeal, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                _tanggal,
                                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                              ),
                              const Spacer(),
                              const Icon(Icons.edit_rounded, color: AppTheme.textHint, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Data Pasien
                      _buildSectionTitle('Data Pasien'),
                      const SizedBox(height: 12),
                      _buildVoiceField('nama', 'Nama Pasien', _namaCtrl, Icons.person_outline_rounded, required_: true),
                      const SizedBox(height: 12),
                      _buildVoiceField('usia', 'Usia (contoh: 72 tahun)', _usiaCtrl, Icons.cake_outlined, required_: true),
                      const SizedBox(height: 12),
                      _buildVoiceField('alamat', 'Alamat (RT/RW)', _alamatCtrl, Icons.location_on_outlined, required_: true),
                      const SizedBox(height: 24),

                      // Kategori Keluarga
                      _buildSectionTitle('Kategori Keluarga'),
                      const SizedBox(height: 12),
                      _buildVoiceField('kategoriKeluarga', 'Contoh: Bumil Resti, Lansia, dll', _kategoriKeluargaCtrl, Icons.family_restroom_rounded),
                      const SizedBox(height: 24),

                      // Data Pengukuran
                      _buildSectionTitle('Data Pengukuran'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildSmallField('BB (Kg)', _bbCtrl)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildSmallField('TB (cm)', _tbCtrl)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildSmallField('LP (cm)', _lingkarPinggangCtrl)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildSmallField('Tensi', _tensiCtrl)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildSmallField('LILA (cm)', _lilaCtrl)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildSmallField('LiKa (cm)', _likaCtrl)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildSmallField('Gula Darah', _gulaDarahCtrl)),
                          const SizedBox(width: 12),
                          const Spacer(),
                        ],
                      ),

                      // Custom measurement fields
                      ..._customFieldControllers.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final controllers = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildSmallField('Label', controllers['label']!),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: _buildSmallField('Nilai', controllers['value']!),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _customFieldControllers[idx]['label']?.dispose();
                                    _customFieldControllers[idx]['value']?.dispose();
                                    _customFieldControllers.removeAt(idx);
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.error.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.close, color: AppTheme.error, size: 18),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 12),
                      // Add custom field button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _customFieldControllers.add({
                              'label': TextEditingController(),
                              'value': TextEditingController(),
                            });
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.4)),
                            borderRadius: BorderRadius.circular(12),
                            color: AppTheme.accentTeal.withValues(alpha: 0.05),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_circle_outline, color: AppTheme.accentTeal, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Tambah Pengukuran',
                                style: TextStyle(color: AppTheme.accentTeal, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Keluhan
                      _buildSectionTitle('Keluhan'),
                      const SizedBox(height: 8),
                      _buildDynamicList(_keluhanControllers, 'keluhan', 'Tambah keluhan'),
                      const SizedBox(height: 24),

                      // Tindak Lanjut
                      _buildSectionTitle('Tindak Lanjut'),
                      const SizedBox(height: 8),
                      _buildDynamicList(_tindakLanjutControllers, 'tindakLanjut', 'Tambah tindak lanjut'),
                      const SizedBox(height: 24),

                      // Foto
                      _buildSectionTitle('Foto Geotag'),
                      const SizedBox(height: 8),
                      _buildPhotoSection(),
                      const SizedBox(height: 32),

                      // Save Button
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
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 24, height: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.save_rounded, color: Colors.white),
                                        const SizedBox(width: 8),
                                        Text(
                                          widget.existingReport != null ? 'Update Laporan' : 'Simpan Laporan',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.accentTeal,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildVoiceField(
    String fieldName,
    String label,
    TextEditingController controller,
    IconData icon, {
    bool required_ = false,
  }) {
    final isActive = _isListening && _activeListeningField == fieldName;
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        hintText: label,
        prefixIcon: Icon(icon, color: AppTheme.accentTeal),
        suffixIcon: IconButton(
          onPressed: () => _toggleVoice(fieldName, controller),
          icon: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isActive ? AppTheme.error.withValues(alpha: 0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isActive ? Icons.mic_rounded : Icons.mic_none_rounded,
              color: isActive ? AppTheme.error : AppTheme.textHint,
              size: 22,
            ),
          ),
        ),
        filled: true,
        fillColor: AppTheme.surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isActive ? AppTheme.error : AppTheme.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isActive ? AppTheme.error : AppTheme.divider),
        ),
      ),
      style: const TextStyle(color: AppTheme.textPrimary),
      validator: required_ ? (v) => v == null || v.trim().isEmpty ? '$label wajib diisi' : null : null,
    );
  }

  Widget _buildSmallField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        hintText: label,
        filled: true,
        fillColor: AppTheme.surfaceDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.divider),
        ),
      ),
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      keyboardType: TextInputType.text,
    );
  }

  Widget _buildDynamicList(
    List<TextEditingController> controllers,
    String fieldPrefix,
    String addLabel,
  ) {
    return Column(
      children: [
        ...List.generate(controllers.length, (i) {
          final fieldName = '${fieldPrefix}_$i';
          final isActive = _isListening && _activeListeningField == fieldName;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controllers[i],
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: '${fieldPrefix == 'keluhan' ? 'Keluhan' : 'Tindak lanjut'} ${i + 1}',
                      filled: true,
                      fillColor: AppTheme.surfaceDark,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: isActive ? AppTheme.error : AppTheme.divider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: isActive ? AppTheme.error : AppTheme.divider),
                      ),
                      suffixIcon: IconButton(
                        onPressed: () => _toggleVoice(fieldName, controllers[i]),
                        icon: Icon(
                          isActive ? Icons.mic_rounded : Icons.mic_none_rounded,
                          color: isActive ? AppTheme.error : AppTheme.textHint,
                          size: 20,
                        ),
                      ),
                    ),
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  ),
                ),
                if (controllers.length > 1)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        controllers[i].dispose();
                        controllers.removeAt(i);
                      });
                    },
                    icon: const Icon(Icons.remove_circle_outline, color: AppTheme.error, size: 20),
                  ),
              ],
            ),
          );
        }),
        InkWell(
          onTap: () => setState(() => controllers.add(TextEditingController())),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.divider, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_rounded, color: AppTheme.accentTeal, size: 20),
                const SizedBox(width: 6),
                Text(
                  addLabel,
                  style: const TextStyle(color: AppTheme.accentTeal, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoSection() {
    if (_fotoPath != null && File(_fotoPath!).existsSync()) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              File(_fotoPath!),
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              children: [
                _buildPhotoAction(Icons.refresh_rounded, () => _pickPhoto()),
                const SizedBox(width: 4),
                _buildPhotoAction(Icons.close_rounded, () => setState(() => _fotoPath = null)),
              ],
            ),
          ),
        ],
      );
    }

    return InkWell(
      onTap: _pickPhoto,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_rounded, color: AppTheme.accentTeal, size: 32),
            SizedBox(height: 8),
            Text(
              'Tambah Foto',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoAction(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
