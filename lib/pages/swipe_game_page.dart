import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../game_settings.dart';
import '../models/round_result.dart';
import '../models/game_session.dart';
import '../services/game_history_service.dart';
import '../services/sound_service.dart';
import '../widgets/base_game_page.dart';
import '../data/exercise_data.dart';
import 'color_change_results_page.dart';

enum SwipeDirection { up, down, left, right }

class SwipeGamePage extends StatefulWidget {
  final String? categoryName;
  final String? exerciseName;

  const SwipeGamePage({super.key, this.categoryName, this.exerciseName});

  @override
  State<SwipeGamePage> createState() => _SwipeGamePageState();
}

class _SwipeGamePageState extends State<SwipeGamePage> {
  int _currentRound = 0;
  int _completedRounds = 0;
  int _bestSession = 240; // in milliseconds
  bool _isPlaying = false;
  bool _isWaitingForRound = false;
  bool _isRoundActive = false;
  SwipeDirection? _targetDirection;
  String? _targetDirectionName;
  bool _isGreen =
      true; // true = green (same direction), false = red (opposite direction)
  bool _isAdvanced =
      false; // false = Normal (only green), true = Advanced (both red and green)
  DateTime? _roundStartTime;
  Timer? _delayTimer;
  Timer? _errorDisplayTimer;
  Timer? _reactionTimeDisplayTimer;
  String? _errorMessage;
  String? _reactionTimeMessage;
  List<RoundResult> _roundResults = [];
  Offset? _swipeStartPosition;
  Offset? _swipeEndPosition;
  // Get penalty time from exercise data (exercise ID 14)
  late final int _wrongTapPenaltyMs = ExerciseData.getExercises()
      .firstWhere(
        (e) => e.id == 14,
        orElse: () => ExerciseData.getExercises().first,
      )
      .penaltyTime;

  final Map<SwipeDirection, String> _directionNames = {
    SwipeDirection.up: 'UP',
    SwipeDirection.down: 'DOWN',
    SwipeDirection.left: 'LEFT',
    SwipeDirection.right: 'RIGHT',
  };

  SwipeDirection _getOppositeDirection(SwipeDirection direction) {
    switch (direction) {
      case SwipeDirection.up:
        return SwipeDirection.down;
      case SwipeDirection.down:
        return SwipeDirection.up;
      case SwipeDirection.left:
        return SwipeDirection.right;
      case SwipeDirection.right:
        return SwipeDirection.left;
    }
  }

