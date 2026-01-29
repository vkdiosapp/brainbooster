import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../game_settings.dart';
import '../models/game_session.dart';
import '../models/round_result.dart';
import '../services/game_history_service.dart';
import '../services/sound_service.dart';
import '../widgets/base_game_page.dart';
import '../widgets/difficulty_selector.dart';
import '../data/exercise_data.dart';
import 'color_change_results_page.dart';

class MemorizeGamePage extends StatefulWidget {
  final String? categoryName;
  final String? exerciseName;

  const MemorizeGamePage({super.key, this.categoryName, this.exerciseName});

  @override
  State<MemorizeGamePage> createState() => _MemorizeGamePageState();
}

class _MemorizeGamePageState extends State<MemorizeGamePage> {
  // Get penalty time from exercise data (exercise ID 17)
  late final int _wrongTapPenaltyMs = ExerciseData.getExercises()
      .firstWhere(
        (e) => e.id == 17,
        orElse: () => ExerciseData.getExercises().first,
      )
      .penaltyTime;
  static const int _displayDurationMs = 3000; // Show emojis for 3 seconds

  // Normal mode constants
  static const int _normalGridSize = 4; // 4x4 grid
  static const int _normalTotalBoxes = 16; // 4x4 = 16 boxes
  static const int _normalPairsCount = 8; // 8 pairs of emojis

  // Advanced mode constants
  static const int _advancedGridSize = 5; // 5x5 grid
  static const int _advancedTotalBoxes = 25; // 5x5 = 25 boxes
  static const int _advancedPairsCount = 12; // 12 pairs of emojis

  bool _isAdvanced = false; // false = Normal, true = Advanced

  int _currentRound = 0;
  int _completedRounds = 0;
  int _bestSession = 240; // ms

  bool _isPlaying = false;
  bool _isWaitingForRound = false;
  bool _isShowingEmojis = false; // Phase 1: Showing emojis for 3 seconds
  bool _isRoundActive = false; // Phase 2: User can tap black boxes

  // Map position index to emoji (each emoji appears twice)
  Map<int, String> _emojiPositions = {};
  // Map position index to whether it's a red dot (only in advanced)
  Set<int> _redDotPositions = {};
  // Currently opened boxes (for matching)
  List<int> _openedBoxes = [];
  // Matched pairs (stay open)
  Set<int> _matchedPositions = {};
  DateTime? _roundStartTime;
  Timer? _roundDelayTimer;
  Timer? _emojiDisplayTimer;
  Timer? _matchCheckTimer;
  Timer? _overlayTimer;

  String? _errorMessage;
  String? _reactionTimeMessage;

  final List<RoundResult> _roundResults = [];
  final math.Random _rand = math.Random();

