import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../game_settings.dart';
import '../models/round_result.dart';
import '../models/game_session.dart';
import '../services/game_history_service.dart';
import '../widgets/game_container.dart';
import '../widgets/category_header.dart';
import '../widgets/gradient_background.dart';
import 'color_change_results_page.dart';

class FindNumberPage extends StatefulWidget {
  final String? categoryName;

  const FindNumberPage({super.key, this.categoryName});

  @override
  State<FindNumberPage> createState() => _FindNumberPageState();
}

class _FindNumberPageState extends State<FindNumberPage> {
  int _currentRound = 0;
  int _completedRounds = 0;
  int _bestSession = 240; // in milliseconds
  bool _isPlaying = false;
  bool _isWaitingForRound = false;
  bool _isRoundActive = false;
  int? _targetNumber;
  String? _targetNumberWord;
  List<int> _gridNumbers = [];
  DateTime? _roundStartTime;
  Timer? _delayTimer;
  Timer? _errorDisplayTimer;
  Timer? _reactionTimeDisplayTimer;
  String? _errorMessage;
  String? _reactionTimeMessage;
  List<RoundResult> _roundResults = [];

  // Number word mapping
  final Map<int, String> _numberWords = {
    0: 'ZERO',
    1: 'ONE',
    2: 'TWO',
    3: 'THREE',
    4: 'FOUR',
    5: 'FIVE',
    6: 'SIX',
    7: 'SEVEN',
    8: 'EIGHT',
    9: 'NINE',
  };

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
    _targetNumber = null;
    _targetNumberWord = null;
    _gridNumbers.clear();
    _roundStartTime = null;
    _errorMessage = null;
    _reactionTimeMessage = null;
    _roundResults.clear();
    _delayTimer?.cancel();
    _errorDisplayTimer?.cancel();
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

