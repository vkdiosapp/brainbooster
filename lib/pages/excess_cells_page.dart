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

enum TriangleDirection { up, down, left, right }

class ExcessCellsPage extends StatefulWidget {
  final String? categoryName;
  final String? exerciseName;

  const ExcessCellsPage({super.key, this.categoryName, this.exerciseName});

  @override
  State<ExcessCellsPage> createState() => _ExcessCellsPageState();
}

class _ExcessCellsPageState extends State<ExcessCellsPage> {
  // Get penalty time from exercise data (exercise ID 15)
  late final int _wrongTapPenaltyMs = ExerciseData.getExercises()
      .firstWhere(
        (e) => e.id == 15,
        orElse: () => ExerciseData.getExercises().first,
      )
      .penaltyTime;

  int _gridSize = 4; // Grid size: 4 or 5
  int _currentRound = 0;
  int _completedRounds = 0;
  int _bestSession = 240; // ms

  bool _isPlaying = false;
  bool _isWaitingForRound = false;
  bool _isRoundActive = false;

  // Maps position index to triangle direction
  Map<int, TriangleDirection> _triangleDirections = {};
  TriangleDirection _commonDirection =
      TriangleDirection.up; // Most triangles use this
  Set<int> _differentDirectionPositions =
      {}; // 2 positions with different direction
  Set<int> _tappedPositions = {}; // Positions user has tapped
  DateTime? _roundStartTime;
  Timer? _roundDelayTimer;
  Timer? _overlayTimer;

  String? _errorMessage;
  String? _reactionTimeMessage;

  final List<RoundResult> _roundResults = [];
  final math.Random _rand = math.Random();

