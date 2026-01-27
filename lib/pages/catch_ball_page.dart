import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../game_settings.dart';
import '../models/round_result.dart';
import '../models/game_session.dart';
import '../services/game_history_service.dart';
import '../services/sound_service.dart';
import '../widgets/base_game_page.dart';
import 'color_change_results_page.dart';

class CatchBallPage extends StatefulWidget {
  final String? categoryName;
  final String? exerciseName;

  const CatchBallPage({super.key, this.categoryName, this.exerciseName});

  @override
  State<CatchBallPage> createState() => _CatchBallPageState();
}

class _CatchBallPageState extends State<CatchBallPage> {
  int _currentRound = 0;
  int _completedRounds = 0;
  int _bestSession = 300; // in milliseconds
  bool _isPlaying = false;
  bool _isWaitingForBall = false;
  bool _isBallVisible = false;
  DateTime? _ballAppearedTime;
  Timer? _delayTimer;
  Timer? _errorDisplayTimer;
  Timer? _reactionTimeDisplayTimer;
  String? _errorMessage;
  String? _reactionTimeMessage;
  List<RoundResult> _roundResults = [];

  // Ball position and velocity
  Offset _ballPosition = Offset.zero;
  Offset _ballVelocity = Offset.zero; // Velocity in pixels per frame
  Timer? _ballMovementTimer;
  double _currentSpeed = 1.8; // Base speed multiplier (moderate speed)
  Size? _containerSize;

