import 'dart:async';
import 'package:flutter/material.dart';

import '../data/exercise_data.dart';
import '../game_settings.dart';
import '../models/game_session.dart';
import '../models/round_result.dart';
import '../services/game_history_service.dart';
import '../theme/app_theme.dart';
import '../widgets/base_game_page.dart';
import '../widgets/difficulty_selector.dart';
import 'color_change_results_page.dart';

class TicTacToePage extends StatefulWidget {
  final String? categoryName;
  final String? exerciseName;

  const TicTacToePage({super.key, this.categoryName, this.exerciseName});

  @override
  State<TicTacToePage> createState() => _TicTacToePageState();
}

class _TicTacToePageState extends State<TicTacToePage>
    with SingleTickerProviderStateMixin {
  static const String _player = 'X';
  static const String _computer = 'O';
  static const Duration _roundDelay = Duration(milliseconds: 500);
  static const Duration _computerDelay = Duration(milliseconds: 400);
  static const Duration _overlayDuration = Duration(milliseconds: 1500);
  static const double _gridPadding = 20;
  static const double _gridSpacing = 8;

  bool _isAdvanced = false; // false = Normal (3x3), true = Advanced (5x5)
  int get _gridSize => _isAdvanced ? 5 : 3;
  int get _cellCount => _gridSize * _gridSize;

  List<List<int>> _getWinningLines() {
    if (_gridSize == 3) {
      return const [
        [0, 1, 2],
        [3, 4, 5],
        [6, 7, 8],
        [0, 3, 6],
        [1, 4, 7],
        [2, 5, 8],
        [0, 4, 8],
        [2, 4, 6],
      ];
    }
    // 5x5: win with 3 in a row (all possible length-3 lines)
    const n = 5;
    final lines = <List<int>>[];
    // Rows: 3 consecutive in each row
    for (int row = 0; row < n; row++) {
      for (int start = 0; start <= n - 3; start++) {
        lines.add([row * n + start, row * n + start + 1, row * n + start + 2]);
      }
    }
    // Columns: 3 consecutive in each column
    for (int col = 0; col < n; col++) {
      for (int start = 0; start <= n - 3; start++) {
        lines.add([
          start * n + col,
          (start + 1) * n + col,
          (start + 2) * n + col,
        ]);
      }
    }
    // Diagonals top-left to bottom-right (length >= 3)
    for (int row = 0; row <= n - 3; row++) {
      for (int col = 0; col <= n - 3; col++) {
        lines.add([
          row * n + col,
          (row + 1) * n + (col + 1),
          (row + 2) * n + (col + 2),
        ]);
      }
    }
    // Diagonals top-right to bottom-left (length >= 3)
    for (int row = 0; row <= n - 3; row++) {
      for (int col = 2; col < n; col++) {
        lines.add([
          row * n + col,
          (row + 1) * n + (col - 1),
          (row + 2) * n + (col - 2),
        ]);
      }
    }
    return lines;
  }

  int _currentRound = 0;
  int _completedRounds = 0;
  int _bestSession = 0; // best average time in ms (lower is better)

  bool _isPlaying = false;
  bool _isWaitingForRound = false;
  bool _isRoundActive = false;
  bool _isPlayerTurn = true;

  DateTime? _roundStartTime;
  Timer? _roundDelayTimer;
  Timer? _computerMoveTimer;
  Timer? _overlayTimer;
  Timer? _messageDelayTimer;

  late final AnimationController _lineController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  String? _errorMessage;
  String? _reactionTimeMessage;
  List<int>? _winningLine;
  Color? _winningLineColor;

  final List<RoundResult> _roundResults = [];
  late List<String?> _board;
  late final int _lossPenaltyMs = ExerciseData.getExercises()
      .firstWhere(
        (e) => e.id == 30,
        orElse: () => ExerciseData.getExercises().first,
      )
      .penaltyTime;

  @override
  void initState() {
    super.initState();
    _resetGame();
  }

  @override
  void dispose() {
    _roundDelayTimer?.cancel();
    _computerMoveTimer?.cancel();
    _overlayTimer?.cancel();
    _messageDelayTimer?.cancel();
    _lineController.dispose();
    super.dispose();
  }

  void _resetGame() {
    _roundDelayTimer?.cancel();
    _computerMoveTimer?.cancel();
    _overlayTimer?.cancel();
    _messageDelayTimer?.cancel();

    _currentRound = 0;
    _completedRounds = 0;
    _isPlaying = false;
    _isWaitingForRound = false;
    _isRoundActive = false;
    _isPlayerTurn = true;
    _roundStartTime = null;
    _errorMessage = null;
    _reactionTimeMessage = null;
    _winningLine = null;
    _winningLineColor = null;
    _roundResults.clear();
    _board = List.filled(_cellCount, null);
    _lineController.reset();
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
    _computerMoveTimer?.cancel();
    _overlayTimer?.cancel();
    _messageDelayTimer?.cancel();

    setState(() {
      _currentRound++;
      _isWaitingForRound = true;
      _isRoundActive = false;
      _isPlayerTurn = true;
      _board = List.filled(_cellCount, null);
      _roundStartTime = null;
      _errorMessage = null;
      _reactionTimeMessage = null;
      _winningLine = null;
      _winningLineColor = null;
    });
    _lineController.reset();

    _roundDelayTimer = Timer(_roundDelay, () {
      if (!mounted) return;
      _beginRound();
    });
  }

  void _beginRound() {
    setState(() {
      _isWaitingForRound = false;
      _isRoundActive = true;
      _roundStartTime = DateTime.now();
      _isPlayerTurn = true;
    });
  }

  void _handleCellTap(int index) {
    if (!_isRoundActive || !_isPlaying || !_isPlayerTurn) return;
    if (_board[index] != null) return;

    setState(() {
      _board[index] = _player;
    });

    final outcome = _evaluateBoard();
    if (outcome != null) {
      _finishRound(outcome);
      return;
    }

    setState(() {
      _isPlayerTurn = false;
    });

    _computerMoveTimer?.cancel();
    _computerMoveTimer = Timer(_computerDelay, () {
      if (!mounted || !_isRoundActive) return;
      _makeComputerMove();
    });
  }

  void _makeComputerMove() {
    final move = _pickComputerMove();
    if (move == null) return;

    setState(() {
      _board[move] = _computer;
    });

    final outcome = _evaluateBoard();
    if (outcome != null) {
      _finishRound(outcome);
      return;
    }

    setState(() {
      _isPlayerTurn = true;
    });
  }

  int? _pickComputerMove() {
    final available = _availableMoves();
    if (available.isEmpty) return null;

    // Win if possible
    for (final move in available) {
      if (_isWinningMove(move, _computer)) return move;
    }
    // Block player win
    for (final move in available) {
      if (_isWinningMove(move, _player)) return move;
    }
    // Center (index 4 for 3x3, 12 for 5x5)
    final center = _gridSize == 3 ? 4 : 12;
    if (available.contains(center)) return center;
    // Corners
    final corners = _gridSize == 3 ? [0, 2, 6, 8] : [0, 4, 20, 24]
      ..shuffle();
    for (final move in corners) {
      if (available.contains(move)) return move;
    }
    // Any remaining
    available.shuffle();
    return available.first;
  }

  bool _isWinningMove(int move, String symbol) {
    final tempBoard = List<String?>.from(_board);
    tempBoard[move] = symbol;
    return _checkWinner(tempBoard) == symbol;
  }

  List<int> _availableMoves() {
    final moves = <int>[];
    for (int i = 0; i < _board.length; i++) {
      if (_board[i] == null) moves.add(i);
    }
    return moves;
  }

  String? _evaluateBoard() {
    final winner = _checkWinner(_board);
    if (winner != null) return winner;
    if (_availableMoves().isEmpty) return 'draw';
    return null;
  }

  String? _checkWinner(List<String?> board) {
    final winningLines = _getWinningLines();
    for (final line in winningLines) {
      final first = board[line[0]];
      if (first == null) continue;
      bool win = true;
      for (int i = 1; i < line.length; i++) {
        if (board[line[i]] != first) {
          win = false;
          break;
        }
      }
      if (win) return first;
    }
    return null;
  }

  List<int>? _findWinningLine(List<String?> board) {
    final winningLines = _getWinningLines();
    for (final line in winningLines) {
      final first = board[line[0]];
      if (first == null) continue;
      bool win = true;
      for (int i = 1; i < line.length; i++) {
        if (board[line[i]] != first) {
          win = false;
          break;
        }
      }
      if (win) return line;
    }
    return null;
  }

  void _finishRound(String outcome) {
    _computerMoveTimer?.cancel();
    _overlayTimer?.cancel();
    _messageDelayTimer?.cancel();

    final endTime = DateTime.now();
    final durationMs = _roundStartTime == null
        ? 0
        : endTime.difference(_roundStartTime!).inMilliseconds;

    final bool isFailed = outcome == _computer;
    final int roundTime = isFailed ? _lossPenaltyMs : durationMs;
    if (outcome != 'draw') {
      _winningLine = _findWinningLine(_board);
      _winningLineColor = outcome == _player
          ? const Color(0xFF15803D)
          : const Color(0xFFB91C1C);
      if (_winningLine != null) {
        _lineController.forward(from: 0);
      }
    } else {
      _winningLine = null;
      _winningLineColor = null;
      _lineController.reset();
    }

    _roundResults.add(
      RoundResult(
        roundNumber: _currentRound,
        reactionTime: roundTime,
        isFailed: isFailed,
      ),
    );

    setState(() {
      _isRoundActive = false;
      _completedRounds++;
      _isPlayerTurn = true;
      _reactionTimeMessage = null;
      _errorMessage = null;
    });

    if (outcome == 'draw') {
      setState(() {
        _reactionTimeMessage = 'DRAW - ${roundTime} ms';
      });
      _startOverlayTimer();
      return;
    }

    final lineDelay = _lineController.duration ?? Duration.zero;
    _messageDelayTimer = Timer(lineDelay, () {
      if (!mounted) return;
      setState(() {
        if (outcome == _player) {
          _reactionTimeMessage = 'YOU WIN - ${roundTime} ms';
        } else if (outcome == _computer) {
          _errorMessage = 'YOU LOSE +${_lossPenaltyMs} ms';
        }
      });
      _startOverlayTimer();
    });
  }

  void _startOverlayTimer() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(_overlayDuration, () {
      if (!mounted) return;
      setState(() {
        _reactionTimeMessage = null;
        _errorMessage = null;
        _winningLine = null;
        _winningLineColor = null;
      });
      _lineController.reset();
      _startNextRound();
    });
  }

  Future<void> _endGame() async {
    _roundDelayTimer?.cancel();
    _computerMoveTimer?.cancel();
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
      if (_bestSession == 0 || averageTime < _bestSession) {
        _bestSession = averageTime;
      }
    } else if (_roundResults.isNotEmpty) {
      averageTime =
          _roundResults.map((r) => r.reactionTime).reduce((a, b) => a + b) ~/
          _roundResults.length;
    }

    if (_roundResults.isNotEmpty) {
      final sessionNumber = await GameHistoryService.getNextSessionNumber(
        'tic_tac_toe',
      );
      final session = GameSession(
        gameId: 'tic_tac_toe',
        gameName: 'Tic Tac Toe',
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
              gameName: widget.exerciseName ?? 'Tic Tac Toe',
              gameId: 'tic_tac_toe',
              exerciseId: 30,
            ),
          ),
        )
        .then((_) {
          if (!mounted) return;
          _resetGame();
          setState(() {});
        });
  }

  Widget _buildBoard() {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(_gridPadding),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _gridSize,
                  crossAxisSpacing: _gridSpacing,
                  mainAxisSpacing: _gridSpacing,
                ),
                itemCount: _cellCount,
                itemBuilder: (context, index) {
                  final value = _board[index];
                  final isEnabled =
                      _isRoundActive && _isPlayerTurn && value == null;
                  final textColor = value == _player
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFB91C1C);
                  final fontSize = _gridSize == 3 ? 36.0 : 22.0;

                  return GestureDetector(
                    onTap: isEnabled ? () => _handleCellTap(index) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          _gridSize == 3 ? 16 : 10,
                        ),
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
                      child: Center(
                        child: Text(
                          value ?? '',
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (_winningLine != null && _winningLineColor != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _lineController,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _WinningLinePainter(
                            line: _winningLine!,
                            color: _winningLineColor!,
                            progress: _lineController.value,
                            padding: _gridPadding,
                            spacing: _gridSpacing,
                            gridSize: _gridSize,
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusPill() {
    final text = !_isPlaying
        ? 'READY TO PLAY'
        : _isWaitingForRound
        ? 'GET READY'
        : _isPlayerTurn
        ? 'YOUR TURN'
        : 'COMPUTER TURN';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.buttonBackground(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.borderColor(context), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: AppTheme.textPrimary(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseGamePage(
      config: GamePageConfig(
        gameName: 'Tic Tac Toe',
        categoryName: widget.categoryName ?? 'Logic',
        gameId: 'tic_tac_toe',
        bestSession: _bestSession,
      ),
      state: GameState(
        isPlaying: _isPlaying,
        isWaiting: _isWaitingForRound,
        isRoundActive: _isRoundActive,
        currentRound: _currentRound,
        completedRounds: _completedRounds,
        errorMessage: _errorMessage,
        reactionTimeMessage: _reactionTimeMessage,
      ),
      callbacks: GameCallbacks(
        onStart: _startGame,
        onReset: () {
          _resetGame();
          setState(() {});
        },
      ),
      builders: GameBuilders(
        titleBuilder: (state) {
          if (!state.isPlaying) {
            return _isAdvanced
                ? 'Beat the computer at 5×5 Tic Tac Toe'
                : 'Beat the computer at Tic Tac Toe';
          }
          if (state.isWaiting) {
            return 'GET READY...';
          }
          if (state.isRoundActive) {
            return _isPlayerTurn ? 'YOUR MOVE' : 'COMPUTER THINKING...';
          }
          return 'Round ${state.currentRound}';
        },
        middleContentBuilder: (state, context) {
          if (!state.isPlaying) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
              child: DifficultySelector(
                isAdvanced: _isAdvanced,
                onChanged: (value) {
                  setState(() {
                    _isAdvanced = value;
                  });
                },
                normalLabel: 'Normal',
                advancedLabel: 'Advanced',
              ),
            );
          }
          return _buildStatusPill();
        },
        contentBuilder: (state, context) {
          if (state.isWaiting) {
            return const Positioned.fill(child: SizedBox.shrink());
          }
          return Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Center(child: _buildBoard()),
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

class _WinningLinePainter extends CustomPainter {
  final List<int> line;
  final Color color;
  final double progress;
  final double padding;
  final double spacing;
  final int gridSize;

  const _WinningLinePainter({
    required this.line,
    required this.color,
    required this.progress,
    required this.padding,
    required this.spacing,
    required this.gridSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final totalGaps = (gridSize - 1) * spacing;
    final cellSize = (size.width - (padding * 2) - totalGaps) / gridSize;

    Offset centerForIndex(int index) {
      final row = index ~/ gridSize;
      final col = index % gridSize;
      final dx = padding + col * (cellSize + spacing) + cellSize / 2;
      final dy = padding + row * (cellSize + spacing) + cellSize / 2;
      return Offset(dx, dy);
    }

    final start = centerForIndex(line.first);
    final end = centerForIndex(line.last);
    final current = Offset.lerp(start, end, progress) ?? start;

    final paint = Paint()
      ..color = color
      ..strokeWidth = gridSize == 3 ? 2.0 : 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(start, current, paint);
  }

  @override
  bool shouldRepaint(covariant _WinningLinePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.line != line ||
        oldDelegate.color != color ||
        oldDelegate.gridSize != gridSize;
  }
}
