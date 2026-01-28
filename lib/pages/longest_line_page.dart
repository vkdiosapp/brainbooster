import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../game_settings.dart';
import '../models/game_session.dart';
import '../models/round_result.dart';
import '../services/game_history_service.dart';
import '../services/sound_service.dart';
import '../widgets/base_game_page.dart';
import '../data/exercise_data.dart';
import 'color_change_results_page.dart';

// Line data structure
class LineData {
  final String side; // 'top', 'bottom', 'left', 'right'
  final double
      relativeLength; // Relative length (0.5 to 1.0) - 0.5 = half, 1.0 = full
  final double position; // Position along the perpendicular axis (0.0 to 1.0)
  final int index; // Index in the lines list
  final Color color; // Original color of the line

  LineData({
    required this.side,
    required this.relativeLength,
    required this.position,
    required this.index,
    required this.color,
  });
}

class LongestLinePage extends StatefulWidget {
  final String? categoryName;
  final String? exerciseName;

  const LongestLinePage({super.key, this.categoryName, this.exerciseName});

  @override
  State<LongestLinePage> createState() => _LongestLinePageState();
}

class _LongestLinePageState extends State<LongestLinePage> {
  // Get penalty time from exercise data (exercise ID 19)
  late final int _wrongTapPenaltyMs = ExerciseData.getExercises()
      .firstWhere(
        (e) => e.id == 19,
        orElse: () => ExerciseData.getExercises().first,
      )
      .penaltyTime;

  int _currentRound = 0;
  int _completedRounds = 0;
  int _bestSession = 240; // ms

  bool _isPlaying = false;
  bool _isWaitingForRound = false;
  bool _isRoundActive = false; // User can tap lines
  bool _isShowingColors = false; // Phase 1: showing colored lines

