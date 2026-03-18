import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  bool get isListening => _isListening;

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    _isInitialized = await _speech.initialize(
      onError: (error) {
        _isListening = false;
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _isListening = false;
        }
      },
    );
    return _isInitialized;
  }

  Future<void> startListening({
    required Function(String text) onResult,
    required Function(String error) onError,
  }) async {
    if (!_isInitialized) {
      final available = await initialize();
      if (!available) {
        onError('Speech recognition tidak tersedia di perangkat ini');
        return;
      }
    }

    _isListening = true;
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          onResult(result.recognizedWords);
          _isListening = false;
        }
      },
      localeId: 'id_ID',
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        cancelOnError: true,
      ),
    );
  }

  Future<void> stopListening() async {
    _isListening = false;
    await _speech.stop();
  }

  void dispose() {
    _speech.stop();
    _speech.cancel();
  }
}
