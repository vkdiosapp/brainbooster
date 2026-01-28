import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../game_settings.dart';
import '../models/game_session.dart';
import '../models/round_result.dart';
import '../services/game_history_service.dart';
import '../services/sound_service.dart';
import '../widgets/base_game_page.dart';
import '../data/exercise_data.dart';
import 'color_change_results_page.dart';

class RotationPage extends StatefulWidget {
  final String? categoryName;
  final String? exerciseName;

  const RotationPage({super.key, this.categoryName, this.exerciseName});

  @override
  State<RotationPage> createState() => _RotationPageState();
}

class _RotationPageState extends State<RotationPage>
    with SingleTickerProviderStateMixin {
  // Get penalty time from exercise data (exercise ID 28)
  late final int _wrongTapPenaltyMs = ExerciseData.getExercises()
      .firstWhere(
        (e) => e.id == 28,
        orElse: () => ExerciseData.getExercises().first,
      )
      .penaltyTime;
  static const int _displayDurationMs = 2000; // Show red dots for 2 seconds

  // Normal mode constants
  static const int _normalGridSize = 4; // 4x4 grid
  static const int _normalTotalBoxes = 16; // 4x4 = 16 boxes
  static const int _normalRedDotsCount = 4; // Show 4 red dots
  static const int _normalDistractorDotsCount = 2; // Show 2 distractor dots

  // Advanced mode constants
  static const int _advancedGridSize = 5; // 5x5 grid
  static const int _advancedTotalBoxes = 25; // 5x5 = 25 boxes
  static const int _advancedRedDotsCount = 8; // Show 8 red dots
  static const int _advancedDistractorDotsCount = 4; // Show 4 distractor dots

  bool _isAdvanced = false; // false = Normal, true = Advanced

  int _currentRound = 0;
  int _completedRounds = 0;
  int _bestSession = 240; // ms

  bool _isPlaying = false;
  bool _isWaitingForRound = false;
  bool _isShowingRedDots = false; // Phase 1: Showing red dots
  bool _isRotating = false; // Phase 2: Grid is rotating, user can't tap
  bool _isRoundActive = false; // Phase 3: User can tap black boxes

  Set<int> _redDotPositions = {}; // Positions with red dots (rotated)
  Set<int> _originalRedDotPositions = {}; // Original positions before rotation
  Map<int, Color> _distractorDotPositions =
      {}; // Positions with distractor dots (different colors)
  Set<int> _tappedPositions = {}; // Positions user has correctly tapped
  DateTime? _roundStartTime;
  Timer? _roundDelayTimer;
  Timer? _redDotTimer;
  Timer? _overlayTimer;

  String? _errorMessage;
  String? _reactionTimeMessage;

  final List<RoundResult> _roundResults = [];
  final math.Random _rand = math.Random();

  late final AnimationController _rotationController;
  late final Animation<double> _rotationAnimation;
  int _totalRotations = 0; // Total number of 90° rotations to perform (1-4)
  int _currentRotationCount = 0; // Current rotation number (0 to _totalRotations)
  double _baseAngle = 0; // Base angle from completed rotations (before current animation)

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), // Each 90° rotation takes 1 second
    );
    // 0 -> 1, we'll scale by _currentTargetAngle each round
    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _rotationController,
        curve: Curves.linear,
      ),
    );

    _resetGame();
  }

  @override
  void dispose() {
    _roundDelayTimer?.cancel();
    _redDotTimer?.cancel();
    _overlayTimer?.cancel();
    _rotationController.dispose();
    super.dispose();
  }

  // Getters for dynamic values based on difficulty
  int get _gridSize => _isAdvanced ? _advancedGridSize : _normalGridSize;
  int get _totalBoxes => _isAdvanced ? _advancedTotalBoxes : _normalTotalBoxes;
  int get _redDotsCount =>
      _isAdvanced ? _advancedRedDotsCount : _normalRedDotsCount;
  int get _distractorDotsCount =>
      _isAdvanced ? _advancedDistractorDotsCount : _normalDistractorDotsCount;

  /// Rotate a position 90 degrees clockwise in the grid
  /// For a grid of size N: row = pos ~/ N, col = pos % N
  /// After 90° clockwise: new row = col, new col = N - 1 - row
  /// New position = new row * N + new col
  int _rotatePosition90Clockwise(int position) {
    final row = position ~/ _gridSize;
    final col = position % _gridSize;
    final newRow = col;
    final newCol = _gridSize - 1 - row;
    return newRow * _gridSize + newCol;
  }

  /// Transform all positions in a set by rotating 90° clockwise
  Set<int> _rotatePositions90Clockwise(Set<int> positions) {
    return positions.map(_rotatePosition90Clockwise).toSet();
  }

  void _resetGame() {
    _roundDelayTimer?.cancel();
    _redDotTimer?.cancel();
    _overlayTimer?.cancel();
    _rotationController.stop();
    _rotationController.reset();

    _currentRound = 0;
    _completedRounds = 0;
    _isPlaying = false;
    _isWaitingForRound = false;
    _isShowingRedDots = false;
    _isRotating = false;
    _isRoundActive = false;
    _redDotPositions.clear();
    _originalRedDotPositions.clear();
    _distractorDotPositions.clear();
    _tappedPositions.clear();
    _roundStartTime = null;
    _errorMessage = null;
    _reactionTimeMessage = null;
    _roundResults.clear();
    _totalRotations = 0;
    _currentRotationCount = 0;
    _baseAngle = 0;
    // Keep _isAdvanced state when resetting (don't reset to false)
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
    _redDotTimer?.cancel();
    _overlayTimer?.cancel();
    _rotationController.stop();
    _rotationController.reset();

    setState(() {
      _currentRound++;
      _isWaitingForRound = true;
      _isShowingRedDots = false;
      _isRotating = false;
      _isRoundActive = false;
      _errorMessage = null;
      _reactionTimeMessage = null;
      _redDotPositions.clear();
      _originalRedDotPositions.clear();
      _distractorDotPositions.clear();
      _tappedPositions.clear();
      _roundStartTime = null;
      _totalRotations = 0;
      _currentRotationCount = 0;
      _baseAngle = 0;
    });

    _roundDelayTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _showRedDots();
    });
  }

  void _showRedDots() {
    // Generate random positions for red dots based on difficulty
    final positions = List.generate(_totalBoxes, (i) => i);
    positions.shuffle(_rand);
    _originalRedDotPositions = positions.take(_redDotsCount).toSet();
    // Initially, positions are not rotated (will be rotated after dots hide)
    _redDotPositions = Set.from(_originalRedDotPositions);

    // Generate distractor dots with different colors
    // Make sure they don't overlap with red dots
    final remainingPositions = positions
        .where((pos) => !_redDotPositions.contains(pos))
        .toList();
    remainingPositions.shuffle(_rand);

    final distractorPositions =
        remainingPositions.take(_distractorDotsCount).toList();
    // Use more colors for advanced mode
    final distractorColors = _isAdvanced
        ? [Colors.blue, Colors.green, Colors.orange, Colors.purple]
        : [Colors.blue, Colors.green];
    _distractorDotPositions = {};
    for (int i = 0;
        i < distractorPositions.length && i < distractorColors.length;
        i++) {
      _distractorDotPositions[distractorPositions[i]] = distractorColors[i];
    }

    setState(() {
      _isWaitingForRound = false;
      _isShowingRedDots = true;
      _isRoundActive = false;
    });

    // After 2 seconds, hide red dots and show black boxes
    _redDotTimer = Timer(const Duration(milliseconds: _displayDurationMs), () {
      if (!mounted) return;
      _hideRedDots();
    });
  }

  void _hideRedDots() {
    setState(() {
      _isShowingRedDots = false;
      _isRotating = true;
      _isRoundActive = false; // grid is black but taps disabled
      _roundStartTime = null; // We don't track time while rotating
    });

    // Always do 1 full rotation (4 × 90° = 360°), then randomly do 0-3 more rotations
    // So total rotations = 4, 5, 6, or 7
    _totalRotations = 4 + _rand.nextInt(4); // 4 + (0-3) = 4-7 rotations
    _currentRotationCount = 0;
    _baseAngle = 0;

    // Start the first rotation
    _performNextRotation();
  }

  void _performNextRotation() {
    _currentRotationCount++;

    _rotationController
      ..reset()
      ..forward().whenComplete(() {
        if (!mounted) return;

        // Update base angle after this rotation completes
        _baseAngle += math.pi / 2; // Add 90° to base angle

        // Rotate the red dot positions 90° clockwise for each rotation
        _redDotPositions = _rotatePositions90Clockwise(_redDotPositions.isEmpty
            ? _originalRedDotPositions
            : _redDotPositions);

        // Check if we need to do more rotations
        if (_currentRotationCount < _totalRotations) {
          // Do the next rotation (base angle is already updated)
          setState(() {}); // Trigger rebuild to show updated base angle
          _performNextRotation();
        } else {
          // All rotations complete - now user can tap and timing starts
          setState(() {
            _isRotating = false;
            _isRoundActive = true;
            _roundStartTime = DateTime.now();
            // Reset visual rotation angle to 0 (grid snaps back)
            _baseAngle = 0;
          });
        }
      });
  }

  void _handleTileTap(int index) {
    // User cannot tap while rotating or before timing starts
    if (_isRotating || !_isRoundActive || _roundStartTime == null) {
      return;
    }

    // Check if already tapped
    if (_tappedPositions.contains(index)) {
      return; // Already tapped this position
    }

    // Check if this is a correct position (had red dot)
    if (_redDotPositions.contains(index)) {
      // Play tap sound for correct tap
      SoundService.playTapSound();
      // Correct tap
      setState(() {
        _tappedPositions.add(index);
      });

      // Check if all red dot positions are tapped (dynamic based on difficulty)
      if (_tappedPositions.length == _redDotsCount) {
        _completeRound();
      }
    } else {
      // Wrong tap - penalty (includes tapping distractor dots or empty boxes)
      _handleWrongTap();
    }
  }

  void _handleWrongTap() {
    // Play penalty sound for wrong tap
    SoundService.playPenaltySound();
    _overlayTimer?.cancel();

    // End round immediately with penalty
    final roundTime = _wrongTapPenaltyMs; // Use penalty as round time

    _roundResults.add(
      RoundResult(
        roundNumber: _currentRound,
        reactionTime: roundTime,
        isFailed: true, // Mark as failed
      ),
    );

    setState(() {
      _isRotating = false;
      _isRoundActive = false;
      _completedRounds++;
      _errorMessage = 'PENALTY +1 SECOND';
    });

    _rotationController.stop();

    _overlayTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _errorMessage = null);
      _startNextRound();
    });
  }

  void _completeRound() {
    _overlayTimer?.cancel();

    // Calculate round time (from when boxes turned black until all required tapped)
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
      _isRotating = false;
      _isRoundActive = false;
      _completedRounds++;
      _reactionTimeMessage = '$roundTime ms';
    });

    _rotationController.stop();

    _overlayTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _reactionTimeMessage = null);
      _startNextRound();
    });
  }

  Future<void> _endGame() async {
    _roundDelayTimer?.cancel();
    _redDotTimer?.cancel();
    _overlayTimer?.cancel();
    _rotationController.stop();

    setState(() {
      _isPlaying = false;
      _isWaitingForRound = false;
      _isShowingRedDots = false;
      _isRotating = false;
      _isRoundActive = false;
    });

    // Calculate average/best
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
        'rotation',
      );
      final session = GameSession(
        gameId: 'rotation',
        gameName: 'Rotation',
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
              gameName: widget.exerciseName ?? 'Rotation',
              gameId: 'rotation',
              exerciseId: 28,
            ),
          ),
        )
        .then((_) {
          if (!mounted) return;
          _resetGame();
          setState(() {});
        });
  }

  Widget _buildGrid() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: AspectRatio(
          aspectRatio: 1.0,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _gridSize,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _totalBoxes,
            itemBuilder: (context, index) {
              final hasRedDot = _redDotPositions.contains(index);
              final hasDistractorDot = _distractorDotPositions.containsKey(
                index,
              );
              final distractorColor = _distractorDotPositions[index];
              final isTapped = _tappedPositions.contains(index);
              final isShowingRedDots = _isShowingRedDots;
              // Show black boxes both while rotating and when round is active
              final isGridActive = _isRotating || _isRoundActive;

              // Determine box color and content
              Color boxColor;
              Widget? content;

              if (isShowingRedDots) {
                // Phase 1: Show red dots and distractor dots on white boxes, others empty white
                boxColor = Colors.white;
                if (hasRedDot) {
                  content = Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  );
                } else if (hasDistractorDot && distractorColor != null) {
                  content = Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: distractorColor,
                      shape: BoxShape.circle,
                    ),
                  );
                }
              } else if (isGridActive) {
                // Phase 2 & 3: All boxes are black (rotation + answer phase)
                boxColor = Colors.black;
                if (isTapped) {
                  // If tapped correctly, show white with red dot
                  boxColor = Colors.white;
                  content = Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  );
                }
              } else {
                // Idle state: white boxes
                boxColor = Colors.white;
              }

              return GestureDetector(
                onTap: () => _handleTileTap(index),
                child: Container(
                  decoration: BoxDecoration(
                    color: boxColor,
                    borderRadius: BorderRadius.circular(16),
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
                  child: content != null ? Center(child: content) : null,
                ),
              );
            },
          ),
        ),
      ),
    );
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
    final state = GameState(
      isPlaying: _isPlaying,
      // We treat rotation as part of the round, not a wait state
      isWaiting: _isWaitingForRound || _isShowingRedDots,
      isRoundActive: _isRoundActive,
      currentRound: _currentRound,
      completedRounds: _completedRounds,
      errorMessage: _errorMessage,
      reactionTimeMessage: _reactionTimeMessage,
    );

    return BaseGamePage(
      config: GamePageConfig(
        gameName: 'Rotation',
        categoryName: widget.categoryName ?? 'Memory',
        gameId: 'rotation',
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
          if (!s.isPlaying) return 'Memorize the red dots';
          if (s.isWaiting) {
            if (_isShowingRedDots) return 'MEMORIZE THE RED DOTS!';
            return 'Wait...';
          }
          if (s.isRoundActive) {
            return 'GRID ROTATED - TAP THE RED DOTS!';
          }
          return 'Round ${s.currentRound}';
        },
        contentBuilder: (s, context) {
          // Only show grid when showing red dots, rotating, or when round is active.
          // Hide grid during initial wait phase to avoid UI override.
          if (_isShowingRedDots || _isRotating || s.isRoundActive) {
            return Positioned.fill(
              child: AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  // Rotate during rotation phase: base angle + current 90° rotation progress
                  // Once stopped, snap back to 0 so grid positions match the original layout
                  final angle = _isRotating
                      ? _baseAngle + (_rotationAnimation.value * math.pi / 2)
                      : 0.0;
                  return Transform.rotate(
                    angle: angle,
                    child: child,
                  );
                },
                child: _buildGrid(),
              ),
            );
          }
          // idle background or wait state (no grid)
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
          if (_isShowingRedDots) return '';
          return 'WAIT...';
        },
        startButtonText: 'START',
        middleContentBuilder: (s, context) {
          // Show difficulty selector only before game starts
          if (!s.isPlaying) {
            return _buildDifficultySelector();
          }
          return const SizedBox.shrink();
        },
      ),
      useBackdropFilter: true,
    );
  }
}

