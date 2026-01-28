import 'dart:async';
import 'package:flutter/material.dart';

import '../data/exercise_data.dart';
import '../game_settings.dart';
import '../models/game_session.dart';
import '../models/round_result.dart';
import '../services/game_history_service.dart';
import '../widgets/base_game_page.dart';
import 'color_change_results_page.dart';

class ClickLimitPage extends StatefulWidget {
  final String? categoryName;
  final String? exerciseName;

  const ClickLimitPage({super.key, this.categoryName, this.exerciseName});

  @override
  State<ClickLimitPage> createState() => _ClickLimitPageState();
}

class _ClickLimitPageState extends State<ClickLimitPage> {
  // Get minimum click count from exercise data (exercise ID 22)
  late final int _minClickCount = ExerciseData.getExercises()
      .firstWhere(
        (e) => e.id == 22,
        orElse: () => ExerciseData.getExercises().first,
      )
      .timeRequired;

  static const int _roundDurationSeconds = 10;

  int _currentRound = 0;
  int _completedRounds = 0;
  int _bestSession = 0; // highest average taps

  bool _isPlaying = false;
  bool _isWaitingForRound = false;
  bool _isRoundActive = false; // User can tap

  int _currentClickCount = 0;
  double _remainingSeconds = _roundDurationSeconds.toDouble();

  DateTime? _roundStartTime;
  Timer? _roundDelayTimer;
  Timer? _roundTimer;
  Timer? _overlayTimer;

  String? _errorMessage;
  String? _reactionTimeMessage;

  final List<RoundResult> _roundResults = [];

  @override
  void initState() {
    super.initState();
    _resetGame();
  }

  @override
  void dispose() {
    _roundDelayTimer?.cancel();
    _roundTimer?.cancel();
    _overlayTimer?.cancel();
    super.dispose();
  }

  void _resetGame() {
    _roundDelayTimer?.cancel();
    _roundTimer?.cancel();
    _overlayTimer?.cancel();

    _currentRound = 0;
    _completedRounds = 0;
    _isPlaying = false;
    _isWaitingForRound = false;
    _isRoundActive = false;
    _currentClickCount = 0;
    _remainingSeconds = _roundDurationSeconds.toDouble();
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
    _roundTimer?.cancel();
    _overlayTimer?.cancel();

    setState(() {
      _currentRound++;
      _isWaitingForRound = true;
      _isRoundActive = false;
      _currentClickCount = 0;
      _remainingSeconds = _roundDurationSeconds.toDouble();
      _errorMessage = null;
      _reactionTimeMessage = null;
      _roundStartTime = null;
    });

    _roundDelayTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _beginRound();
    });
  }

  void _beginRound() {
    _roundTimer?.cancel();

    setState(() {
      _isWaitingForRound = false;
      _isRoundActive = true;
      _currentClickCount = 0;
      _remainingSeconds = _roundDurationSeconds.toDouble();
      _roundStartTime = DateTime.now();
    });

    // High‑resolution timer for smooth countdown
    const tick = Duration(milliseconds: 100);
    final totalDuration = Duration(seconds: _roundDurationSeconds);

    _roundTimer = Timer.periodic(tick, (timer) {
      if (!mounted || !_isRoundActive || _roundStartTime == null) {
        timer.cancel();
        return;
      }

      final elapsed = DateTime.now().difference(_roundStartTime!);
      final remaining = totalDuration - elapsed;

      if (remaining <= Duration.zero) {
        setState(() {
          _remainingSeconds = 0;
        });
        timer.cancel();
        _completeRound();
      } else {
        setState(() {
          _remainingSeconds = remaining.inMilliseconds / 1000.0;
        });
      }
    });
  }

  void _handleTap() {
    if (!_isRoundActive) return;
    setState(() {
      _currentClickCount++;
    });
  }

  void _completeRound() {
    _overlayTimer?.cancel();
    _roundTimer?.cancel();

    final taps = _currentClickCount;
    final bool isFailed = taps < _minClickCount;

    _roundResults.add(
      RoundResult(
        roundNumber: _currentRound,
        reactionTime: taps, // use taps as the score
        isFailed: isFailed,
      ),
    );

    setState(() {
      _isRoundActive = false;
      _completedRounds++;
      _reactionTimeMessage = '$taps taps';
      _errorMessage = isFailed ? null : null;
    });

    _overlayTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() {
        _reactionTimeMessage = null;
        _errorMessage = null;
      });
      _startNextRound();
    });
  }

  Future<void> _endGame() async {
    _roundDelayTimer?.cancel();
    _roundTimer?.cancel();
    _overlayTimer?.cancel();

    setState(() {
      _isPlaying = false;
      _isWaitingForRound = false;
      _isRoundActive = false;
    });

    // Calculate average / best taps (higher is better)
    final successfulRounds = _roundResults.where((r) => !r.isFailed).toList();
    int averageTaps = 0;
    int bestTaps = 0;

    if (successfulRounds.isNotEmpty) {
      averageTaps =
          successfulRounds.map((r) => r.reactionTime).reduce((a, b) => a + b) ~/
          successfulRounds.length;
      bestTaps = successfulRounds
          .map((r) => r.reactionTime)
          .reduce((a, b) => a > b ? a : b);
      if (bestTaps > _bestSession) {
        _bestSession = bestTaps;
      }
    } else if (_roundResults.isNotEmpty) {
      averageTaps =
          _roundResults.map((r) => r.reactionTime).reduce((a, b) => a + b) ~/
          _roundResults.length;
    }

    if (_roundResults.isNotEmpty) {
      final sessionNumber = await GameHistoryService.getNextSessionNumber(
        'click_limit',
      );
      final session = GameSession(
        gameId: 'click_limit',
        gameName: 'Click Limit',
        timestamp: DateTime.now(),
        sessionNumber: sessionNumber,
        roundResults: List.from(_roundResults),
        averageTime: averageTaps,
        bestTime: bestTaps,
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
              gameName: widget.exerciseName ?? 'Click Limit',
              gameId: 'click_limit',
              exerciseId: 22,
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
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
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
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CLICKS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.0,
                              color: Color(0xFFCBD5F5),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_currentClickCount',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'TIMER',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.0,
                              color: Color(0xFFCBD5F5),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_remainingSeconds.ceil()} s',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _handleTap,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'TAP AS FAST AS YOU CAN',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
        gameName: 'CLICK LIMIT',
        categoryName: widget.categoryName ?? 'Reaction',
        gameId: 'click_limit',
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
            return 'Reach at least $_minClickCount taps in 10 seconds';
          }
          if (s.isWaiting) {
            return 'GET READY...';
          }
          if (s.isRoundActive) {
            return 'TAP INSIDE THE AREA!';
          }
          return 'Round ${s.currentRound}';
        },
        contentBuilder: (s, context) {
          if (s.isWaiting || s.isRoundActive) {
            return Positioned.fill(child: _buildGameContainer());
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
