import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Sound service for playing app sound effects (e.g. camera shutter).
/// Explicitly configured to play audio even when the phone is in silent mode.
class SoundService {
  static final SoundService instance = SoundService._internal();
  SoundService._internal();

  AudioPlayer _player = AudioPlayer();
  bool _isInitialized = false;

  @visibleForTesting
  void setPlayer(AudioPlayer player) {
    _player = player;
    _isInitialized = true;
  }

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      // Configure audio context so playback ignores the hardware Ring/Silent switch
      // on iOS and plays on the media stream on Android.
      AudioPlayer.global.setAudioContext(
        AudioContextConfig(
          respectSilence: false, // Overrides silent mode switch
          focus: AudioContextConfigFocus.duckOthers, // Ducks other background audio during playback
          stayAwake: false,
        ).build(),
      );
      await _player.setReleaseMode(ReleaseMode.stop);
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing SoundService: $e');
    }
  }

  /// Plays the mechanical camera shutter sound with full volume even in silent mode.
  Future<void> playShutter() async {
    try {
      if (!_isInitialized) {
        await init();
      }
      await _player.stop();
      await _player.play(AssetSource('camera_shutter.wav'), volume: 1.0);
    } catch (e) {
      debugPrint('Error playing shutter sound: $e');
    }
  }

  void dispose() {
    _player.dispose();
  }
}
