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
import '../data/exercise_data.dart';
import 'color_change_results_page.dart';

class ColorFramesCountPage extends StatefulWidget {
  final String? categoryName;
  final String? exerciseName;

  const ColorFramesCountPage({super.key, this.categoryName, this.exerciseName});

  @override
  State<ColorFramesCountPage> createState() => _ColorFramesCountPageState();
}

class _ColorFramesCountPageState extends State<ColorFramesCountPage> {
  // Normal mode constants
  static const int _normalGridSize = 3; // 3x3 grid
  static const int _normalTotalBoxes = 9; // 3x3 = 9 boxes

  // Advanced mode constants
  static const int _advancedGridSize = 4; // 4x4 grid
  static const int _advancedTotalBoxes = 16; // 4x4 = 16 boxes

  static const int _displayDurationMs = 2000; // Show colors for 2 seconds

  bool _isAdvanced = false; // false = Normal, true = Advanced

  // Getters for dynamic values based on difficulty
  int get _gridSize => _isAdvanced ? _advancedGridSize : _normalGridSize;
  int get _totalBoxes => _isAdvanced ? _advancedTotalBoxes : _normalTotalBoxes;

  // Get penalty time from exercise data (exercise ID 26)
  late final int _wrongTapPenaltyMs = ExerciseData.getExercises()
      .firstWhere(
        (e) => e.id == 26,
        orElse: () => ExerciseData.getExercises().first,
      )
      .penaltyTime;

  int _currentRound = 0;
  int _completedRounds = 0;
  int _bestSession = 0; // ms - will be loaded from GameHistoryService

  bool _isPlaying = false;
  bool _isWaitingForRound = false;
  bool _isRoundActive = false;
  bool _isShowingColors = false; // Whether colors are currently visible
  bool _optionsEnabled = false; // Whether options are enabled for selection

  Color? _targetColor;
  String? _targetColorName;
  int _targetColorCount = 0; // How many boxes have the target color
  Map<int, Color> _gridColors = {}; // Map of index -> color for each grid cell
  List<int> _options = []; // 4 options for count selection
  int? _correctOption; // The correct count option

  DateTime? _roundStartTime;
  Timer? _roundDelayTimer;
  Timer? _hideColorsTimer;
  Timer? _overlayTimer;

  String? _errorMessage;
  String? _reactionTimeMessage;

  final List<RoundResult> _roundResults = [];

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

  List<Color> _remainingColors = [];
  final math.Random _rand = math.Random();

  @override
  void initState() {
    super.initState();
    _resetGame();
    _loadBestSession();
  }

  Future<void> _loadBestSession() async {
    final bestTime = await GameHistoryService.getBestTime('color_frames_count');
    if (mounted) {
      setState(() {
        _bestSession = bestTime;
      });
    }
  }

  @override
  void dispose() {
    _roundDelayTimer?.cancel();
    _hideColorsTimer?.cancel();
    _overlayTimer?.cancel();
    super.dispose();
  }

  void _resetGame() {
    _roundDelayTimer?.cancel();
    _hideColorsTimer?.cancel();
    _overlayTimer?.cancel();

    _currentRound = 0;
    _completedRounds = 0;
    _isPlaying = false;
    _isWaitingForRound = false;
    _isRoundActive = false;
    _isShowingColors = false;
    _optionsEnabled = false;
    _targetColor = null;
    _targetColorName = null;
    _targetColorCount = 0;
    _gridColors.clear();
    _options.clear();
    _correctOption = null;
    _roundStartTime = null;
    _errorMessage = null;
    _reactionTimeMessage = null;
    _roundResults.clear();
    // Keep _isAdvanced state when resetting (don't reset to false)

    _remainingColors = List<Color>.from(_availableColors)..shuffle(_rand);
  }

  void _startGame() {
    setState(() {
      _isPlaying = true;
      _currentRound = 0;
      _completedRounds = 0;
      _roundResults.clear();
      _remainingColors = List<Color>.from(_availableColors)..shuffle(_rand);
    });
    _startNextRound();
  }

