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

class SpatialImaginationPage extends StatefulWidget {
  final String? categoryName;
  final String? exerciseName;

  const SpatialImaginationPage({
    super.key,
    this.categoryName,
    this.exerciseName,
  });

  @override
  State<SpatialImaginationPage> createState() => _SpatialImaginationPageState();
}

class _SpatialImaginationPageState extends State<SpatialImaginationPage> {
  // Get penalty time from exercise data (exercise ID 21)
  late final int _wrongTapPenaltyMs = ExerciseData.getExercises()
      .firstWhere(
        (e) => e.id == 21,
        orElse: () => ExerciseData.getExercises().first,
      )
      .penaltyTime;

  int _currentRound = 0;
  int _completedRounds = 0;
  int _bestSession = 240; // ms

  bool _isPlaying = false;
  bool _isWaitingForRound = false;
  bool _isRoundActive = false; // User can tap buttons

  DateTime? _roundStartTime;
  Timer? _roundDelayTimer;
  Timer? _overlayTimer;

  String? _errorMessage;
  String? _reactionTimeMessage;

  final List<RoundResult> _roundResults = [];
  final math.Random _rand = math.Random();

  // Current pair of patterns
  List<List<bool>>? _leftPattern;
  List<List<bool>>? _rightPattern;
  bool _arePatternsSame = false; // whether right is rotation of left

  // Predefined base shapes (5x5 grids)
  static const int _gridSize = 5;
  late final List<List<List<bool>>> _baseShapes = _createBaseShapes();

  @override
  void initState() {
    super.initState();
    _resetGame();
  }

  @override
  void dispose() {
    _roundDelayTimer?.cancel();
    _overlayTimer?.cancel();
    super.dispose();
  }

