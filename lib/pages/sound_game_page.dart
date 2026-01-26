import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../game_settings.dart';
import '../models/round_result.dart';
import '../models/game_session.dart';
import '../services/game_history_service.dart';
import '../widgets/game_container.dart';
import '../widgets/category_header.dart';
import '../widgets/gradient_background.dart';
import 'color_change_results_page.dart';

class SoundGamePage extends StatefulWidget {
  final String? categoryName;

  const SoundGamePage({super.key, this.categoryName});

  @override
  State<SoundGamePage> createState() => _SoundGamePageState();
}

class _SoundGamePageState extends State<SoundGamePage> {
  int _currentRound = 0;
  int _completedRounds = 0;
  int _bestSession = 240; // in milliseconds
  bool _isPlaying = false;
  bool _isWaitingForSound = false;
  bool _isSoundPlayed = false;
  DateTime? _soundPlayedTime;
  Timer? _delayTimer;
  Timer? _errorDisplayTimer;
  Timer? _reactionTimeDisplayTimer;
  String? _errorMessage;
  String? _reactionTimeMessage;
  List<RoundResult> _roundResults = [];
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Array of different sound frequencies (in Hz) - 10 sounds
  final List<double> _soundFrequencies = [
    400, 500, 600, 700, 800, 900, 1000, 1100, 1200, 1300,
  ];
  
  // Track which sounds are available (not yet used in current cycle)
  List<double> _availableSounds = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _resetGame();
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _errorDisplayTimer?.cancel();
    _reactionTimeDisplayTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _resetGame() {
    _currentRound = 0;
    _completedRounds = 0;
    _isPlaying = false;
    _isWaitingForSound = false;
    _isSoundPlayed = false;
    _soundPlayedTime = null;
    _errorMessage = null;
    _roundResults.clear();
    _delayTimer?.cancel();
    _errorDisplayTimer?.cancel();
    // Reset available sounds - shuffle the array
    _availableSounds = List.from(_soundFrequencies);
    _availableSounds.shuffle(_random);
  }

  void _startGame() {
    setState(() {
      _isPlaying = true;
      _currentRound = 0;
      _completedRounds = 0;
      _roundResults.clear();
      // Reset available sounds - shuffle the array
      _availableSounds = List.from(_soundFrequencies);
      _availableSounds.shuffle(_random);
    });
    _startNextRound();
  }

  void _startNextRound() {
    if (_currentRound >= GameSettings.numberOfRepetitions) {
      _endGame();
      return;
    }

    setState(() {
      _currentRound++;
      _isWaitingForSound = true;
      _isSoundPlayed = false;
      _soundPlayedTime = null;
      _errorMessage = null;
    });

    // Random delay between 1-5 seconds
    final random = math.Random();
    final delaySeconds = 1 + random.nextDouble() * 4; // 1 to 5 seconds
    final delayMilliseconds = (delaySeconds * 1000).toInt();

    _delayTimer = Timer(Duration(milliseconds: delayMilliseconds), () {
      if (mounted && _isWaitingForSound) {
        _playSound();
      }
    });
  }

  Future<void> _playSound() async {
    if (!_isWaitingForSound) return;

    // Get a random sound from available sounds
    // If all sounds have been used, shuffle and reset
    if (_availableSounds.isEmpty) {
      _availableSounds = List.from(_soundFrequencies);
      _availableSounds.shuffle(_random);
    }
    
    // Pick a random sound from available sounds
    final randomIndex = _random.nextInt(_availableSounds.length);
    final selectedFrequency = _availableSounds[randomIndex];
    
    // Remove the selected sound from available sounds
    _availableSounds.removeAt(randomIndex);

    try {
      // Generate a beep sound programmatically with the selected frequency
      final beepWav = _generateBeepWav(selectedFrequency, 200); // 200ms duration
      
      // Save to temporary file and play
      final tempDir = await getTemporaryDirectory();
      final beepFile = File('${tempDir.path}/beep_${selectedFrequency.toInt()}.wav');
      await beepFile.writeAsBytes(beepWav);
      
      await _audioPlayer.setVolume(0.7); // Set volume to 70%
      await _audioPlayer.play(DeviceFileSource(beepFile.path));
      
      // Clean up file after playing
      Timer(const Duration(milliseconds: 500), () async {
        try {
          if (await beepFile.exists()) {
            await beepFile.delete();
          }
        } catch (e) {
          // Ignore cleanup errors
        }
      });
    } catch (e) {
      // Fallback: Try system sound
      try {
        SystemSound.play(SystemSoundType.alert);
      } catch (e2) {
        // If all else fails, just mark sound as played
        // The visual indicator will still show
      }
    }

    setState(() {
      _isSoundPlayed = true;
      _isWaitingForSound = false;
      _soundPlayedTime = DateTime.now();
    });
  }

