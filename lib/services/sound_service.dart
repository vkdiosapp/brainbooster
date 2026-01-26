import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

class SoundService {
  static AudioPlayer? _audioPlayer;
  static Timer? _cleanupTimer;

  /// Initialize the audio player
  static AudioPlayer _getAudioPlayer() {
    _audioPlayer ??= AudioPlayer();
    return _audioPlayer!;
  }

  /// Play a tap sound (pleasant, short beep)
  static Future<void> playTapSound() async {
    try {
      final audioPlayer = _getAudioPlayer();
      
      // Generate a pleasant tap sound (800 Hz, 100ms duration)
      final tapWav = _generateBeepWav(800, 100);
      
      // Save to temporary file and play
      final tempDir = await getTemporaryDirectory();
      final tapFile = File('${tempDir.path}/tap_sound.wav');
      await tapFile.writeAsBytes(tapWav);

      await audioPlayer.setVolume(0.5); // Set volume to 50%
      await audioPlayer.play(DeviceFileSource(tapFile.path));

      // Clean up file after playing
      _scheduleCleanup(tapFile);
    } catch (e) {
      // Silently fail - don't interrupt gameplay if sound fails
      // Could optionally use SystemSound as fallback
    }
  }

  /// Play a penalty sound (lower, more negative tone)
  static Future<void> playPenaltySound() async {
    try {
      final audioPlayer = _getAudioPlayer();
      
      // Generate a penalty sound (400 Hz, 200ms duration - lower, longer)
      final penaltyWav = _generateBeepWav(400, 200);
      
      // Save to temporary file and play
      final tempDir = await getTemporaryDirectory();
      final penaltyFile = File('${tempDir.path}/penalty_sound.wav');
      await penaltyFile.writeAsBytes(penaltyWav);

      await audioPlayer.setVolume(0.6); // Set volume to 60%
      await audioPlayer.play(DeviceFileSource(penaltyFile.path));

      // Clean up file after playing
      _scheduleCleanup(penaltyFile);
    } catch (e) {
      // Silently fail - don't interrupt gameplay if sound fails
    }
  }

  /// Schedule cleanup of temporary sound file
  static void _scheduleCleanup(File file) {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer(const Duration(milliseconds: 1000), () async {
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // Ignore cleanup errors
      }
    });
  }

  /// Generate a WAV file with a beep sound
  static Uint8List _generateBeepWav(double frequency, int durationMs) {
    final sampleRate = 44100;
    final duration = durationMs / 1000.0;
    final numSamples = (sampleRate * duration).round();

    // Generate a pleasant beep sound with harmonics
    final samples = Int16List(numSamples);
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;

      // Create a pleasant beep with harmonics
      // Fundamental frequency
      double value = math.sin(2 * math.pi * frequency * t) * 0.3;

      // Add harmonics for richer sound
      value += math.sin(2 * math.pi * frequency * 2 * t) * 0.15; // 2nd harmonic
      value += math.sin(2 * math.pi * frequency * 3 * t) * 0.1; // 3rd harmonic

      // Apply envelope (fade in/out) for smoother sound
      final envelope = math.exp(-t * 5); // Exponential decay
      value *= envelope;

      samples[i] = (value * 32767).round().clamp(-32768, 32767);
    }

    // Create WAV file
    final dataSize = numSamples * 2; // 16-bit = 2 bytes per sample
    final fileSize = 36 + dataSize;

    final wav = ByteData(44 + dataSize);

    // RIFF header
    wav.setUint8(0, 0x52); // 'R'
    wav.setUint8(1, 0x49); // 'I'
    wav.setUint8(2, 0x46); // 'F'
    wav.setUint8(3, 0x46); // 'F'
    wav.setUint32(4, fileSize, Endian.little);
    wav.setUint8(8, 0x57); // 'W'
    wav.setUint8(9, 0x41); // 'A'
    wav.setUint8(10, 0x56); // 'V'
    wav.setUint8(11, 0x45); // 'E'

    // fmt chunk
    wav.setUint8(12, 0x66); // 'f'
    wav.setUint8(13, 0x6D); // 'm'
    wav.setUint8(14, 0x74); // 't'
    wav.setUint8(15, 0x20); // ' '
    wav.setUint32(16, 16, Endian.little); // fmt chunk size
    wav.setUint16(20, 1, Endian.little); // Audio format (PCM)
    wav.setUint16(22, 1, Endian.little); // Number of channels (mono)
    wav.setUint32(24, sampleRate, Endian.little); // Sample rate
    wav.setUint32(28, sampleRate * 2, Endian.little); // Byte rate
    wav.setUint16(32, 2, Endian.little); // Block align
    wav.setUint16(34, 16, Endian.little); // Bits per sample

    // data chunk
    wav.setUint8(36, 0x64); // 'd'
    wav.setUint8(37, 0x61); // 'a'
    wav.setUint8(38, 0x74); // 't'
    wav.setUint8(39, 0x61); // 'a'
    wav.setUint32(40, dataSize, Endian.little);

    // Copy sample data
    for (int i = 0; i < samples.length; i++) {
      wav.setUint16(44 + i * 2, samples[i], Endian.little);
    }

    return wav.buffer.asUint8List();
  }

  /// Dispose the audio player (call when app closes)
  static void dispose() {
    _audioPlayer?.dispose();
    _audioPlayer = null;
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
  }
}
