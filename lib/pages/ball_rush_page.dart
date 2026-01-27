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
import 'color_change_results_page.dart';

class BallRushPage extends StatefulWidget {
  final String? categoryName;
  final String? exerciseName;

  const BallRushPage({super.key, this.categoryName, this.exerciseName});

  @override
  State<BallRushPage> createState() => _BallRushPageState();
}

class _BallRushPageState extends State<BallRushPage> {
  int _currentRound = 0;
  int _completedRounds = 0;
  int _bestSession = 300; // in milliseconds
  bool _isPlaying = false;
  bool _isWaitingForBalls = false;
  bool _areBallsVisible = false;
  DateTime? _ballsAppearedTime;
  Timer? _delayTimer;
  Timer? _reactionTimeDisplayTimer;
  Timer? _errorDisplayTimer;
  String? _errorMessage;
  String? _reactionTimeMessage;
  List<RoundResult> _roundResults = [];
  bool _isAdvanced = false; // false = Normal, true = Advanced

  // Ball properties
  static const int _totalBalls = 10;
  static const int _bombCount = 2; // Number of bombs in advanced mode
  static const double _minBallRadius = 40.0; // Minimum ball radius
  static const double _maxBallRadius = 60.0; // Maximum ball radius (1.5x of minimum)
  static const int _wrongTapPenaltyMs = 1000; // Penalty for tapping bomb

  // List to store all balls
  List<_Ball> _balls = [];
  Timer? _ballMovementTimer;
  double _currentSpeed = 1.8; // Base speed multiplier
  Size? _containerSize;
  int _ballsCaught = 0;

