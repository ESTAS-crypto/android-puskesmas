import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Pengenalan suara bahasa Indonesia.
///
/// Perbedaan dari versi lama:
///  1. Memilih locale Indonesia yang BENAR-BENAR ada di HP (id_ID / in_ID). Versi lama memaksa
///     'id_ID'; bila tidak tersedia, mesin diam-diam memakai bahasa lain → hasil ngawur.
///  2. Hasil sementara (partial) ditampilkan langsung, jadi pengguna melihat apa yang terdengar.
///  3. Jika perekaman berhenti tanpa hasil akhir, kata terakhir yang terdengar tetap dipakai.
///  4. Galat TIDAK lagi ditelan: dikirim sebagai pesan bahasa sederhana.
///  5. pauseFor/listenFor diatur eksplisit (Android biasanya memotong ±10 dtk bila hening).
class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();

  /// Tingkat suara 0..1 (perkiraan) untuk animasi gelombang di UI.
  final ValueNotifier<double> level = ValueNotifier<double>(0);

  bool _ready = false;
  String? _localeId;
  String _last = '';

  void Function(String text)? _onResult;
  void Function(String message)? _onError;
  void Function()? _onDone;

  bool get isListening => _speech.isListening;
  String? get localeId => _localeId;

  Future<bool> initialize() async {
    if (_ready) return true;
    _ready = await _speech.initialize(
      onError: _handleError,
      onStatus: _handleStatus,
    );
    if (_ready) {
      final locales = await _speech.locales();
      _localeId = _pickIndonesian(locales);
      debugPrint('[Speech] locale terpilih: $_localeId '
          '(tersedia ${locales.length}, sistem: ${(await _speech.systemLocale())?.localeId})');
    }
    return _ready;
  }

  static String? _pickIndonesian(List<stt.LocaleName> locales) {
    for (final pref in const ['id_id', 'in_id', 'id-id', 'in-id']) {
      for (final l in locales) {
        if (l.localeId.toLowerCase() == pref) return l.localeId;
      }
    }
    final re = RegExp(r'^(id|in)[_-]', caseSensitive: false);
    for (final l in locales) {
      if (re.hasMatch(l.localeId)) return l.localeId;
    }
    return null;
  }

  Future<void> startListening({
    required void Function(String text) onResult,
    required void Function(String message) onError,
    void Function(String partial)? onPartial,
    void Function()? onDone,
  }) async {
    if (!await initialize()) {
      onError('Pengenalan suara tidak tersedia di HP ini. Pastikan aplikasi Google '
          'terpasang dan izin mikrofon aktif.');
      return;
    }
    if (_localeId == null) {
      onError(friendly('error_language_unavailable'));
      return;
    }

    _onResult = onResult;
    _onError = onError;
    _onDone = onDone;
    _last = '';

    await _speech.listen(
      onResult: (SpeechRecognitionResult r) {
        _last = r.recognizedWords;
        debugPrint('[Speech] words: "${r.recognizedWords}", final: ${r.finalResult}');
        if (r.finalResult) {
          _deliver();
        } else {
          onPartial?.call(r.recognizedWords);
        }
      },
      localeId: _localeId,
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 7),
      onSoundLevelChange: (l) => level.value = ((l + 2) / 12).clamp(0.0, 1.0).toDouble(),
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
        onDevice: false,
      ),
    );
  }

  void _deliver() {
    final words = _last.trim();
    if (words.isEmpty) return;
    _onResult?.call(words);
  }

  void _handleStatus(String status) {
    debugPrint('[Speech] status: $status');
    if (status == 'notListening') {
      level.value = 0;
      // Jangan langsung memutus sesi di sini; recognizer Android masih dalam proses
      // menghasilkan transkripsi final dari audio yang baru selesai didengar.
    } else if (status == 'done' || status == 'doneNoResult') {
      level.value = 0;
      _deliver();
      _onDone?.call();
    }
  }

  void _handleError(SpeechRecognitionError e) {
    debugPrint('[Speech] error: ${e.errorMsg} permanent=${e.permanent}');
    level.value = 0;
    if (_last.trim().isNotEmpty) {
      _deliver();
    } else {
      _onError?.call(friendly(e.errorMsg));
    }
    _onDone?.call();
  }

  Future<void> stopListening() async {
    await _speech.stop();
    level.value = 0;
    _deliver();
    _onDone?.call();
  }

  void dispose() {
    _speech.cancel();
    level.dispose();
  }

  /// Pesan galat dalam bahasa sederhana (tanpa kode teknis).
  static String friendly(String code) {
    final c = code.toLowerCase();
    if (c.contains('no_match')) {
      return 'Suara belum terbaca. Coba ulangi, dekatkan HP ke mulut, bicara pelan dan jelas.';
    }
    if (c.contains('speech_timeout')) {
      return 'Tidak ada suara terdengar. Ketuk mikrofon, lalu langsung bicara.';
    }
    if (c.contains('network')) {
      return 'Pengenalan suara butuh internet. Atau unduh bahasa Indonesia di pengaturan suara Google agar bisa tanpa sinyal.';
    }
    if (c.contains('permission')) {
      return 'Izin mikrofon belum diberikan. Aktifkan di Pengaturan › Aplikasi › Izin.';
    }
    if (c.contains('language')) {
      return 'Bahasa Indonesia belum tersedia untuk suara di HP ini. Buka pengaturan suara Google, lalu unduh bahasa Indonesia.';
    }
    if (c.contains('busy')) {
      return 'Mikrofon sedang dipakai. Tunggu sebentar lalu coba lagi.';
    }
    if (c.contains('audio')) {
      return 'Mikrofon bermasalah. Tutup aplikasi lain yang memakai mikrofon.';
    }
    return 'Suara belum bisa diproses. Silakan ketik manual.';
  }
}
