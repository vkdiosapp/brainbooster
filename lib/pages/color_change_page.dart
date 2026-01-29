import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../game_settings.dart';
import '../models/round_result.dart';
import '../models/game_session.dart';
import '../services/game_history_service.dart';
import '../services/sound_service.dart';
import '../widgets/base_game_page.dart';
import '../data/exercise_data.dart';
import 'color_change_results_page.dart';

class ColorChangePage extends StatefulWidget {
  final String? categoryName;
  final String? exerciseName;

  const ColorChangePage({super.key, this.categoryName, this.exerciseName});

  @override
  State<ColorChangePage> createState() => _ColorChangePageState();
}

class _ColorChangePageState extends State<ColorChangePage> {
  int _currentRound = 0;
  int _completedRounds = 0;
  int _bestSession = 240; // in milliseconds
  bool _isPlaying = false;
  bool _isWaitingForColor = false;
  bool _isColorVisible = false;
  Color? _currentColor;
  DateTime? _colorAppearedTime;
  Timer? _delayTimer;
  Timer? _errorDisplayTimer;
  Timer? _reactionTimeDisplayTimer;
  String? _errorMessage;
  String? _reactionTimeMessage;
  List<RoundResult> _roundResults = [];
  // Get penalty time from exercise data (exercise ID 1)
  late final int _wrongTapPenaltyMs = ExerciseData.getExercises()
      .firstWhere(
        (e) => e.id == 1,
        orElse: () => ExerciseData.getExercises().first,
      )
      .penaltyTime;

  // Random colors for the game
  final List<Color> _gameColors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.teal,
    Colors.cyan,
    Colors.amber,
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
    _currentRound = 0;
    _completedRounds = 0;
    _isPlaying = false;
    _isWaitingForColor = false;
    _isColorVisible = false;
    _currentColor = null;
    _colorAppearedTime = null;
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
      _isWaitingForColor = true;
      _isColorVisible = false;
      _currentColor = null;
      _colorAppearedTime = null;
      _errorMessage = null;
    });

    // Random delay between 1-5 seconds
    final random = math.Random();
    final delaySeconds = 1 + random.nextDouble() * 4; // 1 to 5 seconds
    final delayMilliseconds = (delaySeconds * 1000).toInt();

    _delayTimer = Timer(Duration(milliseconds: delayMilliseconds), () {
      if (mounted && _isWaitingForColor) {
        _showColor();
      }
    });
  }

  void _showColor() {
    if (!_isWaitingForColor) return;

    final random = math.Random();
    _currentColor = _gameColors[random.nextInt(_gameColors.length)];

    setState(() {
      _isColorVisible = true;
      _isWaitingForColor = false;
      _colorAppearedTime = DateTime.now();
    });
  }

  void _handleTap() {
    if (!_isPlaying) {
      _startGame();
      return;
    }

    if (_isWaitingForColor && !_isColorVisible) {
      // User tapped too early - penalty
      _handleEarlyTap();
      return;
    }

    if (_isColorVisible && _colorAppearedTime != null) {
      // Play tap sound for successful tap
      SoundService.playTapSound();
      // Calculate reaction time
      final reactionTime = DateTime.now()
          .difference(_colorAppearedTime!)
          .inMilliseconds;
      _completeRound(reactionTime, false);
    }
  }

  void _handleEarlyTap() {
    // Play penalty sound for early tap
    SoundService.playPenaltySound();
    setState(() {
      _errorMessage = 'PENALTY +1 SECOND';
      _isWaitingForColor = false;
      _isColorVisible = false;
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
      _isColorVisible = false;
      _completedRounds++;
      _currentColor = null;
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
      _isWaitingForColor = false;
      _isColorVisible = false;
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
        'color_change',
      );
      final session = GameSession(
        gameId: 'color_change',
        gameName: 'Color Change',
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
              gameName: widget.exerciseName ?? 'Color Change',
              gameId: 'color_change',
              exerciseId: 1,
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
        gameName: 'Color Change',
        categoryName: widget.categoryName ?? 'Reaction',
        gameId: 'color_change',
        bestSession: _bestSession,
      ),
      state: GameState(
        isPlaying: _isPlaying,
        isWaiting: _isWaitingForColor,
        isRoundActive: _isColorVisible,
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
          if (!state.isPlaying) return 'Tap when the color appears';
          if (state.isWaiting) return 'Wait for the color...';
          if (state.isRoundActive) return 'TAP NOW!';
          return 'Round ${state.currentRound}';
        },
        contentBuilder: (state, context) {
          return Stack(
            children: [
              if (!_isColorVisible)
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
              if (_isColorVisible && _currentColor != null)
                Positioned.fill(child: Container(color: _currentColor)),
            ],
          );
        },
        waitingTextBuilder: (state) => 'WAIT...',
        startButtonText: 'START',
      ),
      useBackdropFilter: true,
    );
  }
}