    setState(() {
      _currentRound++;
      _isWaitingForRound = true;
      _isRoundActive = false;
      _targetNumber = null;
      _targetNumberWord = null;
      _gridNumbers.clear();
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

    // Generate random target number (0-9)
    _targetNumber = random.nextInt(10);
    _targetNumberWord = _numberWords[_targetNumber];

    // Generate grid with random numbers 0-9 (ensuring target is included)
    final numbers = List.generate(10, (index) => index);
    numbers.shuffle(random);
    _gridNumbers = numbers.take(9).toList();

    // Ensure target number is in the grid
    if (!_gridNumbers.contains(_targetNumber)) {
      _gridNumbers[random.nextInt(9)] = _targetNumber!;
    }

    // Shuffle again to randomize position
    _gridNumbers.shuffle(random);

    setState(() {
      _isWaitingForRound = false;
      _isRoundActive = true;
      _roundStartTime = DateTime.now();
    });
  }

  void _handleNumberTap(int tappedNumber) {
    if (!_isRoundActive || _roundStartTime == null) return;

    if (tappedNumber == _targetNumber) {
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
    setState(() {
      _errorMessage = 'PENALTY +1 SECOND';
      _isRoundActive = false;
    });

    // Mark round as failed with penalty
    _roundResults.add(
      RoundResult(
        roundNumber: _currentRound,
        reactionTime: 1000, // 1 second penalty
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

  Widget _buildNumberCell(int number) {
    return GestureDetector(
      onTap: () => _handleNumberTap(number),
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
            number.toString(),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
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
        'find_number',
      );
      final session = GameSession(
        gameId: 'find_number',
        gameName: 'Find Number',
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
    return Scaffold(
      backgroundColor: GradientBackground.backgroundColor,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'FIND NUMBER',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const Spacer(),
                    ValueListenableBuilder<int>(
                      valueListenable: GameSettings.repetitionsNotifier,
                      builder: (context, numberOfRepetitions, _) {
                        return Row(
                          children: [
                            Text(
                              _isPlaying
                                  ? '$_completedRounds / $numberOfRepetitions'
                                  : '0 / $numberOfRepetitions',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: () {
                                _resetGame();
                                setState(() {});
                              },
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.4),
                                shape: const CircleBorder(),
                                padding: const EdgeInsets.all(8),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              // Main content
              Expanded(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // Category header
                    CategoryHeader(
                      categoryName: widget.categoryName ?? 'Memory',
                    ),
                    const SizedBox(height: 4),
                    // Title
                    Text(
                      _isPlaying
                          ? (_isWaitingForRound
                                ? 'Wait for the number...'
                                : (_isRoundActive
                                      ? 'TAP NOW!'
                                      : 'Round $_currentRound'))
                          : 'Tap the correct number',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    // Game content area
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(35, 20, 35, 20),
                        child: GameContainer(
                          child: Stack(
                            children: [
                              // Main content - Column for active round, gradient for idle
                              if (_isRoundActive && _gridNumbers.isNotEmpty)
                                Column(
                                  children: [
                                    // Target number word banner
                                    if (_targetNumberWord != null)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          12,
                                          12,
                                          12,
                                          8,
                                        ),
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF475569),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.1,
                                                ),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            _targetNumberWord!,
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
                                    // Number grid - fills remaining space
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          children: [
                                            // Row 1
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            3,
                                                          ),
                                                      child: _buildNumberCell(
                                                        _gridNumbers[0],
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            3,
                                                          ),
                                                      child: _buildNumberCell(
                                                        _gridNumbers[1],
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            3,
                                                          ),
                                                      child: _buildNumberCell(
                                                        _gridNumbers[2],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Row 2
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            3,
                                                          ),
                                                      child: _buildNumberCell(
                                                        _gridNumbers[3],
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            3,
                                                          ),
                                                      child: _buildNumberCell(
                                                        _gridNumbers[4],
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            3,
                                                          ),
                                                      child: _buildNumberCell(
                                                        _gridNumbers[5],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Row 3
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            3,
                                                          ),
                                                      child: _buildNumberCell(
                                                        _gridNumbers[6],
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            3,
                                                          ),
                                                      child: _buildNumberCell(
                                                        _gridNumbers[7],
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            3,
                                                          ),
                                                      child: _buildNumberCell(
                                                        _gridNumbers[8],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Positioned.fill(
                                  child: Container(
                                    decoration: !_isRoundActive && !_isPlaying
                                        ? BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                const Color(
                                                  0xFFDBEAFE,
                                                ).withOpacity(0.4),
                                                const Color(
                                                  0xFFE2E8F0,
                                                ).withOpacity(0.4),
                                                const Color(
                                                  0xFFFCE7F3,
                                                ).withOpacity(0.4),
                                              ],
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                              // Waiting state
                              if (_isWaitingForRound)
                                const Center(
                                  child: Text(
                                    'WAIT...',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF94A3B8),
                                      letterSpacing: 4.0,
                                    ),
                                  ),
                                ),
                              // Error message overlay
                              if (_errorMessage != null)
                                Positioned.fill(
                                  child: Container(
                                    color: Colors.red.withOpacity(0.9),
                                    child: Center(
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: 2.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              // Reaction time message
                              if (_reactionTimeMessage != null)
                                Positioned.fill(
                                  child: Container(
                                    color: Colors.green.withOpacity(0.8),
                                    child: Center(
                                      child: Text(
                                        _reactionTimeMessage!,
                                        style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: 2.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              // Start button
                              if (!_isPlaying &&
                                  _errorMessage == null &&
                                  _reactionTimeMessage == null)
                                Center(
                                  child: GestureDetector(
                                    onTap: _startGame,
                                    child: const Text(
                                      'START',
                                      style: TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 4.0,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Best session indicator
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(999),
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
                          borderRadius: BorderRadius.circular(999),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFDBEAFE),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFFDBEAFE,
                                        ).withOpacity(0.8),
                                        blurRadius: 8,
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'BEST SESSION: ${_bestSession}MS',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Bottom indicator
              // Padding(
              //   padding: const EdgeInsets.only(bottom: 32),
              //   child: Row(
              //     mainAxisAlignment: MainAxisAlignment.center,
              //     children: [
              //       Container(
              //         width: 6,
              //         height: 6,
              //         decoration: BoxDecoration(
              //           shape: BoxShape.circle,
              //           color: const Color(0xFFCBD5E1),
              //         ),
              //       ),
              //       const SizedBox(width: 12),
              //       Container(
              //         width: 6,
              //         height: 6,
              //         decoration: BoxDecoration(
              //           shape: BoxShape.circle,
              //           color: const Color(0xFFCBD5E1),
              //         ),
              //       ),
              //       const SizedBox(width: 12),
              //       Container(
              //         width: 40,
              //         height: 6,
              //         decoration: BoxDecoration(
              //           borderRadius: BorderRadius.circular(3),
              //           color: const Color(0xFF94A3B8),
              //           boxShadow: [
              //             BoxShadow(
              //               color: Colors.black.withOpacity(0.1),
              //               blurRadius: 4,
              //               offset: const Offset(0, 2),
              //             ),
              //           ],
              //         ),
              //       ),
              //     ],
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
