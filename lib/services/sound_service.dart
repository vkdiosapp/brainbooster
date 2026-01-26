import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import '../game_settings.dart';

class SoundService {
  static AudioPlayer? _audioPlayer;

  /// Initialize the audio player
  static AudioPlayer _getAudioPlayer() {
    _audioPlayer ??= AudioPlayer();
    return _audioPlayer!;
  }

  /// Check if sound is enabled
  static bool _isSoundEnabled() {
    return GameSettings.soundEnabled;
  }

  /// Stop any currently playing sound
  static Future<void> _stopCurrentSound() async {
    try {
      final audioPlayer = _getAudioPlayer();
      await audioPlayer.stop();
    } catch (e) {
      // Ignore errors when stopping
    }
  }

  /// Play a tap sound (user tap sound)
  static Future<void> playTapSound() async {
    if (!_isSoundEnabled()) return; // Don't play if sound is disabled
    
    try {
      final audioPlayer = _getAudioPlayer();
      // Stop any currently playing sound first
      await _stopCurrentSound();
      await audioPlayer.setVolume(0.5); // Set volume to 50%
      await audioPlayer.play(AssetSource('sounds/user-tap-sound.mp3'));
    } catch (e) {
      // Silently fail - don't interrupt gameplay if sound fails
    }
  }

  /// Play a penalty sound (penalty sound)
  static Future<void> playPenaltySound() async {
    if (!_isSoundEnabled()) return; // Don't play if sound is disabled
    
    try {
      final audioPlayer = _getAudioPlayer();
      // Stop any currently playing sound first
      await _stopCurrentSound();
      await audioPlayer.setVolume(0.6); // Set volume to 60%
      await audioPlayer.play(AssetSource('sounds/penalty-sound.mp3'));
    } catch (e) {
      // Silently fail - don't interrupt gameplay if sound fails
    }
  }

  /// Play a result sound (result sound)
  static Future<void> playResultSound() async {
    if (!_isSoundEnabled()) return; // Don't play if sound is disabled
    
    try {
      final audioPlayer = _getAudioPlayer();
      // Stop any currently playing sound first
      await _stopCurrentSound();
      await audioPlayer.setVolume(0.7); // Set volume to 70%
      await audioPlayer.play(AssetSource('sounds/result-sound.mp3'));
    } catch (e) {
      // Silently fail - don't interrupt gameplay if sound fails
    }
  }

  /// Dispose the audio player (call when app closes)
  static void dispose() {
    _audioPlayer?.dispose();
    _audioPlayer = null;
  }
}
