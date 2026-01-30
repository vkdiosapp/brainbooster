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

class StickData {
  final double x;
  double y;
  final double length;
  final double width;
  final double speed;
  final int index;
  bool isActive;

  StickData({
    required this.x,
    required this.y,
    required this.length,
    required this.width,
    required this.speed,
    required this.index,
    this.isActive = true,
  });
}

class DropStickPage extends StatefulWidget {
  final String? categoryName;
  final String? exerciseName;

  const DropStickPage({super.key, this.categoryName, this.exerciseName});

  @override
  State<DropStickPage> createState() => _DropStickPageState();
}

class _DropStickPageState extends State<DropStickPage> {
  // Get penalty time from exercise data (exercise ID 31)
  late final int _wrongTapPenaltyMs = ExerciseData.getExercises()
      .firstWhere(
        (e) => e.id == 31,
        orElse: () => ExerciseData.getExercises().first,
      )
      .penaltyTime;

  int _currentRound = 0;
  int _completedRounds = 0;
  int _bestSession = 240; // ms

  bool _isPlaying = false;
  bool _isWaitingForRound = false;
  bool _isRoundActive = false;

  final List<StickData> _sticks = [];
  Size? _containerSize;
  DateTime? _roundStartTime;
  DateTime? _lastTickTime;

