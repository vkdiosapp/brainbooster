import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../game_settings.dart';
import '../models/game_session.dart';
import '../models/round_result.dart';
import '../services/game_history_service.dart';
import '../widgets/base_game_page.dart';
import 'color_change_results_page.dart';

class CatchColorPage extends StatefulWidget {
  final String? categoryName;

  const CatchColorPage({super.key, this.categoryName});

  @override
  State<CatchColorPage> createState() => _CatchColorPageState();
}

class _CatchColorPageState extends State<CatchColorPage> {
  static const int _gridSize = 4; // 4x4
  static const int _turnsPerRound = 7;
  static const int _correctTurnsPerRound =
      3; // Out of 7 turns, 3 will have correct color
  static const int _turnTimeLimitMs =
      3000; // Correct color turn timeout (3 seconds)
  static const int _wrongColorTurnTimeoutMs =
      2000; // Wrong color turn auto-advance (2 seconds)
  static const int _wrongTapPenaltyMs = 1000;

  int _currentRound = 0;
  int _completedRounds = 0;
  int _bestSession = 240; // ms

  bool _isPlaying = false;
  bool _isWaitingForRound = false;
  bool _isRoundActive = false;
  bool _isWaitingForTurn = false; // 1-second delay before turn starts

  Color? _targetColor;
  String? _targetColorName;
  List<int> _correctTurnIndices =
      []; // Which turns (0-6) will show the correct color
  Color?
  _currentDisplayColor; // The color currently displayed (target or wrong)

  int? _activeIndex; // which tile currently shows the color
  int _currentTurnInRound = 0; // 0..6
  int _currentTurnPenaltyMs = 0;
  DateTime? _turnStartTime;
  Timer? _roundDelayTimer;
  Timer? _turnStartDelayTimer; // 1-second delay before showing colored tile
  Timer? _turnTimeoutTimer;
  Timer? _overlayTimer;
  bool _hadTimeoutThisRound = false;
  bool _hadPenaltyThisRound = false;

  String? _errorMessage;
  String? _reactionTimeMessage;