  // List of emojis to use (no faces or people)
  static const List<String> _emojis = [
    '🍎',
    '🍌',
    '🍇',
    '🍊',
    '🍋',
    '🍉',
    '🍓',
    '🍑',
    '🥝',
    '🍒',
    '🍐',
    '🥭',
    '🍍',
    '🥥',
    '🥑',
    '🍅',
    '🥕',
    '🌽',
    '🥒',
    '🥬',
    '🥦',
    '🍄',
    '🥔',
    '🍠',
    '🌶️',
    '🫑',
    '🫒',
    '🫐',
    '🫑',
    '🧄',
    '🧅',
    '🥜',
    '🍞',
    '🥐',
    '🥖',
    '🫓',
    '🥨',
    '🥯',
    '🥞',
    '🧇',
    '🍗',
    '🍖',
    '🌭',
    '🍔',
    '🍟',
    '🍕',
    '🥪',
    '🥙',
    '🧆',
    '🌮',
    '🌯',
    '🫔',
    '🥗',
    '🥘',
    '🥫',
    '🍝',
    '🍜',
    '🍲',
    '🍛',
    '🍣',
    '🍱',
    '🥟',
    '🦪',
    '🍤',
    '🍙',
    '🍚',
    '🍘',
    '🍥',
    '🥠',
    '🥮',
    '🍢',
    '🍡',
    '🍧',
    '🍨',
    '🍦',
    '🥧',
    '🧁',
    '🍰',
    '🎂',
    '🍮',
    '🍭',
    '🍬',
    '🍫',
    '🍿',
    '🍩',
    '🍪',
    '🌰',
    '🥜',
    '☕',
    '🍵',
    '🧃',
    '🥤',
    '🍶',
    '🍺',
    '🍻',
    '🥂',
    '🍷',
    '🥃',
    '🍸',
    '🍹',
    '🧉',
    '🍾',
    '🧊',
    '🥄',
    '🐶',
    '🐱',
    '🐭',
    '🐹',
    '🐰',
    '🦊',
    '🐻',
    '🐼',
    '🐨',
    '🐯',
    '🦁',
    '🐮',
    '🐷',
    '🐽',
    '🐸',
    '🐵',
    '🐔',
    '🐧',
    '🐦',
    '🐤',
    '🐣',
    '🐥',
    '🦆',
    '🦅',
    '🦉',
    '🦇',
    '🐺',
    '🐗',
    '🐴',
    '🦄',
    '🐝',
    '🐛',
    '🦋',
    '🐌',
    '🐞',
    '🐜',
    '🦟',
    '🦗',
    '🕷️',
    '🦂',
    '🐢',
    '🐍',
    '🦎',
    '🦖',
    '🦕',
    '🐙',
    '🦑',
    '🦐',
    '🦞',
    '🦀',
    '🐡',
    '🐠',
    '🐟',
    '🐬',
    '🐳',
    '🐋',
    '🦈',
    '🐊',
    '🐅',
    '🐆',
    '🦓',
    '🦍',
    '🦧',
    '🐘',
    '🦛',
    '🦏',
    '🐪',
    '🐫',
    '🦒',
    '🦘',
    '🦬',
    '🐃',
    '🐂',
    '🐄',
    '🐎',
    '🐖',
    '🐏',
    '🐑',
    '🦙',
    '🐐',
    '🦌',
    '🐕',
    '🐩',
    '🦮',
    '🐕‍🦺',
    '🐈',
    '🐓',
    '🦃',
    '🦤',
    '🦚',
    '🦜',
    '🦢',
    '🦩',
    '🕊️',
    '🐇',
    '🦝',
    '🦨',
    '🦡',
    '🦫',
    '🦦',
    '🦥',
    '🐁',
    '🐀',
    '🐿️',
    '🦔',
    '🌲',
    '🌳',
    '🌴',
    '🌵',
    '🌶️',
    '🌾',
    '🌿',
    '☘️',
    '🍀',
    '🍁',
    '🍂',
    '🍃',
    '🌺',
    '🌻',
    '🌹',
    '🌷',
    '🌼',
    '🌸',
    '💐',
    '🌾',
    '🌱',
    '🌿',
    '🍃',
    '🍂',
    '🍁',
    '🍄',
    '🌰',
    '🪵',
    '🪴',
    '🌳',
    '🌴',
    '🌲',
    '🌵',
    '🌊',
    '🌍',
    '🌎',
    '🌏',
    '🌑',
    '🌒',
    '🌓',
    '🌔',
    '🌕',
    '🌖',
    '🌗',
    '🌘',
    '🌙',
    '🌚',
    '🌛',
    '🌜',
    '🌝',
    '🌞',
    '⭐',
    '🌟',
    '💫',
    '✨',
    '⚡',
    '☄️',
    '💥',
    '🔥',
    '🌈',
    '☀️',
    '⛅',
    '☁️',
    '🌦️',
    '🌧️',
    '⛈️',
    '🌩️',
    '❄️',
    '☃️',
    '⛄',
    '🌨️',
    '💧',
    '💦',
    '☔',
    '☂️',
    '🌊',
    '🌫️',
    '🍏',
    '🍎',
    '🎃',
    '🎄',
    '🎆',
    '🎇',
    '✨',
    '🎈',
    '🎉',
    '🎊',
    '🎋',
    '🎍',
    '🎎',
    '🎏',
    '🎐',
    '🎑',
    '🧧',
    '🎀',
    '🎁',
    '🎗️',
    '🎟️',
    '🎫',
    '🎪',
    '🎭',
    '🩰',
    '🎨',
    '🎬',
    '🎤',
    '🎧',
    '🎼',
    '🎵',
    '🎶',
    '🎹',
    '🥁',
    '🎷',
    '🎺',
    '🎸',
    '🪕',
    '🎻',
    '🎲',
    '♟️',
    '🎯',
    '🎳',
    '🎮',
    '🎰',
    '🧩',
    '🚗',
    '🚕',
    '🚙',
    '🚌',
    '🚎',
    '🏎️',
    '🚓',
    '🚑',
    '🚒',
    '🚐',
    '🛻',
    '🚚',
    '🚛',
    '🚜',
    '🏍️',
    '🛵',
    '🚲',
    '🛴',
    '🛹',
    '🛼',
    '🚁',
    '✈️',
    '🛩️',
    '🛫',
    '🛬',
    '🪂',
    '💺',
    '🚀',
    '🛸',
    '🚤',
    '⛵',
    '🛥️',
    '🚢',
    '⚓',
    '⛽',
    '🚧',
    '🚦',
    '🚥',
    '🗺️',
    '🗿',
    '🗽',
    '🗼',
    '🏰',
    '🏯',
    '🏟️',
    '🎡',
    '🎢',
    '🎠',
    '⛲',
    '⛱️',
    '🏖️',
    '🏝️',
    '🏜️',
    '🌋',
    '⛰️',
    '🏔️',
    '🗻',
    '🏕️',
    '⛺',
    '🏠',
    '🏡',
    '🏘️',
    '🏚️',
    '🏗️',
    '🏭',
    '🏢',
    '🏬',
    '🏣',
    '🏤',
    '🏥',
    '🏦',
    '🏨',
    '🏪',
    '🏫',
    '🏩',
    '💒',
    '🏛️',
    '⛪',
    '🕌',
    '🕍',
    '🛕',
    '🕋',
    '⛩️',
    '🛤️',
    '🛣️',
    '🗾',
    '🎑',
    '🏞️',
    '🌅',
    '🌄',
    '🌠',
    '🎇',
    '🎆',
    '🌇',
    '🌆',
    '🏙️',
    '🌃',
    '🌌',
    '🌉',
    '🌁',
  ];

