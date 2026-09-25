import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService instance = TtsService._internal();
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;

  DateTime _lastSpokenTime = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastSpokenText;

  // Synchronization queue to guarantee speeches run sequentially without overlapping
  Future<void> _speechChain = Future.value();

  Future<void> init(String language) async {
    try {
      final langCode = language.toUpperCase() == 'KR' ? 'ko-KR' : 'en-US';
      await _flutterTts.setLanguage(langCode);
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      // Tell native TTS engine to wait until audio playback finishes
      await _flutterTts.awaitSpeakCompletion(true);

      // Enable audio playback even when the device is in silent mode:
      // On iOS, AVAudioSessionCategoryPlayback ignores the hardware Ring/Silent switch.
      // mixWithOthers and duckOthers allow speech to duck background music and restore it seamlessly.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        try {
          await _flutterTts.setIosAudioCategory(
            IosTextToSpeechAudioCategory.playback,
            [
              IosTextToSpeechAudioCategoryOptions.mixWithOthers,
              IosTextToSpeechAudioCategoryOptions.duckOthers,
            ],
            IosTextToSpeechAudioMode.defaultMode,
          );
          await _flutterTts.setSharedInstance(true);
          await _flutterTts.autoStopSharedSession(true);
        } catch (e) {
          debugPrint('Error configuring iOS audio category: $e');
        }
      }

      // On Android, set navigation guidance / speech audio attributes so audio plays when ringer is silent
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          await _flutterTts.setAudioAttributesForNavigation();
        } catch (e) {
          debugPrint('Error configuring Android audio attributes: $e');
        }
      }

      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
      });

      _flutterTts.setCancelHandler(() {
        _isSpeaking = false;
      });

      _flutterTts.setErrorHandler((msg) {
        _isSpeaking = false;
        debugPrint('TTS Error: $msg');
      });
    } catch (e) {
      debugPrint('TTS initialization error: $e');
    }
  }

  Future<void> setLanguage(String language) async {
    try {
      final langCode = language.toUpperCase() == 'KR' ? 'ko-KR' : 'en-US';
      await _flutterTts.setLanguage(langCode);
    } catch (e) {
      debugPrint('Error changing TTS language: $e');
    }
  }

  /// Speaks text and waits until playback is completely finished before returning.
  /// Sequential calls are queued so they never overlap or cut each other off.
  Future<void> speak(
    String text, {
    bool isGuidance = false,
    Duration minInterval = const Duration(seconds: 3),
  }) async {
    final now = DateTime.now();

    // Guidance debouncing: never interrupt or backlog guidance if already speaking
    if (isGuidance) {
      if (_isSpeaking) return;
      if (text == _lastSpokenText && now.difference(_lastSpokenTime) < minInterval) {
        return;
      }
      if (now.difference(_lastSpokenTime) < const Duration(milliseconds: 1800)) {
        return;
      }
    }

    final completer = Completer<void>();
    final prev = _speechChain;
    _speechChain = completer.future;

    try {
      await prev;
    } catch (_) {}

    try {
      _lastSpokenTime = DateTime.now();
      _lastSpokenText = text;
      _isSpeaking = true;
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('Error in TTS speak: $e');
    } finally {
      _isSpeaking = false;
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      _isSpeaking = false;
      _speechChain = Future.value();
    } catch (e) {
      debugPrint('Error stopping TTS: $e');
    }
  }
}
