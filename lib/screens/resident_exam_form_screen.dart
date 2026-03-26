import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../theme/app_theme.dart';
import '../models/resident_exam.dart';
import '../services/speech_service.dart';
import '../services/storage_service.dart';

/// Form untuk mengisi data satu warga dalam sebuah laporan.
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
  final List<TextEditingController> _tindakLanjutCtrls = [TextEditingController()];
  final List<Map<String, TextEditingController>> _customFieldCtrls = [];

  String? _fotoPath;
  bool _isListening = false;
  String? _activeField;

  @override
  void initState() {
    super.initState();
    final e = widget.existingExam;
    _namaCtrl = TextEditingController(text: e?.nama ?? '');
    _nikCtrl = TextEditingController(text: e?.nik ?? '');
    _tanggal = e?.tanggal ?? DateFormat('dd.MM.yy').format(DateTime.now());
    _usiaCtrl = TextEditingController(text: e?.usia ?? '');
    _alamatCtrl = TextEditingController(text: e?.alamat ?? '');
    _kategoriKeluargaCtrl = TextEditingController(text: e?.kategoriKeluarga ?? '');
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
      if (_tindakLanjutCtrls.isEmpty) _tindakLanjutCtrls.add(TextEditingController());

      for (final entry in e.customFields.entries) {
        _customFieldCtrls.add({
          'label': TextEditingController(text: entry.key),
          'value': TextEditingController(text: entry.value),
        });
      }
    }
    _speechService.initialize();
    
    // Load autocomplete cache
    StorageService.getAllResidents().then((list) {
      if (mounted) setState(() => _cachedResidents = list);
    });
  }

  @override
  void dispose() {
    _namaCtrl.dispose(); _nikCtrl.dispose(); _usiaCtrl.dispose(); _alamatCtrl.dispose();
    _kategoriKeluargaCtrl.dispose(); _bbCtrl.dispose(); _tbCtrl.dispose();
    _lpCtrl.dispose(); _tensiCtrl.dispose(); _lilaCtrl.dispose();
    _likaCtrl.dispose(); _gulaDarahCtrl.dispose();
    for (final c in _keluhanCtrls) { c.dispose(); }
    for (final c in _tindakLanjutCtrls) { c.dispose(); }
    for (final m in _customFieldCtrls) { m['label']?.dispose(); m['value']?.dispose(); }
    _speechService.dispose();
    super.dispose();
  }

  Future<void> _toggleVoice(String fieldName, TextEditingController ctrl) async {
    if (_isListening && _activeField == fieldName) {
      await _speechService.stopListening();
      setState(() { _isListening = false; _activeField = null; });
      return;
    }
    if (_isListening) await _speechService.stopListening();
    setState(() { _isListening = true; _activeField = fieldName; });
    await _speechService.startListening(
      onResult: (text) {
        setState(() {
          ctrl.text = ctrl.text.isEmpty ? text : '${ctrl.text} $text';
          ctrl.selection = TextSelection.fromPosition(TextPosition(offset: ctrl.text.length));
        });
      },
      onError: (_) => setState(() { _isListening = false; _activeField = null; }),
    );
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('Pilih Sumber Foto', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppTheme.accentTeal.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.camera_alt_rounded, color: AppTheme.accentTeal)),
              title: const Text('Kamera', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppTheme.accentBlue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.photo_library_rounded, color: AppTheme.accentBlue)),
              title: const Text('Galeri', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await _imagePicker.pickImage(source: source, maxWidth: 1200, maxHeight: 1200, imageQuality: 80);
    if (picked != null) setState(() => _fotoPath = picked.path);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final keluhan = _keluhanCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    final tindakLanjut = _tindakLanjutCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    final customFields = <String, String>{};
    for (final m in _customFieldCtrls) {
      final label = m['label']!.text.trim();
      final value = m['value']!.text.trim();
      if (label.isNotEmpty && value.isNotEmpty) customFields[label] = value;
    }

    final exam = ResidentExam(
      id: widget.existingExam?.id,
      tanggal: _tanggal,
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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.existingExam != null
                            ? 'Edit Data Pasien ${widget.examIndex}'
                            : 'Data Pasien ${widget.examIndex}',
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton(
                      onPressed: _save,
                      child: const Text('Simpan', style: TextStyle(color: AppTheme.accentTeal, fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppTheme.divider, height: 1),
              // Form
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _sectionTitle('Identitas Pasien'),
                      const SizedBox(height: 12),
                      
                      // -- Tanggal Pemriksaan --
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            builder: (ctx, child) => Theme(
                              data: Theme.of(ctx).copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: AppTheme.accentTeal,
                                  surface: AppTheme.cardDark,
                                  onSurface: AppTheme.textPrimary,
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) {
                            setState(() => _tanggal = DateFormat('dd.MM.yy').format(picked));
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceDark,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.divider),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, color: AppTheme.accentTeal),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Tanggal Kunjungan', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                    Text(_tanggal, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.edit_calendar_rounded, color: AppTheme.textHint, size: 20),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // -- Nama Auto-complete --
                      RawAutocomplete<ResidentExam>(
                        textEditingController: _namaCtrl,
                        focusNode: FocusNode(),
                        displayStringForOption: (option) => option.nama,
                        optionsBuilder: (textEditingValue) {
                          if (textEditingValue.text.isEmpty) return const Iterable<ResidentExam>.empty();
                          return _cachedResidents.where((r) => r.nama.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                        },
                        onSelected: (selection) {
                          setState(() {
                            _nikCtrl.text = selection.nik;
                            _usiaCtrl.text = selection.usia;
                            _alamatCtrl.text = selection.alamat;
                            _kategoriKeluargaCtrl.text = selection.kategoriKeluarga;
                            // Pre-fill last known baseline measurements (can be edited)
                            if (selection.tb.isNotEmpty) _tbCtrl.text = selection.tb;
                            if (selection.bb.isNotEmpty) _bbCtrl.text = selection.bb;
                            if (selection.lingkarPinggang.isNotEmpty) _lpCtrl.text = selection.lingkarPinggang;
                            if (selection.tensi.isNotEmpty) _tensiCtrl.text = selection.tensi;
                            if (selection.lila.isNotEmpty) _lilaCtrl.text = selection.lila;
                            if (selection.lika.isNotEmpty) _likaCtrl.text = selection.lika;
                            if (selection.gulaDarah.isNotEmpty) _gulaDarahCtrl.text = selection.gulaDarah;
                            
                            // Pre-fill custom fields
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
                        },
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                          final isActive = _isListening && _activeField == 'nama';
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            onFieldSubmitted: (_) => onFieldSubmitted(),
                            decoration: InputDecoration(
                              hintText: 'Nama Lengkap (Auto-complete)',
                              prefixIcon: const Icon(Icons.person_outline_rounded, color: AppTheme.accentTeal),
                              suffixIcon: IconButton(
                                onPressed: () => _toggleVoice('nama', controller),
                                icon: Icon(isActive ? Icons.mic_rounded : Icons.mic_none_rounded,
                                    color: isActive ? AppTheme.error : AppTheme.textHint, size: 22),
                              ),
                              filled: true, fillColor: AppTheme.surfaceDark,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.divider)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.divider)),
                            ),
                            style: const TextStyle(color: AppTheme.textPrimary),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Nama Lengkap wajib diisi' : null,
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 8,
                              color: AppTheme.surfaceDark,
                              borderRadius: BorderRadius.circular(12),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 200, maxWidth: 320),
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  itemCount: options.length,
                                  itemBuilder: (context, index) {
                                    final option = options.elementAt(index);
                                    return ListTile(
                                      title: Text(option.nama, style: const TextStyle(color: AppTheme.textPrimary)),
                                      subtitle: Text(option.alamat, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12), maxLines: 1),
                                      onTap: () => onSelected(option),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _voiceField('alamat', 'Alamat Lengkap', _alamatCtrl, Icons.location_on_outlined, required_: true),
                      const SizedBox(height: 12),
                      _voiceField('nik', 'NIK', _nikCtrl, Icons.badge_outlined),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _smallField('Usia', _usiaCtrl)),
                        const SizedBox(width: 12),
                        Expanded(child: _smallField('Kategori Keluarga', _kategoriKeluargaCtrl)),
                      ]),
                      const SizedBox(height: 24),

                      _sectionTitle('Hasil Pemeriksaan'),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _smallField('BB (kg)', _bbCtrl)),
                        const SizedBox(width: 12),
                        Expanded(child: _smallField('TB (cm)', _tbCtrl)),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _smallField('LP (cm)', _lpCtrl)),
                        const SizedBox(width: 12),
                        Expanded(child: _smallField('Tensi', _tensiCtrl)),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _smallField('LILA (cm)', _lilaCtrl)),
                        const SizedBox(width: 12),
                        Expanded(child: _smallField('LiKa (cm)', _likaCtrl)),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _smallField('Gula Darah', _gulaDarahCtrl)),
                        const SizedBox(width: 12),
                        const Spacer(),
                      ]),

                      // Custom measurement fields
                      ..._customFieldCtrls.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final ctrls = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(children: [
                            Expanded(flex: 2, child: _smallField('Label', ctrls['label']!)),
                            const SizedBox(width: 8),
                            Expanded(flex: 2, child: _smallField('Nilai', ctrls['value']!)),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => setState(() {
                                _customFieldCtrls[idx]['label']?.dispose();
                                _customFieldCtrls[idx]['value']?.dispose();
                                _customFieldCtrls.removeAt(idx);
                              }),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.close, color: AppTheme.error, size: 18),
                              ),
                            ),
                          ]),
                        );
                      }),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => setState(() => _customFieldCtrls.add({'label': TextEditingController(), 'value': TextEditingController()})),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.4)),
                            borderRadius: BorderRadius.circular(12),
                            color: AppTheme.accentTeal.withValues(alpha: 0.05),
                          ),
                          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.add_circle_outline, color: AppTheme.accentTeal, size: 20),
                            SizedBox(width: 8),
                            Text('Tambah Hasil Pemeriksaan', style: TextStyle(color: AppTheme.accentTeal, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 24),

                      _sectionTitle('Keluhan'),
                      const SizedBox(height: 8),
                      _dynamicList(_keluhanCtrls, 'keluhan', 'Tambah keluhan'),
                      const SizedBox(height: 24),

                      _sectionTitle('Tindak Lanjut'),
                      const SizedBox(height: 8),
                      _dynamicList(_tindakLanjutCtrls, 'tindakLanjut', 'Tambah tindak lanjut'),
                      const SizedBox(height: 24),

                      _sectionTitle('Foto Geotag'),
                      const SizedBox(height: 8),
                      _photoSection(),
                      const SizedBox(height: 32),
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

  Widget _sectionTitle(String title) => Text(title,
      style: const TextStyle(color: AppTheme.accentTeal, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5));

  Widget _voiceField(String fieldName, String hint, TextEditingController ctrl, IconData icon, {bool required_ = false}) {
    final isActive = _isListening && _activeField == fieldName;
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.accentTeal),
        suffixIcon: IconButton(
          onPressed: () => _toggleVoice(fieldName, ctrl),
          icon: Icon(isActive ? Icons.mic_rounded : Icons.mic_none_rounded,
              color: isActive ? AppTheme.error : AppTheme.textHint, size: 22),
        ),
        filled: true, fillColor: AppTheme.surfaceDark,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.divider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.divider)),
      ),
      style: const TextStyle(color: AppTheme.textPrimary),
      validator: required_ ? (v) => v == null || v.trim().isEmpty ? '$hint wajib diisi' : null : null,
    );
  }

  Widget _smallField(String label, TextEditingController ctrl) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        hintText: label, filled: true, fillColor: AppTheme.surfaceDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.divider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.divider)),
      ),
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
    );
  }

  Widget _dynamicList(List<TextEditingController> ctrls, String prefix, String addLabel) {
    return Column(children: [
      ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: ctrls.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex--;
            final item = ctrls.removeAt(oldIndex);
            ctrls.insert(newIndex, item);
          });
        },
        itemBuilder: (context, i) {
          final fieldName = '${prefix}_$i';
          final isActive = _isListening && _activeField == fieldName;
          return Padding(
            key: ObjectKey(ctrls[i]),
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              ReorderableDragStartListener(
                index: i,
                child: Container(
                  color: Colors.transparent,
                  padding: const EdgeInsets.only(right: 12, top: 12, bottom: 12),
                  child: const Icon(Icons.drag_handle_rounded, color: AppTheme.textHint, size: 20),
                ),
              ),
              Expanded(
                child: TextFormField(
                  controller: ctrls[i],
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: '${prefix == 'keluhan' ? 'Keluhan' : 'Tindak Lanjut'} ${i + 1}',
                    filled: true, fillColor: AppTheme.surfaceDark,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isActive ? AppTheme.error : AppTheme.divider)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isActive ? AppTheme.error : AppTheme.divider)),
                    suffixIcon: IconButton(
                      onPressed: () => _toggleVoice(fieldName, ctrls[i]),
                      icon: Icon(isActive ? Icons.mic_rounded : Icons.mic_none_rounded,
                          color: isActive ? AppTheme.error : AppTheme.textHint, size: 20),
                    ),
                  ),
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                ),
              ),
              if (ctrls.length > 1) IconButton(
                onPressed: () => setState(() { ctrls[i].dispose(); ctrls.removeAt(i); }),
                icon: const Icon(Icons.remove_circle_outline, color: AppTheme.error, size: 20),
              ),
            ]),
          );
        },
      ),
      InkWell(
        onTap: () => setState(() => ctrls.add(TextEditingController())),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(border: Border.all(color: AppTheme.divider), borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.add_rounded, color: AppTheme.accentTeal, size: 20),
            const SizedBox(width: 6),
            Text(addLabel, style: const TextStyle(color: AppTheme.accentTeal, fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    ]);
  }

  Widget _photoSection() {
    if (_fotoPath != null && File(_fotoPath!).existsSync()) {
      return Stack(children: [
        ClipRRect(borderRadius: BorderRadius.circular(16),
            child: Image.file(File(_fotoPath!), height: 200, width: double.infinity, fit: BoxFit.cover)),
        Positioned(top: 8, right: 8, child: Row(children: [
          _photoBtn(Icons.refresh_rounded, () => _pickPhoto()),
          const SizedBox(width: 4),
          _photoBtn(Icons.close_rounded, () => setState(() => _fotoPath = null)),
        ])),
      ]);
    }
    return InkWell(
      onTap: _pickPhoto,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 120,
        decoration: BoxDecoration(color: AppTheme.surfaceDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.divider)),
        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.add_a_photo_rounded, color: AppTheme.accentTeal, size: 32),
          SizedBox(height: 8),
          Text('Tambah Foto', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        ]),
      ),
    );
  }

  Widget _photoBtn(IconData icon, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: Container(padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: Colors.white, size: 20)),
  );
}
