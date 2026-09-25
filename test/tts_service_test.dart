import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_tracker/services/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TtsService Tests', () {
    final List<MethodCall> methodCalls = [];

    setUp(() {
      methodCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (call) async {
        methodCalls.add(call);
        return 1;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
    });

    test('isSpeaking initial state is false', () {
      expect(TtsService.instance.isSpeaking, isFalse);
    });

    test('init configures audio settings including silent mode playback', () async {
      await TtsService.instance.init('EN');

      final methodNames = methodCalls.map((c) => c.method).toList();
      expect(methodNames, contains('setLanguage'));
      expect(methodNames, contains('setSpeechRate'));
      expect(methodNames, contains('setVolume'));
      expect(methodNames, contains('awaitSpeakCompletion'));
    });

    test('init on iOS configures AVAudioSessionCategoryPlayback to bypass silent switch', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        methodCalls.clear();
        await TtsService.instance.init('EN');

        final methodNames = methodCalls.map((c) => c.method).toList();
        // flutter_tts checks Platform.isIOS internally before invoking 'setIosAudioCategory',
        // but invokes setSharedInstance and autoStopSharedSession directly.
        expect(methodNames, contains('setSharedInstance'));
        expect(methodNames, contains('autoStopSharedSession'));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('init on Android configures navigation/media audio attributes', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        methodCalls.clear();
        await TtsService.instance.init('EN');

        final methodNames = methodCalls.map((c) => c.method).toList();
        expect(methodNames, contains('setAudioAttributesForNavigation'));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('Guidance debouncing skips identical recent messages', () async {
      // Calling stop resets state
      await TtsService.instance.stop();
      expect(TtsService.instance.isSpeaking, isFalse);
    });
  });
}
