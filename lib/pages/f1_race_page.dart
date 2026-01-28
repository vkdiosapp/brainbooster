import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/exercise_data.dart';
import '../game_settings.dart';
import '../models/game_session.dart';
import '../models/round_result.dart';
import '../services/game_history_service.dart';
import '../services/sound_service.dart';
import '../widgets/base_game_page.dart';
import 'color_change_results_page.dart';

enum _TrafficLightColor { red, yellow, green }

class F1RacePage extends StatefulWidget {
  final String? categoryName;
  final String? exerciseName;

  const F1RacePage({super.key, this.categoryName, this.exerciseName});

  @override
  State<F1RacePage> createState() => _F1RacePageState();
}

class _F1RacePageState extends State<F1RacePage> {
  // Get penalty time from exercise data (exercise ID 20)
  late final int _wrongTapPenaltyMs = ExerciseData.getExercises()
      .firstWhere(
        (e) => e.id == 20,
        orElse: () => ExerciseData.getExercises().first,
      )
      .penaltyTime;

  int _currentRound = 0;
  int _completedRounds = 0;
  int _bestSession = 240; // ms

  bool _isPlaying = false;
  bool _isWaitingForRound = false;
  bool _isRoundActive = false; // User can tap buttons

  _TrafficLightColor _currentLight = _TrafficLightColor.red;
  bool _isCyclingLights = false;