  @override
  void initState() {
    super.initState();
    _resetGame();
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
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
    _ballsAppearedTime = null;
    _balls.clear();
    _ballsCaught = 0;
    _currentSpeed = 1.8;
    _errorMessage = null;
    _reactionTimeMessage = null;
    _roundResults.clear();
    _delayTimer?.cancel();
    _reactionTimeDisplayTimer?.cancel();
    _errorDisplayTimer?.cancel();
    _ballMovementTimer?.cancel();
    // Keep _isAdvanced state when resetting (don't reset to false)
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
      _ballsCaught = 0;
      _balls.clear();
    });

    // Random delay before showing balls (0.5-2 seconds)
    final random = math.Random();
    final delaySeconds = 0.5 + random.nextDouble() * 1.5;
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
    
    // Create balls at random positions with random sizes
    _balls.clear();
    
    // Determine how many regular balls vs bombs
    int regularBallsCount = _totalBalls;
    int bombsCount = 0;
    if (_isAdvanced) {
      bombsCount = _bombCount;
      regularBallsCount = _totalBalls - _bombCount;
    }
    
    // Create regular balls
    for (int i = 0; i < regularBallsCount; i++) {
      // Use minimum radius for all balls (same size)
      final radius = _minBallRadius;
      
      // Calculate safe area for this ball
      final safeWidth = _containerSize!.width - (radius * 2);
      final safeHeight = _containerSize!.height - (radius * 2);

      // Set initial position (random within safe area)
      final position = Offset(
        radius + random.nextDouble() * safeWidth,
        radius + random.nextDouble() * safeHeight,
      );

      // Set initial velocity (random direction with speed based on _currentSpeed)
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
        isBomb: false,
      ));
    }
    
    // Create bombs (only in advanced mode)
    for (int i = 0; i < bombsCount; i++) {
      // Use minimum radius for all balls (same size)
      final radius = _minBallRadius;
      
      // Calculate safe area for this ball
      final safeWidth = _containerSize!.width - (radius * 2);
      final safeHeight = _containerSize!.height - (radius * 2);

      // Set initial position (random within safe area)
      final position = Offset(
        radius + random.nextDouble() * safeWidth,
        radius + random.nextDouble() * safeHeight,
      );

      // Set initial velocity (random direction with speed based on _currentSpeed)
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
        isBomb: true, // Mark as bomb
      ));
    }

    setState(() {
      _areBallsVisible = true;
      _isWaitingForBalls = false;
      _ballsAppearedTime = DateTime.now();
    });

    // Start continuous bouncing movement
    _startBallMovement();
  }

  void _startBallMovement() {
    if (!_areBallsVisible || _containerSize == null) return;

    _ballMovementTimer?.cancel();
    _ballMovementTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!_areBallsVisible || _containerSize == null || !mounted) {
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

    // If balls are not visible yet, ignore the tap
    if (!_areBallsVisible) return;

    // Check if any ball was tapped
    bool ballCaught = false;
    bool bombTapped = false;
    for (var ball in _balls) {
      if (ball.isCaught) continue;

      // Calculate distance from tap to ball center
      final distance = (tapPosition - ball.position).distance;
      
      if (distance <= ball.radius) {
        if (ball.isBomb) {
          // Bomb tapped - penalty!
          bombTapped = true;
          ball.isCaught = true; // Hide the bomb
          _handleBombTap();
          break;
        } else {
          // Regular ball tapped - caught it!
          ball.isCaught = true;
          _ballsCaught++;
          ballCaught = true;
          break;
        }
      }
    }

    if (ballCaught && !bombTapped) {
      // Check if all regular balls are caught (bombs don't count)
      final regularBallsCount = _isAdvanced ? (_totalBalls - _bombCount) : _totalBalls;
      if (_ballsCaught >= regularBallsCount) {
        _catchAllBalls();
      } else {
        setState(() {}); // Update UI to hide caught ball
      }
    }
    // If no ball was caught, just ignore the tap (no penalty)
  }
  
  void _handleBombTap() {
    // Play penalty sound for tapping bomb
    SoundService.playPenaltySound();
    _errorDisplayTimer?.cancel();
    
    // Mark round as failed with penalty
    _roundResults.add(
      RoundResult(
        roundNumber: _currentRound,
        reactionTime: _wrongTapPenaltyMs, // 1 second penalty
        isFailed: true,
      ),
    );
    
    setState(() {
      _areBallsVisible = false;
      _errorMessage = 'PENALTY +1 SECOND';
      _ballsAppearedTime = null;
    });
    
    _ballMovementTimer?.cancel();
    
    // Show error for 1.5 seconds, then start next round
    _errorDisplayTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _errorMessage = null;
          _completedRounds++;
        });
        _startNextRound();
      }
    });
  }

  void _catchAllBalls() {
    if (!_areBallsVisible || _ballsAppearedTime == null) return;

    // Play tap sound when all balls are caught
    SoundService.playTapSound();
    
    // Calculate reaction time from when balls appeared
    final reactionTime = DateTime.now()
        .difference(_ballsAppearedTime!)
        .inMilliseconds;

    _completeRound(reactionTime, false);
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
      _ballsAppearedTime = null;
      _completedRounds++;
      if (!isFailed) {
        _reactionTimeMessage = '$reactionTime ms';
      }
    });

    _ballMovementTimer?.cancel();

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
    final savedBestTime = await GameHistoryService.getBestTime('ball_rush');
    final finalBestTime = (savedBestTime == 0 || averageTime < savedBestTime) 
        ? averageTime 
        : savedBestTime;

    // Save session
    final session = GameSession(
      gameId: 'ball_rush',
      gameName: 'Ball Rush',
      sessionNumber: await GameHistoryService.getNextSessionNumber('ball_rush'),
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
              gameName: widget.exerciseName ?? 'Ball Rush',
              gameId: 'ball_rush',
              exerciseId: 11,
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
        gameName: 'BALL RUSH',
        categoryName: widget.categoryName ?? 'Reaction',
        gameId: 'ball_rush',
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
          if (!state.isPlaying) {
            return _isAdvanced 
                ? 'Tap all 8 balls, avoid 2 bombs!'
                : 'Tap all 10 balls as they move';
          }
          if (state.isWaiting) return 'Wait for the balls...';
          if (state.isRoundActive) {
            final regularBallsCount = _isAdvanced ? (_totalBalls - _bombCount) : _totalBalls;
            return 'CATCH THEM! ($_ballsCaught/$regularBallsCount)';
          }
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
                  if (_isPlaying && _areBallsVisible) {
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
                        ..._balls.where((ball) => !ball.isCaught).map((ball) {
                          return Positioned(
                            left: ball.position.dx - ball.radius,
                            top: ball.position.dy - ball.radius,
                            child: Container(
                              width: ball.radius * 2,
                              height: ball.radius * 2,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: ball.isBomb ? Colors.red : GameSettings.ballColor,
                              ),
                              child: ball.isBomb
                                  ? Icon(
                                      Icons.warning,
                                      color: Colors.white,
                                      size: ball.radius * 0.8,
                                    )
                                  : null,
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
        middleContentBuilder: (s, context) {
          // Show difficulty selector only before game starts
          if (!s.isPlaying) {
            return _buildDifficultySelector();
          }
          return const SizedBox.shrink();
        },
      ),
      useBackdropFilter: false,
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
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isAdvanced = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: !_isAdvanced ? const Color(0xFF475569) : Colors.white,
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
                        color: !_isAdvanced ? Colors.white : const Color(0xFF475569),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: _isAdvanced ? const Color(0xFF475569) : Colors.white,
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
                        color: _isAdvanced ? Colors.white : const Color(0xFF475569),
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
}

// Helper class to represent a ball
class _Ball {
  Offset position;
  Offset velocity;
  double radius;
  bool isCaught;
  bool isBomb; // true if this is a bomb (only in advanced mode)

  _Ball({
    required this.position,
    required this.velocity,
    required this.radius,
    required this.isCaught,
    this.isBomb = false,
  });
}
