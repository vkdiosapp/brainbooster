import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../game_settings.dart';
import '../models/round_result.dart';
import '../models/game_session.dart';
import '../services/game_history_service.dart';
import '../widgets/base_game_page.dart';
import 'color_change_results_page.dart';

class BallTrackPage extends StatefulWidget {
  final String? categoryName;

  const BallTrackPage({super.key, this.categoryName});

  @override
  State<BallTrackPage> createState() => _BallTrackPageState();
}

class _BallTrackPageState extends State<BallTrackPage> {
  int _currentRound = 0;
  int _completedRounds = 0;
  int _bestSession = 300; // in milliseconds
  bool _isPlaying = false;
  bool _isWaitingForBalls = false;
  bool _areBallsVisible = false;
  Timer? _delayTimer;
  Timer? _redBallTimer;
  Timer? _movementTimer;
  Timer? _stopTimer;
  Timer? _reactionTimeDisplayTimer;
  String? _errorMessage;
  String? _reactionTimeMessage;
  List<RoundResult> _roundResults = [];

  // Ball properties
  static const int _totalBalls = 7;
  static const double _minBallRadius = 40.0; // Minimum ball radius
  static const double _maxBallRadius = 60.0; // Maximum ball radius (1.5x of minimum)
  static const int _redBallDisplayMs = 2000; // 2 seconds showing red ball
  static const int _movementDurationMs = 5000; // 5 seconds of movement

  // Game states
  bool _isRedBallPhase = false; // Showing red ball (2 seconds)
  bool _isMovingPhase = false; // Balls are moving (5 seconds)
  bool _isStoppedPhase = false; // Balls stopped, waiting for user tap
  int? _targetBallIndex; // Index of the ball that was red (the one user needs to tap)

  // List to store all balls
  List<_Ball> _balls = [];
  Timer? _ballMovementTimer;
  double _currentSpeed = 1.8; // Base speed multiplier
  Size? _containerSize;
  DateTime? _timerStartTime; // When balls stop and timer starts

  @override
  void initState() {
    super.initState();
    _resetGame();
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _redBallTimer?.cancel();
    _movementTimer?.cancel();
    _stopTimer?.cancel();
    _reactionTimeDisplayTimer?.cancel();
    _ballMovementTimer?.cancel();
    super.dispose();
  }

  void _resetGame() {
    _currentRound = 0;
    _completedRounds = 0;
    _isPlaying = false;
    _isWaitingForBalls = false;
    _areBallsVisible = false;
    _balls.clear();
    _currentSpeed = 1.8;
    _errorMessage = null;
    _reactionTimeMessage = null;
    _roundResults.clear();
    _isRedBallPhase = false;
    _isMovingPhase = false;
    _isStoppedPhase = false;
    _targetBallIndex = null;
    _timerStartTime = null;
    _delayTimer?.cancel();
    _redBallTimer?.cancel();
    _movementTimer?.cancel();
    _stopTimer?.cancel();
    _reactionTimeDisplayTimer?.cancel();
    _ballMovementTimer?.cancel();
  }

  void _startGame() {
    setState(() {
      _isPlaying = true;
      _currentRound = 0;
      _completedRounds = 0;
      _roundResults.clear();
      _currentSpeed = 1.8;
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
      _isWaitingForBalls = true;
      _areBallsVisible = false;
      _errorMessage = null;
      _reactionTimeMessage = null;
      _isRedBallPhase = false;
      _isMovingPhase = false;
      _isStoppedPhase = false;
      _targetBallIndex = null;
      _timerStartTime = null;
      _balls.clear();
    });

    // Small delay before showing balls
    final random = math.Random();
    final delaySeconds = 0.5 + random.nextDouble() * 1.0;
    final delayMilliseconds = (delaySeconds * 1000).toInt();

    _delayTimer = Timer(Duration(milliseconds: delayMilliseconds), () {
      if (mounted && _isWaitingForBalls) {
        _showBalls();
      }
    });
  }

