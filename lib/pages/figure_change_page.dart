import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../game_settings.dart';
import '../models/game_session.dart';
import '../models/round_result.dart';
import '../services/game_history_service.dart';
import '../widgets/base_game_page.dart';
import 'color_change_results_page.dart';

enum FigureType {
  circle,
  square,
  triangle,
  diamond,
  star,
  hexagon,
}

class FigureChangePage extends StatefulWidget {
  final String? categoryName;

  const FigureChangePage({super.key, this.categoryName});

  @override
  State<FigureChangePage> createState() => _FigureChangePageState();
}

class _FigureChangePageState extends State<FigureChangePage> {
  int _currentRound = 0;
  int _completedRounds = 0;
  int _bestSession = 300; // ms

  bool _isPlaying = false;
  bool _isWaitingForRound = false;
  bool _isRoundActive = false;
  bool _isMatchFound = false;

  FigureType? _firstFigureType;
  Color? _firstFigureColor;
  FigureType? _secondFigureType;
  Color? _secondFigureColor;

  DateTime? _matchFoundTime; // Time when figures matched
  int _matchProbability = 0; // Random 1-10, determines when figures will match
  int _changeCount = 0; // Count of figure changes in current round
  Timer? _roundDelayTimer;
  Timer? _figureChangeTimer;
  Timer? _overlayTimer;
  String? _errorMessage;
  String? _reactionTimeMessage;

  final List<RoundResult> _roundResults = [];
  final math.Random _rand = math.Random();

  final List<Color> _availableColors = [
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.purple,
    Colors.pink,
    Colors.brown,
    Colors.black,
    Colors.grey,
  ];

  final List<FigureType> _availableFigures = FigureType.values;
  static const int _wrongTapPenaltyMs = 1000;

  @override
  void initState() {
    super.initState();
    _resetGame();
  }

  @override
  void dispose() {
    _roundDelayTimer?.cancel();
    _figureChangeTimer?.cancel();
    _overlayTimer?.cancel();
    super.dispose();
  }

