import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_tracker/services/sound_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SoundService Tests', () {
    final List<MethodCall> globalMethodCalls = [];
    final List<MethodCall> playerMethodCalls = [];

    setUp(() {
      globalMethodCalls.clear();
      playerMethodCalls.clear();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('xyz.luan/audioplayers.global'), (call) async {
        globalMethodCalls.add(call);
        return 1;
      });

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('xyz.luan/audioplayers'), (call) async {
        playerMethodCalls.add(call);
        return 1;
      });

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (call) async {
        return '/tmp';
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('xyz.luan/audioplayers.global'), null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('xyz.luan/audioplayers'), null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), null);
    });

    test('init configures audio context with respectSilence false on iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        globalMethodCalls.clear();
        playerMethodCalls.clear();
        SoundService.instance.resetForTest();
        await SoundService.instance.init();

        // Audio context is configured to play through silent switch
        final contextCall = globalMethodCalls.where((c) => c.method == 'setAudioContext').toList();
        expect(contextCall.isNotEmpty, isTrue);

        final args = contextCall.first.arguments as Map<dynamic, dynamic>;
        expect(args['category'], equals('playback'));
        expect(args['options'], contains('duckOthers'));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('init configures audio context on Android for both global and player instance', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        globalMethodCalls.clear();
        playerMethodCalls.clear();
        SoundService.instance.resetForTest();
        await SoundService.instance.init();

        // Audio context is configured globally
        final globalContextCall = globalMethodCalls.where((c) => c.method == 'setAudioContext').toList();
        expect(globalContextCall.isNotEmpty, isTrue);

        // Audio context is also applied directly to the player instance
        final playerContextCall = playerMethodCalls.where((c) => c.method == 'setAudioContext').toList();
        expect(playerContextCall.isNotEmpty, isTrue);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('playShutter triggers playback without errors', () async {
      final fakePlayer = FakeAudioPlayer();
      SoundService.instance.setPlayer(fakePlayer);

      await SoundService.instance.playShutter();

      expect(fakePlayer.stopCalled, isTrue);
      expect(fakePlayer.playCalled, isTrue);
      expect(fakePlayer.lastSource, isA<AssetSource>());
      expect((fakePlayer.lastSource as AssetSource).path, equals('camera_shutter.wav'));
    });
  });
}

class FakeAudioPlayer extends Fake implements AudioPlayer {
  bool stopCalled = false;
  bool playCalled = false;
  Source? lastSource;
  double? lastVolume;

  @override
  Future<void> stop() async {
    stopCalled = true;
  }

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    playCalled = true;
    lastSource = source;
    lastVolume = volume;
  }
}
