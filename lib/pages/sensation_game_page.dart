import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../game_settings.dart';
import '../models/round_result.dart';
import '../models/game_session.dart';
import '../services/game_history_service.dart';
import '../services/sound_service.dart';
import '../services/vibration_service.dart';
import '../widgets/base_game_page.dart';
import '../data/exercise_data.dart';
import 'color_change_results_page.dart';

class SensationGamePage extends StatefulWidget {
  final String? categoryName;
  final String? exerciseName;

  const SensationGamePage({super.key, this.categoryName, this.exerciseName});

  @override
  State<SensationGamePage> createState() => _SensationGamePageState();
}

class _SensationGamePageState extends State<SensationGamePage> {
  int _currentRound = 0;
  int _completedRounds = 0;
  int _bestSession = 240; // in milliseconds
  bool _isPlaying = false;
  bool _isWaitingForVibration = false;
  bool _isVibrationPlayed = false;
  DateTime? _vibrationPlayedTime;
  Timer? _delayTimer;
  Timer? _errorDisplayTimer;
  Timer? _reactionTimeDisplayTimer;
  String? _errorMessage;
  String? _reactionTimeMessage;
  List<RoundResult> _roundResults = [];
  // Get penalty time from exercise data (exercise ID 9)
  late final int _wrongTapPenaltyMs = ExerciseData.getExercises()
      .firstWhere(
        (e) => e.id == 9,
        orElse: () => ExerciseData.getExercises().first,
      )
      .penaltyTime;

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
    _currentRound = 0;
    _completedRounds = 0;
    _isPlaying = false;
    _isWaitingForVibration = false;
    _isVibrationPlayed = false;
    _vibrationPlayedTime = null;
    _errorMessage = null;
    _roundResults.clear();
    _delayTimer?.cancel();
    _errorDisplayTimer?.cancel();
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
      _isWaitingForVibration = true;
      _isVibrationPlayed = false;
      _vibrationPlayedTime = null;
      _errorMessage = null;
    });

    // Random delay between 1-5 seconds
    final random = math.Random();
    final delaySeconds = 1 + random.nextDouble() * 4; // 1 to 5 seconds
    final delayMilliseconds = (delaySeconds * 1000).toInt();

    _delayTimer = Timer(Duration(milliseconds: delayMilliseconds), () {
      if (mounted && _isWaitingForVibration) {
        _playVibration();
      }
    });
  }

  Future<void> _playVibration() async {
    if (!_isWaitingForVibration) {
      return;
    }

    // Trigger single vibration
    await VibrationService.playStandardVibration();

    setState(() {
      _isVibrationPlayed = true;
      _isWaitingForVibration = false;
      _vibrationPlayedTime = DateTime.now();
    });
  }

  void _handleTap() {
    if (!_isPlaying) {
      _startGame();
      return;
    }

    if (_isWaitingForVibration && !_isVibrationPlayed) {
      // User tapped too early - penalty
      _handleEarlyTap();
      return;
    }

    if (_isVibrationPlayed && _vibrationPlayedTime != null) {
      // Play tap sound for correct tap
      SoundService.playTapSound();
      // Calculate reaction time
      final reactionTime = DateTime.now()
          .difference(_vibrationPlayedTime!)
          .inMilliseconds;
      _completeRound(reactionTime, false);
    }
  }

  void _handleEarlyTap() {
    // Play penalty sound for early tap
    SoundService.playPenaltySound();
    setState(() {
      _errorMessage = 'PENALTY +1 SECOND';
      _isWaitingForVibration = false;
      _isVibrationPlayed = false;
    });

    // Mark round as failed with penalty
    _roundResults.add(
      RoundResult(
        roundNumber: _currentRound,
        reactionTime: _wrongTapPenaltyMs, // Penalty from exercise data
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

  void _completeRound(int reactionTime, bool isFailed) {
    _roundResults.add(
      RoundResult(
        roundNumber: _currentRound,
        reactionTime: reactionTime,
        isFailed: isFailed,
      ),
    );

    setState(() {
      _isVibrationPlayed = false;
      _completedRounds++;
      if (!isFailed) {
        _reactionTimeMessage = '$reactionTime ms';
      }
    });

    // Show reaction time for 1 second, then start next round
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
      _isWaitingForVibration = false;
      _isVibrationPlayed = false;
    });

    // Calculate average reaction time
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
    } else {
      // If no successful rounds, calculate from all rounds
      if (_roundResults.isNotEmpty) {
        averageTime =
            _roundResults.map((r) => r.reactionTime).reduce((a, b) => a + b) ~/
            _roundResults.length;
      }
    }

    // Save game session
    if (_roundResults.isNotEmpty) {
      final sessionNumber = await GameHistoryService.getNextSessionNumber(
        'sensation',
      );
      final session = GameSession(
        gameId: 'sensation',
        gameName: 'Sensation',
        timestamp: DateTime.now(),
        sessionNumber: sessionNumber,
        roundResults: List.from(_roundResults),
        averageTime: averageTime,
        bestTime: bestTime,
      );
      await GameHistoryService.saveSession(session);
    }

    // Navigate to results page or show results
    _showResults();
  }

  void _showResults() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => ColorChangeResultsPage(
              roundResults: List.from(_roundResults),
              bestSession: _bestSession,
              gameName: widget.exerciseName ?? 'Sensation',
              gameId: 'sensation',
              exerciseId: 9,
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
        gameName: 'Sensation',
        categoryName: widget.categoryName ?? 'Reaction',
        gameId: 'sensation',
        bestSession: _bestSession,
      ),
      state: GameState(
        isPlaying: _isPlaying,
        isWaiting: _isWaitingForVibration,
        isRoundActive: _isVibrationPlayed,
        currentRound: _currentRound,
        completedRounds: _completedRounds,
        errorMessage: _errorMessage,
        reactionTimeMessage: _reactionTimeMessage,
      ),
      callbacks: GameCallbacks(
        onStart: _startGame,
        onTap: _handleTap,
        onReset: () {
          _resetGame();
          setState(() {});
        },
      ),
      builders: GameBuilders(
        titleBuilder: (state) {
          if (!state.isPlaying) return 'Tap when you feel the vibration';
          if (state.isWaiting) return 'Wait for the vibration...';
          if (state.isRoundActive) return 'TAP NOW!';
          return 'Round ${state.currentRound}';
        },
        middleContentBuilder: (state, context) {
          if (!state.isPlaying) {
            return Padding(
              padding: const EdgeInsets.only(top: 8, left: 24, right: 24),
              child: Text(
                'Note: System Haptic and Vibration should on from setting.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            );
          }
          return const SizedBox.shrink();
        },
        contentBuilder: (state, context) {
          return Stack(
            children: [
              if (!(state.isPlaying &&
                  (state.isWaiting || state.isRoundActive) &&
                  state.errorMessage == null &&
                  state.reactionTimeMessage == null))
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFDBEAFE).withOpacity(0.4),
                          const Color(0xFFE2E8F0).withOpacity(0.4),
                          const Color(0xFFFCE7F3).withOpacity(0.4),
                        ],
                      ),
                    ),
                  ),
                ),
              if (state.isPlaying &&
                  (state.isWaiting || state.isRoundActive) &&
                  state.errorMessage == null &&
                  state.reactionTimeMessage == null)
                const Center(
                  child: Text(
                    'TAP WHEN\nVIBRATION PLAYS',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF475569),
                      letterSpacing: 2.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          );
        },
        waitingTextBuilder: (state) => '',
        startButtonText: 'START',
      ),
      useBackdropFilter: true,
    );
  }
}