  void _showBalls() {
    if (!_isWaitingForBalls || _containerSize == null) return;

    final random = math.Random();
    
    // Create 7 balls at random positions with no overlap
    _balls.clear();
    
    for (int i = 0; i < _totalBalls; i++) {
      // Assign random radius between min and max
      final radius = _minBallRadius + 
          (random.nextDouble() * (_maxBallRadius - _minBallRadius));
      
      // Try to find a position that doesn't overlap with existing balls
      Offset position = Offset.zero;
      int attempts = 0;
      bool positionValid = false;
      
      while (!positionValid && attempts < 100) {
        final safeWidth = _containerSize!.width - (radius * 2);
        final safeHeight = _containerSize!.height - (radius * 2);
        
        position = Offset(
          radius + random.nextDouble() * safeWidth,
          radius + random.nextDouble() * safeHeight,
        );
        
        // Check if this position overlaps with any existing ball
        positionValid = true;
        for (var existingBall in _balls) {
          final distance = (position - existingBall.position).distance;
          if (distance < (radius + existingBall.radius)) {
            positionValid = false;
            break;
          }
        }
        
        attempts++;
      }
      
      // If we couldn't find a non-overlapping position, use the last attempted position
      if (!positionValid) {
        final safeWidth = _containerSize!.width - (radius * 2);
        final safeHeight = _containerSize!.height - (radius * 2);
        position = Offset(
          radius + random.nextDouble() * safeWidth,
          radius + random.nextDouble() * safeHeight,
        );
      }

      // Set initial velocity (will be used when movement starts)
      final baseSpeed = 3.0 * _currentSpeed;
      final angle = random.nextDouble() * 2 * math.pi;
      final velocity = Offset(
        math.cos(angle) * baseSpeed,
        math.sin(angle) * baseSpeed,
      );

      _balls.add(_Ball(
        position: position,
        velocity: velocity,
        radius: radius,
        isCaught: false,
      ));
    }

    // Select one random ball to be red
    _targetBallIndex = random.nextInt(_totalBalls);

    setState(() {
      _areBallsVisible = true;
      _isWaitingForBalls = false;
      _isRedBallPhase = true;
    });

    // After 2 seconds, turn red ball black and start movement
    _redBallTimer = Timer(const Duration(milliseconds: _redBallDisplayMs), () {
      if (mounted && _isRedBallPhase) {
        _startMovement();
      }
    });
  }

  void _startMovement() {
    setState(() {
      _isRedBallPhase = false;
      _isMovingPhase = true;
    });

    // Start ball movement
    _startBallMovement();

    // After 5 seconds, stop all balls
    _movementTimer = Timer(const Duration(milliseconds: _movementDurationMs), () {
      if (mounted && _isMovingPhase) {
        _stopBalls();
      }
    });
  }

  void _stopBalls() {
    _ballMovementTimer?.cancel();
    
    setState(() {
      _isMovingPhase = false;
      _isStoppedPhase = true;
      _timerStartTime = DateTime.now(); // Start recording time
    });
  }

  void _startBallMovement() {
    if (!_isMovingPhase || _containerSize == null) return;

    _ballMovementTimer?.cancel();
    _ballMovementTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!_isMovingPhase || _containerSize == null || !mounted) {
        timer.cancel();
        return;
      }

      // Update each ball's position
      for (var ball in _balls) {
        if (ball.isCaught) continue;

        // Update ball position
        ball.position = Offset(
          ball.position.dx + ball.velocity.dx,
          ball.position.dy + ball.velocity.dy,
        );

        // Check for collisions with container edges and bounce (using ball's individual radius)
        final minX = ball.radius;
        final maxX = _containerSize!.width - ball.radius;
        final minY = ball.radius;
        final maxY = _containerSize!.height - ball.radius;

        // Bounce off left or right edge
        if (ball.position.dx <= minX || ball.position.dx >= maxX) {
          ball.velocity = Offset(-ball.velocity.dx, ball.velocity.dy);
          ball.position = Offset(
            ball.position.dx.clamp(minX, maxX),
            ball.position.dy,
          );
        }

        // Bounce off top or bottom edge
        if (ball.position.dy <= minY || ball.position.dy >= maxY) {
          ball.velocity = Offset(ball.velocity.dx, -ball.velocity.dy);
          ball.position = Offset(
            ball.position.dx,
            ball.position.dy.clamp(minY, maxY),
          );
        }
      }

      // Update UI continuously
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _handleTap(Offset tapPosition) {
    if (!_isPlaying) return;

    // Only allow taps when balls are stopped
    if (!_isStoppedPhase || _timerStartTime == null) return;

    // Check if the target ball was tapped
    if (_targetBallIndex == null || _targetBallIndex! >= _balls.length) return;

    final targetBall = _balls[_targetBallIndex!];
    if (targetBall.isCaught) return;

    // Calculate distance from tap to ball center
    final distance = (tapPosition - targetBall.position).distance;
    
    if (distance <= targetBall.radius) {
      // Correct ball tapped!
      final reactionTime = DateTime.now()
          .difference(_timerStartTime!)
          .inMilliseconds;
      _completeRound(reactionTime, false);
    } else {
      // Wrong ball tapped - penalty
      _handleWrongTap();
    }
  }