  // Ball properties
  static const double _ballRadius = 80.0; // Blue ball radius (outer circle)
  static const double _blackBallRadius = 40.0; // Black ball radius (inner circle - target)

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
    _ballMovementTimer?.cancel();
    super.dispose();
  }

  void _resetGame() {
    _currentRound = 0;
    _completedRounds = 0;
    _isPlaying = false;
    _isWaitingForBall = false;
    _isBallVisible = false;
    _ballAppearedTime = null;
    _ballPosition = Offset.zero;
    _ballVelocity = Offset.zero;
    _currentSpeed = 1.8; // Reset to moderate speed
    _errorMessage = null;
    _reactionTimeMessage = null;
    _roundResults.clear();
    _delayTimer?.cancel();
    _errorDisplayTimer?.cancel();
    _reactionTimeDisplayTimer?.cancel();
    _ballMovementTimer?.cancel();
  }

  void _startGame() {
    setState(() {
      _isPlaying = true;
      _currentRound = 0;
      _completedRounds = 0;
      _roundResults.clear();
      _currentSpeed = 1.8; // Reset to moderate speed
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
      _isWaitingForBall = true;
      _isBallVisible = false;
      _errorMessage = null;
      _reactionTimeMessage = null;
    });

    // Random delay before showing ball (0.5-2 seconds)
    final random = math.Random();
    final delaySeconds = 0.5 + random.nextDouble() * 1.5;
    final delayMilliseconds = (delaySeconds * 1000).toInt();

    _delayTimer = Timer(Duration(milliseconds: delayMilliseconds), () {
      if (mounted && _isWaitingForBall) {
        _showBall();
      }
    });
  }

  void _showBall() {
    if (!_isWaitingForBall || _containerSize == null) return;

    final random = math.Random();
    
    // Calculate safe area for ball (using black ball radius so it can touch edges)
    final safeWidth = _containerSize!.width - (_blackBallRadius * 2);
    final safeHeight = _containerSize!.height - (_blackBallRadius * 2);

    // Set initial position (random within safe area)
    _ballPosition = Offset(
      _blackBallRadius + random.nextDouble() * safeWidth,
      _blackBallRadius + random.nextDouble() * safeHeight,
    );

    // Set initial velocity (random direction with speed based on _currentSpeed)
    final baseSpeed = 3.0 * _currentSpeed; // Base speed in pixels per frame
    final angle = random.nextDouble() * 2 * math.pi; // Random angle
    _ballVelocity = Offset(
      math.cos(angle) * baseSpeed,
      math.sin(angle) * baseSpeed,
    );

    setState(() {
      _isBallVisible = true;
      _isWaitingForBall = false;
      _ballAppearedTime = DateTime.now();
    });

    // Start continuous bouncing movement
    _startBallMovement();
  }

  void _startBallMovement() {
    if (!_isBallVisible || _containerSize == null) return;

    _ballMovementTimer?.cancel();
    _ballMovementTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!_isBallVisible || _containerSize == null || !mounted) {
        timer.cancel();
        return;
      }

      // Update ball position
      _ballPosition = Offset(
        _ballPosition.dx + _ballVelocity.dx,
        _ballPosition.dy + _ballVelocity.dy,
      );

      // Check for collisions with container edges and bounce (using black ball radius)
      final minX = _blackBallRadius;
      final maxX = _containerSize!.width - _blackBallRadius;
      final minY = _blackBallRadius;
      final maxY = _containerSize!.height - _blackBallRadius;

      // Bounce off left or right edge
      if (_ballPosition.dx <= minX || _ballPosition.dx >= maxX) {
        _ballVelocity = Offset(-_ballVelocity.dx, _ballVelocity.dy);
        // Clamp position to prevent going outside
        _ballPosition = Offset(
          _ballPosition.dx.clamp(minX, maxX),
          _ballPosition.dy,
        );
      }

      // Bounce off top or bottom edge
      if (_ballPosition.dy <= minY || _ballPosition.dy >= maxY) {
        _ballVelocity = Offset(_ballVelocity.dx, -_ballVelocity.dy);
        // Clamp position to prevent going outside
        _ballPosition = Offset(
          _ballPosition.dx,
          _ballPosition.dy.clamp(minY, maxY),
        );
      }

      // Update UI
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _handleTap(Offset tapPosition) {
    if (!_isPlaying) return;

    // If ball is not visible yet, ignore the tap (no penalty for early taps)
    if (!_isBallVisible) return;

    // Calculate distance from tap to ball center
    final distance = (tapPosition - _ballPosition).distance;
    
    if (distance <= _blackBallRadius) {
      // Black ball tapped - caught it!
      _catchBall();
    } else if (distance <= _ballRadius) {
      // Blue ball area tapped (but not black ball) - do nothing
      return;
    } else {
      // Missed - tapped outside the blue ball - penalty
      _handleMiss();
    }
  }

  void _handleMiss() {
    // Play penalty sound for missed tap
    SoundService.playPenaltySound();
    setState(() {
      _errorMessage = 'PENALTY +1 SECOND';
      _isBallVisible = false;
      _ballAppearedTime = null;
    });

    _ballMovementTimer?.cancel();

    // Mark round as failed with penalty
    _roundResults.add(
      RoundResult(
        roundNumber: _currentRound,
        reactionTime: 1000, // 1 second penalty
        isFailed: true,
      ),
    );

    _errorDisplayTimer?.cancel();
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

  void _catchBall() {
    if (!_isBallVisible || _ballAppearedTime == null) return;

    // Play tap sound for successful catch
    SoundService.playTapSound();
    
    // Calculate reaction time from when ball appeared
    final reactionTime = DateTime.now()
        .difference(_ballAppearedTime!)
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
      _isBallVisible = false;
      _ballAppearedTime = null;
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
      _isBallVisible = false;
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
    final savedBestTime = await GameHistoryService.getBestTime('catch_ball');
    final finalBestTime = (savedBestTime == 0 || averageTime < savedBestTime) 
        ? averageTime 
        : savedBestTime;

    // Save session
    final session = GameSession(
      gameId: 'catch_ball',
      gameName: 'Catch The Ball',
      sessionNumber: await GameHistoryService.getNextSessionNumber('catch_ball'),
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
              gameName: widget.exerciseName ?? 'Catch The Ball',
              gameId: 'catch_ball',
              exerciseId: 3,
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
        gameName: 'CATCH THE BALL',
        categoryName: widget.categoryName ?? 'Reaction',
        gameId: 'catch_ball',
        bestSession: _bestSession,
      ),
      state: GameState(
        isPlaying: _isPlaying,
        isWaiting: _isWaitingForBall,
        isRoundActive: _isBallVisible,
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
          if (!state.isPlaying) return 'Tap the ball as it moves';
          if (state.isWaiting) return 'Wait for the ball...';
          if (state.isRoundActive) return 'CATCH IT!';
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
                  if (_isPlaying && _isBallVisible) {
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
                      if (state.isRoundActive && _isBallVisible)
                        Positioned(
                          left: _ballPosition.dx - _blackBallRadius,
                          top: _ballPosition.dy - _blackBallRadius,
                          child: Container(
                            width: _blackBallRadius * 2,
                            height: _blackBallRadius * 2,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.transparent, // Blue ball is transparent (used only for radius)
                            ),
                            child: Center(
                              child: Container(
                                width: _blackBallRadius * 2, // Black ball diameter
                                height: _blackBallRadius * 2,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ),
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