  int get _totalCells => _gridSize * _gridSize;

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
    _gridSize = 4; // Reset to default
    _triangleDirections.clear();
    _commonDirection = TriangleDirection.up;
    _differentDirectionPositions.clear();
    _tappedPositions.clear();
    _roundStartTime = null;
    _errorMessage = null;
    _reactionTimeMessage = null;
    _roundResults.clear();
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
      _tappedPositions.clear();
      _roundStartTime = null;
    });

    _roundDelayTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _showRound();
    });
  }

  void _showRound() {
    // Randomly choose a common direction (most triangles will use this)
    final allDirections = TriangleDirection.values;
    _commonDirection = allDirections[_rand.nextInt(allDirections.length)];

    // Generate all positions
    final positions = List.generate(_totalCells, (i) => i);
    positions.shuffle(_rand);

    // Set most triangles to common direction
    _triangleDirections = {};
    for (int i = 0; i < _totalCells; i++) {
      _triangleDirections[i] = _commonDirection;
    }

    // Choose 2 positions for different directions
    final differentPositions = positions.take(2).toList();
    _differentDirectionPositions = differentPositions.toSet();

    // Get two different directions (both different from common and from each other)
    final otherDirections = allDirections
        .where((d) => d != _commonDirection)
        .toList();
    otherDirections.shuffle(_rand);

    // Assign different directions to the 2 positions
    // First position gets first different direction
    _triangleDirections[differentPositions[0]] = otherDirections[0];
    // Second position gets second different direction (ensuring they're different)
    if (otherDirections.length > 1) {
      _triangleDirections[differentPositions[1]] = otherDirections[1];
    } else {
      // If only one other direction available, use it for both (shouldn't happen with 4 directions)
      _triangleDirections[differentPositions[1]] = otherDirections[0];
    }

    setState(() {
      _isWaitingForRound = false;
      _isRoundActive = true;
      _roundStartTime = DateTime.now();
    });
  }

  void _handleTileTap(int index) {
    if (!_isRoundActive || _roundStartTime == null) {
      return;
    }

    // Check if already tapped
    if (_tappedPositions.contains(index)) {
      return; // Already tapped this position
    }

    // Check if this is one of the different direction positions
    if (_differentDirectionPositions.contains(index)) {
      // Play tap sound for correct tap
      SoundService.playTapSound();
      // Correct tap
      setState(() {
        _tappedPositions.add(index);
      });

      // Check if both different direction positions are tapped
      if (_tappedPositions.length == 2) {
        _completeRound();
      }
    } else {
      // Wrong tap - penalty
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
      _isRoundActive = false;
      _completedRounds++;
      _errorMessage = 'PENALTY +1 SECOND';
    });

    _overlayTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _errorMessage = null);
      _startNextRound();
    });
  }

  void _completeRound() {
    _overlayTimer?.cancel();

    // Calculate round time
    final roundTime = DateTime.now()
        .difference(_roundStartTime!)
        .inMilliseconds;

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
        'excess_cells',
      );
      final session = GameSession(
        gameId: 'excess_cells',
        gameName: 'Excess Cells',
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
              gameName: widget.exerciseName ?? 'Excess Cells',
              gameId: 'excess_cells',
              exerciseId: 15,
            ),
          ),
        )
        .then((_) {
          if (!mounted) return;
          _resetGame();
          setState(() {});
        });
  }

  Widget _buildGridSizeSelector() {
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
                      _gridSize = 4;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _gridSize == 4
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
                        color: _gridSize == 4
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
                      _gridSize = 5;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _gridSize == 5
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
                        color: _gridSize == 5
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

  Widget _buildTriangle(TriangleDirection direction) {
    return CustomPaint(
      painter: TrianglePainter(direction: direction, color: Colors.black),
      size: const Size(28, 28),
    );
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
            itemCount: _totalCells,
            itemBuilder: (context, index) {
              final direction = _triangleDirections[index];

              return GestureDetector(
                onTap: () => _handleTileTap(index),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
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
                  child: direction != null
                      ? Center(child: _buildTriangle(direction))
                      : null,
                ),
              );
            },
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
        gameName: 'Excess Cells',
        categoryName: widget.categoryName ?? 'Visual',
        gameId: 'excess_cells',
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
          if (!s.isPlaying) return 'Find the different triangles';
          if (s.isWaiting) return 'Wait...';
          if (s.isRoundActive) {
            return 'TAP THE DIFFERENT TRIANGLES!';
          }
          return 'Round ${s.currentRound}';
        },
        middleContentBuilder: (s, context) {
          // Show grid size selector only before game starts
          if (!s.isPlaying) {
            return _buildGridSizeSelector();
          }
          return const SizedBox.shrink();
        },
        contentBuilder: (s, context) {
          if (s.isRoundActive && !s.isWaiting) {
            return Positioned.fill(child: _buildGrid());
          }
          // idle background
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
        waitingTextBuilder: (_) => 'WAIT...',
        startButtonText: 'START',
      ),
      useBackdropFilter: true,
    );
  }
}

class TrianglePainter extends CustomPainter {
  final TriangleDirection direction;
  final Color color;

  TrianglePainter({required this.direction, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 3;

    final path = Path();

    switch (direction) {
      case TriangleDirection.up:
        path.moveTo(center.dx, center.dy - radius);
        path.lineTo(center.dx - radius, center.dy + radius);
        path.lineTo(center.dx + radius, center.dy + radius);
        break;
      case TriangleDirection.down:
        path.moveTo(center.dx, center.dy + radius);
        path.lineTo(center.dx - radius, center.dy - radius);
        path.lineTo(center.dx + radius, center.dy - radius);
        break;
      case TriangleDirection.left:
        path.moveTo(center.dx - radius, center.dy);
        path.lineTo(center.dx + radius, center.dy - radius);
        path.lineTo(center.dx + radius, center.dy + radius);
        break;
      case TriangleDirection.right:
        path.moveTo(center.dx + radius, center.dy);
        path.lineTo(center.dx - radius, center.dy - radius);
        path.lineTo(center.dx - radius, center.dy + radius);
        break;
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
