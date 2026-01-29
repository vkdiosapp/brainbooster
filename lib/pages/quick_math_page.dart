import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../game_settings.dart';
import '../models/round_result.dart';
import '../models/game_session.dart';
import '../services/game_history_service.dart';
import '../services/sound_service.dart';
import '../widgets/base_game_page.dart';
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

class QuickMathPage extends StatefulWidget {
  final String? categoryName;
  final String? exerciseName;

  const QuickMathPage({super.key, this.categoryName, this.exerciseName});

  @override
  State<QuickMathPage> createState() => _QuickMathPageState();
}

class _QuickMathPageState extends State<QuickMathPage> {
  int _currentRound = 0;
  int _completedRounds = 0;
  int _bestSession = 240; // in milliseconds
  bool _isPlaying = false;
  bool _isWaitingForRound = false;
  bool _isRoundActive = false;
  MathQuestion? _currentQuestion;
  List<int> _options = [];
  int? _correctAnswer;
  DateTime? _roundStartTime;
  Timer? _delayTimer;
  Timer? _errorDisplayTimer;
  Timer? _reactionTimeDisplayTimer;
  String? _errorMessage;
  String? _reactionTimeMessage;
  List<RoundResult> _roundResults = [];
  // Get penalty time from exercise data (exercise ID 6)
  late final int _wrongTapPenaltyMs = ExerciseData.getExercises()
      .firstWhere(
        (e) => e.id == 6,
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
    _options.clear();
    _correctAnswer = null;
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
      _options.clear();
      _correctAnswer = null;
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

    switch (questionType) {
      case 0: // Format: a + ? = c
        {
          final a = random.nextInt(20) + 1; // 1-20
          final answer = random.nextInt(20) + 1; // 1-20
          final c = a + answer;
          return MathQuestion(
            question: '$a + ? = $c',
            answer: answer,
            operator: '+',
          );
        }
      case 1: // Format: a - ? = c
        {
          final a = random.nextInt(20) + 5; // 5-24
          final c = random.nextInt(a - 1) + 1; // 1 to (a-1)
          final answer = a - c;
          return MathQuestion(
            question: '$a - ? = $c',
            answer: answer,
            operator: '-',
          );
        }
      case 2: // Format: ? * b = c
        {
          final answer = random.nextInt(10) + 1; // 1-10
          final b = random.nextInt(10) + 1; // 1-10
          final c = answer * b;
          return MathQuestion(
            question: '? × $b = $c',
            answer: answer,
            operator: '*',
          );
        }
      case 3: // Format: a - b = ?
        {
          final a = random.nextInt(20) + 5; // 5-24
          final b = random.nextInt(a - 1) + 1; // 1 to (a-1)
          final answer = a - b;
          return MathQuestion(
            question: '$a - $b = ?',
            answer: answer,
            operator: '-',
          );
        }
      default:
        {
          final a = random.nextInt(20) + 1;
          final answer = random.nextInt(20) + 1;
          final c = a + answer;
          return MathQuestion(
            question: '$a + ? = $c',
            answer: answer,
            operator: '+',
          );
        }
    }
  }

  void _showRound() {
    final random = math.Random();

    // Generate math question
    _currentQuestion = _generateMathQuestion();
    _correctAnswer = _currentQuestion!.answer;

    // Generate 3 wrong answers
    final wrongAnswers = <int>{};
    while (wrongAnswers.length < 3) {
      // Generate wrong answers that are different from correct answer
      int wrongAnswer;
      do {
        // Generate wrong answer within reasonable range
        wrongAnswer =
            _correctAnswer! + (random.nextInt(10) - 5); // ±5 from correct
        if (wrongAnswer < 0) wrongAnswer = random.nextInt(20) + 1;
        if (wrongAnswer == _correctAnswer) {
          wrongAnswer = _correctAnswer! + random.nextInt(5) + 1;
        }
      } while (wrongAnswer == _correctAnswer ||
          wrongAnswers.contains(wrongAnswer));
      wrongAnswers.add(wrongAnswer);
    }

    // Combine correct and wrong answers, then shuffle
    _options = [_correctAnswer!, ...wrongAnswers];
    _options.shuffle(random);

    setState(() {
      _isWaitingForRound = false;
      _isRoundActive = true;
      _roundStartTime = DateTime.now();
    });
  }

  void _handleOptionTap(int tappedAnswer) {
    if (!_isRoundActive || _roundStartTime == null) return;

    if (tappedAnswer == _correctAnswer) {
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

  Widget _buildOptionCell(int answer) {
    return GestureDetector(
      onTap: () => _handleOptionTap(answer),
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
            answer.toString(),
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
        'quick_math',
      );
      final session = GameSession(
        gameId: 'quick_math',
        gameName: 'Quick Math',
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
              gameName: widget.exerciseName ?? 'Quick Math',
              gameId: 'quick_math',
              exerciseId: 6,
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
    return BaseGamePage(
      config: GamePageConfig(
        gameName: 'Quick Math',
        categoryName: widget.categoryName ?? 'Math',
        gameId: 'quick_math',
        bestSession: _bestSession,
      ),
      state: GameState(
        isPlaying: _isPlaying,
        isWaiting: _isWaitingForRound,
        isRoundActive: _isRoundActive,
        currentRound: _currentRound,
        completedRounds: _completedRounds,
        errorMessage: _errorMessage,
        reactionTimeMessage: _reactionTimeMessage,
      ),
      callbacks: GameCallbacks(
        onStart: _startGame,
        onReset: () {
          _resetGame();
          setState(() {});
        },
      ),
      builders: GameBuilders(
        titleBuilder: (state) {
          if (!state.isPlaying) return 'Solve the math problem';
          if (state.isWaiting) return 'Wait for the question...';
          if (state.isRoundActive) return 'TAP NOW!';
          return 'Round ${state.currentRound}';
        },
        contentBuilder: (state, context) {
          if (_isRoundActive &&
              _currentQuestion != null &&
              _options.isNotEmpty) {
            return Column(
              children: [
                // Math question banner
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF475569),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
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
                // Options grid - 2x2
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(3),
                                  child: _buildOptionCell(_options[0]),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(3),
                                  child: _buildOptionCell(_options[1]),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(3),
                                  child: _buildOptionCell(_options[2]),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(3),
                                  child: _buildOptionCell(_options[3]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          return Positioned.fill(
            child: Container(
              decoration: !state.isRoundActive && !state.isPlaying
                  ? BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFDBEAFE).withOpacity(0.4),
                          const Color(0xFFE2E8F0).withOpacity(0.4),
                          const Color(0xFFFCE7F3).withOpacity(0.4),
                        ],
                      ),
                    )
                  : null,
            ),
          );
        },
        waitingTextBuilder: (state) => 'WAIT...',
        startButtonText: 'START',
      ),
      useBackdropFilter: false,
    );
  }
}
