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
  static const int _turnsPerRound = 3;
  static const int _turnTimeLimitMs = 3000; // user said "3 ms" -> treated as 3 seconds
  static const int _wrongTapPenaltyMs = 1000;

  int _currentRound = 0;
  int _completedRounds = 0;
  int _bestSession = 240; // ms

  bool _isPlaying = false;
  bool _isWaitingForRound = false;
  bool _isRoundActive = false;

  Color? _targetColor;
  String? _targetColorName;

  int? _activeIndex; // which tile currently shows the color
  int _currentTurnInRound = 0; // 0..2
  int _currentTurnPenaltyMs = 0;
  DateTime? _turnStartTime;
  Timer? _roundDelayTimer;
  Timer? _turnTimeoutTimer;
  Timer? _overlayTimer;
  bool _hadTimeoutThisRound = false;
  DateTime? _lastPenaltyUiShownAt;

  String? _errorMessage;
  String? _reactionTimeMessage;

  final List<int> _turnTimesMs = [];
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
    _turnTimeoutTimer?.cancel();
    _overlayTimer?.cancel();
    super.dispose();
  }

  void _resetGame() {
    _roundDelayTimer?.cancel();
    _turnTimeoutTimer?.cancel();
    _overlayTimer?.cancel();

    _currentRound = 0;
    _completedRounds = 0;
    _isPlaying = false;
    _isWaitingForRound = false;
    _isRoundActive = false;
    _targetColor = null;
    _targetColorName = null;
    _activeIndex = null;
    _currentTurnInRound = 0;
    _currentTurnPenaltyMs = 0;
    _turnStartTime = null;
    _errorMessage = null;
    _reactionTimeMessage = null;
    _turnTimesMs.clear();
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
    _turnTimeoutTimer?.cancel();
    _overlayTimer?.cancel();

    setState(() {
      _currentRound++;
      _isWaitingForRound = true;
      _isRoundActive = false;
      _errorMessage = null;
      _reactionTimeMessage = null;
      _turnTimesMs.clear();
      _currentTurnInRound = 0;
      _currentTurnPenaltyMs = 0;
      _turnStartTime = null;
      _activeIndex = null;
      _hadTimeoutThisRound = false;
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

    setState(() {
      _isWaitingForRound = false;
      _isRoundActive = true;
    });

    _startTurn();
  }

  void _startTurn() {
    _turnTimeoutTimer?.cancel();

    setState(() {
      _currentTurnPenaltyMs = 0;
      _turnStartTime = DateTime.now();
      _activeIndex = _rand.nextInt(_gridSize * _gridSize);
    });

    _turnTimeoutTimer = Timer(
      const Duration(milliseconds: _turnTimeLimitMs),
      _handleTurnTimeout,
    );
  }

  void _handleTurnTimeout() {
    if (!mounted || !_isRoundActive || _turnStartTime == null) return;

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
  }

  void _handleTileTap(int index) {
    if (!_isRoundActive || _turnStartTime == null || _activeIndex == null) {
      return;
    }

    if (index == _activeIndex) {
      // Correct tap - calculate reaction time
      final rt =
          DateTime.now().difference(_turnStartTime!).inMilliseconds +
              _currentTurnPenaltyMs;
      _turnTimesMs.add(rt);
      _advanceTurn(isTimeout: false);
    } else {
      // Wrong tap - end turn immediately with penalty time as score
      _handleWrongTap();
    }
  }

  void _handleWrongTap() {
    // Record penalty time (1000ms) as the score for this turn
    _turnTimesMs.add(_wrongTapPenaltyMs);
    
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

  void _advanceTurn({required bool isTimeout}) {
    _turnTimeoutTimer?.cancel();

    _currentTurnInRound++;
    if (_currentTurnInRound < _turnsPerRound) {
      // Next turn: same target color, new random tile
      _startTurn();
      return;
    }

    // Round completed: store average of the 3 turns as the round's reaction time
    final roundAvg = _turnTimesMs.isEmpty
        ? 0
        : (_turnTimesMs.reduce((a, b) => a + b) ~/ _turnTimesMs.length);

    _roundResults.add(
      RoundResult(
        roundNumber: _currentRound,
        reactionTime: roundAvg,
        isFailed: _hadTimeoutThisRound,
      ),
    );

    setState(() {
      _isRoundActive = false;
      _completedRounds++;
      _reactionTimeMessage = '$roundAvg ms';
      _activeIndex = null;
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
    _turnTimeoutTimer?.cancel();
    _overlayTimer?.cancel();

    setState(() {
      _isPlaying = false;
      _isWaitingForRound = false;
      _isRoundActive = false;
      _activeIndex = null;
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
      final sessionNumber =
          await GameHistoryService.getNextSessionNumber('catch_color');
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
    final activeIndex = _activeIndex;
    final targetColor = _targetColor;

    return Column(
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
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _gridSize,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _gridSize * _gridSize,
              itemBuilder: (context, index) {
                final isActive = activeIndex == index && targetColor != null;
                return GestureDetector(
                  onTap: () => _handleTileTap(index),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isActive ? targetColor : Colors.white,
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
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            _isRoundActive
                ? 'TURN ${_currentTurnInRound + 1} / $_turnsPerRound'
                : '',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
              color: Color(0xFF94A3B8),
            ),
          ),
        ),
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
            return _buildGrid();
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