  void _resetGame() {
    _roundDelayTimer?.cancel();
    _overlayTimer?.cancel();

    _currentRound = 0;
    _completedRounds = 0;
    _isPlaying = false;
    _isWaitingForRound = false;
    _isRoundActive = false;
    _roundStartTime = null;
    _errorMessage = null;
    _reactionTimeMessage = null;
    _roundResults.clear();
    _leftPattern = null;
    _rightPattern = null;
    _arePatternsSame = false;
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

    _roundDelayTimer?.cancel();
    _overlayTimer?.cancel();

    setState(() {
      _currentRound++;
      _isWaitingForRound = true;
      _isRoundActive = false;
      _errorMessage = null;
      _reactionTimeMessage = null;
      _roundStartTime = null;
      _leftPattern = null;
      _rightPattern = null;
      _arePatternsSame = false;
    });

    // Small delay before showing next pair so user can reset focus
    _roundDelayTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _generateNewPatterns();
    });
  }

  void _generateNewPatterns() {
    // Pick a random base shape
    final baseIndex = _rand.nextInt(_baseShapes.length);
    final baseShape = _baseShapes[baseIndex];

    // Random rotation for the left pattern
    final leftRotations = _rand.nextInt(4);
    final left = _rotateNTimes(baseShape, leftRotations);

    // Decide whether this round should be "same" or "not same"
    final shouldBeSame = _rand.nextBool();

    List<List<bool>> right;
    if (shouldBeSame) {
      // Same up to rotation - use the same base with a different random rotation
      final rightRotations = _rand.nextInt(4);
      right = _rotateNTimes(baseShape, rightRotations);
    } else {
      // Different shape (not equal under rotation)
      List<List<bool>> otherBase;
      int safety = 0;
      do {
        final idx = _rand.nextInt(_baseShapes.length);
        otherBase = _baseShapes[idx];
        safety++;
      } while (_areSameWithRotation(baseShape, otherBase) && safety < 20);

      final rightRotations = _rand.nextInt(4);
      right = _rotateNTimes(otherBase, rightRotations);
    }

    setState(() {
      _leftPattern = left;
      _rightPattern = right;
      _arePatternsSame = shouldBeSame;
      _isWaitingForRound = false;
      _isRoundActive = true;
      _roundStartTime = DateTime.now(); // Start timing when patterns appear
    });
  }

  void _handleAnswer(bool userThinksSame) {
    if (!_isRoundActive || _roundStartTime == null) {
      return;
    }

    final isCorrect = userThinksSame == _arePatternsSame;

    if (isCorrect) {
      SoundService.playTapSound();
      _completeRound();
    } else {
      SoundService.playPenaltySound();
      _handleWrongTap();
    }
  }

  void _handleWrongTap() {
    _overlayTimer?.cancel();

    final roundTime = _wrongTapPenaltyMs;

    _roundResults.add(
      RoundResult(
        roundNumber: _currentRound,
        reactionTime: roundTime,
        isFailed: true,
      ),
    );

    setState(() {
      _isRoundActive = false;
      _completedRounds++;
      _errorMessage = 'PENALTY +${_wrongTapPenaltyMs ~/ 1000} SECOND';
    });

    _overlayTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _errorMessage = null);
      _startNextRound();
    });
  }

  void _completeRound() {
    _overlayTimer?.cancel();

    final roundTime =
        DateTime.now().difference(_roundStartTime!).inMilliseconds;

    _roundResults.add(
      RoundResult(
        roundNumber: _currentRound,
        reactionTime: roundTime,
        isFailed: false,
      ),
    );

    setState(() {
      _isRoundActive = false;
      _completedRounds++;
      _reactionTimeMessage = '$roundTime ms';
    });

    _overlayTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _reactionTimeMessage = null);
      _startNextRound();
    });
  }

  Future<void> _endGame() async {
    _roundDelayTimer?.cancel();
    _overlayTimer?.cancel();

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
        'spatial_imagination',
      );
      final session = GameSession(
        gameId: 'spatial_imagination',
        gameName: 'Spatial Imagination',
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
              gameName: widget.exerciseName ?? 'Spatial Imagination',
            ),
          ),
        )
        .then((_) {
          if (!mounted) return;
          _resetGame();
          setState(() {});
        });
  }

  // ---------- Pattern helpers ----------

  static List<List<List<bool>>> _createBaseShapes() {
    // A few asymmetric shapes so rotations look different but equivalent
    // 1 = green block, 0 = empty
    List<List<bool>> s1 = [
      [true, true, false, false, false],
      [true, false, false, true, false],
      [true, true, true, true, false],
      [false, false, true, false, false],
      [false, false, true, true, true],
    ];

    List<List<bool>> s2 = [
      [false, true, true, false, false],
      [false, true, false, true, false],
      [false, true, false, true, true],
      [false, true, true, false, false],
      [false, false, true, true, false],
    ];

    List<List<bool>> s3 = [
      [false, false, true, true, false],
      [true, true, true, false, false],
      [false, false, true, false, true],
      [false, false, true, true, true],
      [false, false, false, true, false],
    ];

    List<List<bool>> s4 = [
      [true, false, true, false, true],
      [true, true, true, true, false],
      [false, true, false, true, false],
      [false, true, true, true, true],
      [true, false, true, false, false],
    ];

    return [s1, s2, s3, s4];
  }

  List<List<bool>> _rotate90(List<List<bool>> grid) {
    final n = grid.length;
    final result = List.generate(
      n,
      (_) => List<bool>.filled(n, false),
    );
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        result[c][n - 1 - r] = grid[r][c];
      }
    }
    return result;
  }

  List<List<bool>> _rotateNTimes(List<List<bool>> grid, int times) {
    var result = grid;
    final n = (times % 4 + 4) % 4;
    for (int i = 0; i < n; i++) {
      result = _rotate90(result);
    }
    return result;
  }

  bool _gridsEqual(List<List<bool>> a, List<List<bool>> b) {
    if (a.length != b.length) return false;
    for (int r = 0; r < a.length; r++) {
      for (int c = 0; c < a[r].length; c++) {
        if (a[r][c] != b[r][c]) return false;
      }
    }
    return true;
  }

  bool _areSameWithRotation(List<List<bool>> a, List<List<bool>> b) {
    if (a.length != b.length) return false;
    var current = a;
    for (int i = 0; i < 4; i++) {
      if (_gridsEqual(current, b)) return true;
      current = _rotate90(current);
    }
    return false;
  }

  // ---------- UI ----------

  Widget _buildPatternBox(List<List<bool>>? pattern) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF111827), width: 2),
        ),
        padding: const EdgeInsets.all(6),
        child: pattern == null
            ? const SizedBox.shrink()
            : LayoutBuilder(
                builder: (context, constraints) {
                  final cellSize = constraints.maxWidth / _gridSize;
                  return Column(
                    children: List.generate(_gridSize, (r) {
                      return Row(
                        children: List.generate(_gridSize, (c) {
                          final isFilled = pattern[r][c];
                          return Container(
                            width: cellSize,
                            height: cellSize,
                            color: isFilled
                                ? const Color(0xFF22C55E)
                                : Colors.white,
                          );
                        }),
                      );
                    }),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildGameContainer() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final containerWidth = constraints.maxWidth;
        final containerHeight = constraints.maxHeight;
        final isPortrait = containerHeight >= containerWidth;
        final maxPatternWidth = isPortrait
            ? containerWidth * 0.32
            : containerHeight * 0.35;

        // When we're in the "WAIT..." phase, keep the game area clean
        // so the overlay text doesn't overlap any UI.
        if (_isWaitingForRound && !_isRoundActive) {
          return const SizedBox.shrink();
        }

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: containerWidth * 0.9,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    SizedBox(
                      width: maxPatternWidth,
                      child: _buildPatternBox(_leftPattern),
                    ),
                    SizedBox(
                      width: maxPatternWidth,
                      child: _buildPatternBox(_rightPattern),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: containerWidth * 0.9,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildAnswerButton(
                        label: '≠',
                        description: 'NOT SAME',
                        onTap: () => _handleAnswer(false),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildAnswerButton(
                        label: '=',
                        description: 'SAME',
                        onTap: () => _handleAnswer(true),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnswerButton({
    required String label,
    required String description,
    required VoidCallback onTap,
  }) {
    final bool enabled = _isRoundActive;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: enabled ? 1.0 : 0.6,
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF111827), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: Color(0xFF4B5563),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = GameState(
      isPlaying: _isPlaying,
      isWaiting: _isWaitingForRound,
      isRoundActive: _isRoundActive,
      currentRound: _currentRound,
      completedRounds: _completedRounds,
      errorMessage: _errorMessage,
      reactionTimeMessage: _reactionTimeMessage,
    );

    return BaseGamePage(
      config: GamePageConfig(
        gameName: 'SPATIAL IMAGINATION',
        categoryName: widget.categoryName ?? 'Visual',
        gameId: 'spatial_imagination',
        bestSession: _bestSession,
      ),
      state: state,
      callbacks: GameCallbacks(
        onStart: _startGame,
        onReset: () {
          _resetGame();
          setState(() {});
        },
      ),
      builders: GameBuilders(
        titleBuilder: (s) {
          if (!s.isPlaying) {
            return 'Are the shapes the same?';
          }
          if (s.isWaiting) {
            return 'GET READY...';
          }
          if (s.isRoundActive) {
            return 'SAME OR NOT SAME?';
          }
          return 'Round ${s.currentRound}';
        },
        contentBuilder: (s, context) {
          if (s.isRoundActive || s.isWaiting) {
            return Positioned.fill(child: _buildGameContainer());
          }
          return Positioned.fill(
            child: Container(
              decoration: !s.isRoundActive && !s.isPlaying
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
              child: const SizedBox.shrink(),
            ),
          );
        },
        waitingTextBuilder: (_) {
          return 'WAIT...';
        },
        startButtonText: 'START',
      ),
      useBackdropFilter: true,
    );
  }
}

