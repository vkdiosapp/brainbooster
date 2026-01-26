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

class VisualMemoryPage extends StatefulWidget {
  final String? categoryName;

  const VisualMemoryPage({super.key, this.categoryName});

  @override
  State<VisualMemoryPage> createState() => _VisualMemoryPageState();
}

class _VisualMemoryPageState extends State<VisualMemoryPage> {
  static const int _wrongTapPenaltyMs = 1000; // Penalty for wrong tap
  static const int _gridSize = 4; // Fixed 4x4 grid
  static const int _totalBoxes = 16; // 4x4 = 16 boxes
  static const int _redDotsCount = 4; // Show 4 red dots
  static const int _distractorDotsCount = 2; // Show 2 distractor dots with different colors
  static const int _displayDurationMs = 2000; // Show red dots for 2 seconds

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
    // Generate 4 random positions for red dots
    final positions = List.generate(_totalBoxes, (i) => i);
    positions.shuffle(_rand);
    _redDotPositions = positions.take(_redDotsCount).toSet();

    // Generate distractor dots with different colors (blue and green)
    // Make sure they don't overlap with red dots
    final remainingPositions = positions
        .where((pos) => !_redDotPositions.contains(pos))
        .toList();
    remainingPositions.shuffle(_rand);
    
    final distractorPositions = remainingPositions.take(_distractorDotsCount).toList();
    final distractorColors = [Colors.blue, Colors.green];
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

      // Check if all 4 positions are tapped
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
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
          if (s.isRoundActive || s.isWaiting || s.isPlaying) {
            return Positioned.fill(child: _buildGrid());
          }
          // idle background
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
      ),
      useBackdropFilter: true,
    );
  }
}