  void _startNextRound() {
    if (_currentRound >= GameSettings.numberOfRepetitions) {
      _endGame();
      return;
    }

    _roundDelayTimer?.cancel();
    _hideColorsTimer?.cancel();
    _overlayTimer?.cancel();

    setState(() {
      _currentRound++;
      _isWaitingForRound = true;
      _isRoundActive = false;
      _isShowingColors = false;
      _optionsEnabled = false;
      _targetColor = null;
      _targetColorName = null;
      _targetColorCount = 0;
      _gridColors.clear();
      _options.clear();
      _correctOption = null;
      _roundStartTime = null;
      _errorMessage = null;
      _reactionTimeMessage = null;
    });

    _roundDelayTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _showRound();
    });
  }

  void _showRound() {
    // Pick target color (no repeat until pool exhausted)
    if (_remainingColors.isEmpty) {
      _remainingColors = List<Color>.from(_availableColors)..shuffle(_rand);
    }
    _targetColor = _remainingColors.removeAt(0);
    _targetColorName = _colorNames[_targetColor];

    // Generate grid colors
    // Random count of target color boxes based on difficulty
    if (_isAdvanced) {
      // Advanced: 6-8 boxes out of 16
      _targetColorCount = 6 + _rand.nextInt(3); // 6..8
    } else {
      // Normal: 3-5 boxes out of 9
      _targetColorCount = 3 + _rand.nextInt(3); // 3..5
    }

    // Get 3 other different colors for distraction
    final distractionColors =
        _availableColors.where((c) => c != _targetColor).toList()
          ..shuffle(_rand);
    final distractor1 = distractionColors[0];
    final distractor2 = distractionColors[1];
    final distractor3 = distractionColors[2];

    // Create list of all positions based on grid size
    final allPositions = List.generate(_totalBoxes, (i) => i);
    allPositions.shuffle(_rand);

    // Assign target color to first _targetColorCount positions
    final targetPositions = allPositions.take(_targetColorCount).toList();
    final remainingPositions = allPositions.skip(_targetColorCount).toList();

    // Fill grid colors
    _gridColors.clear();
    for (var i = 0; i < _targetColorCount; i++) {
      _gridColors[targetPositions[i]] = _targetColor!;
    }

    // Distribute remaining positions among 3 distraction colors
    final distractorCounts = [
      remainingPositions.length ~/ 3,
      remainingPositions.length ~/ 3,
      remainingPositions.length - 2 * (remainingPositions.length ~/ 3),
    ];
    int posIndex = 0;
    for (var i = 0; i < distractorCounts[0]; i++) {
      _gridColors[remainingPositions[posIndex++]] = distractor1;
    }
    for (var i = 0; i < distractorCounts[1]; i++) {
      _gridColors[remainingPositions[posIndex++]] = distractor2;
    }
    for (var i = 0; i < distractorCounts[2]; i++) {
      _gridColors[remainingPositions[posIndex++]] = distractor3;
    }

    // Generate 4 options: correct count + 3 wrong nearby counts
    final correct = _targetColorCount;
    final optionSet = <int>{correct};
    while (optionSet.length < 4) {
      final delta = _rand.nextInt(3) + 1; // 1..3
      final sign = _rand.nextBool() ? 1 : -1;
      final candidate = correct + delta * sign;
      if (candidate > 0 && candidate <= _totalBoxes) {
        optionSet.add(candidate);
      }
    }
    _options = optionSet.toList()..shuffle(_rand);
    _correctOption = correct;

    setState(() {
      _isWaitingForRound = false;
      _isRoundActive = true;
      _isShowingColors = true;
      _optionsEnabled = false;
      _roundStartTime = DateTime.now();
    });

    // After 2 seconds, hide colors and enable options
    _hideColorsTimer = Timer(
      const Duration(milliseconds: _displayDurationMs),
      () {
        if (!mounted || !_isRoundActive) return;
        setState(() {
          _isShowingColors = false;
          _optionsEnabled = true;
        });
      },
    );
  }

  void _handleOptionTap(int value) {
    if (!_isRoundActive || !_optionsEnabled || _roundStartTime == null) return;

    if (value == _correctOption) {
      SoundService.playTapSound();
      final reactionTime = DateTime.now()
          .difference(_roundStartTime!)
          .inMilliseconds;
      _completeRound(reactionTime, false);
    } else {
      _handleWrongTap();
    }
  }

  void _handleWrongTap() {
    SoundService.playPenaltySound();

    setState(() {
      _errorMessage =
          'PENALTY +${(_wrongTapPenaltyMs / 1000).toStringAsFixed(0)} SECOND';
      _isRoundActive = false;
      _optionsEnabled = false;
    });

    _roundResults.add(
      RoundResult(
        roundNumber: _currentRound,
        reactionTime: _wrongTapPenaltyMs,
        isFailed: true,
      ),
    );

    _overlayTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _errorMessage = null;
        _completedRounds++;
      });
      _startNextRound();
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
      _isRoundActive = false;
      _optionsEnabled = false;
      _completedRounds++;
      if (!isFailed) {
        _reactionTimeMessage = '$reactionTime ms';
      }
    });

    _overlayTimer = Timer(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      setState(() {
        _reactionTimeMessage = null;
      });
      _startNextRound();
    });
  }

  Future<void> _endGame() async {
    _roundDelayTimer?.cancel();
    _hideColorsTimer?.cancel();
    _overlayTimer?.cancel();

    setState(() {
      _isPlaying = false;
      _isWaitingForRound = false;
      _isRoundActive = false;
      _isShowingColors = false;
      _optionsEnabled = false;
    });

    // Calculate average/best (ignore failed rounds for best session calc)
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
    } else if (_roundResults.isNotEmpty) {
      averageTime =
          _roundResults.map((r) => r.reactionTime).reduce((a, b) => a + b) ~/
          _roundResults.length;
    }

    if (_roundResults.isNotEmpty) {
      final sessionNumber = await GameHistoryService.getNextSessionNumber(
        'color_frames_count',
      );
      final session = GameSession(
        gameId: 'color_frames_count',
        gameName: 'Color Frames Count',
        timestamp: DateTime.now(),
        sessionNumber: sessionNumber,
        roundResults: List.from(_roundResults),
        averageTime: averageTime,
        bestTime: bestTime,
      );
      await GameHistoryService.saveSession(session);

      // Update best session from all saved sessions
      final savedBestTime = await GameHistoryService.getBestTime(
        'color_frames_count',
      );
      if (mounted) {
        setState(() {
          _bestSession = savedBestTime;
        });
      }
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
              gameName: widget.exerciseName ?? 'Color Frames Count',
              gameId: 'color_frames_count',
              exerciseId: 26,
            ),
          ),
        )
        .then((_) async {
          if (!mounted) return;
          _resetGame();
          // Reload best session after returning from results
          await _loadBestSession();
          if (mounted) {
            setState(() {});
          }
        });
  }

  Widget _buildGrid() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        if (_targetColorName != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _gridSize,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _totalBoxes,
                  itemBuilder: (context, index) {
                    final color = _isShowingColors ? _gridColors[index] : null;
                    return Container(
                      decoration: BoxDecoration(
                        color: color ?? Colors.white,
                        borderRadius: BorderRadius.circular(16),
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
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        // Options row at bottom
        if (_options.isNotEmpty && _isRoundActive)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                4,
                (index) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: _buildOptionCell(_options[index]),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOptionCell(int value) {
    final enabled = _optionsEnabled;
    return GestureDetector(
      onTap: enabled ? () => _handleOptionTap(value) : null,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
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
        child: Center(
          child: Text(
            value.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: enabled
                  ? const Color(0xFF0F172A)
                  : const Color(0xFF94A3B8),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
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
          border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: !_isAdvanced
                          ? const Color(0xFF475569)
                          : Colors.white,
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
                        color: !_isAdvanced
                            ? Colors.white
                            : const Color(0xFF475569),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _isAdvanced
                          ? const Color(0xFF475569)
                          : Colors.white,
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
                        color: _isAdvanced
                            ? Colors.white
                            : const Color(0xFF475569),
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
        gameName: 'Color Frames Count',
        categoryName: widget.categoryName ?? 'Visual',
        gameId: 'color_frames_count',
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
          if (!s.isPlaying) return 'Count the color frames';
          if (s.isWaiting) return 'Wait...';
          if (s.isRoundActive) {
            if (_isShowingColors) return 'MEMORIZE!';
            return 'SELECT COUNT!';
          }
          return 'Round ${s.currentRound}';
        },
        contentBuilder: (s, context) {
          if (s.isRoundActive) {
            return Positioned.fill(child: _buildGrid());
          }
          // idle background similar to Catch Color
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
        middleContentBuilder: (s, context) {
          // Show difficulty selector only before game starts
          if (!s.isPlaying) {
            return _buildDifficultySelector();
          }
          return const SizedBox.shrink();
        },
      ),
      useBackdropFilter: true,
    );
  }
}
