import 'package:flutter/material.dart';
import 'game_container.dart';
import 'category_header.dart';
import 'gradient_background.dart';
import '../game_settings.dart';
import '../theme/app_theme.dart';

/// Configuration for a game page
class GamePageConfig {
  final String gameName;
  final String categoryName;
  final String gameId;
  final int? bestSession;

  const GamePageConfig({
    required this.gameName,
    required this.categoryName,
    required this.gameId,
    this.bestSession,
  });
}

/// Game state information
class GameState {
  final bool isPlaying;
  final bool isWaiting;
  final bool isRoundActive;
  final int currentRound;
  final int completedRounds;
  final String? errorMessage;
  final String? reactionTimeMessage;

  const GameState({
    required this.isPlaying,
    required this.isWaiting,
    required this.isRoundActive,
    required this.currentRound,
    required this.completedRounds,
    this.errorMessage,
    this.reactionTimeMessage,
  });
}

/// Callbacks for game actions
class GameCallbacks {
  final VoidCallback onStart;
  final VoidCallback? onTap;
  final VoidCallback onReset;

  const GameCallbacks({
    required this.onStart,
    this.onTap,
    required this.onReset,
  });
}

/// Builder functions for dynamic content
class GameBuilders {
  /// Builds the title text based on game state
  final String Function(GameState state) titleBuilder;

  /// Builds the game content widget
  final Widget Function(GameState state, BuildContext context) contentBuilder;

  /// Optional: Builds waiting state text (defaults to "WAIT...")
  final String Function(GameState state)? waitingTextBuilder;

  /// Optional: Builds start button text (defaults to "START")
  final String? startButtonText;

  /// Optional: Builds content between title and game container
  final Widget Function(GameState state, BuildContext context)?
  middleContentBuilder;

  const GameBuilders({
    required this.titleBuilder,
    required this.contentBuilder,
    this.waitingTextBuilder,
    this.startButtonText,
    this.middleContentBuilder,
  });
}

/// A reusable base game page that provides common structure and UI
/// for all games in the app
class BaseGamePage extends StatelessWidget {
  final GamePageConfig config;
  final GameState state;
  final GameCallbacks callbacks;
  final GameBuilders builders;
  final bool useBackdropFilter;

  const BaseGamePage({
    super.key,
    required this.config,
    required this.state,
    required this.callbacks,
    required this.builders,
    this.useBackdropFilter = false,
  });

  /// Centralized style for the game label. Change here to affect all games.
  /// Game pages only provide the label text via [GameBuilders.titleBuilder].
  static TextStyle gameLabelStyle(BuildContext context) {
    return TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      color: AppTheme.textPrimary(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GradientBackground.getBackgroundColor(context),
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(context),
              // Main content
              Expanded(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // Category header
                    CategoryHeader(categoryName: config.categoryName),
                    const SizedBox(height: 4),
                    // Game label (text from game page, style from base - change here to affect all games)
                    Text(
                      builders.titleBuilder(state),
                      style: BaseGamePage.gameLabelStyle(context),
                      textAlign: TextAlign.center,
                    ),
                    // Optional middle content (between title and game container)
                    if (builders.middleContentBuilder != null) ...[
                      const SizedBox(height: 16),
                      builders.middleContentBuilder!(state, context),
                    ],
                    const SizedBox(height: 16),
                    // Game content area
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(35, 20, 35, 20),
                        child: GameContainer(
                          onTap: callbacks.onTap,
                          useBackdropFilter: useBackdropFilter,
                          child: Stack(
                            children: [
                              // Game-specific content
                              if (state.isPlaying ||
                                  state.errorMessage != null ||
                                  state.reactionTimeMessage != null)
                                builders.contentBuilder(state, context),
                              // Error message overlay
                              if (state.errorMessage != null)
                                Positioned.fill(
                                  child: Container(
                                    color: Colors.red.withOpacity(0.9),
                                    child: Center(
                                      child: Text(
                                        state.errorMessage!,
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
                              if (state.reactionTimeMessage != null)
                                Positioned.fill(
                                  child: Container(
                                    color: Colors.green.withOpacity(0.8),
                                    child: Center(
                                      child: Text(
                                        state.reactionTimeMessage!,
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
                              if (!state.isPlaying &&
                                  state.errorMessage == null &&
                                  state.reactionTimeMessage == null)
                                Center(
                                  child: GestureDetector(
                                    onTap: callbacks.onStart,
                                    child: Text(
                                      builders.startButtonText ?? 'START',
                                      style: TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 4.0,
                                        color: AppTheme.iconColor(context),
                                      ),
                                    ),
                                  ),
                                ),
                              // Waiting state
                              if (state.isPlaying &&
                                  state.isWaiting &&
                                  !state.isRoundActive &&
                                  state.errorMessage == null &&
                                  state.reactionTimeMessage == null)
                                Center(
                                  child: Text(
                                    builders.waitingTextBuilder?.call(state) ??
                                        'WAIT...',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.textSecondary(context),
                                      letterSpacing: 4.0,
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
                    if (config.bestSession != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Builder(
                          builder: (context) {
                            final isDark = AppTheme.isDark(context);
                            const accentColor = Color(0xFF8B5CF6);
                            const lightBackgroundColor = Color(0xFFEDE9FE);
                            final backgroundColor = isDark
                                ? Color.alphaBlend(
                                    accentColor.withOpacity(0.12),
                                    AppTheme.cardColor(context),
                                  )
                                : lightBackgroundColor;
                            final borderColor = isDark
                                ? AppTheme.borderColor(context)
                                : Colors.white.withOpacity(0.5);
                            final shadowColor = AppTheme.shadowColor(
                              opacity: isDark ? 0.3 : 0.05,
                            );

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: backgroundColor,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: borderColor,
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: shadowColor,
                                    blurRadius: 0,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                'BEST SESSION: ${config.bestSession}ms',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary(context),
                                  letterSpacing: 1.0,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            style: IconButton.styleFrom(backgroundColor: Colors.transparent),
          ),
          const Spacer(),
          Text(
            config.gameName.toUpperCase(),
            textAlign: .left,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
              color: AppTheme.textSecondary(context),
            ),
          ),
          const Spacer(),
          ValueListenableBuilder<int>(
            valueListenable: GameSettings.repetitionsNotifier,
            builder: (context, numberOfRepetitions, _) {
              return Row(
                children: [
                  Text(
                    state.isPlaying
                        ? '${state.completedRounds} / $numberOfRepetitions'
                        : '0 / $numberOfRepetitions',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: Icon(
                      Icons.refresh,
                      color: AppTheme.iconColor(context),
                    ),
                    onPressed: callbacks.onReset,
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.buttonBackground(context),
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
    );
  }
}
