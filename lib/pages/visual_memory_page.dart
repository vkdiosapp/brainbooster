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
import 'color_change_results_page.dart';

class VisualMemoryPage extends StatefulWidget {
  final String? categoryName;
  final String? exerciseName;

  const VisualMemoryPage({super.key, this.categoryName, this.exerciseName});

  @override
  State<VisualMemoryPage> createState() => _VisualMemoryPageState();
}

class _VisualMemoryPageState extends State<VisualMemoryPage> {
  static const int _wrongTapPenaltyMs = 1000; // Penalty for wrong tap
  static const int _displayDurationMs = 2000; // Show red dots for 2 seconds
  
  // Normal mode constants
  static const int _normalGridSize = 4; // 4x4 grid
  static const int _normalTotalBoxes = 16; // 4x4 = 16 boxes
  static const int _normalRedDotsCount = 4; // Show 4 red dots
  static const int _normalDistractorDotsCount = 2; // Show 2 distractor dots
  
  // Advanced mode constants
  static const int _advancedGridSize = 5; // 5x5 grid
  static const int _advancedTotalBoxes = 25; // 5x5 = 25 boxes
  static const int _advancedRedDotsCount = 8; // Show 8 red dots
  static const int _advancedDistractorDotsCount = 4; // Show 4 distractor dots
  
  bool _isAdvanced = false; // false = Normal, true = Advanced

  int _currentRound = 0;
  int _completedRounds = 0;
  int _bestSession = 240; // ms

  bool _isPlaying = false;
  bool _isWaitingForRound = false;
  bool _isShowingRedDots = false; // Phase 1: Showing red dots
  bool _isRoundActive = false; // Phase 2: User can tap black boxes