  Uint8List _generateBeepWav(double frequency, int durationMs) {
    final sampleRate = 44100;
    final duration = durationMs / 1000.0;
    final numSamples = (sampleRate * duration).round();
    
    // Generate bell-like sound with harmonics (more pleasant than simple beep)
    final samples = Int16List(numSamples);
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      
      // Create a bell-like sound with multiple harmonics and envelope
      // Fundamental frequency
      double value = math.sin(2 * math.pi * frequency * t) * 0.3;
      
      // Add harmonics for richer bell sound
      value += math.sin(2 * math.pi * frequency * 2 * t) * 0.15; // 2nd harmonic
      value += math.sin(2 * math.pi * frequency * 3 * t) * 0.1;  // 3rd harmonic
      value += math.sin(2 * math.pi * frequency * 4 * t) * 0.05; // 4th harmonic
      
      // Apply envelope (fade out) for bell-like decay
      final envelope = math.exp(-t * 8); // Exponential decay
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

  void _handleTap() {
    if (!_isPlaying) {
      _startGame();
      return;
    }

    if (_isWaitingForSound && !_isSoundPlayed) {
      // User tapped too early - penalty
      _handleEarlyTap();
      return;
    }

    if (_isSoundPlayed && _soundPlayedTime != null) {
      // Calculate reaction time
      final reactionTime = DateTime.now()
          .difference(_soundPlayedTime!)
          .inMilliseconds;
      _completeRound(reactionTime, false);
    }
  }

  void _handleEarlyTap() {
    setState(() {
      _errorMessage = 'PENALTY +1 SECOND';
      _isWaitingForSound = false;
      _isSoundPlayed = false;
    });

    // Mark round as failed with penalty
    _roundResults.add(
      RoundResult(
        roundNumber: _currentRound,
        reactionTime: 1000, // 1 second penalty
        isFailed: true,
      ),
    );

    _errorDisplayTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _errorMessage = null;
          _completedRounds++;
        });
        _startNextRound();
      }
    });
  }

  void _completeRound(int reactionTime, bool isFailed) {
    _roundResults.add(
      RoundResult(
        roundNumber: _currentRound,
        reactionTime: reactionTime,
        isFailed: isFailed,
      ),
    );

    setState(() {
      _isSoundPlayed = false;
      _completedRounds++;
      if (!isFailed) {
        _reactionTimeMessage = '$reactionTime ms';
      }
    });

    // Show reaction time for 1 second, then start next round
    _reactionTimeDisplayTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _reactionTimeMessage = null;
        });
        _startNextRound();
      }
    });
  }

  Future<void> _endGame() async {
    setState(() {
      _isPlaying = false;
      _isWaitingForSound = false;
      _isSoundPlayed = false;
    });

    // Calculate average reaction time
    final successfulRounds = _roundResults.where((r) => !r.isFailed).toList();
    int averageTime = 0;
    int bestTime = 0;

    if (successfulRounds.isNotEmpty) {
      averageTime =
          successfulRounds.map((r) => r.reactionTime).reduce((a, b) => a + b) ~/
          successfulRounds.length;

      bestTime = successfulRounds
          .map((r) => r.reactionTime)
          .reduce((a, b) => a < b ? a : b);

      if (averageTime < _bestSession || _bestSession == 0) {
        _bestSession = averageTime;
      }
    } else {
      // If no successful rounds, calculate from all rounds
      if (_roundResults.isNotEmpty) {
        averageTime =
            _roundResults.map((r) => r.reactionTime).reduce((a, b) => a + b) ~/
            _roundResults.length;
      }
    }

    // Save game session
    if (_roundResults.isNotEmpty) {
      final sessionNumber = await GameHistoryService.getNextSessionNumber(
        'sound',
      );
      final session = GameSession(
        gameId: 'sound',
        gameName: 'Sound',
        timestamp: DateTime.now(),
        sessionNumber: sessionNumber,
        roundResults: List.from(_roundResults),
        averageTime: averageTime,
        bestTime: bestTime,
      );
      await GameHistoryService.saveSession(session);
    }

    // Navigate to results page or show results
    _showResults();
  }

  void _showResults() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => ColorChangeResultsPage(
              roundResults: List.from(_roundResults),
              bestSession: _bestSession,
            ),
          ),
        )
        .then((_) {
          // Reset game when returning from results
          if (mounted) {
            _resetGame();
            setState(() {});
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GradientBackground.backgroundColor,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'SOUND',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const Spacer(),
                    ValueListenableBuilder<int>(
                      valueListenable: GameSettings.repetitionsNotifier,
                      builder: (context, numberOfRepetitions, _) {
                        return Row(
                          children: [
                            Text(
                              _isPlaying
                                  ? '$_completedRounds / $numberOfRepetitions'
                                  : '0 / $numberOfRepetitions',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: () {
                                _resetGame();
                                setState(() {});
                              },
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.4),
                                shape: const CircleBorder(),
                                padding: const EdgeInsets.all(8),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              // Main content
              Expanded(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // Category header
                    CategoryHeader(
                      categoryName: widget.categoryName ?? 'Reaction',
                    ),
                    const SizedBox(height: 4),
                    // Title
                    Text(
                      _isPlaying
                          ? (_isWaitingForSound
                                ? 'Wait for the sound...'
                                : (_isSoundPlayed
                                      ? 'TAP NOW!'
                                      : 'Round $_currentRound'))
                          : 'Tap when you hear the sound',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    // Main game card - flexible with 20 padding on all sides
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(35, 20, 35, 20),
                        child: GameContainer(
                          onTap: _handleTap,
                          useBackdropFilter: true,
                          child: Stack(
                                  children: [
                                    // Background gradient blur effect (always shown)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              const Color(
                                                0xFFDBEAFE,
                                              ).withOpacity(0.4),
                                              const Color(
                                                0xFFE2E8F0,
                                              ).withOpacity(0.4),
                                              const Color(
                                                0xFFFCE7F3,
                                              ).withOpacity(0.4),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Error message overlay
                                    if (_errorMessage != null)
                                      Positioned.fill(
                                        child: Container(
                                          color: Colors.red.withOpacity(0.9),
                                          child: Center(
                                            child: Text(
                                              _errorMessage!,
                                              style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                                letterSpacing: 2.0,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    // Reaction time message
                                    if (_reactionTimeMessage != null)
                                      Positioned.fill(
                                        child: Container(
                                          color: Colors.green.withOpacity(0.8),
                                          child: Center(
                                            child: Text(
                                              _reactionTimeMessage!,
                                              style: const TextStyle(
                                                fontSize: 32,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                                letterSpacing: 2.0,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    // Start button
                                    if (!_isPlaying &&
                                        _errorMessage == null &&
                                        _reactionTimeMessage == null)
                                      Center(
                                        child: GestureDetector(
                                          onTap: _handleTap,
                                          child: const Text(
                                            'START',
                                            style: TextStyle(
                                              fontSize: 48,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 4.0,
                                              color: Color(0xFF475569),
                                            ),
                                          ),
                                        ),
                                      ),
                                    // Show "Tap when sound plays" - both while waiting and after sound plays
                                    if (_isPlaying &&
                                        (_isWaitingForSound || _isSoundPlayed) &&
                                        _errorMessage == null &&
                                        _reactionTimeMessage == null)
                                      const Center(
                                        child: Text(
                                          'TAP WHEN SOUND PLAYS',
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF475569),
                                            letterSpacing: 2.0,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Best session indicator
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFDBEAFE),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFFDBEAFE,
                                        ).withOpacity(0.8),
                                        blurRadius: 8,
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'BEST SESSION: ${_bestSession}MS',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Bottom indicator
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFCBD5E1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFCBD5E1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 40,
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: const Color(0xFF94A3B8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
