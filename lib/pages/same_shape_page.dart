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
import '../widgets/base_game_page.dart';
import 'color_change_results_page.dart';

enum SameShapeType {
  cylinder,
  polyhedron,
  pyramidUp,
  cube,
  sphere,
  pentagon,
  slab,
  dodecahedron,
  pyramidDown,
}

class SameShapePage extends StatefulWidget {
  final String? categoryName;
  final String? exerciseName;

  const SameShapePage({super.key, this.categoryName, this.exerciseName});

  @override
  State<SameShapePage> createState() => _SameShapePageState();
}

class _SameShapePageState extends State<SameShapePage> {
  // Normal mode constants
  static const int _normalGridSize = 3; // 3x3 grid
  static const int _normalTotalCells = 9;

  // Advanced mode constants
  static const int _advancedGridSize = 4; // 4x4 grid
  static const int _advancedTotalCells = 16;

  bool _isAdvanced = false; // false = Normal, true = Advanced

  // Dynamic getters based on difficulty
  int get _gridSize => _isAdvanced ? _advancedGridSize : _normalGridSize;
  int get _totalCells => _isAdvanced ? _advancedTotalCells : _normalTotalCells;

  int _currentRound = 0;
  int _completedRounds = 0;
  int _bestSession = 240; // in milliseconds

  bool _isPlaying = false;
  bool _isWaitingForRound = false;
  bool _isRoundActive = false;

  SameShapeType? _targetShape;
  List<SameShapeType> _gridShapes = [];

  DateTime? _roundStartTime;
  Timer? _delayTimer;
  Timer? _errorDisplayTimer;
  Timer? _reactionTimeDisplayTimer;

  String? _errorMessage;
  String? _reactionTimeMessage;

  final List<RoundResult> _roundResults = [];
  final math.Random _random = math.Random();

  // Get penalty time from exercise data (exercise ID 25)
  late final int _wrongTapPenaltyMs = ExerciseData.getExercises()
      .firstWhere(
        (e) => e.id == 25,
        orElse: () => ExerciseData.getExercises().first,
      )
      .penaltyTime;

  // All available shapes used in the grid, matching the reference design
  final List<SameShapeType> _availableShapes = const [
    SameShapeType.cylinder,
    SameShapeType.polyhedron,
    SameShapeType.pyramidUp,
    SameShapeType.cube,
    SameShapeType.sphere,
    SameShapeType.pentagon,
    SameShapeType.slab,
    SameShapeType.dodecahedron,
    SameShapeType.pyramidDown,
  ];

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
    // Keep _isAdvanced state when resetting (don't reset to false)
    _currentRound = 0;
    _completedRounds = 0;
    _isPlaying = false;
    _isWaitingForRound = false;
    _isRoundActive = false;
    _targetShape = null;
    _gridShapes.clear();
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
      _targetShape = null;
      _gridShapes.clear();
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
    // Pick a random target shape
    final targetIndex = _random.nextInt(_availableShapes.length);
    final targetShape = _availableShapes[targetIndex];

    // Create a grid of shapes based on difficulty, ensuring target is included
    List<SameShapeType> grid;

    if (!_isAdvanced) {
      // Normal mode: original 3x3 behavior using unique-ish shapes
      final shapesPool = List<SameShapeType>.from(_availableShapes);
      shapesPool.shuffle(_random);

      grid = shapesPool.take(_normalTotalCells).toList();

      if (!grid.contains(targetShape)) {
        // Replace a random position to guarantee target is in the grid
        final replaceIndex = _random.nextInt(_normalTotalCells);
        grid[replaceIndex] = targetShape;
      }

      grid.shuffle(_random);
    } else {
      // Advanced mode: 4x4 grid, allow repeated shapes but ensure at least one target
      grid = List<SameShapeType>.generate(
        _advancedTotalCells,
        (_) => _availableShapes[_random.nextInt(_availableShapes.length)],
      );

      if (!grid.contains(targetShape)) {
        final replaceIndex = _random.nextInt(_advancedTotalCells);
        grid[replaceIndex] = targetShape;
      }
    }