  DateTime? _roundStartTime;
  Timer? _roundDelayTimer;
  Timer? _lightCycleTimer;
  Timer? _lightStopTimer;
  Timer? _overlayTimer;

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
    _lightCycleTimer?.cancel();
    _lightStopTimer?.cancel();
    _overlayTimer?.cancel();
    super.dispose();
  }

  void _resetGame() {
    _roundDelayTimer?.cancel();
    _lightCycleTimer?.cancel();
    _lightStopTimer?.cancel();
    _overlayTimer?.cancel();

    _currentRound = 0;
    _completedRounds = 0;
    _isPlaying = false;
    _isWaitingForRound = false;
    _isRoundActive = false;
    _isCyclingLights = false;
    _currentLight = _TrafficLightColor.red;
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
    _lightCycleTimer?.cancel();
    _lightStopTimer?.cancel();
    _overlayTimer?.cancel();

    setState(() {
      _currentRound++;
      _isWaitingForRound = true;
      _isRoundActive = false;
      _isCyclingLights = false;
      _currentLight = _TrafficLightColor.red;
      _errorMessage = null;
      _reactionTimeMessage = null;
      _roundStartTime = null;
    });

    // Short delay before lights start cycling
    _roundDelayTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _startLightCycle();
    });
  }

  void _startLightCycle() {
    _lightCycleTimer?.cancel();
    _lightStopTimer?.cancel();

    setState(() {
      _isWaitingForRound = false;
      _isCyclingLights = true;
      _isRoundActive = false;
    });

    // Cycle through the three lights continuously
    _lightCycleTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      setState(() {
        _currentLight = _nextLight(_currentLight);
      });
    });

    // Random time between 3 and 5 seconds before stopping on a random light
    final randomMs = 3000 + _rand.nextInt(2000);
    _lightStopTimer = Timer(Duration(milliseconds: randomMs), () {
      if (!mounted) return;
      _stopOnRandomLight();
    });
  }

  _TrafficLightColor _nextLight(_TrafficLightColor current) {
    switch (current) {
      case _TrafficLightColor.red:
        return _TrafficLightColor.yellow;
      case _TrafficLightColor.yellow:
        return _TrafficLightColor.green;
      case _TrafficLightColor.green:
        return _TrafficLightColor.red;
    }
  }

  void _stopOnRandomLight() {
    _lightCycleTimer?.cancel();

    // Pick a random final light (red, yellow, or green)
    final values = _TrafficLightColor.values;
    final finalLight = values[_rand.nextInt(values.length)];

    setState(() {
      _isCyclingLights = false;
      _currentLight = finalLight;
      _isRoundActive = true;
      _roundStartTime = DateTime.now(); // Start timing when light stops
    });
  }

  void _handleAcceleratorTap() {
    _handleUserInput(isAccelerator: true);
  }

  void _handleBrakeTap() {
    _handleUserInput(isAccelerator: false);
  }

  void _handleUserInput({required bool isAccelerator}) {
    if (!_isRoundActive || _roundStartTime == null) {
      return;
    }

    // Expected action:
    // - If light is GREEN -> accelerator
    // - If light is RED or YELLOW -> brake
    final bool shouldAccelerate = _currentLight == _TrafficLightColor.green;
    final bool isCorrect =
        (shouldAccelerate && isAccelerator) ||
        (!shouldAccelerate && !isAccelerator);

    if (isCorrect) {
      SoundService.playTapSound();
      _completeRound();
    } else {
      SoundService.playPenaltySound();
      _handleWrongTap();
    }
  }

  void _handleWrongTap() {
    _overlayTimer?.cancel();

    // End round immediately with penalty
    final roundTime = _wrongTapPenaltyMs;

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
      _errorMessage = 'PENALTY +${_wrongTapPenaltyMs ~/ 1000} SECOND';
    });

    _overlayTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _errorMessage = null);
      _startNextRound();
    });
  }

  void _completeRound() {
    _overlayTimer?.cancel();
    _lightCycleTimer?.cancel();
    _lightStopTimer?.cancel();

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
    _lightCycleTimer?.cancel();
    _lightStopTimer?.cancel();
    _overlayTimer?.cancel();

    setState(() {
      _isPlaying = false;
      _isWaitingForRound = false;
      _isRoundActive = false;
      _isCyclingLights = false;
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
        'f1_race',
      );
      final session = GameSession(
        gameId: 'f1_race',
        gameName: 'F1 Race',
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
              gameName: widget.exerciseName ?? 'F1 Race',
            ),
          ),
        )
        .then((_) {
          if (!mounted) return;
          _resetGame();
          setState(() {});
        });
  }

  Widget _buildGameContainer() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final containerWidth = constraints.maxWidth;
        final buttonHeight = 64.0;
        // Extra space between lights and pedals
        final verticalSpacing = 40.0;

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: containerWidth * 0.4,
                child: _buildTrafficLight(),
              ),
              SizedBox(height: verticalSpacing),
              SizedBox(
                width: containerWidth * 0.8,
                child: _buildControlsRow(buttonHeight),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrafficLight() {
    Color _lightColorFor(_TrafficLightColor color) {
      final isActive = _currentLight == color;
      switch (color) {
        case _TrafficLightColor.red:
          return isActive ? Colors.red : Colors.red.withOpacity(0.25);
        case _TrafficLightColor.yellow:
          return isActive
              ? Colors.yellow.shade600
              : Colors.yellow.withOpacity(0.25);
        case _TrafficLightColor.green:
          return isActive ? Colors.green : Colors.green.withOpacity(0.25);
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF020617),
        // Slightly smaller radius for a less pill-like shape
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 2),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _buildLightCircle(_lightColorFor(_TrafficLightColor.red)),
          const SizedBox(height: 14),
          _buildLightCircle(_lightColorFor(_TrafficLightColor.yellow)),
          const SizedBox(height: 14),
          _buildLightCircle(_lightColorFor(_TrafficLightColor.green)),
        ],
      ),
    );
  }

  Widget _buildLightCircle(Color color) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.55),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildControlsRow(double buttonHeight) {
    final bool canTap = _isRoundActive;

    return Row(
      children: [
        Expanded(
          child: Transform.rotate(
            angle: -0.08, // slight tilt like a brake pedal
            child: _buildControlButton(
              label: 'BRAKE',
              color: const Color(0xFF0F172A),
              accentColor: Colors.redAccent,
              icon: Icons.stop_circle_outlined,
              height: buttonHeight,
              enabled: canTap,
              onTap: _handleBrakeTap,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Transform.rotate(
            angle: 0.08, // slight tilt like an accelerator pedal
            child: _buildControlButton(
              label: 'ACCELERATOR',
              color: const Color(0xFF0F172A),
              accentColor: Colors.greenAccent.shade400,
              icon: Icons.speed,
              height: buttonHeight,
              enabled: canTap,
              onTap: _handleAcceleratorTap,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required String label,
    required Color color,
    required Color accentColor,
    required IconData icon,
    required double height,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: enabled ? 1.0 : 0.6,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            // Pedal-like shape: flatter top, more rounded bottom
            color: const Color(0xFF0F172A),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Thin colored strip at top, like pedal edge
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Spacer(),
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = GameState(
      isPlaying: _isPlaying,
      isWaiting: _isWaitingForRound || _isCyclingLights,
      isRoundActive: _isRoundActive,
      currentRound: _currentRound,
      completedRounds: _completedRounds,
      errorMessage: _errorMessage,
      reactionTimeMessage: _reactionTimeMessage,
    );

    return BaseGamePage(
      config: GamePageConfig(
        gameName: 'F1 RACE',
        categoryName: widget.categoryName ?? 'Reaction',
        gameId: 'f1_race',
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
          if (!s.isPlaying) {
            return 'React to the lights';
          }
          if (s.isWaiting) {
            if (_isCyclingLights) {
              return 'GET READY...';
            }
            return 'Wait...';
          }
          if (s.isRoundActive) {
            return 'TAP NOW!';
            // if (_currentLight == _TrafficLightColor.green) {
            //   return 'GO! TAP ACCELERATOR!';
            // }
            // return 'STOP! TAP BRAKE!';
          }
          return 'Round ${s.currentRound}';
        },
        contentBuilder: (s, context) {
          // Show game container when lights are cycling or when round is active
          if (_isCyclingLights || s.isRoundActive) {
            return Positioned.fill(child: _buildGameContainer());
          }
          // idle background or wait state
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
          if (_isCyclingLights) return '';
          return 'WAIT...';
        },
        startButtonText: 'START',
      ),
      useBackdropFilter: true,
    );
  }
}
