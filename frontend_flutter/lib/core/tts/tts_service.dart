
import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { idle, loading, playing }

class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  TtsState _state       = TtsState.idle;
  String?  _playingText;

  bool get isIdle    => _state == TtsState.idle;
  bool get isPlaying => _state == TtsState.playing;
  bool get isLoading => _state == TtsState.loading;

  bool isPlayingText(String text) =>
      _state == TtsState.playing && _playingText == text;

  bool isLoadingText(String text) =>
      _state == TtsState.loading && _playingText == text;

  /// UI calls this to rebuild when state changes
  void Function()? onStateChanged;

  Future<void> init() async {
    await _tts.setVolume(1.0);
    await _tts.setSpeechRate(0.5);  // slightly slower — easier to follow
    await _tts.setPitch(1.0);

    _tts.setCompletionHandler(() => _reset());
    _tts.setErrorHandler((_)    => _reset());
    _tts.setCancelHandler(()    => _reset());
  }

  /// Speak text in the given language code (matches Aurora's lang codes)
  Future<void> speak(String text, {String langCode = 'en'}) async {
    // Tap again while playing → stop
    if (_playingText == text &&
        (_state == TtsState.playing || _state == TtsState.loading)) {
      await stop();
      return;
    }

    await stop();

    _state       = TtsState.loading;
    _playingText = text;
    onStateChanged?.call();

    // Map Aurora lang codes to BCP-47 locale strings
    final locale = _localeFor(langCode);
    await _tts.setLanguage(locale);

    _state = TtsState.playing;
    onStateChanged?.call();

    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
    _reset();
  }

  void _reset() {
    _state       = TtsState.idle;
    _playingText = null;
    onStateChanged?.call();
  }

  void dispose() {
    _tts.stop();
  }

  /// Maps Aurora's language codes → BCP-47 locale for flutter_tts
  String _localeFor(String code) {
    const map = {
      'en':      'en-US',
      'hi':      'hi-IN',
      'bn':      'bn-IN',
      'mr':      'mr-IN',
      'ta':      'ta-IN',
      'te':      'te-IN',
      'gu':      'gu-IN',
      'kn':      'kn-IN',
      'ml':      'ml-IN',
      'pa':      'pa-IN',
      'ur':      'ur-PK',
      'or':      'or-IN',
      'as':      'as-IN',
      'ne':      'ne-NP',
      'es':      'es-ES',
      'fr':      'fr-FR',
      'de':      'de-DE',
      'ar':      'ar-SA',
      'pt':      'pt-PT',
      'id':      'id-ID',
      'ja':      'ja-JP',
      'ko':      'ko-KR',
      'zh':      'zh-CN',
      'hinglish': 'hi-IN',  // closest match
    };
    return map[code] ?? 'en-US';
  }
}