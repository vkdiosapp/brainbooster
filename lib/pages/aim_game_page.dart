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
import 'color_change_results_page.dart';

class Aim {
  Offset position;
  bool isTapped;
  double radius;

  Aim({
    required this.position,
    this.isTapped = false,
    this.radius = 40.0,
  });
}

class AimGamePage extends StatefulWidget {
  final String? categoryName;
  final String? exerciseName;

  const AimGamePage({super.key, this.categoryName, this.exerciseName});

  @override
  State<AimGamePage> createState() => _AimGamePageState();
}

class _AimGamePageState extends State<AimGamePage> {
  int _aimCount = 2; // Default 2 aims, can be 1-10
  int _currentRound = 0;
  int _completedRounds = 0;
  int _bestSession = 240; // ms

  bool _isPlaying = false;
  bool _isWaitingForRound = false;
  bool _isRoundActive = false;

  List<Aim> _aims = [];
  DateTime? _roundStartTime;
  Timer? _roundDelayTimer;
  Timer? _overlayTimer;
  Size? _containerSize;

  String? _errorMessage;
  String? _reactionTimeMessage;

  final List<RoundResult> _roundResults = [];
  final math.Random _rand = math.Random();

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
    _aimCount = 2; // Reset to default
    _aims.clear();
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
      _aims.clear();
      _roundStartTime = null;
    });

    _roundDelayTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _showRound();
    });
  }

  void _showRound() {
    if (_containerSize == null) return;

    // Generate random positions for aims without overlap
    _aims.clear();
    const double aimRadius = 40.0;
    const double minDistance = aimRadius * 2.5; // Minimum distance between aims

    for (int i = 0; i < _aimCount; i++) {
      int attempts = 0;
      Offset? position;

      while (attempts < 100) {
        // Calculate safe area (accounting for radius)
        final safeWidth = _containerSize!.width - (aimRadius * 2);
        final safeHeight = _containerSize!.height - (aimRadius * 2);

        final candidatePosition = Offset(
          aimRadius + _rand.nextDouble() * safeWidth,
          aimRadius + _rand.nextDouble() * safeHeight,
        );

        // Check if this position overlaps with existing aims
        bool overlaps = false;
        for (var existingAim in _aims) {
          final distance = (candidatePosition - existingAim.position).distance;
          if (distance < minDistance) {
            overlaps = true;
            break;
          }
        }

        if (!overlaps) {
          position = candidatePosition;
          break;
        }

        attempts++;
      }

      // If we couldn't find a non-overlapping position, place it anyway
      // (shouldn't happen with reasonable aim counts)
      if (position == null) {
        final safeWidth = _containerSize!.width - (aimRadius * 2);
        final safeHeight = _containerSize!.height - (aimRadius * 2);
        position = Offset(
          aimRadius + _rand.nextDouble() * safeWidth,
          aimRadius + _rand.nextDouble() * safeHeight,
        );
      }

      _aims.add(Aim(
        position: position,
        radius: aimRadius,
        isTapped: false,
      ));
    }

    setState(() {
      _isWaitingForRound = false;
      _isRoundActive = true;
      _roundStartTime = DateTime.now();
    });
  }

  void _handleTap(Offset tapPosition) {
    if (!_isRoundActive || _roundStartTime == null) {
      return;
    }

    // Check if any aim was tapped
    bool aimTapped = false;
    for (var aim in _aims) {
      if (aim.isTapped) continue;

      // Calculate distance from tap to aim center
      final distance = (tapPosition - aim.position).distance;

      if (distance <= aim.radius) {
        // Play tap sound for correct tap
        SoundService.playTapSound();
        aim.isTapped = true;
        aimTapped = true;
        break;
      }
    }

    if (aimTapped) {
      setState(() {});

      // Check if all aims are tapped
      if (_aims.every((aim) => aim.isTapped)) {
        _completeRound();
      }
    }
    // If no aim was tapped, just ignore (no penalty)
  }

  void _completeRound() {
    _overlayTimer?.cancel();

    // Calculate round time
    final roundTime = DateTime.now().difference(_roundStartTime!).inMilliseconds;

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
        'aim',
      );
      final session = GameSession(
        gameId: 'aim',
        gameName: 'Aim',
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
              gameName: widget.exerciseName ?? 'Aim',
            ),
          ),
        )
        .then((_) {
          if (!mounted) return;
          _resetGame();
          setState(() {});
        });
  }

  Widget _buildAimCountSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
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
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Decrease button
                GestureDetector(
                  onTap: () {
                    if (_aimCount > 1) {
                      setState(() {
                        _aimCount--;
                      });
                    }
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _aimCount > 1
                          ? const Color(0xFF475569)
                          : Colors.grey.withOpacity(0.3),
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
                    child: const Icon(
                      Icons.remove,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Aim count display
                Text(
                  '$_aimCount Aim${_aimCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(width: 24),
                // Increase button
                GestureDetector(
                  onTap: () {
                    if (_aimCount < 10) {
                      setState(() {
                        _aimCount++;
                      });
                    }
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _aimCount < 10
                          ? const Color(0xFF475569)
                          : Colors.grey.withOpacity(0.3),
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
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 24,
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

  Widget _buildAimTarget(double radius) {
    return CustomPaint(
      painter: AimTargetPainter(),
      size: Size(radius * 2, radius * 2),
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
        gameName: 'AIM',
        categoryName: widget.categoryName ?? 'Visual',
        gameId: 'aim',
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
          if (!s.isPlaying) return 'Tap all the aims';
          if (s.isWaiting) return 'Wait...';
          if (s.isRoundActive) {
            final tappedCount = _aims.where((a) => a.isTapped).length;
            return 'TAP THE AIMS! ($tappedCount/$_aimCount)';
          }
          return 'Round ${s.currentRound}';
        },
        middleContentBuilder: (s, context) {
          // Show aim count selector only before game starts
          if (!s.isPlaying) {
            return _buildAimCountSelector();
          }
          return const SizedBox.shrink();
        },
        contentBuilder: (s, context) {
          return LayoutBuilder(
            builder: (context, constraints) {
              // Store container size for calculations
              if (_containerSize == null ||
                  _containerSize!.width != constraints.maxWidth ||
                  _containerSize!.height != constraints.maxHeight) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _containerSize = Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                    });
                  }
                });
              }

              return GestureDetector(
                onTapDown: (details) {
                  if (_isPlaying && _isRoundActive) {
                    // Convert local position to container coordinates
                    final localPosition = details.localPosition;
                    _handleTap(localPosition);
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  child: Stack(
                    children: [
                      if (s.isRoundActive)
                        ..._aims.where((aim) => !aim.isTapped).map((aim) {
                          return Positioned(
                            left: aim.position.dx - aim.radius,
                            top: aim.position.dy - aim.radius,
                            child: _buildAimTarget(aim.radius),
                          );
                        }).toList(),
                    ],
                  ),
                ),
              );
            },
          );
        },
        waitingTextBuilder: (_) => 'WAIT...',
        startButtonText: 'START',
      ),
      useBackdropFilter: true,
    );
  }
}

class AimTargetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer circle (dark grey)
    final outerPaint = Paint()
      ..color = const Color(0xFF475569)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, outerPaint);

    // Inner circle (white)
    final innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.7, innerPaint);

    // Center circle (dark grey) - crosshair center
    final centerPaint = Paint()
      ..color = const Color(0xFF475569)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.25, centerPaint);

    // Crosshair lines (white)
    final linePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    // Horizontal line
    canvas.drawLine(
      Offset(center.dx - radius * 0.9, center.dy),
      Offset(center.dx + radius * 0.9, center.dy),
      linePaint,
    );
    
    // Vertical line
    canvas.drawLine(
      Offset(center.dx, center.dy - radius * 0.9),
      Offset(center.dx, center.dy + radius * 0.9),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
