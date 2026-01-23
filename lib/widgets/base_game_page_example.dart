// This file demonstrates how to use BaseGamePage for creating new games
// 
// To use BaseGamePage in your game:
// 
// 1. Import the base game page:
//    import '../widgets/base_game_page.dart';
//
// 2. In your game's build method, use BaseGamePage:
//
// @override
// Widget build(BuildContext context) {
//   return BaseGamePage(
//     config: GamePageConfig(
//       gameName: 'YOUR GAME NAME',
//       categoryName: widget.categoryName ?? 'Category',
//       gameId: 'your_game_id',
//       bestSession: _bestSession,
//     ),
//     state: GameState(
//       isPlaying: _isPlaying,
//       isWaiting: _isWaitingForColor,
//       isRoundActive: _isColorVisible,
//       currentRound: _currentRound,
//       completedRounds: _completedRounds,
//       errorMessage: _errorMessage,
//       reactionTimeMessage: _reactionTimeMessage,
//     ),
//     callbacks: GameCallbacks(
//       onStart: _startGame,
//       onTap: _handleTap, // Optional
//       onReset: _resetGame,
//     ),
//     builders: GameBuilders(
//       titleBuilder: (state) {
//         if (!state.isPlaying) return 'Your game description';
//         if (state.isWaiting) return 'Wait for...';
//         if (state.isRoundActive) return 'TAP NOW!';
//         return 'Round ${state.currentRound}';
//       },
//       contentBuilder: (state, context) {
//         // Build your game-specific content here
//         return YourGameContentWidget();
//       },
//       waitingTextBuilder: (state) => 'WAIT...', // Optional
//       startButtonText: 'START', // Optional, defaults to 'START'
//     ),
//     useBackdropFilter: true, // Optional, for blur effects
//   );
// }
//
// Benefits:
// - All common UI (header, category, container, overlays) is handled automatically
// - Change styling in BaseGamePage and it updates all games
// - Consistent look and feel across all games
// - Less code duplication