  Timer? _roundDelayTimer;
  Timer? _dropTimer;
  Timer? _startDropTimer;
  Timer? _overlayTimer;
  int? _droppingIndex;

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
    _dropTimer?.cancel();
    _startDropTimer?.cancel();
    _overlayTimer?.cancel();
    super.dispose();
  }

  void _resetGame() {
    _roundDelayTimer?.cancel();
    _dropTimer?.cancel();
    _startDropTimer?.cancel();
    _overlayTimer?.cancel();

    _currentRound = 0;
    _completedRounds = 0;
    _isPlaying = false;
    _isWaitingForRound = false;
    _isRoundActive = false;
    _sticks.clear();
    _roundStartTime = null;
    _lastTickTime = null;
    _droppingIndex = null;
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
    _dropTimer?.cancel();
    _startDropTimer?.cancel();
    _overlayTimer?.cancel();

    setState(() {
      _currentRound++;
      _isWaitingForRound = true;
      _isRoundActive = false;
      _sticks.clear();
      _roundStartTime = null;
      _lastTickTime = null;
      _droppingIndex = null;
      _errorMessage = null;
      _reactionTimeMessage = null;
    });

    _roundDelayTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _isWaitingForRound = false;
        _isRoundActive = true;
      });
      _tryStartDropping();
    });
  }

  void _tryStartDropping() {
    if (!_isRoundActive || _containerSize == null || _sticks.isNotEmpty) {
      return;
    }

    _generateSticks(_containerSize!);
    _scheduleNextDrop(const Duration(milliseconds: 1100));

    _dropTimer?.cancel();
    _dropTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted || !_isRoundActive || _containerSize == null) return;
      _tickDrop();
    });
  }

  void _scheduleNextDrop(Duration delay) {
    _startDropTimer?.cancel();
    _startDropTimer = Timer(delay, () {
      if (!mounted || !_isRoundActive) return;
      _startRandomDrop();
    });
  }

  void _startRandomDrop() {
    final activeIndices = _sticks
        .where((stick) => stick.isActive)
        .map((stick) => stick.index)
        .toList(growable: false);
    if (activeIndices.isEmpty) {
      _completeRound();
      return;
    }
    _droppingIndex = activeIndices[_rand.nextInt(activeIndices.length)];
    _roundStartTime ??= DateTime.now();
    _lastTickTime = DateTime.now();
    setState(() {});
  }

  void _tickDrop() {
    final now = DateTime.now();
    final last = _lastTickTime ?? now;
    final deltaSeconds =
        now.difference(last).inMilliseconds.clamp(0, 1000) / 1000.0;
    _lastTickTime = now;

    if (deltaSeconds <= 0 || _containerSize == null) return;

    if (_droppingIndex == null) {
      return;
    }

    final stickIndex = _droppingIndex!;
    if (stickIndex < 0 || stickIndex >= _sticks.length) {
      _droppingIndex = null;
      _scheduleNextDrop(const Duration(milliseconds: 200));
      return;
    }

    final stick = _sticks[stickIndex];
    if (!stick.isActive) {
      _droppingIndex = null;
      _scheduleNextDrop(const Duration(milliseconds: 200));
      return;
    }

    final bottomLimit = _containerSize!.height - 12;
    stick.y += stick.speed * deltaSeconds;
    if (stick.y + stick.length >= bottomLimit) {
      SoundService.playPenaltySound();
      _handleMissedStick();
      return;
    }

    setState(() {});
  }

  void _generateSticks(Size size) {
    _sticks.clear();

    const totalSticks = 6;
    const spacing = 20.0;
    const horizontalPadding = 15.0;
    final availableWidth = (size.width - horizontalPadding * 2).clamp(
      1.0,
      size.width,
    );
    final stickWidth =
        (availableWidth - (totalSticks - 1) * spacing) / totalSticks;
    final startX = horizontalPadding;
    final stickLength = (size.height * 0.18).clamp(60.0, 140.0);
    final baseSpeed = (size.height * 0.65).clamp(260.0, 420.0);

    for (int i = 0; i < totalSticks; i++) {
      final length = stickLength;
      final x = startX + i * (stickWidth + spacing);
      final y = 16.0;
      final speed = baseSpeed + _rand.nextDouble() * 180;

      _sticks.add(
        StickData(
          x: x,
          y: y,
          length: length,
          width: stickWidth,
          speed: speed,
          index: i,
        ),
      );
    }

    setState(() {});
  }

  void _handleStickTap(StickData stick) {
    if (!_isRoundActive || !stick.isActive) return;
    if (_droppingIndex == null || stick.index != _droppingIndex) return;
    SoundService.playTapSound();

    setState(() {
      stick.isActive = false;
      _droppingIndex = null;
    });

    final remaining = _sticks
        .where((element) => element.isActive)
        .toList(growable: false);
    if (remaining.isEmpty) {
      _completeRound();
    } else {
      _scheduleNextDrop(const Duration(milliseconds: 200));
    }
  }

  void _handleMissedStick() {
    _overlayTimer?.cancel();
    _dropTimer?.cancel();
    _startDropTimer?.cancel();

    final roundTime = _wrongTapPenaltyMs;
    _roundResults.add(
      RoundResult(
        roundNumber: _currentRound,
        reactionTime: roundTime,
        isFailed: true,
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
    _dropTimer?.cancel();
    _startDropTimer?.cancel();

    final roundTime = _roundStartTime == null
        ? 0
        : DateTime.now().difference(_roundStartTime!).inMilliseconds;

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
    _dropTimer?.cancel();
    _startDropTimer?.cancel();
    _overlayTimer?.cancel();

    setState(() {
      _isPlaying = false;
      _isWaitingForRound = false;
      _isRoundActive = false;
    });

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
        'drop_stick',
      );
      final session = GameSession(
        gameId: 'drop_stick',
        gameName: 'Drop Stick',
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
              gameName: widget.exerciseName ?? 'Drop Stick',
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
        _containerSize = Size(containerWidth, containerHeight);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _tryStartDropping();
        });

        if (_sticks.isEmpty) {
          return const SizedBox.shrink();
        }

        return Stack(
          children: _sticks.where((stick) => stick.isActive).map((stick) {
            return Positioned(
              left: stick.x,
              top: stick.y,
              child: GestureDetector(
                onTap: () => _handleStickTap(stick),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: stick.width,
                  height: stick.length,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
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
        gameName: 'DROP STICK',
        categoryName: widget.categoryName ?? 'Visual',
        gameId: 'drop_stick',
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
            return 'Tap falling sticks before falling down.';
          }
          if (s.isWaiting) {
            return 'WAIT...';
          }
          if (s.isRoundActive) {
            return 'TAP ALL STICKS!';
          }
          return 'Round ${s.currentRound}';
        },
        contentBuilder: (s, context) {
          if (s.isRoundActive) {
            return Positioned.fill(child: _buildGameContainer());
          }
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
