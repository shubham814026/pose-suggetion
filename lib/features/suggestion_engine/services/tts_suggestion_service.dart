import 'package:flutter_tts/flutter_tts.dart';

class TtsSuggestionService {
  final FlutterTts _flutterTts = FlutterTts();
  
  bool _isInitialized = false;
  bool _isMuted = false; // Configurable per open decision
  
  String? _lastSpokenText;
  DateTime _lastSpokenTimestamp = DateTime.now().subtract(const Duration(seconds: 10));
  
  static const Duration _minimumSpeechInterval = Duration(seconds: 3);

  bool get isMuted => _isMuted;

  Future<void> initialize({bool voiceOnByDefault = true}) async {
    if (_isInitialized) return;

    _isMuted = !voiceOnByDefault;
    
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _isInitialized = true;
    } catch (_) {
      // Handle TTS platform initialization gracefully
    }
  }

  void setMuted(bool muted) {
    _isMuted = muted;
    if (muted) {
      _flutterTts.stop();
    }
  }

  Future<void> speakSuggestion(String text) async {
    if (!_isInitialized || _isMuted || text.trim().isEmpty) return;

    final now = DateTime.now();
    final bool isNewText = text != _lastSpokenText;
    final bool isIntervalElapsed = now.difference(_lastSpokenTimestamp) >= _minimumSpeechInterval;

    // Throttle guard: only speak on text change OR 3-4s interval elapsed
    if (isNewText || isIntervalElapsed) {
      _lastSpokenText = text;
      _lastSpokenTimestamp = now;

      await _flutterTts.stop();
      await _flutterTts.speak(text);
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
