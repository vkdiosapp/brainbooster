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

class PeripheralVisionPage extends StatefulWidget {
  final String? categoryName;
  final String? exerciseName;

  const PeripheralVisionPage({super.key, this.categoryName, this.exerciseName});

  @override
  State<PeripheralVisionPage> createState() => _PeripheralVisionPageState();
}

class _PeripheralVisionPageState extends State<PeripheralVisionPage> {
  // Get penalty time from exercise data (exercise ID 18)
  late final int _wrongTapPenaltyMs = ExerciseData.getExercises()
      .firstWhere(
        (e) => e.id == 18,
        orElse: () => ExerciseData.getExercises().first,
      )
      .penaltyTime;
  static const int _displayDurationMs = 1000; // Show digits for 0.5 seconds

  bool _isAdvanced = false; // false = Normal, true = Advanced

  int _currentRound = 0;
  int _completedRounds = 0;
  int _bestSession = 240; // ms

  bool _isPlaying = false;
  bool _isWaitingForRound = false;
  bool _isShowingDigits = false; // Phase 1: Showing digits for 1 second
  bool _isRoundActive = false; // Phase 2: User can tap boxes

  // Map position to digit value (0-99)
  // Normal: positions are 'top', 'bottom', 'left', 'right'
  // Advanced: positions are 'top', 'bottom', 'left', 'right', 'top-left', 'top-right', 'bottom-left', 'bottom-right'
  Map<String, int> _boxDigits = {};
  int? _higherDigitValue; // The correct answer (higher number)
  DateTime? _roundStartTime;
  Timer? _roundDelayTimer;
  Timer? _digitDisplayTimer;
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
    _digitDisplayTimer?.cancel();
    _overlayTimer?.cancel();
    super.dispose();
  }

  void _resetGame() {
    _roundDelayTimer?.cancel();
    _digitDisplayTimer?.cancel();
    _overlayTimer?.cancel();

    _currentRound = 0;
    _completedRounds = 0;
    _isPlaying = false;
    _isWaitingForRound = false;
    _isShowingDigits = false;
    _isRoundActive = false;
    _boxDigits.clear();
    _higherDigitValue = null;
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
    _digitDisplayTimer?.cancel();
    _overlayTimer?.cancel();

    setState(() {
      _currentRound++;
      _isWaitingForRound = true;
      _isShowingDigits = false;
      _isRoundActive = false;
      _errorMessage = null;
      _reactionTimeMessage = null;
      _boxDigits.clear();
      _higherDigitValue = null;
      _roundStartTime = null;
    });

    _roundDelayTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _showDigits();
    });
  }

  void _showDigits() {
    // Generate random digits (0-99) for each box
    _boxDigits.clear();

    if (_isAdvanced) {
      // Advanced: 8 boxes (top, bottom, left, right, top-left, top-right, bottom-left, bottom-right)
      final digits = [
        _rand.nextInt(100), // top
        _rand.nextInt(100), // bottom
        _rand.nextInt(100), // left
        _rand.nextInt(100), // right
        _rand.nextInt(100), // top-left
        _rand.nextInt(100), // top-right
        _rand.nextInt(100), // bottom-left
        _rand.nextInt(100), // bottom-right
      ];
      _boxDigits['top'] = digits[0];
      _boxDigits['bottom'] = digits[1];
      _boxDigits['left'] = digits[2];
      _boxDigits['right'] = digits[3];
      _boxDigits['top-left'] = digits[4];
      _boxDigits['top-right'] = digits[5];
      _boxDigits['bottom-left'] = digits[6];
      _boxDigits['bottom-right'] = digits[7];

      // Find the highest digit
      _higherDigitValue = digits.reduce((a, b) => a > b ? a : b);
    } else {
      // Normal: 4 boxes (top, bottom, left, right)
      final digits = [
        _rand.nextInt(100), // top
        _rand.nextInt(100), // bottom
        _rand.nextInt(100), // left
        _rand.nextInt(100), // right
      ];
      _boxDigits['top'] = digits[0];
      _boxDigits['bottom'] = digits[1];
      _boxDigits['left'] = digits[2];
      _boxDigits['right'] = digits[3];

      // Find the highest digit
      _higherDigitValue = digits.reduce((a, b) => a > b ? a : b);
    }

    setState(() {
      _isWaitingForRound = false;
      _isShowingDigits = true;
      _isRoundActive = false;
    });

    // After 1 second, hide digits and start timing
    _digitDisplayTimer = Timer(
      const Duration(milliseconds: _displayDurationMs),
      () {
        if (!mounted) return;
        _hideDigits();
      },
    );
  }

  void _hideDigits() {
    setState(() {
      _isShowingDigits = false;
      _isRoundActive = true;
      _roundStartTime = DateTime.now(); // Start timing when user can tap
    });
  }

  void _handleBoxTap(String position) {
    if (!_isRoundActive || _roundStartTime == null) {
      return;
    }

    final tappedDigit = _boxDigits[position];
    if (tappedDigit == null) {
      return;
    }

    // Check if correct (tapped box has the higher number)
    final isCorrect = tappedDigit == _higherDigitValue;

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
    _digitDisplayTimer?.cancel();

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
    _digitDisplayTimer?.cancel();
    _overlayTimer?.cancel();

    setState(() {
      _isPlaying = false;
      _isWaitingForRound = false;
      _isShowingDigits = false;
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
        'peripheral_vision',
      );
      final session = GameSession(
        gameId: 'peripheral_vision',
        gameName: 'Peripheral Vision',
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
              gameName: widget.exerciseName ?? 'Peripheral Vision',
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
        final centerX = containerWidth / 2;
        final centerY = containerHeight / 2;

        // Use the smaller dimension to ensure everything fits
        final minDimension = containerWidth < containerHeight
            ? containerWidth
            : containerHeight;
        final boxSize = minDimension * 0.2; // Box size relative to container
        final centerDotSize = 12.0;
        final spacing = minDimension * 0.15; // Spacing from center to boxes

        return Stack(
          children: [
            // Center red dot (always visible)
            Positioned(
              left: centerX - centerDotSize / 2,
              top: centerY - centerDotSize / 2,
              child: Container(
                width: centerDotSize,
                height: centerDotSize,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Boxes based on mode
            if (_isAdvanced) ...[
              // Advanced: 8 boxes (top, bottom, left, right, top-left, top-right, bottom-left, bottom-right)
              // Top box
              Positioned(
                left: centerX - boxSize / 2,
                top: centerY - boxSize / 2 - spacing - boxSize,
                child: _buildBox('top', boxSize),
              ),
              // Bottom box
              Positioned(
                left: centerX - boxSize / 2,
                top: centerY + boxSize / 2 + spacing,
                child: _buildBox('bottom', boxSize),
              ),
              // Left box
              Positioned(
                left: centerX - boxSize / 2 - spacing - boxSize,
                top: centerY - boxSize / 2,
                child: _buildBox('left', boxSize),
              ),
              // Right box
              Positioned(
                left: centerX + boxSize / 2 + spacing,
                top: centerY - boxSize / 2,
                child: _buildBox('right', boxSize),
              ),
              // Top-left box
              Positioned(
                left: centerX - boxSize / 2 - spacing - boxSize,
                top: centerY - boxSize / 2 - spacing - boxSize,
                child: _buildBox('top-left', boxSize),
              ),
              // Top-right box
              Positioned(
                left: centerX + boxSize / 2 + spacing,
                top: centerY - boxSize / 2 - spacing - boxSize,
                child: _buildBox('top-right', boxSize),
              ),
              // Bottom-left box
              Positioned(
                left: centerX - boxSize / 2 - spacing - boxSize,
                top: centerY + boxSize / 2 + spacing,
                child: _buildBox('bottom-left', boxSize),
              ),
              // Bottom-right box
              Positioned(
                left: centerX + boxSize / 2 + spacing,
                top: centerY + boxSize / 2 + spacing,
                child: _buildBox('bottom-right', boxSize),
              ),
            ] else ...[
              // Normal: 4 boxes (top, bottom, left, right)
              // Top box
              Positioned(
                left: centerX - boxSize / 2,
                top: centerY - boxSize / 2 - spacing - boxSize,
                child: _buildBox('top', boxSize),
              ),
              // Bottom box
              Positioned(
                left: centerX - boxSize / 2,
                top: centerY + boxSize / 2 + spacing,
                child: _buildBox('bottom', boxSize),
              ),
              // Left box
              Positioned(
                left: centerX - boxSize / 2 - spacing - boxSize,
                top: centerY - boxSize / 2,
                child: _buildBox('left', boxSize),
              ),
              // Right box
              Positioned(
                left: centerX + boxSize / 2 + spacing,
                top: centerY - boxSize / 2,
                child: _buildBox('right', boxSize),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildBox(String position, double size) {
    final digit = _boxDigits[position];
    final showDigit = _isShowingDigits && digit != null;

    return GestureDetector(
      onTap: () => _handleBoxTap(position),
      child: Container(
        width: size,
        height: size,
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
        child: showDigit
            ? Center(
                child: Text(
                  digit.toString(),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              )
            : null,
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
      isWaiting: _isWaitingForRound || _isShowingDigits,
      isRoundActive: _isRoundActive,
      currentRound: _currentRound,
      completedRounds: _completedRounds,
      errorMessage: _errorMessage,
      reactionTimeMessage: _reactionTimeMessage,
    );

    return BaseGamePage(
      config: GamePageConfig(
        gameName: 'PERIPHERAL VISION',
        categoryName: widget.categoryName ?? 'Visual',
        gameId: 'peripheral_vision',
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
          if (!s.isPlaying) return 'Tap the box with the higher number';
          if (s.isWaiting) {
            if (_isShowingDigits) return 'MEMORIZE THE NUMBERS!';
            return 'Wait...';
          }
          if (s.isRoundActive) {
            return 'TAP THE HIGHER NUMBER!';
          }
          return 'Round ${s.currentRound}';
        },
        contentBuilder: (s, context) {
          // Show game container when showing digits or when round is active
          if (_isShowingDigits || s.isRoundActive) {
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
          if (_isShowingDigits) return '';
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
