import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../game_settings.dart';
import '../models/round_result.dart';
import '../models/game_session.dart';
import '../services/game_history_service.dart';
import '../widgets/base_game_page.dart';
import 'color_change_results_page.dart';

class CatchBallPage extends StatefulWidget {
  final String? categoryName;

  const CatchBallPage({super.key, this.categoryName});

  @override
  State<CatchBallPage> createState() => _CatchBallPageState();
}

class _CatchBallPageState extends State<CatchBallPage>
    with SingleTickerProviderStateMixin {
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

  // Ball position and animation
  Offset _ballPosition = Offset.zero;
  Offset _targetPosition = Offset.zero;
  late AnimationController _animationController;
  late Animation<Offset> _ballAnimation;
  double _currentSpeed = 1.8; // Base speed multiplier (moderate speed)
  Size? _containerSize;

  // Ball properties
  static const double _ballRadius = 30.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900), // Base animation duration (moderate)
    );

    _ballAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _resetGame();
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _errorDisplayTimer?.cancel();
    _reactionTimeDisplayTimer?.cancel();
    _animationController.dispose();
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
    _targetPosition = Offset.zero;
    _currentSpeed = 1.8; // Reset to moderate speed
    _errorMessage = null;
    _reactionTimeMessage = null;
    _roundResults.clear();
    _delayTimer?.cancel();
    _errorDisplayTimer?.cancel();
    _reactionTimeDisplayTimer?.cancel();
    _animationController.stop();
    _animationController.reset();
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
    
    // Calculate safe area for ball (accounting for ball radius)
    final safeWidth = _containerSize!.width - (_ballRadius * 2);
    final safeHeight = _containerSize!.height - (_ballRadius * 2);

    // Set initial position (random within safe area)
    _ballPosition = Offset(
      _ballRadius + random.nextDouble() * safeWidth,
      _ballRadius + random.nextDouble() * safeHeight,
    );

    // Set target position (random within safe area)
    _targetPosition = Offset(
      _ballRadius + random.nextDouble() * safeWidth,
      _ballRadius + random.nextDouble() * safeHeight,
    );

    setState(() {
      _isBallVisible = true;
      _isWaitingForBall = false;
      _ballAppearedTime = DateTime.now();
    });

    // Start continuous movement
    _moveBallToTarget();
  }

  void _moveBallToTarget() {
    if (!_isBallVisible || _containerSize == null) return;

    // Calculate animation duration based on current speed
    // Faster speed = shorter duration
    final baseDuration = 900.0; // Moderate base duration
    final duration = (baseDuration / _currentSpeed).clamp(500.0, 1200.0); // Moderate range

    _ballAnimation = Tween<Offset>(
      begin: _ballPosition,
      end: _targetPosition,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.duration = Duration(milliseconds: duration.toInt());
    _animationController.reset();
    _animationController.forward().then((_) {
      if (_isBallVisible && mounted) {
        // Ball reached target, move to next random position
        _selectNewTarget();
        _moveBallToTarget();
      }
    });

    // Update position during animation
    _ballAnimation.addListener(() {
      if (mounted) {
        setState(() {
          _ballPosition = _ballAnimation.value;
        });
      }
    });
  }

  void _selectNewTarget() {
    if (_containerSize == null) return;

    final random = math.Random();
    final safeWidth = _containerSize!.width - (_ballRadius * 2);
    final safeHeight = _containerSize!.height - (_ballRadius * 2);

    _targetPosition = Offset(
      _ballRadius + random.nextDouble() * safeWidth,
      _ballRadius + random.nextDouble() * safeHeight,
    );

    // Gradually increase speed for difficulty
    _currentSpeed = (_currentSpeed + 0.05).clamp(1.8, 2.5); // Moderate speed range
  }

  void _handleTap(Offset tapPosition) {
    if (!_isPlaying) return;

    // If ball is not visible yet, ignore the tap (no penalty for early taps)
    if (!_isBallVisible) return;

    // Check if tap is within ball radius
    final distance = (tapPosition - _ballPosition).distance;
    if (distance <= _ballRadius) {
      // Ball caught!
      _catchBall();
    } else {
      // Missed - penalty (only when ball is visible and tap is outside)
      _handleMiss();
    }
  }

  void _handleMiss() {
    setState(() {
      _errorMessage = 'PENALTY +1 SECOND';
      _isBallVisible = false;
      _ballAppearedTime = null;
    });

    _animationController.stop();

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

    _animationController.stop();

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

    _animationController.stop();

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
                          left: _ballPosition.dx - _ballRadius,
                          top: _ballPosition.dy - _ballRadius,
                          child: Container(
                            width: _ballRadius * 2,
                            height: _ballRadius * 2,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF6366F1),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withOpacity(0.5),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
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