  void _resetGame() {
    _roundDelayTimer?.cancel();
    _figureChangeTimer?.cancel();
    _overlayTimer?.cancel();

    _currentRound = 0;
    _completedRounds = 0;
    _isPlaying = false;
    _isWaitingForRound = false;
    _isRoundActive = false;
    _isMatchFound = false;
      _firstFigureType = null;
      _firstFigureColor = null;
      _secondFigureType = null;
      _secondFigureColor = null;
      _matchFoundTime = null;
      _matchProbability = 0;
      _changeCount = 0;
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
    _figureChangeTimer?.cancel();
    _overlayTimer?.cancel();

    setState(() {
      _currentRound++;
      _isWaitingForRound = true;
      _isRoundActive = false;
      _isMatchFound = false;
      _errorMessage = null;
      _reactionTimeMessage = null;
      _firstFigureType = null;
      _firstFigureColor = null;
      _secondFigureType = null;
      _secondFigureColor = null;
      _matchFoundTime = null;
      _matchProbability = 0;
      _changeCount = 0;
    });

    _roundDelayTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _showRound();
    });
  }

  void _showRound() {
    // Set probability for this round (1 to 10)
    _matchProbability = _rand.nextInt(10) + 1; // Random 1-10
    _changeCount = 0;

    // Set first figure: random colored random figure (stays same this round)
    _firstFigureType = _availableFigures[_rand.nextInt(_availableFigures.length)];
    _firstFigureColor = _availableColors[_rand.nextInt(_availableColors.length)];

    // Set initial second figure: random figure with random color (different from first)
    do {
      _secondFigureType = _availableFigures[_rand.nextInt(_availableFigures.length)];
      _secondFigureColor = _availableColors[_rand.nextInt(_availableColors.length)];
    } while (_firstFigureType == _secondFigureType &&
        _firstFigureColor == _secondFigureColor);

    setState(() {
      _isWaitingForRound = false;
      _isRoundActive = true;
    });

    // Start changing second figure every 1 second
    _startFigureChangeTimer();
  }

  void _startFigureChangeTimer() {
    _figureChangeTimer?.cancel();
    if (_isMatchFound || !_isRoundActive) return;

    _figureChangeTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted || _isMatchFound || !_isRoundActive) return;

      _changeCount++;

      // Check if we've reached the probability count
      if (_changeCount >= _matchProbability) {
        // Force match - set second figure to match first
        setState(() {
          _secondFigureType = _firstFigureType;
          _secondFigureColor = _firstFigureColor;
          _isMatchFound = true;
          _matchFoundTime = DateTime.now();
        });
        _figureChangeTimer?.cancel();
      } else {
        // Change second figure to random figure with random color (different from first)
        setState(() {
          do {
            _secondFigureType = _availableFigures[_rand.nextInt(_availableFigures.length)];
            _secondFigureColor = _availableColors[_rand.nextInt(_availableColors.length)];
          } while (_firstFigureType == _secondFigureType &&
              _firstFigureColor == _secondFigureColor);
        });
        // Continue changing until probability is reached
        _startFigureChangeTimer();
      }
    });
  }

  void _handleContainerTap() {
    if (!_isRoundActive) return;

    // Check if figures are matched
    if (_isMatchFound && _matchFoundTime != null) {
      // Correct tap - calculate reaction time from when match was found to now
      final reactionTime =
          DateTime.now().difference(_matchFoundTime!).inMilliseconds;

      _roundResults.add(
        RoundResult(
          roundNumber: _currentRound,
          reactionTime: reactionTime,
          isFailed: false,
        ),
      );

      setState(() {
        _isRoundActive = false;
        _completedRounds++;
        _reactionTimeMessage = '$reactionTime ms';
      });

      _overlayTimer = Timer(const Duration(milliseconds: 1000), () {
        if (!mounted) return;
        setState(() => _reactionTimeMessage = null);
        _startNextRound();
      });
    } else {
      // Wrong tap - user tapped before figures matched
      _handleWrongTap();
    }
  }

  void _handleWrongTap() {
    _figureChangeTimer?.cancel();

    // Record failed round with penalty time
    _roundResults.add(
      RoundResult(
        roundNumber: _currentRound,
        reactionTime: _wrongTapPenaltyMs,
        isFailed: true,
      ),
    );

    setState(() {
      _errorMessage = 'PENALTY +1 SECOND';
      _isRoundActive = false;
      _completedRounds++;
    });

    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _errorMessage = null);
      // Move to next round
      _startNextRound();
    });
  }

  Future<void> _endGame() async {
    _roundDelayTimer?.cancel();
    _figureChangeTimer?.cancel();
    _overlayTimer?.cancel();

    setState(() {
      _isPlaying = false;
      _isWaitingForRound = false;
      _isRoundActive = false;
      _isMatchFound = false;
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
        'figure_change',
      );
      final session = GameSession(
        gameId: 'figure_change',
        gameName: 'Figure Change',
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
            ),
          ),
        )
        .then((_) {
          if (!mounted) return;
          _resetGame();
          setState(() {});
        });
  }

  Widget _buildFigure(FigureType type, Color color, double size) {
    return CustomPaint(
      size: Size(size, size),
      painter: FigurePainter(type: type, color: color),
    );
  }

  Widget _buildFiguresRow() {
    if (_firstFigureType == null ||
        _firstFigureColor == null ||
        _secondFigureType == null ||
        _secondFigureColor == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // First figure (stays same)
          _buildFigure(_firstFigureType!, _firstFigureColor!, 80),
          // Second figure (changes)
          _buildFigure(_secondFigureType!, _secondFigureColor!, 80),
        ],
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
        gameName: 'Figure Change',
        categoryName: widget.categoryName ?? 'Visual',
        gameId: 'figure_change',
        bestSession: _bestSession,
      ),
      state: state,
      callbacks: GameCallbacks(
        onStart: _startGame,
        onTap: _handleContainerTap,
        onReset: () {
          _resetGame();
          setState(() {});
        },
      ),
      builders: GameBuilders(
        titleBuilder: (s) {
          if (!s.isPlaying) return 'Tap when figures match';
          if (s.isWaiting) return 'Wait...';
          if (s.isRoundActive) return 'TAP WHEN MATCH!';
          return 'Round ${s.currentRound}';
        },
        middleContentBuilder: (s, context) {
          if (s.isRoundActive || s.isPlaying) {
            return _buildFiguresRow();
          }
          return const SizedBox.shrink();
        },
        contentBuilder: (s, context) {
          if (s.isRoundActive) {
            return Stack(
              children: [
                // Visual text (non-interactive)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Text(
                        'TAP WHEN MATCH',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.grey.withOpacity(0.3),
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ),
                ),
                // Transparent tap area covering entire container
                Positioned.fill(
                  child: Container(
                    color: Colors.transparent,
                  ),
                ),
              ],
            );
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
        waitingTextBuilder: (_) => 'WAIT...',
        startButtonText: 'START',
      ),
      useBackdropFilter: true,
    );
  }
}

class FigurePainter extends CustomPainter {
  final FigureType type;
  final Color color;

  FigurePainter({required this.type, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    switch (type) {
      case FigureType.circle:
        canvas.drawCircle(center, radius, paint);
        break;
      case FigureType.square:
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: radius * 2, height: radius * 2),
          const Radius.circular(8),
        );
        canvas.drawRRect(rect, paint);
        break;
      case FigureType.triangle:
        final path = Path();
        path.moveTo(center.dx, center.dy - radius);
        path.lineTo(center.dx - radius, center.dy + radius);
        path.lineTo(center.dx + radius, center.dy + radius);
        path.close();
        canvas.drawPath(path, paint);
        break;
      case FigureType.diamond:
        final path = Path();
        path.moveTo(center.dx, center.dy - radius);
        path.lineTo(center.dx + radius, center.dy);
        path.lineTo(center.dx, center.dy + radius);
        path.lineTo(center.dx - radius, center.dy);
        path.close();
        canvas.drawPath(path, paint);
        break;
      case FigureType.star:
        _drawStar(canvas, center, radius, paint);
        break;
      case FigureType.hexagon:
        _drawHexagon(canvas, center, radius, paint);
        break;
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    final outerRadius = radius;
    final innerRadius = radius * 0.5;
    final numPoints = 5;

    for (int i = 0; i < numPoints * 2; i++) {
      final angle = (i * math.pi) / numPoints - math.pi / 2;
      final r = i.isEven ? outerRadius : innerRadius;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawHexagon(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    final numPoints = 6;

    for (int i = 0; i < numPoints; i++) {
      final angle = (i * 2 * math.pi) / numPoints - math.pi / 2;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
