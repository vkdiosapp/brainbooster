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

class DetectDirectionPage extends StatefulWidget {
  final String? categoryName;
  final String? exerciseName;

  const DetectDirectionPage({super.key, this.categoryName, this.exerciseName});

  @override
  State<DetectDirectionPage> createState() => _DetectDirectionPageState();
}

class _DetectDirectionPageState extends State<DetectDirectionPage> {
  // Get penalty time from exercise data (exercise ID 29)
  late final int _wrongTapPenaltyMs = ExerciseData.getExercises()
      .firstWhere(
        (e) => e.id == 29,
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
  TriangleDirection _mostCommonDirection =
      TriangleDirection.up; // Most triangles use this
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
    _loadBestSession();
  }

  Future<void> _loadBestSession() async {
    final bestTime = await GameHistoryService.getBestTime('detect_direction');
    if (mounted && bestTime > 0) {
      setState(() {
        _bestSession = bestTime;
      });
    }
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
    _mostCommonDirection = TriangleDirection.up;
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
      _roundStartTime = null;
    });

    _roundDelayTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _showRound();
    });
  }

  void _showRound() {
    // Randomly choose a most common direction (most triangles will use this)
    final allDirections = TriangleDirection.values;
    final mostCommonDirection =
        allDirections[_rand.nextInt(allDirections.length)];

    // Generate all positions
    final positions = List.generate(_totalCells, (i) => i);
    positions.shuffle(_rand);

    // Calculate how many cells should have the most common direction
    // At least 50% + 1 should have the most common direction to ensure it's the majority
    final minCommonCount = (_totalCells ~/ 2) + 1;
    final commonCount =
        minCommonCount + _rand.nextInt(_totalCells - minCommonCount + 1);

    // Create new triangle directions map
    final newTriangleDirections = <int, TriangleDirection>{};

    // Assign most common direction to majority of cells
    for (int i = 0; i < commonCount; i++) {
      newTriangleDirections[positions[i]] = mostCommonDirection;
    }

    // Assign random other directions to remaining cells
    final otherDirections = allDirections
        .where((d) => d != mostCommonDirection)
        .toList();

    for (int i = commonCount; i < _totalCells; i++) {
      final randomDirection =
          otherDirections[_rand.nextInt(otherDirections.length)];
      newTriangleDirections[positions[i]] = randomDirection;
    }

    setState(() {
      _mostCommonDirection = mostCommonDirection;
      _triangleDirections = newTriangleDirections;
      _isWaitingForRound = false;
      _isRoundActive = true;
      _roundStartTime = DateTime.now();
    });
  }

  void _handleDirectionTap(TriangleDirection selectedDirection) {
    if (!_isRoundActive || _roundStartTime == null) {
      return;
    }

    // Check if selected direction matches the most common direction
    if (selectedDirection == _mostCommonDirection) {
      // Play tap sound for correct tap
      SoundService.playTapSound();
      _completeRound();
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
        'detect_direction',
      );
      final session = GameSession(
        gameId: 'detect_direction',
        gameName: 'Detect Direction',
        timestamp: DateTime.now(),
        sessionNumber: sessionNumber,
        roundResults: List.from(_roundResults),
        averageTime: averageTime,
        bestTime: bestTime,
      );
      await GameHistoryService.saveSession(session);

      // Update best session from all saved sessions
      final savedBestTime = await GameHistoryService.getBestTime(
        'detect_direction',
      );
      if (mounted) {
        setState(() {
          _bestSession = savedBestTime;
        });
      }
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
              gameName: widget.exerciseName ?? 'Detect Direction',
              gameId: 'detect_direction',
              exerciseId: 29,
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

              return Container(
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
                child: direction != null
                    ? Center(child: _buildTriangle(direction))
                    : null,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDirectionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildDirectionButton(TriangleDirection.up),
          _buildDirectionButton(TriangleDirection.down),
          _buildDirectionButton(TriangleDirection.left),
          _buildDirectionButton(TriangleDirection.right),
        ],
      ),
    );
  }

  Widget _buildDirectionButton(TriangleDirection direction) {
    return GestureDetector(
      onTap: () => _handleDirectionTap(direction),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(child: _buildTriangle(direction)),
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
        gameName: 'Detect Direction',
        categoryName: widget.categoryName ?? 'Visual',
        gameId: 'detect_direction',
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
          if (!s.isPlaying) return 'Find the most common direction';
          if (s.isWaiting) return 'Wait...';
          if (s.isRoundActive) {
            return 'TAP THE MOST COMMON DIRECTION!';
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
            return Column(
              children: [
                Expanded(child: _buildGrid()),
                _buildDirectionButtons(),
              ],
            );
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