  // Line data: each line has a side and relative height (0.5 to 1.0)
  List<LineData> _lines = [];
  int? _longestLineIndex; // Index of the longest line of target color
  Color? _targetColor; // Color user must focus on
  String _targetColorName = '';
  DateTime? _roundStartTime;
  Timer? _roundDelayTimer;
  Timer? _lineDisplayTimer;
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
    _lineDisplayTimer?.cancel();
    _overlayTimer?.cancel();
    super.dispose();
  }

  void _resetGame() {
    _roundDelayTimer?.cancel();
    _lineDisplayTimer?.cancel();
    _overlayTimer?.cancel();

    _currentRound = 0;
    _completedRounds = 0;
    _isPlaying = false;
    _isWaitingForRound = false;
    _isRoundActive = false;
    _isShowingColors = false;
    _lines.clear();
    _longestLineIndex = null;
    _targetColor = null;
    _targetColorName = '';
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
    _lineDisplayTimer?.cancel();
    _overlayTimer?.cancel();

    setState(() {
      _currentRound++;
      _isWaitingForRound = true;
      _isRoundActive = false;
      _isShowingColors = false;
      _errorMessage = null;
      _reactionTimeMessage = null;
      _lines.clear();
      _longestLineIndex = null;
      _targetColor = null;
      _targetColorName = '';
      _roundStartTime = null;
    });

    _roundDelayTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _showLines();
    });
  }

  void _showLines() {
    // Generate 8 lines with random sides, lengths and colors
    _generateLines();

    // Phase 1: show colored lines for 2 seconds (memorization)
    setState(() {
      _isWaitingForRound = false;
      _isShowingColors = true;
      _isRoundActive = false;
      _roundStartTime = null;
    });

    _lineDisplayTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      // Phase 2: hide colors (turn all lines black) and start timing
      setState(() {
        _isShowingColors = false;
        _isRoundActive = true;
        _roundStartTime = DateTime.now();
      });
    });
  }

  void _handleLineTap(int lineIndex) {
    if (!_isRoundActive || _roundStartTime == null) {
      return;
    }

    if (lineIndex < 0 || lineIndex >= _lines.length) {
      return;
    }

    // Check if correct (tapped line is the longest)
    final isCorrect = lineIndex == _longestLineIndex;

    if (isCorrect) {
      // Correct tap
      SoundService.playTapSound();
      _completeRound();
    } else {
      // Wrong tap - add penalty
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
      _errorMessage = 'PENALTY +1 SECOND';
    });

    _overlayTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _errorMessage = null);
      _startNextRound();
    });
  }

  void _completeRound() {
    _overlayTimer?.cancel();
    _lineDisplayTimer?.cancel();

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
    _lineDisplayTimer?.cancel();
    _overlayTimer?.cancel();

    setState(() {
      _isPlaying = false;
      _isWaitingForRound = false;
      _isRoundActive = false;
      _isShowingColors = false;
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
        'longest_line',
      );
      final session = GameSession(
        gameId: 'longest_line',
        gameName: 'Longest Line',
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
              gameName: widget.exerciseName ?? 'Longest Line',
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
        final containerHeight = constraints.maxHeight;

        if (_lines.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_targetColor != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _isShowingColors
                        ? const Color(0xFF475569) // hidden / neutral state
                        : _targetColor, // reveal actual color after lines go black
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
                    _isShowingColors ? '???' : _targetColorName,
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
              child: Stack(
                children: [
                  // Draw all lines
                  ..._lines.asMap().entries.map((entry) {
                    final index = entry.key;
                    final line = entry.value;
                    return _buildLine(
                      line,
                      index,
                      containerWidth,
                      containerHeight,
                    );
                  }),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _generateLines() {
    _lines.clear();

    // Available sides
    // NOTE: Only use left and right so lines start from horizontal sides,
    // not from top or bottom.
    final sides = ['left', 'right'];

    // Randomly select ONE side (left or right) for all lines in this round
    final selectedSide = sides[_rand.nextInt(sides.length)];

    // Define 3 colors to use
    final colors = <Color>[
      Colors.red,
      Colors.green,
      Colors.blue,
    ];

    // Choose target color for this round
    final targetIndex = _rand.nextInt(colors.length);
    _targetColor = colors[targetIndex];
    _targetColorName = targetIndex == 0
        ? 'RED'
        : targetIndex == 1
            ? 'GREEN'
            : 'BLUE';

    const totalLines = 8;

    // Generate relative lengths for each line (0.75 to 1.0), all different
    final relativeLengths = <double>[];
    for (int i = 0; i < totalLines; i++) {
      double relativeLength;
      int attempts = 0;
      do {
        // Generate between 0.75 (75%) and 1.0 (full)
        relativeLength = 0.75 + _rand.nextDouble() * 0.25;
        attempts++;
        // Ensure all lengths are different (with tolerance of 0.01)
        if (attempts > 200) break; // Prevent infinite loop
      } while (relativeLengths.any((l) => (l - relativeLength).abs() < 0.01));
      relativeLengths.add(relativeLength);
    }

    // Assign colors so that:
    // - Each of the 3 colors appears at least twice
    // - No two adjacent lines have the same color
    // - The chosen target color is automatically present (>= 2 times)
    final List<int> colorCounts = [2, 2, 2]; // base: each color at least twice
    int remaining = totalLines - colorCounts.reduce((a, b) => a + b); // 8 - 6 = 2

    // Distribute remaining lines randomly among the 3 colors
    while (remaining > 0) {
      final idx = _rand.nextInt(colors.length);
      colorCounts[idx]++;
      remaining--;
    }

    // Build a list of color indices according to counts
    final List<int> colorIndices = [];
    for (int c = 0; c < colors.length; c++) {
      for (int i = 0; i < colorCounts[c]; i++) {
        colorIndices.add(c);
      }
    }

    // Try to arrange colors so that no adjacent indices are equal
    List<int> arranged = [];
    for (int attempt = 0; attempt < 20; attempt++) {
      arranged = [];
      final countsCopy = List<int>.from(colorCounts);
      int? prev;

      for (int i = 0; i < totalLines; i++) {
        // Collect available colors that are not same as previous and still have remaining count
        final List<int> available = [];
        for (int c = 0; c < colors.length; c++) {
          if (countsCopy[c] > 0 && c != prev) {
            available.add(c);
          }
        }

        if (available.isEmpty) {
          // Failed this attempt, break and retry with a new attempt
          arranged = [];
          break;
        }

        final chosen = available[_rand.nextInt(available.length)];
        arranged.add(chosen);
        countsCopy[chosen]--;
        prev = chosen;
      }

      if (arranged.length == totalLines) {
        break;
      }
    }

    // Fallback: if for some reason arrangement failed, just use the flat list
    if (arranged.length != totalLines) {
      arranged = List<int>.from(colorIndices);
      arranged.shuffle(_rand);
    }

    final List<Color> lineColors = arranged.map((i) => colors[i]).toList();

    // Create line data - all lines use the same side
    for (int i = 0; i < totalLines; i++) {
      _lines.add(
        LineData(
          side: selectedSide,
          relativeLength: relativeLengths[i],
          position: 0.0, // Not used anymore since we'll evenly space them
          index: i,
          color: lineColors[i],
        ),
      );
    }

    // Find the longest line among the target color lines
    double maxLength = -1;
    int longestIndex = 0;
    for (int i = 0; i < _lines.length; i++) {
      if (_lines[i].color == _targetColor &&
          _lines[i].relativeLength > maxLength) {
        maxLength = _lines[i].relativeLength;
        longestIndex = i;
      }
    }
    _longestLineIndex = longestIndex;
  }

  Widget _buildLine(
    LineData line,
    int index,
    double containerWidth,
    double containerHeight,
  ) {
    double x, y, width, height;
    const containerPadding = 20.0; // 20px padding on all sides
    const totalLines = 8;

    // Calculate available space after padding (40px total: 20px on each side)
    final availableWidth = containerWidth - (containerPadding * 2);
    final availableHeight = containerHeight - (containerPadding * 2);

    // Dynamically compute line thickness and spacing so that
    // lines + spaces exactly fill the available height.
    // Let h = lineThickness, s = spacing, N = totalLines
    // We choose a ratio r = s / h, then:
    // N*h + (N-1)*s = availableHeight => h = availableHeight / (N + (N-1)*r)
    const double spacingToThicknessRatio = 0.6;
    final double lineThickness =
        availableHeight / (totalLines + (totalLines - 1) * spacingToThicknessRatio);
    final double spacingBetweenLines = lineThickness * spacingToThicknessRatio;

    if (line.side == 'top') {
      // Line starts from top edge, extends DOWNWARD (vertically)
      // Auto-calculate line thickness to fill available space with fixed spacing
      final totalSpacingWidth = (totalLines - 1) * spacingBetweenLines;
      final lineThickness = (availableWidth - totalSpacingWidth) / totalLines;
      width = lineThickness;
      height = availableHeight * line.relativeLength; // Length extends downward
      // Position along horizontal axis with fixed 20px spacing, starting from padding
      x = containerPadding + (index * (lineThickness + spacingBetweenLines));
      y = containerPadding; // Start from top with padding
    } else if (line.side == 'bottom') {
      // Line starts from bottom edge, extends UPWARD (vertically)
      final totalSpacingWidth = (totalLines - 1) * spacingBetweenLines;
      final lineThickness = (availableWidth - totalSpacingWidth) / totalLines;
      width = lineThickness;
      height = availableHeight * line.relativeLength;
      x = containerPadding + (index * (lineThickness + spacingBetweenLines));
      y =
          containerPadding +
          availableHeight -
          height; // Start from bottom with padding
    } else if (line.side == 'left') {
      // Line starts from left edge, extends RIGHTWARD (horizontally)
      width = availableWidth * line.relativeLength; // Length extends rightward
      height = lineThickness;
      x = containerPadding; // Start from left with padding
      // Position along vertical axis with dynamic spacing, starting from padding
      y = containerPadding + (index * (lineThickness + spacingBetweenLines));
    } else {
      // Line starts from right edge, extends LEFTWARD (horizontally)
      width = availableWidth * line.relativeLength;
      height = lineThickness;
      x =
          containerPadding +
          availableWidth -
          width; // Start from right with padding
      y = containerPadding + (index * (lineThickness + spacingBetweenLines));
    }

    // Increase tappable area with padding
    const tapPadding = 20.0; // Padding around line for easier tapping

    // Calculate expanded dimensions for tap area
    double tapWidth, tapHeight, tapX, tapY;
    if (line.side == 'top' || line.side == 'bottom') {
      // Vertical lines - expand width for tap area
      tapWidth = width + (tapPadding * 2);
      tapHeight = height;
      // Adjust X position to center the visual line within the tap area
      tapX = x - tapPadding;
      tapY = y; // Y position stays the same
    } else {
      // Horizontal lines - expand height for tap area
      tapWidth = width;
      tapHeight = height + (tapPadding * 2);
      // Adjust Y position to center the visual line within the tap area
      tapX = x; // X position stays the same
      tapY = y - tapPadding;
    }

    return Positioned(
      left: tapX,
      top: tapY,
      child: GestureDetector(
        onTap: () => _handleLineTap(index),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: tapWidth,
          height: tapHeight,
          child: Center(
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: _isShowingColors
                    ? line.color
                    : const Color(
                        0xFF1E293B,
                      ), // Dark grey/black when hidden
                borderRadius: BorderRadius.circular(2),
              ),
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
      isWaiting: _isWaitingForRound || _isShowingColors,
      isRoundActive: _isRoundActive,
      currentRound: _currentRound,
      completedRounds: _completedRounds,
      errorMessage: _errorMessage,
      reactionTimeMessage: _reactionTimeMessage,
    );

    return BaseGamePage(
      config: GamePageConfig(
        gameName: 'LONGEST LINE',
        categoryName: widget.categoryName ?? 'Visual',
        gameId: 'longest_line',
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
            return 'Tap the longest line of the shown color';
          }
          if (s.isWaiting) {
            if (_isShowingColors) {
              return 'MEMORIZE THE LINES!';
            }
            return 'Wait...';
          }
          if (s.isRoundActive) {
            return _targetColorName.isNotEmpty
                ? 'TAP THE LONGEST $_targetColorName LINE!'
                : 'TAP THE LONGEST LINE!';
          }
          return 'Round ${s.currentRound}';
        },
        contentBuilder: (s, context) {
          // Show game container when showing colors or when round is active
          if (_isShowingColors || s.isRoundActive) {
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
          if (_isShowingColors) return '';
          return 'WAIT...';
        },
        startButtonText: 'START',
      ),
      useBackdropFilter: true,
    );
  }
}