  Set<int> _redDotPositions = {}; // Positions with red dots
  Map<int, Color> _distractorDotPositions = {}; // Positions with distractor dots (different colors)
  Set<int> _tappedPositions = {}; // Positions user has correctly tapped
  DateTime? _roundStartTime;
  Timer? _roundDelayTimer;
  Timer? _redDotTimer;
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
    _redDotTimer?.cancel();
    _overlayTimer?.cancel();
    super.dispose();
  }

  // Getters for dynamic values based on difficulty
  int get _gridSize => _isAdvanced ? _advancedGridSize : _normalGridSize;
  int get _totalBoxes => _isAdvanced ? _advancedTotalBoxes : _normalTotalBoxes;
  int get _redDotsCount => _isAdvanced ? _advancedRedDotsCount : _normalRedDotsCount;
  int get _distractorDotsCount => _isAdvanced ? _advancedDistractorDotsCount : _normalDistractorDotsCount;

  void _resetGame() {
    _roundDelayTimer?.cancel();
    _redDotTimer?.cancel();
    _overlayTimer?.cancel();

    _currentRound = 0;
    _completedRounds = 0;
    _isPlaying = false;
    _isWaitingForRound = false;
    _isShowingRedDots = false;
    _isRoundActive = false;
    _redDotPositions.clear();
    _distractorDotPositions.clear();
    _tappedPositions.clear();
    _roundStartTime = null;
    _errorMessage = null;
    _reactionTimeMessage = null;
    _roundResults.clear();
    // Keep _isAdvanced state when resetting (don't reset to false)
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
    _redDotTimer?.cancel();
    _overlayTimer?.cancel();

    setState(() {
      _currentRound++;
      _isWaitingForRound = true;
      _isShowingRedDots = false;
      _isRoundActive = false;
      _errorMessage = null;
      _reactionTimeMessage = null;
      _redDotPositions.clear();
      _distractorDotPositions.clear();
      _tappedPositions.clear();
      _roundStartTime = null;
    });

    _roundDelayTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _showRedDots();
    });
  }

  void _showRedDots() {
    // Generate random positions for red dots based on difficulty
    final positions = List.generate(_totalBoxes, (i) => i);
    positions.shuffle(_rand);
    _redDotPositions = positions.take(_redDotsCount).toSet();

    // Generate distractor dots with different colors
    // Make sure they don't overlap with red dots
    final remainingPositions = positions
        .where((pos) => !_redDotPositions.contains(pos))
        .toList();
    remainingPositions.shuffle(_rand);
    
    final distractorPositions = remainingPositions.take(_distractorDotsCount).toList();
    // Use more colors for advanced mode
    final distractorColors = _isAdvanced 
        ? [Colors.blue, Colors.green, Colors.orange, Colors.purple]
        : [Colors.blue, Colors.green];
    _distractorDotPositions = {};
    for (int i = 0; i < distractorPositions.length && i < distractorColors.length; i++) {
      _distractorDotPositions[distractorPositions[i]] = distractorColors[i];
    }

    setState(() {
      _isWaitingForRound = false;
      _isShowingRedDots = true;
      _isRoundActive = false;
    });

    // After 2 seconds, hide red dots and show black boxes
    _redDotTimer = Timer(const Duration(milliseconds: _displayDurationMs), () {
      if (!mounted) return;
      _hideRedDots();
    });
  }

  void _hideRedDots() {
    setState(() {
      _isShowingRedDots = false;
      _isRoundActive = true;
      _roundStartTime = DateTime.now(); // Start timing when user can tap
    });
  }

  void _handleTileTap(int index) {
    if (!_isRoundActive || _roundStartTime == null) {
      return;
    }

    // Check if already tapped
    if (_tappedPositions.contains(index)) {
      return; // Already tapped this position
    }

    // Check if this is a correct position (had red dot)
    if (_redDotPositions.contains(index)) {
      // Play tap sound for correct tap
      SoundService.playTapSound();
      // Correct tap
      setState(() {
        _tappedPositions.add(index);
      });

      // Check if all red dot positions are tapped (dynamic based on difficulty)
      if (_tappedPositions.length == _redDotsCount) {
        _completeRound();
      }
    } else {
      // Wrong tap - penalty (includes tapping distractor dots or empty boxes)
      _handleWrongTap();
    }
  }

  void _handleWrongTap() {
    // Play penalty sound for wrong tap
    SoundService.playPenaltySound();
    _overlayTimer?.cancel();

    // End round immediately with penalty
    final roundTime = _wrongTapPenaltyMs; // Use penalty as round time

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

    // Calculate round time (from when boxes turned black until all 4 tapped)
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
    _redDotTimer?.cancel();
    _overlayTimer?.cancel();

    setState(() {
      _isPlaying = false;
      _isWaitingForRound = false;
      _isShowingRedDots = false;
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
        'visual_memory',
      );
      final session = GameSession(
        gameId: 'visual_memory',
        gameName: 'Visual Memory',
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
              gameName: widget.exerciseName ?? 'Visual Memory',
              gameId: 'visual_memory',
              exerciseId: 13,
            ),
          ),
        )
        .then((_) {
          if (!mounted) return;
          _resetGame();
          setState(() {});
        });
  }

  Widget _buildGrid() {
    return Center(
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
              final hasRedDot = _redDotPositions.contains(index);
              final hasDistractorDot = _distractorDotPositions.containsKey(index);
              final distractorColor = _distractorDotPositions[index];
              final isTapped = _tappedPositions.contains(index);
              final isShowingRedDots = _isShowingRedDots;
              final isRoundActive = _isRoundActive;

              // Determine box color and content
              Color boxColor;
              Widget? content;

              if (isShowingRedDots) {
                // Phase 1: Show red dots and distractor dots on white boxes, others empty white
                boxColor = Colors.white;
                if (hasRedDot) {
                  content = Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  );
                } else if (hasDistractorDot && distractorColor != null) {
                  content = Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: distractorColor,
                      shape: BoxShape.circle,
                    ),
                  );
                }
              } else if (isRoundActive) {
                // Phase 2: All boxes are black (user can tap)
                boxColor = Colors.black;
                if (isTapped) {
                  // If tapped correctly, show white with red dot
                  boxColor = Colors.white;
                  content = Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  );
                }
              } else {
                // Idle state: white boxes
                boxColor = Colors.white;
              }

              return GestureDetector(
                onTap: () => _handleTileTap(index),
                child: Container(
                  decoration: BoxDecoration(
                    color: boxColor,
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
                  child: content != null ? Center(child: content) : null,
                ),
              );
            },
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
          border: Border.all(
            color: Colors.white.withOpacity(0.4),
            width: 1,
          ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: !_isAdvanced ? const Color(0xFF475569) : Colors.white,
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
                        color: !_isAdvanced ? Colors.white : const Color(0xFF475569),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: _isAdvanced ? const Color(0xFF475569) : Colors.white,
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
                        color: _isAdvanced ? Colors.white : const Color(0xFF475569),
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
      isWaiting: _isWaitingForRound || _isShowingRedDots,
      isRoundActive: _isRoundActive,
      currentRound: _currentRound,
      completedRounds: _completedRounds,
      errorMessage: _errorMessage,
      reactionTimeMessage: _reactionTimeMessage,
    );

    return BaseGamePage(
      config: GamePageConfig(
        gameName: 'Visual Memory',
        categoryName: widget.categoryName ?? 'Memory',
        gameId: 'visual_memory',
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
          if (!s.isPlaying) return 'Memorize the red dots';
          if (s.isWaiting) {
            if (_isShowingRedDots) return 'MEMORIZE THE RED DOTS!';
            return 'Wait...';
          }
          if (s.isRoundActive) {
            return 'TAP THE RED DOTS!';
          }
          return 'Round ${s.currentRound}';
        },
        contentBuilder: (s, context) {
          // Only show grid when showing red dots or when round is active
          // Hide grid during initial wait phase to avoid UI override
          if (_isShowingRedDots || s.isRoundActive) {
            return Positioned.fill(child: _buildGrid());
          }
          // idle background or wait state (no grid)
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
          if (_isShowingRedDots) return '';
          return 'WAIT...';
        },
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
