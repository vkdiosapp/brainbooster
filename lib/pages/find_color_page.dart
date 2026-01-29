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

class FindColorPage extends StatefulWidget {
  final String? categoryName;
  final String? exerciseName;

  const FindColorPage({super.key, this.categoryName, this.exerciseName});

  @override
  State<FindColorPage> createState() => _FindColorPageState();
}

class _FindColorPageState extends State<FindColorPage> {
  int _currentRound = 0;
  int _completedRounds = 0;
  int _bestSession = 240; // in milliseconds
  bool _isPlaying = false;
  bool _isWaitingForRound = false;
  bool _isRoundActive = false;
  Color? _targetColor;
  String? _targetColorName;
  List<Color> _gridColors = [];
  DateTime? _roundStartTime;
  Timer? _delayTimer;
  Timer? _errorDisplayTimer;
  Timer? _reactionTimeDisplayTimer;
  String? _errorMessage;
  String? _reactionTimeMessage;
  List<RoundResult> _roundResults = [];
  // Get penalty time from exercise data (exercise ID 4)
  late final int _wrongTapPenaltyMs = ExerciseData.getExercises()
      .firstWhere(
        (e) => e.id == 4,
        orElse: () => ExerciseData.getExercises().first,
      )
      .penaltyTime;

  // Color mapping - using exact colors specified
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

  final Map<Color, String> _colorNames = {
    Colors.red: 'RED',
    Colors.orange: 'ORANGE',
    Colors.yellow: 'YELLOW',
    Colors.green: 'GREEN',
    Colors.blue: 'BLUE',
    Colors.purple: 'PURPLE',
    Colors.pink: 'PINK',
    Colors.brown: 'BROWN',
    Colors.black: 'BLACK',
    Colors.grey: 'GRAY',
  };

  // Track which colors have been used to ensure no repeats until all are used
  List<Color> _remainingColors = [];

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
    _isWaitingForRound = false;
    _isRoundActive = false;
    _targetColor = null;
    _targetColorName = null;
    _gridColors.clear();
    _roundStartTime = null;
    _errorMessage = null;
    _reactionTimeMessage = null;
    _roundResults.clear();
    _remainingColors = List<Color>.from(_availableColors);
    _remainingColors.shuffle(math.Random());
    _delayTimer?.cancel();
    _errorDisplayTimer?.cancel();
  }

  void _startGame() {
    setState(() {
      _isPlaying = true;
      _currentRound = 0;
      _completedRounds = 0;
      _roundResults.clear();
      // Reset color pool when starting a new game
      _remainingColors = List<Color>.from(_availableColors);
      _remainingColors.shuffle(math.Random());
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
      _isWaitingForRound = true;
      _isRoundActive = false;
      _targetColor = null;
      _targetColorName = null;
      _gridColors.clear();
      _roundStartTime = null;
      _errorMessage = null;
    });

    // Small delay before showing the round
    _delayTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted && _isWaitingForRound) {
        _showRound();
      }
    });
  }

  void _showRound() {
    final random = math.Random();

    // If all colors have been used, reset the pool
    if (_remainingColors.isEmpty) {
      _remainingColors = List<Color>.from(_availableColors);
      _remainingColors.shuffle(random);
    }

    // Get next color from remaining pool (ensures no repeat until all are used)
    _targetColor = _remainingColors.removeAt(0);
    _targetColorName = _colorNames[_targetColor];

    // Generate grid with random colors (ensuring target is included)
    // Use all available colors for the grid
    final colors = List<Color>.from(_availableColors);
    colors.shuffle(random);
    _gridColors = colors.take(9).toList();

    // Ensure target color is in the grid
    if (!_gridColors.contains(_targetColor)) {
      _gridColors[random.nextInt(9)] = _targetColor!;
    }

    // Shuffle again to randomize position
    _gridColors.shuffle(random);

    setState(() {
      _isWaitingForRound = false;
      _isRoundActive = true;
      _roundStartTime = DateTime.now();
    });
  }

  void _handleColorTap(Color tappedColor) {
    if (!_isRoundActive || _roundStartTime == null) return;

    if (tappedColor == _targetColor) {
      // Play tap sound for correct tap
      SoundService.playTapSound();
      // Correct tap - calculate reaction time
      final reactionTime = DateTime.now()
          .difference(_roundStartTime!)
          .inMilliseconds;
      _completeRound(reactionTime, false);
    } else {
      // Wrong tap - penalty
      _handleWrongTap();
    }
  }

  void _handleWrongTap() {
    // Play penalty sound for wrong tap
    SoundService.playPenaltySound();
    setState(() {
      _errorMessage = 'PENALTY +1 SECOND';
      _isRoundActive = false;
    });

    // Mark round as failed with penalty
    _roundResults.add(
      RoundResult(
        roundNumber: _currentRound,
        reactionTime: _wrongTapPenaltyMs, // Penalty from exercise data
        isFailed: true,
      ),
    );

    // Show error for 1 second, then start next round
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

  Widget _buildColorCell(Color color) {
    return GestureDetector(
      onTap: () => _handleColorTap(color),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
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
      _isRoundActive = false;
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
      _isWaitingForRound = false;
      _isRoundActive = false;
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
        'find_color',
      );
      final session = GameSession(
        gameId: 'find_color',
        gameName: 'Find Color',
        timestamp: DateTime.now(),
        sessionNumber: sessionNumber,
        roundResults: List.from(_roundResults),
        averageTime: averageTime,
        bestTime: bestTime,
      );
      await GameHistoryService.saveSession(session);
    }

    // Navigate to results page
    _showResults();
  }

  void _showResults() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => ColorChangeResultsPage(
              roundResults: List.from(_roundResults),
              bestSession: _bestSession,
              gameName: widget.exerciseName ?? 'Find Color',
              gameId: 'find_color',
              exerciseId: 4,
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
        gameName: 'Find Color',
        categoryName: widget.categoryName ?? 'Visual',
        gameId: 'find_color',
        bestSession: _bestSession,
      ),
      state: GameState(
        isPlaying: _isPlaying,
        isWaiting: _isWaitingForRound,
        isRoundActive: _isRoundActive,
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
          if (!state.isPlaying) return 'Tap the correct color';
          if (state.isWaiting) return 'Wait for the color...';
          if (state.isRoundActive) return 'TAP NOW!';
          return 'Round ${state.currentRound}';
        },
        contentBuilder: (state, context) {
          if (_isRoundActive && _gridColors.isNotEmpty) {
            return Column(
              children: [
                if (_targetColorName != null)
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
                      child: Text(
                        _targetColorName!,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                          itemCount: 9,
                          itemBuilder: (context, index) {
                            return _buildColorCell(_gridColors[index]);
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          return Positioned.fill(
            child: Container(
              decoration: !state.isRoundActive && !state.isPlaying
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
            ),
          );
        },
        waitingTextBuilder: (state) => 'WAIT...',
        startButtonText: 'START',
      ),
      useBackdropFilter: false,
    );
  }
}