  final List<int> _turnTimesMs = []; // All turn times (for tracking)
  final List<int> _tappedTurnTimesMs =
      []; // Only tapped turns (for average - max 3)
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
  }

  @override
  void dispose() {
    _roundDelayTimer?.cancel();
    _turnStartDelayTimer?.cancel();
    _turnTimeoutTimer?.cancel();
    _overlayTimer?.cancel();
    super.dispose();
  }

  void _resetGame() {
    _roundDelayTimer?.cancel();
    _turnStartDelayTimer?.cancel();
    _turnTimeoutTimer?.cancel();
    _overlayTimer?.cancel();

    _currentRound = 0;
    _completedRounds = 0;
    _isPlaying = false;
    _isWaitingForRound = false;
    _isRoundActive = false;
    _isWaitingForTurn = false;
    _targetColor = null;
    _targetColorName = null;
    _correctTurnIndices.clear();
    _currentDisplayColor = null;
    _activeIndex = null;
    _currentTurnInRound = 0;
    _currentTurnPenaltyMs = 0;
    _turnStartTime = null;
    _errorMessage = null;
    _reactionTimeMessage = null;
    _turnTimesMs.clear();
    _tappedTurnTimesMs.clear();
    _roundResults.clear();

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
    _turnStartDelayTimer?.cancel();
    _turnTimeoutTimer?.cancel();
    _overlayTimer?.cancel();

    setState(() {
      _currentRound++;
      _isWaitingForRound = true;
      _isRoundActive = false;
      _isWaitingForTurn = false;
      _errorMessage = null;
      _reactionTimeMessage = null;
      _turnTimesMs.clear();
      _tappedTurnTimesMs.clear();
      _currentTurnInRound = 0;
      _currentTurnPenaltyMs = 0;
      _turnStartTime = null;
      _activeIndex = null;
      _currentDisplayColor = null;
      _hadTimeoutThisRound = false;
      _hadPenaltyThisRound = false;
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

    // Randomly select 3 turns out of 7 that will show the correct color
    final allTurns = List.generate(_turnsPerRound, (i) => i);
    allTurns.shuffle(_rand);
    _correctTurnIndices = allTurns.take(_correctTurnsPerRound).toList()..sort();

    setState(() {
      _isWaitingForRound = false;
      _isRoundActive = true;
    });

    _startTurn();
  }

  void _startTurn() {
    _turnStartDelayTimer?.cancel();
    _turnTimeoutTimer?.cancel();

    // First: show all white boxes for 1 second
    setState(() {
      _isWaitingForTurn = true;
      _currentTurnPenaltyMs = 0;
      _activeIndex = null; // No colored tile visible yet
    });

    // After 1 second, show the colored tile and start the turn
    _turnStartDelayTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted || !_isRoundActive) return;

      // Determine if this turn should show the correct color or a wrong color
      final isCorrectTurn = _correctTurnIndices.contains(_currentTurnInRound);

      if (isCorrectTurn) {
        // Show the target color
        _currentDisplayColor = _targetColor;
      } else {
        // Show a random wrong color (different from target)
        final wrongColors = _availableColors
            .where((c) => c != _targetColor)
            .toList();
        wrongColors.shuffle(_rand);
        _currentDisplayColor = wrongColors.first;
      }

      setState(() {
        _isWaitingForTurn = false;
        _turnStartTime = DateTime.now();
        _activeIndex = _rand.nextInt(_gridSize * _gridSize);
      });

      // Set different timeout based on turn type
      final timeoutMs = isCorrectTurn
          ? _turnTimeLimitMs
          : _wrongColorTurnTimeoutMs;
      _turnTimeoutTimer = Timer(
        Duration(milliseconds: timeoutMs),
        _handleTurnTimeout,
      );
    });
  }

  void _handleTurnTimeout() {
    if (!mounted || !_isRoundActive || _turnStartTime == null) return;

    // Check if this is a correct color turn or wrong color turn
    final isCorrectTurn = _correctTurnIndices.contains(_currentTurnInRound);

    if (isCorrectTurn) {
      // For correct color turns: timeout means user didn't tap in time - apply penalty
      // IMPORTANT (per requirement):
      // Do NOT move the colored tile to another box until the user taps it.
      // So on timeout we just apply a penalty and restart the timer, keeping the same index.
      _hadTimeoutThisRound = true;
      _applyPenalty(showUi: false);
      _turnTimeoutTimer?.cancel();
      _turnTimeoutTimer = Timer(
        const Duration(milliseconds: _turnTimeLimitMs),
        _handleTurnTimeout,
      );
    } else {
      // For wrong color turns: auto-advance after 2 seconds (user should not tap)
      // Don't add to correct turn times - wrong color turns don't count in average
      _advanceTurn(isTimeout: true);
    }
  }

  void _handleTileTap(int index) {
    // Don't allow taps during the 1-second delay (all white boxes)
    if (!_isRoundActive ||
        _isWaitingForTurn ||
        _turnStartTime == null ||
        _activeIndex == null) {
      return;
    }

    // Check if this turn should have the correct color
    final isCorrectTurn = _correctTurnIndices.contains(_currentTurnInRound);

    if (index == _activeIndex) {
      if (isCorrectTurn && _currentDisplayColor == _targetColor) {
        // Correct tap on correct color - calculate reaction time
        final rt =
            DateTime.now().difference(_turnStartTime!).inMilliseconds +
            _currentTurnPenaltyMs;
        _turnTimesMs.add(rt);
        _tappedTurnTimesMs.add(rt);

        // Check if we've completed 3 taps - if so, end round immediately
        if (_tappedTurnTimesMs.length >= 3) {
          _endRoundEarly();
        } else {
          _advanceTurn(isTimeout: false);
        }
      } else {
        // Tapped on wrong color tile (should not tap on wrong colors)
        _handleWrongColorTap();
      }
    } else {
      // Wrong tap - end turn immediately with penalty time as score
      _handleWrongTap();
    }
  }

  void _handleWrongTap() {
    // Mark that this round had a penalty
    _hadPenaltyThisRound = true;

    // Record penalty time (1000ms) as the score for this turn
    _turnTimesMs.add(_wrongTapPenaltyMs);
    _tappedTurnTimesMs.add(_wrongTapPenaltyMs);

    // Check if we've completed 3 taps - if so, end round immediately
    if (_tappedTurnTimesMs.length >= 3) {
      _turnTimeoutTimer?.cancel();
      _overlayTimer?.cancel();
      setState(() {
        _errorMessage = 'PENALTY +1 SECOND';
      });
      _overlayTimer = Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() => _errorMessage = null);
        _endRoundEarly();
      });
      return;
    }

    setState(() {
      _errorMessage = 'PENALTY +1 SECOND';
    });

    _turnTimeoutTimer?.cancel();
    _overlayTimer?.cancel();

    // Show error briefly, then advance to next turn
    _overlayTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _errorMessage = null);
      _advanceTurn(isTimeout: false);
    });
  }

  void _handleWrongColorTap() {
    // Mark that this round had a penalty
    _hadPenaltyThisRound = true;

    // User tapped on a wrong color tile - add penalty and advance to next turn
    // Record penalty time (1000ms) as the score for this turn
    _turnTimesMs.add(_wrongTapPenaltyMs);
    _tappedTurnTimesMs.add(_wrongTapPenaltyMs);

    // Check if we've completed 3 taps - if so, end round immediately
    if (_tappedTurnTimesMs.length >= 3) {
      _turnTimeoutTimer?.cancel();
      _overlayTimer?.cancel();
      setState(() {
        _errorMessage = 'PENALTY +1 SECOND';
      });
      _overlayTimer = Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() => _errorMessage = null);
        _endRoundEarly();
      });
      return;
    }

    setState(() {
      _errorMessage = 'PENALTY +1 SECOND';
    });

    _turnTimeoutTimer?.cancel();
    _overlayTimer?.cancel();

    // Show error briefly, then advance to next turn
    _overlayTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _errorMessage = null);
      _advanceTurn(isTimeout: false);
    });
  }

  void _applyPenalty({bool showUi = true}) {
    // This is now only used for timeout penalties (silent)
    setState(() {
      _currentTurnPenaltyMs += _wrongTapPenaltyMs;
    });
  }

  void _endRoundEarly() {
    _turnTimeoutTimer?.cancel();
    _turnStartDelayTimer?.cancel();
    _overlayTimer?.cancel();

    // Calculate average of only the tapped turns (up to 3)
    final roundAvg = _tappedTurnTimesMs.isEmpty
        ? 0
        : (_tappedTurnTimesMs.reduce((a, b) => a + b) ~/
              _tappedTurnTimesMs.length);

    _roundResults.add(
      RoundResult(
        roundNumber: _currentRound,
        reactionTime: roundAvg,
        isFailed: _hadTimeoutThisRound || _hadPenaltyThisRound,
      ),
    );

    setState(() {
      _isRoundActive = false;
      _completedRounds++;
      _reactionTimeMessage = '$roundAvg ms';
      _activeIndex = null;
      _currentDisplayColor = null;
    });

    _overlayTimer = Timer(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      setState(() => _reactionTimeMessage = null);
      _startNextRound();
    });
  }

  void _advanceTurn({required bool isTimeout}) {
    _turnTimeoutTimer?.cancel();

    _currentTurnInRound++;
    if (_currentTurnInRound < _turnsPerRound) {
      // Next turn: same target color, new random tile
      _startTurn();
      return;
    }

    // Round completed normally (all 7 turns done): store average of only tapped turns (up to 3)
    final roundAvg = _tappedTurnTimesMs.isEmpty
        ? 0
        : (_tappedTurnTimesMs.reduce((a, b) => a + b) ~/
              _tappedTurnTimesMs.length);

    _roundResults.add(
      RoundResult(
        roundNumber: _currentRound,
        reactionTime: roundAvg,
        isFailed: _hadTimeoutThisRound || _hadPenaltyThisRound,
      ),
    );

    setState(() {
      _isRoundActive = false;
      _completedRounds++;
      _reactionTimeMessage = '$roundAvg ms';
      _activeIndex = null;
      _currentDisplayColor = null;
    });

    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      setState(() => _reactionTimeMessage = null);
      _startNextRound();
    });
  }

  Future<void> _endGame() async {
    _roundDelayTimer?.cancel();
    _turnStartDelayTimer?.cancel();
    _turnTimeoutTimer?.cancel();
    _overlayTimer?.cancel();

    setState(() {
      _isPlaying = false;
      _isWaitingForRound = false;
      _isRoundActive = false;
      _isWaitingForTurn = false;
      _activeIndex = null;
      _currentDisplayColor = null;
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
        'catch_color',
      );
      final session = GameSession(
        gameId: 'catch_color',
        gameName: 'Catch Color',
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
    final activeIndex = _isWaitingForTurn
        ? null
        : _activeIndex; // Hide color during 1-second delay
    final displayColor =
        _currentDisplayColor; // Use current display color (could be target or wrong)

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
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _gridSize,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _gridSize * _gridSize,
                  itemBuilder: (context, index) {
                    final isActive = activeIndex == index && displayColor != null;
                    return GestureDetector(
                      onTap: () => _handleTileTap(index),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isActive ? displayColor : Colors.white,
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
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        //DONT REMOVE THIS CODE. WE WILL USE IN FUTURE
        // Padding(
        //   padding: const EdgeInsets.only(bottom: 4),
        //   child: Text(
        //     _isRoundActive
        //         ? 'TURN ${_currentTurnInRound + 1} / $_turnsPerRound'
        //         : '',
        //     style: const TextStyle(
        //       fontSize: 12,
        //       fontWeight: FontWeight.w800,
        //       letterSpacing: 2.0,
        //       color: Color(0xFF94A3B8),
        //     ),
        //   ),
        // ),
      ],
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
        gameName: 'Catch Color',
        categoryName: widget.categoryName ?? 'Visual',
        gameId: 'catch_color',
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
          if (!s.isPlaying) return 'Catch the correct color';
          if (s.isWaiting) return 'Wait...';
          if (s.isRoundActive) return 'TAP NOW!';
          return 'Round ${s.currentRound}';
        },
        contentBuilder: (s, context) {
          if (s.isRoundActive) {
            return Positioned.fill(child: _buildGrid());
          }
          // idle background similar to FindColor
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
