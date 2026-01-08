import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'multiplayer_config_page.dart';

class MultiplayerSpinnerPage extends StatefulWidget {
  final List<String> users;
  final int rounds;

  const MultiplayerSpinnerPage({
    super.key,
    required this.users,
    required this.rounds,
  });

  @override
  State<MultiplayerSpinnerPage> createState() => _MultiplayerSpinnerPageState();
}

class _MultiplayerSpinnerPageState extends State<MultiplayerSpinnerPage>
    with SingleTickerProviderStateMixin {
  // Track disabled rounds for each user (userIndex -> Set of disabled round numbers)
  late List<Set<int>> _disabledRounds;
  int _currentUserIndex = 0;
  bool _isSpinning = false;
  int? _blinkingRound;
  Timer? _blinkingTimer;
  Timer? _stopTimer;
  String? _winner;
  bool _isHighlighting = false;
  int? _finalSelectedRound;
  bool _shouldDisableFinalRound = false;
  late AnimationController _highlightController;
  late Animation<double> _highlightAnimation;

  @override
  void initState() {
    super.initState();
    // Initialize disabled rounds for each user
    _disabledRounds = List.generate(widget.users.length, (_) => <int>{});

    // Initialize highlight animation
    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _highlightAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _highlightController, curve: Curves.easeInOut),
    );
    _highlightController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _highlightController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        setState(() {
          _isHighlighting = false;
        });
        _proceedAfterHighlight();
      }
    });
  }

  @override
  void dispose() {
    _blinkingTimer?.cancel();
    _stopTimer?.cancel();
    _highlightController.dispose();
    super.dispose();
  }

  void _startSpinning() {
    if (_isSpinning || _winner != null) return;

    setState(() {
      _isSpinning = true;
    });

    // Get available rounds for current user (not disabled)
    final availableRounds = List.generate(widget.rounds, (index) => index + 1)
        .where((round) => !_disabledRounds[_currentUserIndex].contains(round))
        .toList();

    if (availableRounds.isEmpty) {
      // Current user has no available rounds, move to next
      _moveToNextUser();
      return;
    }

    // Get all rounds for blinking animation (including disabled ones)
    final allRounds = List.generate(widget.rounds, (index) => index + 1);

    // Start blinking animation - blink on ALL rounds (including disabled)
    _blinkingTimer?.cancel();
    _blinkingTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (mounted) {
        setState(() {
          // Randomly select any round to blink (including disabled ones for visual effect)
          _blinkingRound = allRounds[Random().nextInt(allRounds.length)];
        });
      }
    });

    // Stop after 2 seconds
    _stopTimer?.cancel();
    _stopTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        _blinkingTimer?.cancel();

        // Select final round from ALL rounds (including disabled) for excitement
        final finalRound = allRounds[Random().nextInt(allRounds.length)];

        // Check if we should disable this round
        final shouldDisable = !_disabledRounds[_currentUserIndex].contains(
          finalRound,
        );

        setState(() {
          _blinkingRound = finalRound;
          _isSpinning = false;
          _finalSelectedRound = finalRound;
          _shouldDisableFinalRound = shouldDisable;
          _isHighlighting = true;
        });

        // Start highlight animation
        _highlightController.forward();
      }
    });
  }

  void _proceedAfterHighlight() {
    if (_finalSelectedRound == null) return;

    final finalRound = _finalSelectedRound!;
    final shouldDisable = _shouldDisableFinalRound;

    setState(() {
      _finalSelectedRound = null;
    });

    // Only disable if it's not already disabled (available round)
    if (shouldDisable) {
      _disabledRounds[_currentUserIndex].add(finalRound);

      // Check if current user won (all rounds disabled)
      if (_disabledRounds[_currentUserIndex].length == widget.rounds) {
        _winner = widget.users[_currentUserIndex];
        _showWinnerDialog();
      } else {
        // Move to next user after a short delay
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _moveToNextUser();
          }
        });
      }
    } else {
      // Landed on already disabled round - just move to next user
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _moveToNextUser();
        }
      });
    }
  }

  void _moveToNextUser() {
    setState(() {
      _currentUserIndex = (_currentUserIndex + 1) % widget.users.length;
      _blinkingRound = null;
    });
  }

  void _showWinnerDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF3D3D5C),
        title: const Text(
          'Winner!',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '${_winner} wins!',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              // Navigate back to config page using pushReplacement
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const MultiplayerConfigPage(),
                ),
              );
            },
            child: const Text('OK', style: TextStyle(color: Color(0xFF6C5CE7))),
          ),
        ],
      ),
    );
  }

  void _showExitConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF3D3D5C),
        title: const Text(
          'Leave Game?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to leave the game?',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              // Navigate back to config page using pushReplacement
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const MultiplayerConfigPage(),
                ),
              );
            },
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _showExitConfirmationDialog();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF2D2D44),
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C5CE7),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: () => _showExitConfirmationDialog(),
                        ),
                      ),
                    ),
                    const Text(
                      'Multiplayer Game',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Game content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Users with their rounds - side by side
                      ...List.generate(widget.users.length, (userIndex) {
                        final user = widget.users[userIndex];
                        final isCurrentUser =
                            userIndex == _currentUserIndex &&
                            (_isSpinning || _isHighlighting);
                        final isCurrentUserSpinning =
                            userIndex == _currentUserIndex && _isSpinning;

                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Rounds display vertically
                                Column(
                                  children: List.generate(widget.rounds, (
                                    index,
                                  ) {
                                    final roundNumber = index + 1;
                                    final isDisabled =
                                        _disabledRounds[userIndex].contains(
                                          roundNumber,
                                        );
                                    final isBlinking =
                                        isCurrentUserSpinning &&
                                        _blinkingRound == roundNumber;
                                    final isHighlighting =
                                        _isHighlighting &&
                                        userIndex == _currentUserIndex &&
                                        _finalSelectedRound == roundNumber;
                                    final isHighlightedAndDisabled =
                                        isHighlighting && isDisabled;

                                    return AnimatedBuilder(
                                      animation: _highlightAnimation,
                                      builder: (context, child) {
                                        // Calculate highlight effect
                                        final highlightScale = isHighlighting
                                            ? 1.0 +
                                                  (_highlightAnimation.value *
                                                      0.3)
                                            : 1.0;
                                        final highlightOpacity = isHighlighting
                                            ? 0.5 +
                                                  (_highlightAnimation.value *
                                                      0.5)
                                            : 1.0;
                                        // Red if disabled, green if not disabled
                                        final highlightColor = isHighlighting
                                            ? isHighlightedAndDisabled
                                                  ? Color.lerp(
                                                      Colors.red,
                                                      Colors.redAccent,
                                                      _highlightAnimation.value,
                                                    )!
                                                  : Color.lerp(
                                                      Colors.green,
                                                      Colors.lightGreen,
                                                      _highlightAnimation.value,
                                                    )!
                                            : null;

                                        return Transform.scale(
                                          scale: highlightScale,
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(
                                              vertical: 4,
                                            ),
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: isHighlighting
                                                  ? highlightColor
                                                  : isBlinking
                                                  ? Colors.yellow
                                                  : isDisabled
                                                  ? Colors.grey.withOpacity(0.3)
                                                  : const Color(0xFF3D3D5C),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isHighlighting
                                                    ? Colors.white
                                                    : isBlinking
                                                    ? Colors.orange
                                                    : isDisabled
                                                    ? Colors.grey
                                                    : Colors.transparent,
                                                width: isHighlighting ? 3 : 2,
                                              ),
                                              boxShadow: isHighlighting
                                                  ? [
                                                      BoxShadow(
                                                        color: highlightColor!
                                                            .withOpacity(
                                                              highlightOpacity,
                                                            ),
                                                        blurRadius: 15,
                                                        spreadRadius: 2,
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            child: Center(
                                              child: Text(
                                                '$roundNumber',
                                                style: TextStyle(
                                                  color: isHighlighting
                                                      ? Colors.white
                                                      : isDisabled
                                                      ? Colors.grey
                                                      : Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  decoration:
                                                      isDisabled &&
                                                          !isHighlighting
                                                      ? TextDecoration
                                                            .lineThrough
                                                      : null,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  }),
                                ),
                                const SizedBox(height: 12),
                                // User name
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isCurrentUser
                                        ? const Color(0xFF6C5CE7)
                                        : const Color(0xFF3D3D5C),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isCurrentUser
                                          ? Colors.white
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isCurrentUser)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 6),
                                          child: Icon(
                                            Icons.play_arrow,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      Flexible(
                                        child: Text(
                                          user,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (_disabledRounds[userIndex].length ==
                                          widget.rounds)
                                        const Padding(
                                          padding: EdgeInsets.only(left: 6),
                                          child: Icon(
                                            Icons.emoji_events,
                                            color: Colors.amber,
                                            size: 20,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              // Start button at bottom
              Padding(
                padding: const EdgeInsets.all(20),
                child: ElevatedButton(
                  onPressed: _isSpinning || _winner != null || _isHighlighting
                      ? null
                      : _startSpinning,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isSpinning || _winner != null || _isHighlighting
                        ? Colors.grey
                        : const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: Text(
                    _isSpinning
                        ? 'Spinning...'
                        : _winner != null
                        ? 'Game Over'
                        : 'Start',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
