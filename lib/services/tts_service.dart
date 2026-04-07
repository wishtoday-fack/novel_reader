import 'package:flutter_tts/flutter_tts.dart';
import 'package:novel_reader/utils/logger.dart';

/// Text-to-Speech service for reading aloud book content
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isPlaying = false;
  bool _isInitialized = false;
  double _speechRate = 0.5;
  double _pitch = 1.0;
  String? _currentText;

  bool get isPlaying => _isPlaying;
  bool get isInitialized => _isInitialized;
  double get speechRate => _speechRate;
  double get pitch => _pitch;
  String? get currentText => _currentText;

  /// Initialize TTS engine
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Set language to Chinese
      await _tts.setLanguage('zh-CN');
      
      // Set default speech rate
      await _tts.setSpeechRate(_speechRate);
      
      // Set default pitch
      await _tts.setPitch(_pitch);
      
      // Set completion handler
      _tts.setCompletionHandler(() {
        _isPlaying = false;
        _currentText = null;
        AppLogger.info('TTS playback completed');
      });
      
      // Set error handler
      _tts.setErrorHandler((message) {
        _isPlaying = false;
        AppLogger.error('TTS Error', message);
      });
      
      // Set cancel handler
      _tts.setCancelHandler(() {
        _isPlaying = false;
        _currentText = null;
        AppLogger.info('TTS playback cancelled');
      });
      
      // Get available languages
      final languages = await _tts.getLanguages;
      AppLogger.info('Available TTS languages: $languages');
      
      _isInitialized = true;
      AppLogger.info('TTS service initialized');
    } catch (e) {
      AppLogger.error('Failed to initialize TTS', e);
      rethrow;
    }
  }

  /// Start speaking text
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await init();
    }

    try {
      // Stop any current playback
      if (_isPlaying) {
        await stop();
      }

      _currentText = text;
      _isPlaying = true;
      await _tts.speak(text);
      AppLogger.info('TTS started speaking');
    } catch (e) {
      _isPlaying = false;
      AppLogger.error('Failed to speak', e);
      rethrow;
    }
  }

  /// Stop speaking
  Future<void> stop() async {
    try {
      await _tts.stop();
      _isPlaying = false;
      _currentText = null;
      AppLogger.info('TTS stopped');
    } catch (e) {
      AppLogger.error('Failed to stop TTS', e);
    }
  }

  /// Pause speaking (if supported)
  Future<void> pause() async {
    try {
      await _tts.pause();
      _isPlaying = false;
      AppLogger.info('TTS paused');
    } catch (e) {
      AppLogger.error('Failed to pause TTS', e);
    }
  }

  /// Set speech rate (0.0 - 1.0)
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.0, 1.0);
    await _tts.setSpeechRate(_speechRate);
    AppLogger.info('TTS speech rate set to $_speechRate');
  }

  /// Set pitch (0.5 - 2.0)
  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    await _tts.setPitch(_pitch);
    AppLogger.info('TTS pitch set to $_pitch');
  }

  /// Set language
  Future<void> setLanguage(String language) async {
    await _tts.setLanguage(language);
    AppLogger.info('TTS language set to $language');
  }

  /// Get available voices
  Future<List<Map<String, String>>> getVoices() async {
    try {
      final voices = await _tts.getVoices;
      return List<Map<String, String>>.from(voices);
    } catch (e) {
      AppLogger.error('Failed to get voices', e);
      return [];
    }
  }

  /// Dispose TTS resources
  void dispose() {
    stop();
    _isInitialized = false;
  }
}