  // Getters for dynamic values based on difficulty
  int get _gridSize => _isAdvanced ? _advancedGridSize : _normalGridSize;
  int get _totalBoxes => _isAdvanced ? _advancedTotalBoxes : _normalTotalBoxes;
  int get _pairsCount => _isAdvanced ? _advancedPairsCount : _normalPairsCount;

  @override
  void initState() {
    super.initState();
    _resetGame();
  }

  @override
  void dispose() {
    _roundDelayTimer?.cancel();
    _emojiDisplayTimer?.cancel();
    _matchCheckTimer?.cancel();
    _overlayTimer?.cancel();
    super.dispose();
  }

  void _resetGame() {
    _roundDelayTimer?.cancel();
    _emojiDisplayTimer?.cancel();
    _matchCheckTimer?.cancel();
    _overlayTimer?.cancel();

    _currentRound = 0;
    _completedRounds = 0;
    _isPlaying = false;
    _isWaitingForRound = false;
    _isShowingEmojis = false;
    _isRoundActive = false;
    _emojiPositions.clear();
    _redDotPositions.clear();
    _openedBoxes.clear();
    _matchedPositions.clear();
    _roundStartTime = null;
    _errorMessage = null;
    _reactionTimeMessage = null;
    _roundResults.clear();
    // Keep _isAdvanced state when resetting
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
    _emojiDisplayTimer?.cancel();
    _matchCheckTimer?.cancel();
    _overlayTimer?.cancel();

    setState(() {
      _currentRound++;
      _isWaitingForRound = true;
      _isShowingEmojis = false;
      _isRoundActive = false;
      _errorMessage = null;
      _reactionTimeMessage = null;
      _emojiPositions.clear();
      _redDotPositions.clear();
      _openedBoxes.clear();
      _matchedPositions.clear();
      _roundStartTime = null;
    });

    _roundDelayTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _showEmojis();
    });
  }

  void _showEmojis() {
    // Generate emoji pairs
    final positions = List.generate(_totalBoxes, (i) => i);
    positions.shuffle(_rand);

    _emojiPositions = {};

    // Select random emojis for pairs
    final selectedEmojis = <String>[];
    final availableEmojis = List<String>.from(_emojis);
    availableEmojis.shuffle(_rand);

    // Select unique emojis for pairs
    for (int i = 0; i < _pairsCount && i < availableEmojis.length; i++) {
      selectedEmojis.add(availableEmojis[i]);
    }

    // Assign emojis to pairs (each emoji appears exactly twice)
    int positionIndex = 0;
    for (final emoji in selectedEmojis) {
      // First occurrence
      if (positionIndex < positions.length) {
        _emojiPositions[positions[positionIndex]] = emoji;
        positionIndex++;
      }
      // Second occurrence (same emoji)
      if (positionIndex < positions.length) {
        _emojiPositions[positions[positionIndex]] = emoji;
        positionIndex++;
      }
    }

    // In advanced mode, add one red dot in remaining position
    if (_isAdvanced) {
      final remainingPositions = positions
          .where((pos) => !_emojiPositions.containsKey(pos))
          .toList();
      if (remainingPositions.isNotEmpty) {
        remainingPositions.shuffle(_rand);
        _redDotPositions = {remainingPositions.first};
      }
    } else {
      _redDotPositions.clear();
    }

    setState(() {
      _isWaitingForRound = false;
      _isShowingEmojis = true;
      _isRoundActive = false;
    });

    // After 3 seconds, hide emojis and show black boxes
    _emojiDisplayTimer = Timer(
      const Duration(milliseconds: _displayDurationMs),
      () {
        if (!mounted) return;
        _hideEmojis();
      },
    );
  }

  void _hideEmojis() {
    setState(() {
      _isShowingEmojis = false;
      _isRoundActive = true;
      _roundStartTime = DateTime.now(); // Start timing when user can tap
    });
  }

  void _handleTileTap(int index) {
    if (!_isRoundActive || _roundStartTime == null) {
      return;
    }

    // Check if already matched (stays open)
    if (_matchedPositions.contains(index)) {
      return; // Already matched, can't tap again
    }

    // Check if already opened (waiting for second tap)
    if (_openedBoxes.contains(index)) {
      return; // Already opened, waiting for match check
    }

    // In advanced mode, check if red dot was tapped
    if (_isAdvanced && _redDotPositions.contains(index)) {
      _handleRedDotTap();
      return;
    }

    // Check if this position has an emoji
    if (!_emojiPositions.containsKey(index)) {
      return; // Empty box, ignore
    }

    // Play tap sound
    SoundService.playTapSound();

    // Open this box
    setState(() {
      _openedBoxes.add(index);
    });

    // If two boxes are opened, check for match
    if (_openedBoxes.length == 2) {
      _checkMatch();
    }
  }

  void _checkMatch() {
    final firstIndex = _openedBoxes[0];
    final secondIndex = _openedBoxes[1];
    final firstEmoji = _emojiPositions[firstIndex];
    final secondEmoji = _emojiPositions[secondIndex];

    if (firstEmoji == secondEmoji) {
      // Match! Keep them open
      setState(() {
        _matchedPositions.add(firstIndex);
        _matchedPositions.add(secondIndex);
        _openedBoxes.clear();
      });

      // Check if all pairs are matched
      if (_matchedPositions.length == _pairsCount * 2) {
        _completeRound();
      }
    } else {
      // No match, close both boxes after a short delay
      _matchCheckTimer?.cancel();
      _matchCheckTimer = Timer(const Duration(milliseconds: 1000), () {
        if (mounted) {
          setState(() {
            _openedBoxes.clear();
          });
        }
      });
    }
  }

  void _handleRedDotTap() {
    // Play penalty sound for touching red dot
    SoundService.playPenaltySound();
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
    _matchCheckTimer?.cancel();

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
    _emojiDisplayTimer?.cancel();
    _matchCheckTimer?.cancel();
    _overlayTimer?.cancel();

    setState(() {
      _isPlaying = false;
      _isWaitingForRound = false;
      _isShowingEmojis = false;
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
        'memorize',
      );
      final session = GameSession(
        gameId: 'memorize',
        gameName: 'Memorize',
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
              gameName: widget.exerciseName ?? 'Memorize',
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
              final hasEmoji = _emojiPositions.containsKey(index);
              final emoji = _emojiPositions[index];
              final isRedDot = _redDotPositions.contains(index);
              final isMatched = _matchedPositions.contains(index);
              final isOpened = _openedBoxes.contains(index);
              final isShowingEmojis = _isShowingEmojis;
              final isRoundActive = _isRoundActive;

              // Determine box color and content
              Color boxColor;
              Widget? content;

              if (isShowingEmojis) {
                // Phase 1: Show all emojis and red dot (if advanced) on white boxes
                boxColor = Colors.white;
                if (hasEmoji) {
                  content = Text(emoji!, style: const TextStyle(fontSize: 32));
                } else if (isRedDot) {
                  content = Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  );
                }
              } else if (isRoundActive) {
                // Phase 2: Boxes are black, show opened ones
                if (isMatched) {
                  // Matched pairs stay open (white with emoji)
                  boxColor = Colors.white;
                  content = Text(emoji!, style: const TextStyle(fontSize: 32));
                } else if (isOpened) {
                  // Currently opened box (white with emoji or red dot)
                  boxColor = Colors.white;
                  if (hasEmoji) {
                    content = Text(
                      emoji!,
                      style: const TextStyle(fontSize: 32),
                    );
                  } else if (isRedDot) {
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
                  // Closed box (black)
                  boxColor = Colors.black;
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
    return DifficultySelector(
      isAdvanced: _isAdvanced,
      onChanged: (value) {
        setState(() {
          _isAdvanced = value;
        });
      },
      outerPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = GameState(
      isPlaying: _isPlaying,
      isWaiting: _isWaitingForRound || _isShowingEmojis,
      isRoundActive: _isRoundActive,
      currentRound: _currentRound,
      completedRounds: _completedRounds,
      errorMessage: _errorMessage,
      reactionTimeMessage: _reactionTimeMessage,
    );

    return BaseGamePage(
      config: GamePageConfig(
        gameName: 'MEMORIZE',
        categoryName: widget.categoryName ?? 'Memory',
        gameId: 'memorize',
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
          if (!s.isPlaying) return 'Memorize the emoji pairs';
          if (s.isWaiting) {
            if (_isShowingEmojis) return 'MEMORIZE THE EMOJIS!';
            return 'Wait...';
          }
          if (s.isRoundActive) {
            final matchedCount = _matchedPositions.length ~/ 2;
            return 'MATCH THE PAIRS! ($matchedCount/$_pairsCount)';
          }
          return 'Round ${s.currentRound}';
        },
        contentBuilder: (s, context) {
          // Show grid when showing emojis or when round is active
          if (_isShowingEmojis || s.isRoundActive) {
            return Positioned.fill(child: _buildGrid());
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
          if (_isShowingEmojis) return '';
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
