import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/exercise_data.dart';
import '../game_settings.dart';
import '../models/game_session.dart';
import '../models/round_result.dart';
import '../services/game_history_service.dart';
import '../services/sound_service.dart';
import '../widgets/category_header.dart';
import '../widgets/game_container.dart';
import '../widgets/gradient_background.dart';
import 'color_change_results_page.dart';

class SameNumberPage extends StatefulWidget {
  final String? categoryName;
  final String? exerciseName;

  const SameNumberPage({super.key, this.categoryName, this.exerciseName});

  @override
  State<SameNumberPage> createState() => _SameNumberPageState();
}

class _SameNumberPageState extends State<SameNumberPage> {
  int _currentRound = 0;
  int _completedRounds = 0;
  int _bestSession = 240; // in milliseconds

  bool _isPlaying = false;
  bool _isWaitingForRound = false;
  bool _isRoundActive = false;

  String? _targetNumber;
  List<String> _gridNumbers = [];

  DateTime? _roundStartTime;
  Timer? _delayTimer;
  Timer? _errorDisplayTimer;
  Timer? _reactionTimeDisplayTimer;

  String? _errorMessage;
  String? _reactionTimeMessage;

  final List<RoundResult> _roundResults = [];
  final math.Random _random = math.Random();

  // Get penalty time from exercise data (exercise ID 23)
  late final int _wrongTapPenaltyMs = ExerciseData.getExercises()
      .firstWhere(
        (e) => e.id == 23,
        orElse: () => ExerciseData.getExercises().first,
      )
      .penaltyTime;

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
    super.dispose();
  }

  void _resetGame() {
    _currentRound = 0;
    _completedRounds = 0;
    _isPlaying = false;
    _isWaitingForRound = false;
    _isRoundActive = false;
    _targetNumber = null;
    _gridNumbers.clear();
    _roundStartTime = null;
    _errorMessage = null;
    _reactionTimeMessage = null;
    _roundResults.clear();
    _delayTimer?.cancel();
    _errorDisplayTimer?.cancel();
    _reactionTimeDisplayTimer?.cancel();
  }

  void _startGame() {
    setState(() {
      _isPlaying = true;
      _currentRound = 0;
      _completedRounds = 0;
      _roundResults.clear();
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
      _isWaitingForRound = true;
      _isRoundActive = false;
      _targetNumber = null;
      _gridNumbers.clear();
      _roundStartTime = null;
      _errorMessage = null;
      _reactionTimeMessage = null;
    });

    _delayTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted && _isWaitingForRound) {
        _showRound();
      }
    });
  }

  String _generateTargetNumber() {
    // Generate a random 7-digit number as a string without leading zero
    final firstDigit = _random.nextInt(9) + 1; // 1-9
    final buffer = StringBuffer()..write(firstDigit);
    for (var i = 0; i < 6; i++) {
      buffer.write(_random.nextInt(10));
    }
    return buffer.toString();
  }

  String _generateSimilarNumber(String base) {
    // Change 1–2 digits so it "looks similar"
    final chars = base.split('');
    final positions = List<int>.generate(chars.length, (i) => i)
      ..shuffle(_random);
    final changes = 1 + _random.nextInt(2); // 1 or 2 positions

    for (var i = 0; i < changes; i++) {
      final idx = positions[i];
      final original = chars[idx];
      String newDigit;
      do {
        newDigit = _random.nextInt(10).toString();
      } while (newDigit == original);
      chars[idx] = newDigit;
    }

    // Ensure we don't accidentally recreate the base string
    final candidate = chars.join();
    if (candidate == base) {
      return _generateSimilarNumber(base);
    }
    return candidate;
  }

  void _showRound() {
    final target = _generateTargetNumber();

    final options = <String>[];
    options.add(target); // correct one

    // Generate 3 similar-looking but incorrect options
    while (options.length < 4) {
      final similar = _generateSimilarNumber(target);
      if (!options.contains(similar)) {
        options.add(similar);
      }
    }

    options.shuffle(_random);

    setState(() {
      _targetNumber = target;
      _gridNumbers = options;
      _isWaitingForRound = false;
      _isRoundActive = true;
      _roundStartTime = DateTime.now();
    });
  }

  void _handleNumberTap(String tappedNumber) {
    if (!_isRoundActive || _roundStartTime == null) return;

    if (tappedNumber == _targetNumber) {
      SoundService.playTapSound();
      final reactionTime = DateTime.now()
          .difference(_roundStartTime!)
          .inMilliseconds;
      _completeRound(reactionTime, false);
    } else {
      _handleWrongTap();
    }
  }

  void _handleWrongTap() {
    SoundService.playPenaltySound();

    setState(() {
      _errorMessage =
          'PENALTY +${(_wrongTapPenaltyMs / 1000).toStringAsFixed(0)} SECOND';
      _isRoundActive = false;
    });

    _roundResults.add(
      RoundResult(
        roundNumber: _currentRound,
        reactionTime: _wrongTapPenaltyMs,
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

  Widget _buildNumberCell(String number) {
    return GestureDetector(
      onTap: () => _handleNumberTap(number),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: 2.0,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
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
      _isRoundActive = false;
      _completedRounds++;
      if (!isFailed) {
        _reactionTimeMessage = '$reactionTime ms';
      }
    });

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
      _isWaitingForRound = false;
      _isRoundActive = false;
    });

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
    } else if (_roundResults.isNotEmpty) {
      averageTime =
          _roundResults.map((r) => r.reactionTime).reduce((a, b) => a + b) ~/
          _roundResults.length;
    }

    if (_roundResults.isNotEmpty) {
      final sessionNumber = await GameHistoryService.getNextSessionNumber(
        'same_number',
      );
      final session = GameSession(
        gameId: 'same_number',
        gameName: 'Same Number',
        timestamp: DateTime.now(),
        sessionNumber: sessionNumber,
        roundResults: List.from(_roundResults),
        averageTime: averageTime,
        bestTime: bestTime,
      );
      await GameHistoryService.saveSession(session);
    }

    _showResults();
  }

  void _showResults() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => ColorChangeResultsPage(
              roundResults: List.from(_roundResults),
              bestSession: _bestSession,
              gameName: widget.exerciseName ?? 'Same Number',
              gameId: 'same_number',
              exerciseId: 23,
            ),
          ),
        )
        .then((_) {
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
                      'SAME NUMBER',
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
                    CategoryHeader(
                      categoryName: widget.categoryName ?? 'Memory',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isPlaying
                          ? (_isWaitingForRound
                                ? 'Wait for the numbers...'
                                : (_isRoundActive
                                      ? 'TAP THE SAME NUMBER!'
                                      : 'Round $_currentRound'))
                          : 'Tap the exact same number',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(35, 20, 35, 20),
                        child: GameContainer(
                          child: Stack(
                            children: [
                              if (_isRoundActive &&
                                  _gridNumbers.isNotEmpty &&
                                  _targetNumber != null)
                                Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        12,
                                        12,
                                        8,
                                      ),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF475569),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.1,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          _targetNumber!,
                                          style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            letterSpacing: 3.0,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(20),
                                          child: AspectRatio(
                                            aspectRatio: 1.0,
                                            child: GridView.builder(
                                              physics:
                                                  const NeverScrollableScrollPhysics(),
                                              gridDelegate:
                                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                                    crossAxisCount: 2,
                                                    crossAxisSpacing: 12,
                                                    mainAxisSpacing: 12,
                                                  ),
                                              itemCount: 4,
                                              itemBuilder: (context, index) {
                                                return _buildNumberCell(
                                                  _gridNumbers[index],
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Positioned.fill(
                                  child: Container(
                                    decoration: !_isRoundActive && !_isPlaying
                                        ? BoxDecoration(
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
                                          )
                                        : null,
                                  ),
                                ),
                              if (_isWaitingForRound)
                                const Center(
                                  child: Text(
                                    'WAIT...',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF94A3B8),
                                      letterSpacing: 4.0,
                                    ),
                                  ),
                                ),
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
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
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
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                              if (!_isPlaying &&
                                  _errorMessage == null &&
                                  _reactionTimeMessage == null)
                                Center(
                                  child: GestureDetector(
                                    onTap: _startGame,
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
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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
            ],
          ),
        ),
      ),
    );
  }
}
