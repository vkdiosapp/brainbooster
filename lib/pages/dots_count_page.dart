import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/exercise_data.dart';
import '../game_settings.dart';
import '../models/game_session.dart';
import '../models/round_result.dart';
import '../services/game_history_service.dart';
import '../services/sound_service.dart';
import '../widgets/base_game_page.dart';
import 'color_change_results_page.dart';

class DotsCountPage extends StatefulWidget {
  final String? categoryName;
  final String? exerciseName;

  const DotsCountPage({super.key, this.categoryName, this.exerciseName});

  @override
  State<DotsCountPage> createState() => _DotsCountPageState();
}

class _DotsCountPageState extends State<DotsCountPage> {
  int _currentRound = 0;
  int _completedRounds = 0;
  int _bestSession = 240; // in milliseconds

  bool _isPlaying = false;
  bool _isWaitingForRound = false;
  bool _isRoundActive = false;

  int _dotCount = 0;
  List<Offset> _dotPositions = [];
  List<Offset> _squarePositions = []; // Distractors - don't count these
  List<int> _options = [];

  DateTime? _roundStartTime;
  Timer? _delayTimer;
  Timer? _errorDisplayTimer;
  Timer? _reactionTimeDisplayTimer;

  String? _errorMessage;
  String? _reactionTimeMessage;

  final List<RoundResult> _roundResults = [];
  final math.Random _random = math.Random();

  // Get penalty time from exercise data (exercise ID 24)
  late final int _wrongTapPenaltyMs = ExerciseData.getExercises()
      .firstWhere(
        (e) => e.id == 24,
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
    _dotCount = 0;
    _dotPositions = [];
    _options = [];
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
      _dotCount = 0;
      _dotPositions = [];
      _squarePositions = [];
      _options = [];
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

  void _showRound() {
    // Random number of dots between 4 and 12
    final dotCount = 4 + _random.nextInt(9); // 4..12

    // Generate random relative positions for dots (0.1 - 0.9) to avoid edges
    final dotPositions = <Offset>[];
    for (var i = 0; i < dotCount; i++) {
      final dx = 0.1 + _random.nextDouble() * 0.8;
      final dy = 0.1 + _random.nextDouble() * 0.8;
      dotPositions.add(Offset(dx, dy));
    }

    // Generate random squares as distractors (3-8 squares)
    final squareCount = 3 + _random.nextInt(6); // 3..8
    final squarePositions = <Offset>[];
    for (var i = 0; i < squareCount; i++) {
      final dx = 0.1 + _random.nextDouble() * 0.8;
      final dy = 0.1 + _random.nextDouble() * 0.8;
      squarePositions.add(Offset(dx, dy));
    }

    // Generate 4 options: correct count + 3 wrong nearby counts
    final correct = dotCount;
    final optionSet = <int>{correct};
    while (optionSet.length < 4) {
      final delta = _random.nextInt(3) + 1; // 1..3
      final sign = _random.nextBool() ? 1 : -1;
      final candidate = correct + delta * sign;
      if (candidate > 0 && candidate <= 20) {
        optionSet.add(candidate);
      }
    }
    final options = optionSet.toList()..shuffle(_random);

    setState(() {
      _dotCount = dotCount;
      _dotPositions = dotPositions;
      _squarePositions = squarePositions;
      _options = options;
      _isWaitingForRound = false;
      _isRoundActive = true;
      _roundStartTime = DateTime.now();
    });
  }

  void _handleOptionTap(int value) {
    if (!_isRoundActive || _roundStartTime == null) return;

    if (value == _dotCount) {
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

  Widget _buildOptionCell(int value) {
    return GestureDetector(
      onTap: () => _handleOptionTap(value),
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
            value.toString(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
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
        'dots_count',
      );
      final session = GameSession(
        gameId: 'dots_count',
        gameName: 'Dots Count',
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
              gameName: widget.exerciseName ?? 'Dots Count',
              gameId: 'dots_count',
              exerciseId: 24,
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
    return BaseGamePage(
      config: GamePageConfig(
        gameName: 'Dots Count',
        categoryName: widget.categoryName ?? 'Memory',
        gameId: 'dots_count',
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
          if (!state.isPlaying) return 'Count the black dots';
          if (state.isWaiting) return 'Wait for the dots...';
          if (state.isRoundActive) return 'COUNT THE DOTS AND TAP THE NUMBER!';
          return 'Round ${state.currentRound}';
        },
        contentBuilder: (state, context) {
          if (_isRoundActive && _options.isNotEmpty && _dotCount > 0) {
            return Column(
              children: [
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const dotSize = 16.0;
                        const squareSize = 16.0;
                        return Stack(
                          children: [
                            ..._dotPositions.map((relative) {
                              final left =
                                  relative.dx * constraints.maxWidth -
                                  dotSize / 2;
                              final top =
                                  relative.dy * constraints.maxHeight -
                                  dotSize / 2;
                              return Positioned(
                                left: left.clamp(
                                  0.0,
                                  constraints.maxWidth - dotSize,
                                ),
                                top: top.clamp(
                                  0.0,
                                  constraints.maxHeight - dotSize,
                                ),
                                child: Container(
                                  width: dotSize,
                                  height: dotSize,
                                  decoration: const BoxDecoration(
                                    color: Colors.black87,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              );
                            }),
                            ..._squarePositions.map((relative) {
                              final left =
                                  relative.dx * constraints.maxWidth -
                                  squareSize / 2;
                              final top =
                                  relative.dy * constraints.maxHeight -
                                  squareSize / 2;
                              return Positioned(
                                left: left.clamp(
                                  0.0,
                                  constraints.maxWidth - squareSize,
                                ),
                                top: top.clamp(
                                  0.0,
                                  constraints.maxHeight - squareSize,
                                ),
                                child: Container(
                                  width: squareSize,
                                  height: squareSize,
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          4,
                          (index) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: AspectRatio(
                                aspectRatio: 1.0,
                                child: _buildOptionCell(_options[index]),
                              ),
                            ),
                          ),
                        ),
                      ),
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