  // Track which directions have been used to ensure no repeats until all are used
  List<SwipeDirection> _remainingDirections = [];

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
    _targetDirection = null;
    _targetDirectionName = null;
    _isGreen = true;
    _isAdvanced = false; // Reset to Normal mode
    _roundStartTime = null;
    _errorMessage = null;
    _reactionTimeMessage = null;
    _roundResults.clear();
    _swipeStartPosition = null;
    _swipeEndPosition = null;
    _remainingDirections = List<SwipeDirection>.from(SwipeDirection.values);
    _remainingDirections.shuffle(math.Random());
    _delayTimer?.cancel();
    _errorDisplayTimer?.cancel();
  }

  void _startGame() {
    setState(() {
      _isPlaying = true;
      _currentRound = 0;
      _completedRounds = 0;
      _roundResults.clear();
      // Reset direction pool when starting a new game
      _remainingDirections = List<SwipeDirection>.from(SwipeDirection.values);
      _remainingDirections.shuffle(math.Random());
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
      _targetDirection = null;
      _targetDirectionName = null;
      _isGreen = true;
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

  void _showRound() {
    final random = math.Random();

    // If all directions have been used, reset the pool
    if (_remainingDirections.isEmpty) {
      _remainingDirections = List<SwipeDirection>.from(SwipeDirection.values);
      _remainingDirections.shuffle(random);
    }

    // Get next direction from remaining pool (ensures no repeat until all are used)
    _targetDirection = _remainingDirections.removeAt(0);
    _targetDirectionName = _directionNames[_targetDirection];

    // In Normal mode, always show green. In Advanced mode, randomly choose green or red
    if (_isAdvanced) {
      _isGreen = random.nextBool();
    } else {
      _isGreen = true; // Normal mode: always green
    }

    setState(() {
      _isWaitingForRound = false;
      _isRoundActive = true;
      _roundStartTime = DateTime.now();
    });
  }

  SwipeDirection? _getSwipeDirection(Offset start, Offset end) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;

    // Minimum swipe distance to register (to avoid accidental small movements)
    const minSwipeDistance = 50.0;

    if (dx.abs() < minSwipeDistance && dy.abs() < minSwipeDistance) {
      return null; // Swipe too small
    }

    // Determine swipe direction based on the dominant movement
    if (dx.abs() > dy.abs()) {
      // Horizontal swipe
      if (dx > 0) {
        return SwipeDirection.right;
      } else {
        return SwipeDirection.left;
      }
    } else {
      // Vertical swipe
      if (dy > 0) {
        return SwipeDirection.down;
      } else {
        return SwipeDirection.up;
      }
    }
  }

  void _handleSwipe(SwipeDirection swipeDirection) {
    if (!_isRoundActive || _roundStartTime == null || _targetDirection == null)
      return;

    // Determine the required direction based on green/red
    SwipeDirection requiredDirection;
    if (_isGreen) {
      // Green = same direction
      requiredDirection = _targetDirection!;
    } else {
      // Red = opposite direction
      requiredDirection = _getOppositeDirection(_targetDirection!);
    }

    if (swipeDirection == requiredDirection) {
      // Play tap sound for correct swipe
      SoundService.playTapSound();
      // Correct swipe - calculate reaction time
      final reactionTime = DateTime.now()
          .difference(_roundStartTime!)
          .inMilliseconds;
      _completeRound(reactionTime, false);
    } else {
      // Wrong swipe - penalty
      _handleWrongSwipe();
    }
  }

  void _handleWrongSwipe() {
    // Play penalty sound for wrong swipe
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
        'swipe',
      );
      final session = GameSession(
        gameId: 'swipe',
        gameName: 'Swipe',
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
              gameName: widget.exerciseName ?? 'Swipe',
              gameId: 'swipe',
              exerciseId: 14,
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

  Widget _buildDifficultySelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isAdvanced = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: !_isAdvanced
                          ? const Color(0xFF475569)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'Normal',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: !_isAdvanced
                            ? Colors.white
                            : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isAdvanced = true;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _isAdvanced
                          ? const Color(0xFF475569)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'Advanced',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _isAdvanced
                            ? Colors.white
                            : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseGamePage(
      config: GamePageConfig(
        gameName: 'Swipe',
        categoryName: widget.categoryName ?? 'Visual',
        gameId: 'swipe',
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
          if (!state.isPlaying) {
            return _isAdvanced
                ? 'Swipe in the correct direction for green and opposite for red'
                : 'Swipe in the correct direction';
          }
          if (state.isWaiting) return 'Wait for the direction...';
          if (state.isRoundActive) return 'SWIPE NOW!';
          return 'Round ${state.currentRound}';
        },
        middleContentBuilder: (state, context) {
          if (!state.isPlaying) {
            return _buildDifficultySelector();
          }
          return const SizedBox.shrink();
        },
        contentBuilder: (state, context) {
          if (_isRoundActive && _targetDirectionName != null) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _isGreen ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (_isGreen ? Colors.green : Colors.red)
                              .withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      _targetDirectionName!,
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
                Expanded(
                  child: GestureDetector(
                    onPanStart: (details) {
                      _swipeStartPosition = details.localPosition;
                      _swipeEndPosition = null;
                    },
                    onPanUpdate: (details) {
                      _swipeEndPosition = details.localPosition;
                    },
                    onPanEnd: (details) {
                      if (_swipeStartPosition != null &&
                          _swipeEndPosition != null) {
                        final direction = _getSwipeDirection(
                          _swipeStartPosition!,
                          _swipeEndPosition!,
                        );
                        if (direction != null) {
                          _handleSwipe(direction);
                        }
                        _swipeStartPosition = null;
                        _swipeEndPosition = null;
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                      ),
                      child: Center(
                        child: Text(
                          'SWIPE $_targetDirectionName',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 4.0,
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
