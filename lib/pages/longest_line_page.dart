import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../game_settings.dart';
import '../models/game_session.dart';
import '../models/round_result.dart';
import '../services/game_history_service.dart';
import '../services/sound_service.dart';
import '../widgets/base_game_page.dart';
import 'color_change_results_page.dart';

// Line data structure
class LineData {
  final String side; // 'top', 'bottom', 'left', 'right'
  final double relativeLength; // Relative length (0.5 to 1.0) - 0.5 = half, 1.0 = full
  final double position; // Position along the perpendicular axis (0.0 to 1.0)
  final int index; // Index in the lines list

  LineData({
    required this.side,
    required this.relativeLength,
    required this.position,
    required this.index,
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
  static const int _wrongTapPenaltyMs = 1000; // Penalty for wrong tap
  static const int _displayDurationMs = 1000; // Show lines for 1 second

  int _currentRound = 0;
  int _completedRounds = 0;
  int _bestSession = 240; // ms

  bool _isPlaying = false;
  bool _isWaitingForRound = false;
  bool _isShowingLines = false; // Phase 1: Showing lines for 1 second
  bool _isRoundActive = false; // Phase 2: User can tap lines

  // Line data: each line has a side and relative height (0.5 to 1.0)
  List<LineData> _lines = [];
  int? _longestLineIndex; // Index of the longest line
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
    _isShowingLines = false;
    _isRoundActive = false;
    _lines.clear();
    _longestLineIndex = null;
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
      _isShowingLines = false;
      _isRoundActive = false;
      _errorMessage = null;
      _reactionTimeMessage = null;
      _lines.clear();
      _longestLineIndex = null;
      _roundStartTime = null;
    });

    _roundDelayTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _showLines();
    });
  }

  void _showLines() {
    // Generate 5 lines with random sides and heights
    _generateLines();

    setState(() {
      _isWaitingForRound = false;
      _isShowingLines = true;
      _isRoundActive = false;
    });

    // After 1 second, hide lines and start timing
    _lineDisplayTimer = Timer(
      const Duration(milliseconds: _displayDurationMs),
      () {
        if (!mounted) return;
        _hideLines();
      },
    );
  }

  void _hideLines() {
    setState(() {
      _isShowingLines = false;
      _isRoundActive = true;
      _roundStartTime = DateTime.now(); // Start timing when user can tap
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
      _isShowingLines = false;
      _isRoundActive = false;
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

        return Stack(
          children: [
            // Draw all lines
            ..._lines.asMap().entries.map((entry) {
              final index = entry.key;
              final line = entry.value;
              return _buildLine(line, index, containerWidth, containerHeight);
            }),
          ],
        );
      },
    );
  }

  void _generateLines() {
    _lines.clear();
    
    // Available sides
    final sides = ['top', 'bottom', 'left', 'right'];
    
    // Randomly select ONE side for all lines in this round
    final selectedSide = sides[_rand.nextInt(sides.length)];

    // Generate relative lengths for each line (0.5 to 1.0)
    // All lengths must be different
    final relativeLengths = <double>[];
    
    for (int i = 0; i < 5; i++) {
      double relativeLength;
      int attempts = 0;
      do {
        // Generate between 0.5 (half) and 1.0 (full)
        relativeLength = 0.5 + _rand.nextDouble() * 0.5;
        attempts++;
        // Ensure all lengths are different (with tolerance of 0.01)
        if (attempts > 200) break; // Prevent infinite loop
      } while (relativeLengths.any((l) => (l - relativeLength).abs() < 0.01));
      
      relativeLengths.add(relativeLength);
    }

    // Create line data - all lines use the same side
    for (int i = 0; i < 5; i++) {
      _lines.add(LineData(
        side: selectedSide, // All lines use the same side
        relativeLength: relativeLengths[i],
        position: 0.0, // Not used anymore since we'll evenly space them
        index: i,
      ));
    }

    // Find the longest line (by relative length)
    double maxLength = 0;
    int longestIndex = 0;
    for (int i = 0; i < _lines.length; i++) {
      if (_lines[i].relativeLength > maxLength) {
        maxLength = _lines[i].relativeLength;
        longestIndex = i;
      }
    }
    _longestLineIndex = longestIndex;
  }

  Widget _buildLine(LineData line, int index, double containerWidth, double containerHeight) {
    double x, y, width, height;
    const lineThickness = 12.0; // Slightly thicker for better visibility

    // All lines are on the same side, so we can evenly space them
    // Using index directly since all 5 lines are on the same side
    const totalLines = 5;

    if (line.side == 'top') {
      // Line starts from top edge, extends DOWNWARD (vertically)
      width = lineThickness;
      height = containerHeight * line.relativeLength; // Length extends downward
      // Position along horizontal axis (evenly spaced)
      final totalSpacing = containerWidth - (totalLines * lineThickness);
      final spacing = totalSpacing / (totalLines + 1);
      x = spacing + (index * (lineThickness + spacing));
      y = 0; // Start from top
    } else if (line.side == 'bottom') {
      // Line starts from bottom edge, extends UPWARD (vertically)
      width = lineThickness;
      height = containerHeight * line.relativeLength;
      final totalSpacing = containerWidth - (totalLines * lineThickness);
      final spacing = totalSpacing / (totalLines + 1);
      x = spacing + (index * (lineThickness + spacing));
      y = containerHeight - height; // Start from bottom, extend upward
    } else if (line.side == 'left') {
      // Line starts from left edge, extends RIGHTWARD (horizontally)
      width = containerWidth * line.relativeLength; // Length extends rightward
      height = lineThickness;
      x = 0; // Start from left
      // Position along vertical axis (evenly spaced)
      final totalSpacing = containerHeight - (totalLines * lineThickness);
      final spacing = totalSpacing / (totalLines + 1);
      y = spacing + (index * (lineThickness + spacing));
    } else {
      // Line starts from right edge, extends LEFTWARD (horizontally)
      width = containerWidth * line.relativeLength;
      height = lineThickness;
      x = containerWidth - width; // Start from right, extend leftward
      final totalSpacing = containerHeight - (totalLines * lineThickness);
      final spacing = totalSpacing / (totalLines + 1);
      y = spacing + (index * (lineThickness + spacing));
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
                color: const Color(0xFF1E293B), // Dark grey/black like screenshot
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
      isWaiting: _isWaitingForRound || _isShowingLines,
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
          if (!s.isPlaying) return 'Tap the longest line';
          if (s.isWaiting) {
            if (_isShowingLines) return 'MEMORIZE THE LINES!';
            return 'Wait...';
          }
          if (s.isRoundActive) {
            return 'TAP THE LONGEST LINE!';
          }
          return 'Round ${s.currentRound}';
        },
        contentBuilder: (s, context) {
          // Show game container when showing lines or when round is active
          if (_isShowingLines || s.isRoundActive) {
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
          if (_isShowingLines) return '';
          return 'WAIT...';
        },
        startButtonText: 'START',
      ),
      useBackdropFilter: true,
    );
  }
}