    setState(() {
      _targetShape = targetShape;
      _gridShapes = grid;
      _isWaitingForRound = false;
      _isRoundActive = true;
      _roundStartTime = DateTime.now();
    });
  }

  void _handleShapeTap(SameShapeType tappedShape) {
    if (!_isRoundActive || _roundStartTime == null) return;

    if (tappedShape == _targetShape) {
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

  Widget _buildShapeCell(SameShapeType shape) {
    return GestureDetector(
      onTap: () => _handleShapeTap(shape),
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
          child: CustomPaint(
            painter: SameShapePainter(shape),
            size: const Size(64, 64),
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
        'same_shape',
      );
      final session = GameSession(
        gameId: 'same_shape',
        gameName: 'Same Shape',
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
              gameName: widget.exerciseName ?? 'Same Shape',
              gameId: 'same_shape',
              exerciseId: 25,
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

  Widget _buildGrid() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        if (_targetShape != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
              child: Center(
                child: CustomPaint(
                  painter: SameShapePainter(_targetShape!),
                  size: const Size(96, 96),
                ),
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
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _gridSize,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _totalCells,
                  itemBuilder: (context, index) {
                    return _buildShapeCell(_gridShapes[index]);
                  },
                ),
              ),
            ),
          ),
        ),
      ],
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
        gameName: 'Same Shape',
        categoryName: widget.categoryName ?? 'Visual',
        gameId: 'same_shape',
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
          if (!s.isPlaying) return 'Tap the exact same shape';
          if (s.isWaiting) return 'Wait...';
          if (s.isRoundActive) return 'TAP THE SAME SHAPE!';
          return 'Round ${s.currentRound}';
        },
        contentBuilder: (s, context) {
          if (s.isRoundActive &&
              _gridShapes.isNotEmpty &&
              _targetShape != null) {
            return Positioned.fill(child: _buildGrid());
          }
          // idle background similar to Color Frames Count
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

class SameShapePainter extends CustomPainter {
  final SameShapeType type;

  SameShapePainter(this.type);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF111827)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (type) {
      case SameShapeType.cylinder:
        _drawCylinder(canvas, size, paint);
        break;
      case SameShapeType.polyhedron:
        _drawPolyhedron(canvas, size, paint);
        break;
      case SameShapeType.pyramidUp:
        _drawPyramidUp(canvas, size, paint);
        break;
      case SameShapeType.cube:
        _drawCube(canvas, size, paint);
        break;
      case SameShapeType.sphere:
        _drawSphere(canvas, size, paint);
        break;
      case SameShapeType.pentagon:
        _drawPentagon(canvas, size, paint);
        break;
      case SameShapeType.slab:
        _drawSlab(canvas, size, paint);
        break;
      case SameShapeType.dodecahedron:
        _drawDodecahedron(canvas, size, paint);
        break;
      case SameShapeType.pyramidDown:
        _drawPyramidDown(canvas, size, paint);
        break;
    }
  }

  void _drawCylinder(Canvas canvas, Size size, Paint paint) {
    final w = size.width;
    final h = size.height;
    final top = Offset(w * 0.2, h * 0.25);
    final bottom = Offset(w * 0.2, h * 0.75);

    // Vertical edges
    canvas.drawLine(top, bottom, paint);
    canvas.drawLine(Offset(w * 0.8, top.dy), Offset(w * 0.8, bottom.dy), paint);

    // Top and bottom hex-like edges
    final topPath = Path()
      ..moveTo(w * 0.2, h * 0.25)
      ..lineTo(w * 0.35, h * 0.2)
      ..lineTo(w * 0.65, h * 0.2)
      ..lineTo(w * 0.8, h * 0.25)
      ..lineTo(w * 0.65, h * 0.3)
      ..lineTo(w * 0.35, h * 0.3)
      ..close();

    final bottomPath = Path()
      ..moveTo(w * 0.2, h * 0.75)
      ..lineTo(w * 0.35, h * 0.7)
      ..lineTo(w * 0.65, h * 0.7)
      ..lineTo(w * 0.8, h * 0.75)
      ..lineTo(w * 0.65, h * 0.8)
      ..lineTo(w * 0.35, h * 0.8)
      ..close();

    canvas.drawPath(topPath, paint);
    canvas.drawPath(bottomPath, paint);
  }

  void _drawPolyhedron(Canvas canvas, Size size, Paint paint) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w * 0.28;

    final outer = Path();
    const sides = 6;
    for (var i = 0; i <= sides; i++) {
      final angle = (math.pi * 2 / sides) * i - math.pi / 2;
      final p = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        outer.moveTo(p.dx, p.dy);
      } else {
        outer.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(outer, paint);

    // Inner triangulation
    for (var i = 0; i < sides; i++) {
      final angle = (math.pi * 2 / sides) * i - math.pi / 2;
      final p = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(center, p, paint);
    }
  }

  void _drawPyramidUp(Canvas canvas, Size size, Paint paint) {
    final w = size.width;
    final h = size.height;
    final top = Offset(w * 0.5, h * 0.22);
    final left = Offset(w * 0.2, h * 0.7);
    final right = Offset(w * 0.8, h * 0.7);
    final back = Offset(w * 0.65, h * 0.45);

    final path = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(path, paint);

    canvas.drawLine(top, back, paint);
    canvas.drawLine(back, left, paint);
    canvas.drawLine(back, right, paint);
  }

  void _drawCube(Canvas canvas, Size size, Paint paint) {
    final w = size.width;
    final h = size.height;

    final frontRect = Rect.fromLTWH(w * 0.25, h * 0.3, w * 0.4, h * 0.4);
    final backOffset = Offset(w * 0.18, -h * 0.12);
    final backRect = frontRect.shift(backOffset);

    canvas.drawRect(frontRect, paint);
    canvas.drawRect(backRect, paint);

    canvas.drawLine(frontRect.topLeft, backRect.topLeft, paint);
    canvas.drawLine(frontRect.topRight, backRect.topRight, paint);
    canvas.drawLine(frontRect.bottomLeft, backRect.bottomLeft, paint);
    canvas.drawLine(frontRect.bottomRight, backRect.bottomRight, paint);
  }

  void _drawSphere(Canvas canvas, Size size, Paint paint) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w * 0.32;

    canvas.drawCircle(center, radius, paint);

    final horizontalRect = Rect.fromCenter(
      center: center,
      width: radius * 2,
      height: radius * 0.9,
    );
    final verticalRect = Rect.fromCenter(
      center: center,
      width: radius * 0.9,
      height: radius * 2,
    );

    canvas.drawOval(horizontalRect, paint);
    canvas.drawOval(verticalRect, paint);
  }

  void _drawPentagon(Canvas canvas, Size size, Paint paint) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w * 0.3;

    final path = Path();
    const sides = 5;
    for (var i = 0; i <= sides; i++) {
      final angle = (math.pi * 2 / sides) * i - math.pi / 2;
      final p = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  void _drawSlab(Canvas canvas, Size size, Paint paint) {
    final w = size.width;
    final h = size.height;

    final frontRect = Rect.fromLTWH(w * 0.25, h * 0.42, w * 0.5, h * 0.22);
    final backOffset = Offset(w * 0.18, -h * 0.12);
    final backRect = frontRect.shift(backOffset);

    canvas.drawRect(frontRect, paint);
    canvas.drawRect(backRect, paint);

    canvas.drawLine(frontRect.topLeft, backRect.topLeft, paint);
    canvas.drawLine(frontRect.topRight, backRect.topRight, paint);
    canvas.drawLine(frontRect.bottomRight, backRect.bottomRight, paint);
  }

  void _drawDodecahedron(Canvas canvas, Size size, Paint paint) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radiusOuter = w * 0.28;
    final radiusInner = w * 0.18;

    final outer = Path();
    const sides = 6;
    for (var i = 0; i <= sides; i++) {
      final angle = (math.pi * 2 / sides) * i - math.pi / 2;
      final p = Offset(
        center.dx + radiusOuter * math.cos(angle),
        center.dy + radiusOuter * math.sin(angle),
      );
      if (i == 0) {
        outer.moveTo(p.dx, p.dy);
      } else {
        outer.lineTo(p.dx, p.dy);
      }
    }

    final inner = Path();
    for (var i = 0; i <= sides; i++) {
      final angle = (math.pi * 2 / sides) * i - math.pi / 2 + math.pi / sides;
      final p = Offset(
        center.dx + radiusInner * math.cos(angle),
        center.dy + radiusInner * math.sin(angle),
      );
      if (i == 0) {
        inner.moveTo(p.dx, p.dy);
      } else {
        inner.lineTo(p.dx, p.dy);
      }
    }

    canvas.drawPath(outer, paint);
    canvas.drawPath(inner, paint);
  }

  void _drawPyramidDown(Canvas canvas, Size size, Paint paint) {
    final w = size.width;
    final h = size.height;
    final bottom = Offset(w * 0.5, h * 0.78);
    final left = Offset(w * 0.2, h * 0.3);
    final right = Offset(w * 0.8, h * 0.3);
    final back = Offset(w * 0.35, h * 0.55);

    final path = Path()
      ..moveTo(bottom.dx, bottom.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(path, paint);

    canvas.drawLine(bottom, back, paint);
    canvas.drawLine(back, left, paint);
    canvas.drawLine(back, right, paint);
  }

  @override
  bool shouldRepaint(covariant SameShapePainter oldDelegate) {
    return oldDelegate.type != type;
  }
}