  void _handleWrongTap() {
    setState(() {
      _errorMessage = 'PENALTY +1 SECOND';
      _isStoppedPhase = false;
      _timerStartTime = null;
    });

    // Mark round as failed with penalty
    _roundResults.add(
      RoundResult(
        roundNumber: _currentRound,
        reactionTime: 1000, // 1 second penalty
        isFailed: true,
      ),
    );

    Timer(const Duration(seconds: 1), () {
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
      _areBallsVisible = false;
      _isStoppedPhase = false;
      _timerStartTime = null;
      _completedRounds++;
      if (!isFailed) {
        _reactionTimeMessage = '$reactionTime ms';
      }
    });

    // Show reaction time for 1 second, then start next round
    _reactionTimeDisplayTimer?.cancel();
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
      _areBallsVisible = false;
    });

    _ballMovementTimer?.cancel();

    if (_roundResults.isEmpty) {
      _resetGame();
      return;
    }

    // Calculate average reaction time (only from successful rounds)
    final successfulRounds = _roundResults.where((r) => !r.isFailed).toList();
    int averageTime = 0;

    if (successfulRounds.isNotEmpty) {
      averageTime = successfulRounds
          .map((r) => r.reactionTime)
          .reduce((a, b) => a + b) ~/
          successfulRounds.length;

      if (averageTime < _bestSession || _bestSession == 0) {
        _bestSession = averageTime;
      }
    } else {
      // If no successful rounds, calculate from all rounds
      if (_roundResults.isNotEmpty) {
        averageTime = _roundResults
            .map((r) => r.reactionTime)
            .reduce((a, b) => a + b) ~/
            _roundResults.length;
      }
    }

    // Get best time before saving
    final savedBestTime = await GameHistoryService.getBestTime('ball_track');
    final finalBestTime = (savedBestTime == 0 || averageTime < savedBestTime) 
        ? averageTime 
        : savedBestTime;

    // Save session
    final session = GameSession(
      gameId: 'ball_track',
      gameName: 'Ball Track',
      sessionNumber: await GameHistoryService.getNextSessionNumber('ball_track'),
      timestamp: DateTime.now(),
      roundResults: _roundResults,
      averageTime: averageTime,
      bestTime: finalBestTime,
    );

    await GameHistoryService.saveSession(session);

    // Update best session if needed
    if (savedBestTime == 0 || averageTime < savedBestTime) {
      setState(() {
        _bestSession = averageTime;
      });
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
        gameName: 'BALL TRACK',
        categoryName: widget.categoryName ?? 'Memory',
        gameId: 'ball_track',
        bestSession: _bestSession,
      ),
      state: GameState(
        isPlaying: _isPlaying,
        isWaiting: _isWaitingForBalls,
        isRoundActive: _areBallsVisible,
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
          if (!state.isPlaying) return 'Track the red ball';
          if (state.isWaiting) return 'Wait for the balls...';
          if (_isRedBallPhase) return 'MEMORIZE THE RED BALL!';
          if (_isMovingPhase) return 'BALLS ARE MOVING...';
          if (_isStoppedPhase) return 'TAP THE RED BALL!';
          return 'Round ${state.currentRound}';
        },
        contentBuilder: (state, context) {
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
                  if (_isPlaying && _isStoppedPhase) {
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
                      if (state.isRoundActive && _areBallsVisible)
                        ..._balls.asMap().entries.map((entry) {
                          final index = entry.key;
                          final ball = entry.value;
                          if (ball.isCaught) return const SizedBox.shrink();
                          
                          // Determine ball color: red if it's the target during red phase, black otherwise
                          final isRed = _isRedBallPhase && index == _targetBallIndex;
                          
                          return Positioned(
                            left: ball.position.dx - ball.radius,
                            top: ball.position.dy - ball.radius,
                            child: Container(
                              width: ball.radius * 2,
                              height: ball.radius * 2,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isRed ? Colors.red : Colors.black,
                              ),
                            ),
                          );
                        }).toList(),
                    ],
                  ),
                ),
              );
            },
          );
        },
        waitingTextBuilder: (state) => 'WAIT...',
        startButtonText: 'START',
      ),
      useBackdropFilter: false,
    );
  }
}

// Helper class to represent a ball
class _Ball {
  Offset position;
  Offset velocity;
  double radius;
  bool isCaught;

  _Ball({
    required this.position,
    required this.velocity,
    required this.radius,
    required this.isCaught,
  });
}
