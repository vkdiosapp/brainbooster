import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../game_settings.dart';
import '../models/round_result.dart';
import '../models/game_session.dart';
import '../services/game_history_service.dart';
import '../services/sound_service.dart';
import '../widgets/game_container.dart';
import '../widgets/category_header.dart';
import '../widgets/gradient_background.dart';
import '../data/exercise_data.dart';
import 'color_change_results_page.dart';

class MathQuestion {
  final String question;
  final int answer;
  final String operator;

  MathQuestion({
    required this.question,
    required this.answer,
    required this.operator,
  });
}

class More100Page extends StatefulWidget {
  final String? categoryName;
  final String? exerciseName;

  const More100Page({super.key, this.categoryName, this.exerciseName});

  @override
  State<More100Page> createState() => _More100PageState();
}

class _More100PageState extends State<More100Page> {
  int _currentRound = 0;
  int _completedRounds = 0;
  int _bestSession = 240; // in milliseconds
  bool _isPlaying = false;
  bool _isWaitingForRound = false;
  bool _isRoundActive = false;
  MathQuestion? _currentQuestion;
  bool? _correctAnswerIsGreaterThan100; // true if > 100, false if < 100
  DateTime? _roundStartTime;
  Timer? _delayTimer;
  Timer? _errorDisplayTimer;
  Timer? _reactionTimeDisplayTimer;
  String? _errorMessage;
  String? _reactionTimeMessage;
  List<RoundResult> _roundResults = [];
  // Get penalty time from exercise data (exercise ID 27)
  late final int _wrongTapPenaltyMs = ExerciseData.getExercises()
      .firstWhere(
        (e) => e.id == 27,
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
    _currentQuestion = null;
    _correctAnswerIsGreaterThan100 = null;
    _roundStartTime = null;
    _errorMessage = null;
    _reactionTimeMessage = null;
    _roundResults.clear();
    _delayTimer?.cancel();
    _errorDisplayTimer?.cancel();
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
      _currentQuestion = null;
      _correctAnswerIsGreaterThan100 = null;
      _roundStartTime = null;
      _errorMessage = null;
    });

    // Small delay before showing the round
    _delayTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted && _isWaitingForRound) {
        _showRound();
      }
    });
  }

  MathQuestion _generateMathQuestion() {
    final random = math.Random();
    final questionType = random.nextInt(4); // 0-3 for 4 question types
    final shouldBeGreaterThan100 = random.nextBool(); // Randomly decide if answer should be > 100 or < 100

    // Answer should be between 90-110 (100 ± 10)
    // If > 100: answer is 101-110
    // If < 100: answer is 90-99
    final answer = shouldBeGreaterThan100
        ? random.nextInt(10) + 101 // 101-110
        : random.nextInt(10) + 90; // 90-99

    switch (questionType) {
      case 0: // Format: a + b = ?
        {
          int a, b;
          // Work backwards: a + b = answer
          a = random.nextInt(answer - 1) + 1; // 1 to (answer-1)
          b = answer - a;
          return MathQuestion(
            question: '$a + $b = ?',
            answer: answer,
            operator: '+',
          );
        }
      case 1: // Format: a - b = ?
        {
          int a, b;
          // Work backwards: a - b = answer, so a = answer + b
          b = random.nextInt(50) + 10; // 10-59
          a = answer + b;
          return MathQuestion(
            question: '$a - $b = ?',
            answer: answer,
            operator: '-',
          );
        }
      case 2: // Format: a * b = ?
        {
          int a, b;
          // Work backwards: a * b = answer
          // Find factors of answer
          final factors = <List<int>>[];
          for (int i = 1; i <= answer; i++) {
            if (answer % i == 0) {
              factors.add([i, answer ~/ i]);
            }
          }
          if (factors.isNotEmpty) {
            final factorPair = factors[random.nextInt(factors.length)];
            a = factorPair[0];
            b = factorPair[1];
          } else {
            // Fallback: use answer and 1
            a = answer;
            b = 1;
          }
          return MathQuestion(
            question: '$a × $b = ?',
            answer: answer,
            operator: '*',
          );
        }
      case 3: // Format: a / b = ?
        {
          int a, b;
          // Work backwards: a / b = answer, so a = answer * b
          b = random.nextInt(10) + 2; // 2-11
          a = answer * b;
          return MathQuestion(
            question: '$a / $b = ?',
            answer: answer,
            operator: '/',
          );
        }
      default:
        {
          // Default to addition
          int a, b;
          a = random.nextInt(answer - 1) + 1;
          b = answer - a;
          return MathQuestion(
            question: '$a + $b = ?',
            answer: answer,
            operator: '+',
          );
        }
    }
  }

  void _showRound() {
    // Generate math question
    _currentQuestion = _generateMathQuestion();
    _correctAnswerIsGreaterThan100 = _currentQuestion!.answer > 100;

    setState(() {
      _isWaitingForRound = false;
      _isRoundActive = true;
      _roundStartTime = DateTime.now();
    });
  }

  void _handleOptionTap(bool tappedGreaterThan100) {
    if (!_isRoundActive || _roundStartTime == null) return;

    if (tappedGreaterThan100 == _correctAnswerIsGreaterThan100) {
      // Play tap sound for correct answer
      SoundService.playTapSound();
      // Correct tap - calculate reaction time
      final reactionTime = DateTime.now()
          .difference(_roundStartTime!)
          .inMilliseconds;
      _completeRound(reactionTime, false);
    } else {
      // Wrong tap - penalty
      _handleWrongTap();
    }
  }

  void _handleWrongTap() {
    // Play penalty sound for wrong answer
    SoundService.playPenaltySound();
    setState(() {
      _errorMessage = 'PENALTY +1 SECOND';
      _isRoundActive = false;
    });

    // Mark round as failed with penalty
    _roundResults.add(
      RoundResult(
        roundNumber: _currentRound,
        reactionTime: _wrongTapPenaltyMs, // Penalty from exercise data
        isFailed: true,
      ),
    );

    // Show error for 1 second, then start next round
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

  Widget _buildOptionButton(bool isGreaterThan100) {
    return GestureDetector(
      onTap: () => _handleOptionTap(isGreaterThan100),
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
            isGreaterThan100 ? '> 100' : '< 100',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
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
      _isWaitingForRound = false;
      _isRoundActive = false;
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
        'more_100',
      );
      final session = GameSession(
        gameId: 'more_100',
        gameName: 'More 100',
        timestamp: DateTime.now(),
        sessionNumber: sessionNumber,
        roundResults: List.from(_roundResults),
        averageTime: averageTime,
        bestTime: bestTime,
      );
      await GameHistoryService.saveSession(session);
    }

    // Navigate to results page
    _showResults();
  }

  void _showResults() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => ColorChangeResultsPage(
              roundResults: List.from(_roundResults),
              bestSession: _bestSession,
              gameName: widget.exerciseName ?? 'More 100',
              gameId: 'more_100',
              exerciseId: 27,
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
                      'MORE 100',
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
                    CategoryHeader(categoryName: widget.categoryName ?? 'Math'),
                    const SizedBox(height: 4),
                    // Title
                    Text(
                      _isPlaying
                          ? (_isWaitingForRound
                                ? 'Wait for the question...'
                                : (_isRoundActive
                                      ? 'TAP NOW!'
                                      : 'Round $_currentRound'))
                          : 'Is the answer > 100 or < 100?',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    // Game content area
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(35, 20, 35, 20),
                        child: GameContainer(
                          child: Stack(
                            children: [
                              // Main content - Column centered vertically for active round, gradient for idle
                              if (_isRoundActive &&
                                  _currentQuestion != null &&
                                  _correctAnswerIsGreaterThan100 != null)
                                Positioned.fill(
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Math question banner
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            child: Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 20,
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
                                                _currentQuestion!.question,
                                                style: const TextStyle(
                                                  fontSize: 28,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white,
                                                  letterSpacing: 1.0,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                          // 30 spacing between question and buttons
                                          const SizedBox(height: 30),
                                          // Options - two buttons side by side
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                // < 100 button
                                                Expanded(
                                                  child: AspectRatio(
                                                    aspectRatio: 1.0,
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(8),
                                                      child: _buildOptionButton(
                                                        false,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                // > 100 button
                                                Expanded(
                                                  child: AspectRatio(
                                                    aspectRatio: 1.0,
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(8),
                                                      child: _buildOptionButton(
                                                        true,
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
                              // Waiting state
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
            ],
          ),
        ),
      ),
    );
  }
}
